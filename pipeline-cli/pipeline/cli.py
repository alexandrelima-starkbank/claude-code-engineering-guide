import sys
import click
from json import dumps
from pathlib import Path

from .db import (
    initDb, detectProject, ensureProject, listProjects,
    createTask, getTask, listTasks, updateTask,
    advancePhase, getPhaseHistory, PHASES,
    addEars, listEars, approveEars, approveAllEars,
    addCriterion, listCriteria, approveCriterion, approveAllCriteria,
    setTestQuality,
    recordTest, getTestSummary,
    recordMutation, getLatestMutation,
    createIncident, updateIncident,
    getTaskAudit,
)
from .export import generateTasksMd, formatTask
from . import vector


def autoRegenTasksMd():
    import subprocess
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            return
        gitRoot = result.stdout.strip()
        tasksPath = Path(gitRoot) / "TASKS.md"
        if not tasksPath.exists():
            return
        projectName = Path(gitRoot).name
        projectId = ensureProject(projectName, gitRoot)
        content = generateTasksMd(projectId=projectId)
        tasksPath.write_text(content, encoding="utf-8")
    except Exception:
        pass


@click.group()
def cli():
    initDb()


# ─── PROJECT ──────────────────────────────────────────────────────────────────

@cli.group()
def project():
    """Gerenciar projetos."""
    pass


@project.command("list")
def projectList():
    for p in listProjects():
        click.echo("{0:<20} {1}".format(p["id"], p.get("path") or ""))


# ─── TASK ─────────────────────────────────────────────────────────────────────

@cli.group()
def task():
    """Gerenciar tarefas."""
    pass


@task.command("create")
@click.option("--project", "project_name", default=None, help="Nome do projeto. Detecta via git se omitido.")
@click.option("--title", required=True, help="Título da tarefa.")
@click.option("--description", default=None)
@click.option("--type", "task_type", default="feature", type=click.Choice(["feature", "incident"]))
def taskCreate(project_name, title, description, task_type):
    projectId = ensureProject(project_name) if project_name else detectProject()
    taskId = createTask(projectId, title, description, task_type)
    click.echo(taskId)
    autoRegenTasksMd()


@task.command("list")
@click.option("--project", "project_name", default=None)
@click.option("--status", default=None)
@click.option("--phase", default=None)
@click.option("--format", "fmt", default="table", type=click.Choice(["table", "json", "context"]))
def taskList(project_name, status, phase, fmt):
    projectId = ensureProject(project_name) if project_name else None
    tasks = listTasks(projectId=projectId, status=status, phase=phase)
    if fmt == "json":
        click.echo(dumps(tasks, ensure_ascii=False, indent=2))
        return
    if fmt == "context":
        for t in tasks:
            click.echo("[{0}] {1} | fase: {2} | status: {3} | projeto: {4}".format(
                t["id"], t["title"], t["phase"], t["status"],
                t.get("projectName", t["projectId"]),
            ))
        return
    if not tasks:
        click.echo("Nenhuma tarefa.")
        return
    click.echo("{:<6} {:<38} {:<16} {:<16} {}".format("ID", "Título", "Fase", "Status", "Projeto"))
    click.echo("-" * 92)
    for t in tasks:
        click.echo("{:<6} {:<38} {:<16} {:<16} {}".format(
            t["id"], t["title"][:38], t["phase"], t["status"],
            t.get("projectName", t["projectId"]),
        ))


@task.command("show")
@click.argument("task_id")
@click.option("--format", "fmt", default="markdown", type=click.Choice(["markdown", "json"]))
def taskShow(task_id, fmt):
    if fmt == "json":
        t = getTask(task_id)
        if not t:
            click.echo("Task {0} não encontrada.".format(task_id), err=True)
            sys.exit(1)
        click.echo(dumps(t, ensure_ascii=False, indent=2))
    else:
        md = formatTask(task_id)
        if not md:
            click.echo("Task {0} não encontrada.".format(task_id), err=True)
            sys.exit(1)
        click.echo(md)


@task.command("update")
@click.argument("task_id")
@click.option("--status", default=None)
@click.option("--description", default=None)
@click.option("--title", default=None)
def taskUpdateCmd(task_id, status, description, title):
    updateTask(task_id, status=status, description=description, title=title)
    click.echo("{0} atualizado.".format(task_id))
    autoRegenTasksMd()


# ─── PHASE ────────────────────────────────────────────────────────────────────

@cli.group()
def phase():
    """Controlar fases da pipeline."""
    pass


@phase.command("advance")
@click.argument("task_id")
@click.option("--to", "to_phase", required=True, type=click.Choice(PHASES))
@click.option("--reason", default=None)
def phaseAdvance(task_id, to_phase, reason):
    try:
        advancePhase(task_id, to_phase, reason)
        click.echo("{0} → fase: {1}".format(task_id, to_phase))
        autoRegenTasksMd()
    except ValueError as e:
        click.echo("ERRO: {0}".format(e), err=True)
        sys.exit(1)


