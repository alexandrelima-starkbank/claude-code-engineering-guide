#!/bin/bash
# UserPromptSubmit — injeta tarefas ativas do TASKS.md em cada prompt.
# Garante que Claude sempre sabe o estado atual do trabalho sem precisar ser instruído.

if ! command -v jq &>/dev/null; then
    exit 0
fi

TASKS_FILE="TASKS.md"
[ -f "$TASKS_FILE" ] || exit 0

# Extrai apenas a seção de tarefas ativas (entre ## Tarefas Ativas e ## Histórico)
ACTIVE=$(awk '/^## Tarefas Ativas/{found=1; next} /^## Histórico/{found=0} found' "$TASKS_FILE" \
    | grep -v '^_Nenhuma' \
    | sed '/^[[:space:]]*$/d')

[ -z "$ACTIVE" ] && exit 0

CONTEXT=$(printf "Estado atual das tarefas (TASKS.md):\n%s" "$ACTIVE")

jq -n --arg ctx "$CONTEXT" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $ctx
    }
}'
exit 0
