from sqlite3 import connect, Row
from pathlib import Path
from datetime import datetime

DB_PATH = Path.home() / ".claude" / "pipeline" / "pipeline.db"

PHASES = ["requirements", "spec", "tests", "implementation", "mutation", "done"]

SCHEMA = """
CREATE TABLE IF NOT EXISTS projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    path TEXT,
    createdAt TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    projectId TEXT NOT NULL REFERENCES projects(id),
    title TEXT NOT NULL,
    description TEXT,
    type TEXT DEFAULT 'feature',
    status TEXT DEFAULT 'pendente',
    phase TEXT DEFAULT 'requirements',
    createdAt TEXT DEFAULT (datetime('now')),
    updatedAt TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS phaseTransitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    taskId TEXT NOT NULL REFERENCES tasks(id),
    fromPhase TEXT,
    toPhase TEXT NOT NULL,
    reason TEXT,
    timestamp TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS earsRequirements (
    id TEXT NOT NULL,
    taskId TEXT NOT NULL REFERENCES tasks(id),
    pattern TEXT NOT NULL,
    text TEXT NOT NULL,
    approved INTEGER DEFAULT 0,
    approvedAt TEXT,
    sequence INTEGER NOT NULL,
    PRIMARY KEY (taskId, id)
);

CREATE TABLE IF NOT EXISTS acceptanceCriteria (
    id TEXT NOT NULL,
    taskId TEXT NOT NULL REFERENCES tasks(id),
    earsId TEXT NOT NULL,
    scenarioName TEXT NOT NULL,
    givenText TEXT,
    whenText TEXT,
    thenText TEXT NOT NULL,
    testMethod TEXT,
    testQuality TEXT,
    reviewedAt TEXT,
    approved INTEGER DEFAULT 0,
    sequence INTEGER NOT NULL,
    PRIMARY KEY (taskId, id)
);

CREATE TABLE IF NOT EXISTS testResults (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    taskId TEXT NOT NULL REFERENCES tasks(id),
    testMethod TEXT NOT NULL,
    passed INTEGER NOT NULL,
    runAt TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS mutationResults (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    taskId TEXT NOT NULL REFERENCES tasks(id),
    totalMutants INTEGER NOT NULL,
    killed INTEGER NOT NULL,
    score REAL NOT NULL,
    runAt TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS incidents (
    taskId TEXT PRIMARY KEY REFERENCES tasks(id),
    severity TEXT NOT NULL,
    level TEXT NOT NULL,
    currentBehavior TEXT,
    expectedBehavior TEXT,
    rootCause TEXT,
    rootCauseConfidence TEXT
);
"""

def getConn():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = connect(str(DB_PATH))
    conn.row_factory = Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn

def initDb():
    with getConn() as conn:
        conn.executescript(SCHEMA)
        # Migrations para bancos existentes
        for migration in (
            "ALTER TABLE acceptanceCriteria ADD COLUMN testQuality TEXT",
            "ALTER TABLE acceptanceCriteria ADD COLUMN reviewedAt TEXT",
        ):
            try:
                conn.execute(migration)
            except Exception:
                pass  # Coluna já existe

# --- Projects ---

def ensureProject(name, path=None):
    projectId = name.lower().replace(" ", "-").replace("/", "-")
    with getConn() as conn:
        existing = conn.execute("SELECT id FROM projects WHERE id = ?", (projectId,)).fetchone()
        if not existing:
            conn.execute(
                "INSERT INTO projects (id, name, path) VALUES (?, ?, ?)",
                (projectId, name, path),
            )
    return projectId

def detectProject():
    import subprocess
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            projectPath = result.stdout.strip()
            projectName = Path(projectPath).name
            return ensureProject(projectName, projectPath)
    except Exception:
        pass
    projectName = Path(".").resolve().name
    return ensureProject(projectName, str(Path(".").resolve()))

def listProjects():
    with getConn() as conn:
        return [dict(row) for row in conn.execute("SELECT * FROM projects ORDER BY name").fetchall()]

# --- Tasks ---

def nextTaskId():
    with getConn() as conn:
        row = conn.execute(
            "SELECT id FROM tasks ORDER BY CAST(SUBSTR(id, 2) AS INTEGER) DESC LIMIT 1"
        ).fetchone()
        if not row:
            return "T1"
        return "T{0}".format(int(row["id"][1:]) + 1)

