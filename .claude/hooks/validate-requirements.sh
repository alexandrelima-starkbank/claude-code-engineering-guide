#!/bin/bash
# UserPromptSubmit — verifica Requisitos EARS antes de implementação.
# Se o prompt indicar intenção de implementação e a tarefa ativa não tiver
# Requisitos EARS preenchidos, injeta alerta bloqueando geração de código.

if ! command -v jq &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

[ -z "$PROMPT" ] && exit 0

# Detecta intenção de implementação (PT e EN)
IMPL_PATTERN='(^|\s)(implement|criar|cria|crie|escrever|escreve|escreva|adicionar|adiciona|adicione|build|write|desenvolver|implementar|codificar|faça|fazer|code)(\s|$)'
if ! echo "$PROMPT" | grep -qiE "$IMPL_PATTERN"; then
    exit 0
fi

# Busca TASKS.md: raiz do repositório git primeiro, depois CWD
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ] && [ -f "${GIT_ROOT}/TASKS.md" ]; then
    TASKS_FILE="${GIT_ROOT}/TASKS.md"
elif [ -f "TASKS.md" ]; then
    TASKS_FILE="TASKS.md"
else
    exit 0
fi

# Verifica tarefas em andamento sem Requisitos EARS preenchidos
MISSING=$(python3 - <<PYEOF
import re, sys

try:
    with open("${TASKS_FILE}") as f:
        content = f.read()
except Exception:
    sys.exit(0)

tasks = re.findall(r'(### T\d+.*?)(?=### T\d+|\Z)', content, re.DOTALL)
missing = []

for task in tasks:
    if 'em andamento' not in task:
        continue

    title_match = re.search(r'### (T\d+ — .+)', task)
    title = title_match.group(1).strip() if title_match else 'Tarefa sem título'

    ears_block = re.search(
        r'\*\*Requisitos EARS:\*\*(.+?)(?=- \*\*[A-Z]|\Z)',
        task,
        re.DOTALL
    )
    if not ears_block or not ears_block.group(1).strip():
        missing.append(title)

if missing:
    print('\n'.join(missing))
PYEOF
)

[ -z "$MISSING" ] && exit 0

jq -n --arg tasks "$MISSING" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: ("GATE DE REQUISITOS EARS ativo.\nAs seguintes tarefas em andamento não possuem Requisitos EARS definidos:\n" + $tasks + "\n\nNão escreva código. Execute /requirements <descrição> para elicitar os requisitos. Após aprovação, use /spec para critérios de aceite e /tdd para implementar. Ou use /feature <descrição> para o fluxo completo.")
    }
}'