@phase.command("history")
@click.argument("task_id")
def phaseHistoryCmd(task_id):
    rows = getPhaseHistory(task_id)
    if not rows:
        click.echo("Sem histórico de fases para {0}.".format(task_id))
        return
    for row in rows:
        fromPhase = row.get("fromPhase") or "—"
        reason = "  ({0})".format(row["reason"]) if row.get("reason") else ""
        click.echo("{0}  {1} → {2}{3}".format(row["timestamp"], fromPhase, row["toPhase"], reason))


# ─── EARS ─────────────────────────────────────────────────────────────────────

@cli.group()
def ears():
    """Gerenciar requisitos EARS."""
    pass


@ears.command("add")
@click.argument("task_id")
@click.option("--pattern", required=True,
              type=click.Choice(["ubiquitous", "event", "state", "unwanted", "optional"]))
@click.option("--text", required=True)
def earsAdd(task_id, pattern, text):
    reqId = addEars(task_id, pattern, text)
    t = getTask(task_id)
    if t:
        vector.addRequirement(task_id, reqId, text, t["projectId"])
    click.echo(reqId)
    autoRegenTasksMd()


@ears.command("list")
@click.argument("task_id")
@click.option("--format", "fmt", default="table", type=click.Choice(["table", "json"]))
def earsList(task_id, fmt):
    reqs = listEars(task_id)
    if fmt == "json":
        click.echo(dumps(reqs, ensure_ascii=False, indent=2))
        return
    if not reqs:
        click.echo("Nenhum requisito EARS para {0}.".format(task_id))
        return
    for r in reqs:
        approved = "✓" if r["approved"] else " "
        click.echo("[{0}][{1}] ({2}) {3}".format(r["id"], approved, r["pattern"], r["text"]))


@ears.command("approve")
@click.argument("task_id")
@click.argument("req_id", default="all")
def earsApprove(task_id, req_id):
    if req_id == "all":
        approveAllEars(task_id)
        click.echo("Todos os EARS aprovados para {0}.".format(task_id))
    else:
        approveEars(task_id, req_id)
        click.echo("{0} aprovado.".format(req_id))
    autoRegenTasksMd()


# ─── CRITERION ────────────────────────────────────────────────────────────────

@cli.group()
def criterion():
    """Gerenciar critérios de aceite (BDD)."""
    pass


@criterion.command("add")
@click.argument("task_id")
@click.option("--ears", "ears_id", required=True, help="ID do requisito EARS de origem (ex: R01)")
@click.option("--scenario", required=True, help="Nome do cenário")
@click.option("--given", "given_text", default=None)
@click.option("--when", "when_text", default=None)
@click.option("--then", "then_text", required=True)
@click.option("--test", "test_method", default=None, help="Nome do método de teste")
def criterionAdd(task_id, ears_id, scenario, given_text, when_text, then_text, test_method):
    cId = addCriterion(task_id, ears_id, scenario, then_text, given_text, when_text, test_method)
    click.echo(cId)
    autoRegenTasksMd()


@criterion.command("list")
@click.argument("task_id")
@click.option("--format", "fmt", default="table", type=click.Choice(["table", "json"]))
def criterionList(task_id, fmt):
    criteria = listCriteria(task_id)
    if fmt == "json":
        click.echo(dumps(criteria, ensure_ascii=False, indent=2))
        return
    if not criteria:
        click.echo("Nenhum critério para {0}.".format(task_id))
        return
    for c in criteria:
        approved = "✓" if c["approved"] else " "
        click.echo("[{0}][{1}] ← {2} | {3} → `{4}`".format(
            c["id"], approved, c["earsId"], c["scenarioName"], c.get("testMethod") or "?"
        ))


@criterion.command("set-quality")
@click.argument("task_id")
@click.argument("criterion_id")
@click.argument("quality", type=click.Choice(["WEAK", "ACCEPTABLE", "STRONG"]))
def criterionSetQuality(task_id, criterion_id, quality):
    """Registra a qualidade do teste associado ao critério (WEAK/ACCEPTABLE/STRONG)."""
    setTestQuality(task_id, criterion_id, quality)
    click.echo("{0} qualidade: {1}".format(criterion_id, quality))
    autoRegenTasksMd()


@criterion.command("approve")
@click.argument("task_id")
@click.argument("criterion_id", default="all")
def criterionApprove(task_id, criterion_id):
    if criterion_id == "all":
        approveAllCriteria(task_id)
        click.echo("Todos os critérios aprovados para {0}.".format(task_id))
    else:
        approveCriterion(task_id, criterion_id)
        click.echo("{0} aprovado.".format(criterion_id))
    autoRegenTasksMd()