def createTask(projectId, title, description=None, taskType="feature"):
    taskId = nextTaskId()
    with getConn() as conn:
        conn.execute(
            "INSERT INTO tasks (id, projectId, title, description, type) VALUES (?, ?, ?, ?, ?)",
            (taskId, projectId, title, description, taskType),
        )
        conn.execute(
            "INSERT INTO phaseTransitions (taskId, fromPhase, toPhase, reason) VALUES (?, NULL, 'requirements', 'task created')",
            (taskId,),
        )
    return taskId

def getTask(taskId):
    with getConn() as conn:
        row = conn.execute(
            "SELECT t.*, p.name as projectName FROM tasks t JOIN projects p ON t.projectId = p.id WHERE t.id = ?",
            (taskId,),
        ).fetchone()
        return dict(row) if row else None

def listTasks(projectId=None, status=None, phase=None):
    query = "SELECT t.*, p.name as projectName FROM tasks t JOIN projects p ON t.projectId = p.id WHERE 1=1"
    params = []
    if projectId:
        query += " AND t.projectId = ?"
        params.append(projectId)
    if status:
        query += " AND t.status = ?"
        params.append(status)
    if phase:
        query += " AND t.phase = ?"
        params.append(phase)
    query += " ORDER BY CAST(SUBSTR(t.id, 2) AS INTEGER)"
    with getConn() as conn:
        return [dict(row) for row in conn.execute(query, params).fetchall()]

def updateTask(taskId, **kwargs):
    allowed = {"status", "description", "title", "type"}
    updates = {k: v for k, v in kwargs.items() if k in allowed and v is not None}
    if not updates:
        return
    updates["updatedAt"] = datetime.now().isoformat()
    setClauses = ", ".join("{0} = ?".format(k) for k in updates)
    with getConn() as conn:
        conn.execute(
            "UPDATE tasks SET {0} WHERE id = ?".format(setClauses),
            list(updates.values()) + [taskId],
        )

# --- Phase transitions ---

def advancePhase(taskId, toPhase, reason=None):
    if toPhase not in PHASES:
        raise ValueError("Fase inválida: {0}. Válidas: {1}".format(toPhase, ", ".join(PHASES)))
    task = getTask(taskId)
    if not task:
        raise ValueError("Task {0} não encontrada".format(taskId))
    currentIdx = PHASES.index(task["phase"])
    targetIdx = PHASES.index(toPhase)
    if targetIdx != currentIdx + 1:
        nextPhase = PHASES[currentIdx + 1] if currentIdx + 1 < len(PHASES) else "done"
        raise ValueError(
            "Não é possível avançar de '{0}' para '{1}'. Próxima fase: '{2}'".format(
                task["phase"], toPhase, nextPhase
            )
        )
    # Gate: tests → implementation requer qualidade de testes avaliada
    if task["phase"] == "tests" and toPhase == "implementation":
        criteria = listCriteria(taskId)
        withMethod = [c for c in criteria if c.get("testMethod")]
        unreviewed = [c for c in withMethod if c.get("testQuality") not in ("ACCEPTABLE", "STRONG")]
        if unreviewed:
            ids = ", ".join(c["id"] for c in unreviewed)
            raise ValueError(
                "Gate de qualidade de testes: {0} critério(s) sem qualidade ACCEPTABLE ou STRONG ({1}). "
                "Use: pipeline criterion set-quality {2} <ID> ACCEPTABLE|STRONG".format(
                    len(unreviewed), ids, taskId
                )
            )
    with getConn() as conn:
        conn.execute(
            "UPDATE tasks SET phase = ?, updatedAt = datetime('now') WHERE id = ?",
            (toPhase, taskId),
        )
        conn.execute(
            "INSERT INTO phaseTransitions (taskId, fromPhase, toPhase, reason) VALUES (?, ?, ?, ?)",
            (taskId, task["phase"], toPhase, reason),
        )

def getPhaseHistory(taskId):
    with getConn() as conn:
        return [dict(row) for row in conn.execute(
            "SELECT * FROM phaseTransitions WHERE taskId = ? ORDER BY timestamp",
            (taskId,),
        ).fetchall()]

# --- EARS Requirements ---

def nextEarsId(taskId):
    with getConn() as conn:
        row = conn.execute(
            "SELECT id FROM earsRequirements WHERE taskId = ? ORDER BY sequence DESC LIMIT 1",
            (taskId,),
        ).fetchone()
        if not row:
            return "R01", 1
        n = int(row["id"][1:])
        return "R{0:02d}".format(n + 1), n + 1

