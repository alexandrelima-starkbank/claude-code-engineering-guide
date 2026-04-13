#!/bin/bash
# PostToolUse/Bash — auto-registra resultados de pytest no pipeline DB.
# Lê .pytest-report.json (gerado via pytest-json-report) em vez de parsear stdout.

if ! command -v jq &>/dev/null || ! command -v pipeline &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Só processa comandos pytest
if ! echo "$COMMAND" | grep -qE '(pytest|python.*-m.*pytest)'; then
    exit 0
fi

# Localiza raiz do projeto
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REPORT_FILE="${GIT_ROOT}/.pytest-report.json"

# Fallback: se JSON report não existe, tenta parsear stdout (compatibilidade)
if [ ! -f "$REPORT_FILE" ]; then
    OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.output // empty')
    if [ -z "$OUTPUT" ]; then
        exit 0
    fi
    # Busca task em andamento
    ACTIVE_TASK=$(pipeline task list --status "em andamento" --format json 2>/dev/null | python3 -c "
import sys, json
try:
    tasks = json.load(sys.stdin)
    print(tasks[0]['id'] if tasks else '')
except:
    print('')
" 2>/dev/null)
    [ -z "$ACTIVE_TASK" ] && exit 0

    echo "$OUTPUT" | python3 - "$ACTIVE_TASK" <<'PYEOF'
import sys, re, subprocess

taskId = sys.argv[1]
output = sys.stdin.read()

passed = re.findall(r'PASSED\s+\S+::(\w+)', output)
passed += re.findall(r'\s+(\w+)\s+PASSED', output)
failed = re.findall(r'FAILED\s+\S+::(\w+)', output)
failed += re.findall(r'\s+(\w+)\s+FAILED', output)

passed = list(dict.fromkeys(passed))
failed = list(dict.fromkeys(failed))

recorded = 0
for method in passed:
    result = subprocess.run(
        ["pipeline", "test", "record", taskId, "--method", method, "--passed"],
        capture_output=True,
    )
    if result.returncode == 0:
        recorded += 1

for method in failed:
    result = subprocess.run(
        ["pipeline", "test", "record", taskId, "--method", method, "--failed"],
        capture_output=True,
    )
    if result.returncode == 0:
        recorded += 1

if recorded:
    sys.stderr.write(
        "Pipeline (fallback): {0} passed, {1} failed registrados para {2}\n".format(
            len(passed), len(failed), taskId
        )
    )
PYEOF
    exit 0
fi

# Busca task em andamento
ACTIVE_TASK=$(pipeline task list --status "em andamento" --format json 2>/dev/null | python3 -c "
import sys, json
try:
    tasks = json.load(sys.stdin)
    print(tasks[0]['id'] if tasks else '')
except:
    print('')
" 2>/dev/null)

[ -z "$ACTIVE_TASK" ] && exit 0

# Processa report JSON estruturado
python3 - "$ACTIVE_TASK" "$REPORT_FILE" <<'PYEOF'
import json
import subprocess
import sys

taskId = sys.argv[1]
reportPath = sys.argv[2]

try:
    with open(reportPath, encoding="utf-8") as f:
        report = json.load(f)
except (OSError, json.JSONDecodeError):
    sys.exit(0)

tests = report.get("tests", [])
if not tests:
    sys.exit(0)

recorded = 0
passedCount = 0
failedCount = 0

for test in tests:
    nodeid = test.get("nodeid", "")
    outcome = test.get("outcome", "")

    if outcome not in ("passed", "failed"):
        continue

    parts = nodeid.split("::")
    method = parts[-1] if parts else nodeid

    passed = outcome == "passed"
    flag = "--passed" if passed else "--failed"

    result = subprocess.run(
        ["pipeline", "test", "record", taskId, "--method", method, flag],
        capture_output=True,
    )
    if result.returncode == 0:
        recorded += 1
        if passed:
            passedCount += 1
        else:
            failedCount += 1

if recorded:
    sys.stderr.write(
        "Pipeline: {0} passed, {1} failed registrados para {2} (via JSON report)\n".format(
            passedCount, failedCount, taskId
        )
    )
PYEOF

exit 0