# ─── TEST ─────────────────────────────────────────────────────────────────────

@cli.group()
def test():
    """Registrar resultados de testes."""
    pass


@test.command("record")
@click.argument("task_id")
@click.option("--method", required=True, help="Nome do método de teste")
@click.option("--passed/--failed", default=True)
def testRecord(task_id, method, passed):
    recordTest(task_id, method, passed)
    click.echo("{0} → {1}".format(method, "✓ passou" if passed else "✗ falhou"))
    autoRegenTasksMd()


@test.command("summary")
@click.argument("task_id")
def testSummaryCmd(task_id):
    summary = getTestSummary(task_id)
    click.echo("Total: {0}  Passou: {1}  Falhou: {2}".format(
        summary["total"], summary["passed"], summary["failed"]
    ))
    for m in summary["methods"]:
        icon = "✓" if m["passed"] else "✗"
        click.echo("  [{0}] {1}".format(icon, m["testMethod"]))


# ─── MUTATION ─────────────────────────────────────────────────────────────────

@cli.group()
def mutation():
    """Registrar resultados de mutation testing."""
    pass


@mutation.command("record")
@click.argument("task_id")
@click.option("--total", "total_mutants", required=True, type=int)
@click.option("--killed", required=True, type=int)
def mutationRecord(task_id, total_mutants, killed):
    recordMutation(task_id, total_mutants, killed)
    score = (killed / total_mutants * 100) if total_mutants > 0 else 0.0
    click.echo("{0:.0f}% ({1}/{2} mutantes mortos)".format(score, killed, total_mutants))
    autoRegenTasksMd()


# ─── INCIDENT ─────────────────────────────────────────────────────────────────

@cli.group()
def incident():
    """Gerenciar incidentes N3/N4."""
    pass


@incident.command("create")
@click.argument("task_id")
@click.option("--severity", required=True, type=click.Choice(["crítico", "alto", "médio", "baixo"]))
@click.option("--level", required=True, type=click.Choice(["N3", "N4"]))
@click.option("--current", "current_behavior", default=None)
@click.option("--expected", "expected_behavior", default=None)
def incidentCreate(task_id, severity, level, current_behavior, expected_behavior):
    createIncident(task_id, severity, level, current_behavior, expected_behavior)
    click.echo("Incidente registrado para {0}.".format(task_id))


@incident.command("update")
@click.argument("task_id")
@click.option("--root-cause", "root_cause", default=None)
@click.option("--confidence", "root_cause_confidence", default=None,
              type=click.Choice(["alta", "média", "baixa"]))
def incidentUpdate(task_id, root_cause, root_cause_confidence):
    updateIncident(task_id, rootCause=root_cause, rootCauseConfidence=root_cause_confidence)
    click.echo("{0} atualizado.".format(task_id))


# ─── AUDIT ────────────────────────────────────────────────────────────────────

@cli.command("audit")
@click.argument("task_id", default=None, required=False)
@click.option("--project", "project_name", default=None)
def audit(task_id, project_name):
    """Auditoria completa da pipeline. Sem argumento: audita todas as tarefas."""
    if task_id:
        _auditOne(task_id)
    else:
        projectId = ensureProject(project_name) if project_name else None
        tasks = listTasks(projectId=projectId)
        if not tasks:
            click.echo("Nenhuma tarefa encontrada.")
            return
        click.echo("{:<6} {:<35} {:<16} {:<12} {}".format("ID", "Título", "Fase", "Status", "Gates"))
        click.echo("-" * 88)
        for t in tasks:
            data = getTaskAudit(t["id"])
            if not data:
                continue
            passCount = sum(1 for g in data["gates"].values() if g["pass"])
            total = len(data["gates"])
            gateStr = "{0}/{1} PASS".format(passCount, total)
            ready = "READY ✓" if passCount == total else "NOT READY"
            click.echo("{:<6} {:<35} {:<16} {:<12} {:<12} {}".format(
                t["id"], t["title"][:35], t["phase"], t["status"], gateStr, ready
            ))