def addEars(taskId, pattern, text):
    reqId, seq = nextEarsId(taskId)
    with getConn() as conn:
        conn.execute(
            "INSERT INTO earsRequirements (id, taskId, pattern, text, sequence) VALUES (?, ?, ?, ?, ?)",
            (reqId, taskId, pattern, text, seq),
        )
    return reqId

def listEars(taskId):
    with getConn() as conn:
        return [dict(row) for row in conn.execute(
            "SELECT * FROM earsRequirements WHERE taskId = ? ORDER BY sequence",
            (taskId,),
        ).fetchall()]

def approveEars(taskId, reqId):
    with getConn() as conn:
        conn.execute(
            "UPDATE earsRequirements SET approved = 1, approvedAt = datetime('now') WHERE taskId = ? AND id = ?",
            (taskId, reqId),
        )

def approveAllEars(taskId):
    with getConn() as conn:
        conn.execute(
            "UPDATE earsRequirements SET approved = 1, approvedAt = datetime('now') WHERE taskId = ?",
            (taskId,),
        )

# --- Acceptance Criteria ---

def nextCriterionId(taskId):
    with getConn() as conn:
        row = conn.execute(
            "SELECT id FROM acceptanceCriteria WHERE taskId = ? ORDER BY sequence DESC LIMIT 1",
            (taskId,),
        ).fetchone()
        if not row:
            return "C01", 1
        n = int(row["id"][1:])
        return "C{0:02d}".format(n + 1), n + 1

def addCriterion(taskId, earsId, scenarioName, thenText, givenText=None, whenText=None, testMethod=None):
    cId, seq = nextCriterionId(taskId)
    with getConn() as conn:
        conn.execute(
            "INSERT INTO acceptanceCriteria (id, taskId, earsId, scenarioName, givenText, whenText, thenText, testMethod, sequence) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (cId, taskId, earsId, scenarioName, givenText, whenText, thenText, testMethod, seq),
        )
    return cId

def listCriteria(taskId):
    with getConn() as conn:
        return [dict(row) for row in conn.execute(
            "SELECT * FROM acceptanceCriteria WHERE taskId = ? ORDER BY sequence",
            (taskId,),
        ).fetchall()]

def approveCriterion(taskId, criterionId):
    with getConn() as conn:
        conn.execute(
            "UPDATE acceptanceCriteria SET approved = 1 WHERE taskId = ? AND id = ?",
            (taskId, criterionId),
        )

def approveAllCriteria(taskId):
    with getConn() as conn:
        conn.execute(
            "UPDATE acceptanceCriteria SET approved = 1 WHERE taskId = ?",
            (taskId,),
        )

def setTestQuality(taskId, criterionId, quality):
    with getConn() as conn:
        conn.execute(
            "UPDATE acceptanceCriteria SET testQuality = ?, reviewedAt = datetime('now') WHERE taskId = ? AND id = ?",
            (quality, taskId, criterionId),
        )

# --- Test Results ---

def recordTest(taskId, testMethod, passed):
    with getConn() as conn:
        conn.execute(
            "INSERT INTO testResults (taskId, testMethod, passed) VALUES (?, ?, ?)",
            (taskId, testMethod, 1 if passed else 0),
        )

def getTestSummary(taskId):
    with getConn() as conn:
        rows = conn.execute(
            """
            SELECT testMethod, passed, runAt
            FROM testResults
            WHERE taskId = ? AND id IN (
                SELECT MAX(id) FROM testResults WHERE taskId = ? GROUP BY testMethod
            )
            ORDER BY testMethod
            """,
            (taskId, taskId),
        ).fetchall()
    total = len(rows)
    passed = sum(1 for r in rows if r["passed"])
    return {
        "total": total,
        "passed": passed,
        "failed": total - passed,
        "methods": [dict(r) for r in rows],
    }

def getLatestTestResult(taskId, testMethod):
    if not testMethod:
        return None
    with getConn() as conn:
        row = conn.execute(
            "SELECT passed FROM testResults WHERE taskId = ? AND testMethod = ? ORDER BY runAt DESC LIMIT 1",
            (taskId, testMethod),
        ).fetchone()
        return row["passed"] if row else None

# --- Mutation Results ---

def recordMutation(taskId, totalMutants, killed):
    score = (killed / totalMutants * 100) if totalMutants > 0 else 0.0
    with getConn() as conn:
        conn.execute(
            "INSERT INTO mutationResults (taskId, totalMutants, killed, score) VALUES (?, ?, ?, ?)",
            (taskId, totalMutants, killed, score),
        )

