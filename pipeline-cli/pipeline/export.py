from .db import (
    getTask, listTasks, listEars, listCriteria,
    getTestSummary, getLatestMutation, getLatestTestResult, PHASES,
)

def formatPhaseBar(currentPhase):
    parts = []
    reached = False
    for phase in PHASES:
        if phase == currentPhase:
            parts.append("{0} →".format(phase))
            reached = True
        elif not reached:
            parts.append("{0} ✓".format(phase))
        else:
            parts.append(phase)
    return " | ".join(parts)

def formatTask(taskId):
    task = getTask(taskId)
    if not task:
        return ""

    ears = listEars(taskId)
    criteria = listCriteria(taskId)
    testSummary = getTestSummary(taskId)
    mutation = getLatestMutation(taskId)

    lines = []
    lines.append("### {0} — {1}".format(task["id"], task["title"]))
    lines.append("")
    lines.append("- **Projeto:** {0}".format(task.get("projectName", task["projectId"])))
    lines.append("- **Status:** {0}".format(task["status"]))
    lines.append("- **Fase:** {0}".format(formatPhaseBar(task["phase"])))

    if task.get("description"):
        lines.append("- **Descrição:** {0}".format(task["description"]))

    lines.append("- **Requisitos EARS:**")
    if ears:
        for r in ears:
            approved = " ✓" if r["approved"] else ""
            lines.append("  - [{0}]{1} ({2}) {3}".format(r["id"], approved, r["pattern"], r["text"]))
    else:
        lines.append("  *(não definidos — use `pipeline ears add {0}`)*".format(taskId))

    lines.append("- **Critério de aceitação:**")
    if criteria:
        for c in criteria:
            earsRef = " ← {0}".format(c["earsId"]) if c["earsId"] else ""
            approvedMark = " ✓" if c.get("approved") else ""
            lines.append("")
            lines.append("  **Cenário: {0}**{1}{2}".format(c["scenarioName"], earsRef, approvedMark))
            if c.get("givenText"):
                lines.append("  - Dado: {0}".format(c["givenText"]))
            if c.get("whenText"):
                lines.append("  - Quando: {0}".format(c["whenText"]))
            lines.append("  - Então: {0} → `{1}`".format(
                c["thenText"], c.get("testMethod") or "?"
            ))
    else:
        lines.append("  *(não definidos)*")

    if ears and criteria:
        lines.append("- **Matriz de Rastreabilidade:**")
        lines.append("")
        lines.append("  | ID | Requisito | Cenário | Teste | Qualidade | Status |")
        lines.append("  |----|-----------|---------|-------|-----------|--------|")
        for r in ears:
            related = [c for c in criteria if c["earsId"] == r["id"]]
            if related:
                for c in related:
                    result = getLatestTestResult(taskId, c.get("testMethod"))
                    if result is None:
                        status = "—"
                    elif result:
                        status = "✓ passou"
                    else:
                        status = "✗ falhou"
                    quality = c.get("testQuality") or "—"
                    reqShort = r["text"][:40] + "…" if len(r["text"]) > 40 else r["text"]
                    lines.append("  | {0} | {1} | {2} | `{3}` | {4} | {5} |".format(
                        r["id"], reqShort, c["scenarioName"],
                        c.get("testMethod") or "?", quality, status,
                    ))
            else:
                lines.append("  | {0} | {1} | — | — | — | sem cenário |".format(
                    r["id"], r["text"][:40],
                ))

    hasMetrics = ears or criteria or testSummary["total"] > 0 or mutation
    if hasMetrics:
        lines.append("- **Métricas:**")
        if ears:
            lines.append("  - EARS: {0} requisitos ({1} aprovados)".format(
                len(ears), sum(1 for r in ears if r["approved"])
            ))
        if criteria:
            ratio = len(criteria) / len(ears) if ears else 0
            withMethod = [c for c in criteria if c.get("testMethod")]
            qualityStr = "{0} STRONG, {1} ACCEPTABLE, {2} WEAK, {3} sem revisão".format(
                sum(1 for c in withMethod if c.get("testQuality") == "STRONG"),
                sum(1 for c in withMethod if c.get("testQuality") == "ACCEPTABLE"),
                sum(1 for c in withMethod if c.get("testQuality") == "WEAK"),
                sum(1 for c in withMethod if not c.get("testQuality")),
            ) if withMethod else "sem métodos mapeados"
            lines.append("  - Spec: {0} cenários ({1} aprovados, {2:.1f}/requisito) | Qualidade: {3}".format(
                len(criteria), sum(1 for c in criteria if c["approved"]), ratio, qualityStr,
            ))
        if testSummary["total"] > 0:
            lines.append("  - Testes: {0} métodos — {1} passando, {2} falhando".format(
                testSummary["total"], testSummary["passed"], testSummary["failed"]
            ))
        if mutation:
            lines.append("  - Mutação: {0} mutantes, {1} mortos ({2:.0f}%)".format(
                mutation["totalMutants"], mutation["killed"], mutation["score"]
            ))

    return "\n".join(lines)

def generateTasksMd(projectId=None, taskId=None):
    header = (
        "# TASKS.md\n"
        "# Gerado automaticamente por `pipeline export tasks-md`\n"
        "# Fonte: ~/.claude/pipeline/pipeline.db  —  NÃO EDITAR DIRETAMENTE\n\n"
        "---\n\n"
    )

    if taskId:
        task = getTask(taskId)
        tasks = [task] if task else []
    else:
        tasks = listTasks(projectId=projectId)

    active = [t for t in tasks if t["status"] != "concluído"]
    done = [t for t in tasks if t["status"] == "concluído"]

    parts = [header, "## Tarefas Ativas\n\n"]

    if active:
        for t in active:
            parts.append(formatTask(t["id"]))
            parts.append("\n\n---\n\n")
    else:
        parts.append("_Nenhuma tarefa ativa no momento._\n\n")

    parts.append("## Histórico\n\n")

    if done:
        for t in done:
            parts.append(formatTask(t["id"]))
            parts.append("\n\n---\n\n")
    else:
        parts.append("_Nenhuma tarefa concluída._\n")

    return "".join(parts)
