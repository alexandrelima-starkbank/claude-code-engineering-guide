#!/bin/bash
# PostToolUse/Bash — auto-registra resultados de pytest no pipeline DB.
# Ambiente detecta execução de testes e registra sem intervenção do engenheiro.

if ! command -v jq &>/dev/null || ! command -v pipeline &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.output // empty')

# Só processa comandos pytest
if ! echo "$COMMAND" | grep -qE '(pytest|python.*-m.*pytest)'; then
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

# Parseia output do pytest e registra resultados
echo "$OUTPUT" | python3 - "$ACTIVE_TASK" <<'PYEOF'
import sys, re, subprocess

taskId = sys.argv[1]
output = sys.stdin.read()

# Padrões de output do pytest: "PASSED tests/xxx.py::ClassName::method_name"
passed = re.findall(r'PASSED\s+\S+::(\w+)', output)
passed += re.findall(r'\s+(\w+)\s+PASSED', output)
failed = re.findall(r'FAILED\s+\S+::(\w+)', output)
failed += re.findall(r'\s+(\w+)\s+FAILED', output)

# Deduplicar
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
    sys.stdout.write(
        "Pipeline: {0} passed, {1} failed registrados para {2}\n".format(
            len(passed), len(failed), taskId
        )
    )
PYEOF

exit 0