def _auditOne(taskId):
    data = getTaskAudit(taskId)
    if not data:
        click.echo("Task {0} não encontrada.".format(taskId), err=True)
        sys.exit(1)

    task = data["task"]
    click.echo("\n=== PIPELINE AUDIT: {0} — {1} ===\n".format(task["id"], task["title"]))
    click.echo("Projeto: {0}   Fase: {1}   Status: {2}".format(
        task.get("projectName", task["projectId"]), task["phase"], task["status"]
    ))
    click.echo("")

    allPass = True
    for gateName, gate in data["gates"].items():
        icon = "PASS ✓" if gate["pass"] else "FAIL ✗"
        click.echo("  {0:<14} {1}   {2}".format(gateName.upper(), icon, gate["detail"]))
        if not gate["pass"]:
            allPass = False

    click.echo("")
    if allPass:
        click.echo("Resultado: READY ✓")
    else:
        click.echo("Resultado: NOT READY ✗")
        click.echo("\nGates pendentes:")
        for gateName, gate in data["gates"].items():
            if not gate["pass"]:
                click.echo("  • {0}: {1}".format(gateName, gate["detail"]))

    click.echo("\nHistórico de fases:")
    for row in data["phaseHistory"]:
        fromPhase = row.get("fromPhase") or "—"
        reason = " ({0})".format(row["reason"]) if row.get("reason") else ""
        click.echo("  {0}  {1} → {2}{3}".format(row["timestamp"], fromPhase, row["toPhase"], reason))


# ─── CONTEXT ──────────────────────────────────────────────────────────────────

@cli.group()
def context():
    """Contexto semântico via ChromaDB."""
    pass


@context.command("add")
@click.option("--text", required=True)
@click.option("--type", "context_type", required=True, type=click.Choice(["decision", "lesson", "context"]))
@click.option("--project", "project_name", default=None)
@click.option("--task", "task_id", default=None)
def contextAdd(text, context_type, project_name, task_id):
    if not vector.isAvailable():
        click.echo("ChromaDB não disponível. Instale: pip install chromadb", err=True)
        sys.exit(1)
    projectId = ensureProject(project_name) if project_name else None
    vector.addContext(text, context_type, projectId, task_id)
    click.echo("Contexto ({0}) adicionado.".format(context_type))


@context.command("search")
@click.argument("query")
@click.option("--project", "project_name", default=None)
@click.option("--type", "context_type", default=None, type=click.Choice(["decision", "lesson", "context"]))
@click.option("--n", default=5, type=int)
def contextSearch(query, project_name, context_type, n):
    if not vector.isAvailable():
        click.echo("ChromaDB não disponível.", err=True)
        sys.exit(1)
    projectId = ensureProject(project_name) if project_name else None

    reqResults = vector.searchRequirements(query, projectId=projectId, n=n)
    ctxResults = vector.searchContext(query, contextType=context_type, projectId=projectId, n=n)

    if not reqResults and not ctxResults:
        click.echo("Nenhum resultado para: {0}".format(query))
        return

    if reqResults:
        click.echo("\n── Requisitos similares ──")
        for r in reqResults:
            meta = r["metadata"]
            click.echo("  [{0}:{1}] {2}".format(meta.get("taskId", "?"), meta.get("reqId", "?"), r["text"][:120]))

    if ctxResults:
        click.echo("\n── Contexto relevante ──")
        for r in ctxResults:
            meta = r["metadata"]
            click.echo("  [{0}] {1}".format(meta.get("type", "?"), r["text"][:150]))


# ─── EXPORT ───────────────────────────────────────────────────────────────────

@cli.group()
def export():
    """Exportar views a partir do banco de dados."""
    pass


@export.command("tasks-md")
@click.option("--project", "project_name", default=None)
@click.option("--task", "task_id", default=None)
@click.option("--output", default=None, help="Caminho do arquivo. Padrão: stdout.")
def exportTasksMd(project_name, task_id, output):
    if task_id:
        projectId = None
    elif project_name:
        projectId = ensureProject(project_name)
    else:
        projectId = detectProject()

    content = generateTasksMd(projectId=projectId, taskId=task_id)

    if output:
        Path(output).write_text(content, encoding="utf-8")
        click.echo("TASKS.md gerado em {0}".format(output))
    else:
        click.echo(content)


@export.command("metrics")
@click.option("--project", "project_name", default=None)
def exportMetrics(project_name):
    projectId = ensureProject(project_name) if project_name else None
    tasks = listTasks(projectId=projectId)

    if not tasks:
        click.echo("Nenhuma tarefa encontrada.")
        return

    click.echo("\n=== MÉTRICAS DA PIPELINE ===\n")
    click.echo("Total de tarefas: {0}".format(len(tasks)))

    phaseCount = {ph: 0 for ph in PHASES}
    for t in tasks:
        phaseCount[t["phase"]] = phaseCount.get(t["phase"], 0) + 1

    click.echo("\nDistribuição por fase:")
    for ph, count in phaseCount.items():
        bar = "█" * count
        click.echo("  {0:<16} {1:>3}  {2}".format(ph, count, bar))

    mutations100 = []
    for t in tasks:
        m = getLatestMutation(t["id"])
        if m and m["score"] >= 100.0:
            mutations100.append(t)

    click.echo("\nMutation score 100%: {0}/{1}".format(len(mutations100), len(tasks)))
    for t in mutations100:
        click.echo("  ✓ {0} — {1}".format(t["id"], t["title"]))
