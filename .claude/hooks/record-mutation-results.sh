#!/bin/bash
# PostToolUse/Bash — auto-registra resultados de mutmut no pipeline DB.
# Ambiente detecta execução de mutation testing e registra sem intervenção.

if ! command -v jq &>/dev/null || ! command -v pipeline &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.output // empty')

# Só processa comandos mutmut run ou results
if ! echo "$COMMAND" | grep -qE 'mutmut\s+(run|results)'; then
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

# Parseia output do mutmut e registra resultado
echo "$OUTPUT" | python3 - "$ACTIVE_TASK" <<'PYEOF'
import sys, re, subprocess

taskId = sys.argv[1]
output = sys.stdin.read()

match = (
    re.search(r'Killed\s+(\d+)\s+out of\s+(\d+)', output)
    or re.search(r'(\d+)/(\d+)\s+mutants?\s+killed', output)
    or re.search(r'(\d+)\s+out of\s+(\d+)\s+mutants?\s+(?:were\s+)?killed', output)
)

if not match:
    sys.exit(0)

killed = int(match.group(1))
total = int(match.group(2))

result = subprocess.run(
    ["pipeline", "mutation", "record", taskId,
     "--total", str(total), "--killed", str(killed)],
    capture_output=True,
)

if result.returncode == 0:
    score = (killed / total * 100) if total > 0 else 0
    sys.stdout.write(
        "Pipeline: mutation {0:.0f}% ({1}/{2}) registrado para {3}\n".format(
            score, killed, total, taskId
        )
    )
PYEOF

exit 0
