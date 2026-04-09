#!/bin/bash
# UserPromptSubmit — gates de qualidade: EARS (requirements), critérios (spec).
# Bloqueia implementação prematura e redireciona para o passo correto da pipeline.

if ! command -v jq &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Detecta intenção de implementação (PT e EN)
IMPL_PATTERN='(^|\s)(implement|criar|crie|escrever|escreva|adicionar|adicione|build|write|desenvolver|implementar|codificar|faça|fazer|code|tdd|testes|tests)(\s|$)'
if ! echo "$PROMPT" | grep -qiE "$IMPL_PATTERN"; then
    exit 0
fi

# --- Tentativa 1: pipeline CLI ---
if command -v pipeline &>/dev/null; then
    ACTIVE_JSON=$(pipeline task list --status "em andamento" --format json 2>/dev/null)
    [ -z "$ACTIVE_JSON" ] && exit 0

    PHASE=$(echo "$ACTIVE_JSON" | python3 -c "
import sys, json
try:
    tasks = json.load(sys.stdin)
    print(tasks[0]['phase'] if tasks else '')
except:
    print('')
" 2>/dev/null)
    TASK_ID=$(echo "$ACTIVE_JSON" | python3 -c "
import sys, json
try:
    tasks = json.load(sys.stdin)
    print(tasks[0]['id'] if tasks else '')
except:
    print('')
" 2>/dev/null)

    [ -z "$PHASE" ] || [ -z "$TASK_ID" ] && exit 0

    # Gate 1: requirements — verificar EARS aprovados
    if [ "$PHASE" = "requirements" ]; then
        EARS_COUNT=$(pipeline ears list "$TASK_ID" --format json 2>/dev/null | python3 -c "
import sys, json
try:
    ears = json.load(sys.stdin)
    print(len([r for r in ears if r.get('approved')]))
except:
    print(0)
" 2>/dev/null)
        if [ "${EARS_COUNT:-0}" -eq 0 ]; then
            jq -n --arg task "$TASK_ID" '{
                hookSpecificOutput: {
                    hookEventName: "UserPromptSubmit",
                    additionalContext: ("GATE EARS ativo — " + $task + " está em requirements sem EARS aprovados.\n\nNão escreva código nem testes. Conduza o intake: elicite requisitos EARS, apresente ao engenheiro e aguarde aprovação explícita.\nApós aprovação: pipeline ears add/approve + pipeline phase advance --to spec")
                }
            }'
            exit 0
        fi
    fi

    # Gate 2: spec — verificar critérios de aceite aprovados
    if [ "$PHASE" = "spec" ]; then
        CRITERIA_COUNT=$(pipeline criterion list "$TASK_ID" --format json 2>/dev/null | python3 -c "
import sys, json
try:
    criteria = json.load(sys.stdin)
    print(len([c for c in criteria if c.get('approved')]))
except:
    print(0)
" 2>/dev/null)
        if [ "${CRITERIA_COUNT:-0}" -eq 0 ]; then
            jq -n --arg task "$TASK_ID" '{
                hookSpecificOutput: {
                    hookEventName: "UserPromptSubmit",
                    additionalContext: ("GATE CRITÉRIOS DE ACEITE ativo — " + $task + " está em spec sem critérios aprovados.\n\nNão escreva testes nem código. Derive cenários Given/When/Then a partir dos EARS aprovados, apresente ao engenheiro e aguarde aprovação explícita.\nApós aprovação: pipeline criterion add/approve + pipeline phase advance --to tests")
                }
            }'
            exit 0
        fi
    fi

    exit 0
fi

# --- Fallback: parsing de TASKS.md ---
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ] && [ -f "${GIT_ROOT}/TASKS.md" ]; then
    TASKS_FILE="${GIT_ROOT}/TASKS.md"
elif [ -f "TASKS.md" ]; then
    TASKS_FILE="TASKS.md"
else
    exit 0
fi

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
    ears_block = re.search(r'\*\*Requisitos EARS:\*\*(.+?)(?=- \*\*[A-Z]|\Z)', task, re.DOTALL)
    if not ears_block or not ears_block.group(1).strip() or 'não definidos' in ears_block.group(1):
        missing.append(title)

if missing:
    print('\n'.join(missing))
PYEOF
)

[ -z "$MISSING" ] && exit 0

jq -n --arg tasks "$MISSING" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: ("GATE EARS ativo.\nTarefas em andamento sem EARS aprovados:\n" + $tasks + "\n\nNão escreva código. Conduza o intake primeiro.")
    }
}'