def getLatestMutation(taskId):
    with getConn() as conn:
        row = conn.execute(
            "SELECT * FROM mutationResults WHERE taskId = ? ORDER BY runAt DESC LIMIT 1",
            (taskId,),
        ).fetchone()
        return dict(row) if row else None

# --- Incidents ---

def createIncident(taskId, severity, level, currentBehavior=None, expectedBehavior=None):
    with getConn() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO incidents (taskId, severity, level, currentBehavior, expectedBehavior) VALUES (?, ?, ?, ?, ?)",
            (taskId, severity, level, currentBehavior, expectedBehavior),
        )

def updateIncident(taskId, **kwargs):
    allowed = {"rootCause", "rootCauseConfidence", "currentBehavior", "expectedBehavior"}
    updates = {k: v for k, v in kwargs.items() if k in allowed and v is not None}
    if not updates:
        return
    setClauses = ", ".join("{0} = ?".format(k) for k in updates)
    with getConn() as conn:
        conn.execute(
            "UPDATE incidents SET {0} WHERE taskId = ?".format(setClauses),
            list(updates.values()) + [taskId],
        )

# --- Audit ---

def getTaskAudit(taskId):
    task = getTask(taskId)
    if not task:
        return None
    ears = listEars(taskId)
    criteria = listCriteria(taskId)
    testSummary = getTestSummary(taskId)
    mutation = getLatestMutation(taskId)
    phaseHistory = getPhaseHistory(taskId)

    earsApproved = len(ears) > 0 and all(r["approved"] for r in ears)
    criteriaApproved = len(criteria) > 0 and all(c["approved"] for c in criteria)
    traceabilityOk = len(ears) > 0 and len(criteria) > 0 and all(
        any(c["earsId"] == r["id"] for c in criteria)
        for r in ears
    )
    testsOk = testSummary["total"] > 0 and testSummary["failed"] == 0

    # Gate de qualidade: cada critério com testMethod deve ter qualidade ACCEPTABLE ou STRONG
    withMethod = [c for c in criteria if c.get("testMethod")]
    testQualityOk = len(withMethod) > 0 and all(
        c.get("testQuality") in ("ACCEPTABLE", "STRONG") for c in withMethod
    )
    qualityStrong = sum(1 for c in withMethod if c.get("testQuality") == "STRONG")
    qualityAcceptable = sum(1 for c in withMethod if c.get("testQuality") == "ACCEPTABLE")
    qualityWeak = sum(1 for c in withMethod if c.get("testQuality") == "WEAK")
    qualityNone = sum(1 for c in withMethod if not c.get("testQuality"))

    mutationOk = mutation is not None and mutation["score"] >= 100.0

    gates = {
        "requirements": {
            "pass": earsApproved,
            "detail": "{0} EARS, {1} aprovados".format(
                len(ears), sum(1 for r in ears if r["approved"])
            ),
        },
        "spec": {
            "pass": criteriaApproved,
            "detail": "{0} cenários, {1} aprovados".format(
                len(criteria), sum(1 for c in criteria if c["approved"])
            ),
        },
        "traceability": {
            "pass": traceabilityOk,
            "detail": "cada EARS tem ≥1 cenário" if traceabilityOk else "EARS sem cenário detectado",
        },
        "tests": {
            "pass": testsOk,
            "detail": "{0} testes — {1} passando, {2} falhando".format(
                testSummary["total"], testSummary["passed"], testSummary["failed"]
            ),
        },
        "testQuality": {
            "pass": testQualityOk,
            "detail": "{0} revisados — {1} STRONG, {2} ACCEPTABLE, {3} WEAK, {4} sem revisão".format(
                len(withMethod), qualityStrong, qualityAcceptable, qualityWeak, qualityNone,
            ) if withMethod else "nenhum critério com testMethod",
        },
        "mutation": {
            "pass": mutationOk,
            "detail": "{0:.0f}% ({1}/{2})".format(
                mutation["score"] if mutation else 0,
                mutation["killed"] if mutation else "—",
                mutation["totalMutants"] if mutation else "—",
            ),
        },
    }

    return {
        "task": task,
        "gates": gates,
        "ears": ears,
        "criteria": criteria,
        "testSummary": testSummary,
        "mutation": mutation,
        "phaseHistory": phaseHistory,
    }
