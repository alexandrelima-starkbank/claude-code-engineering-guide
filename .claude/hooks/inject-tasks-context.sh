#!/bin/bash
# UserPromptSubmit — injeta tarefas ativas do TASKS.md em cada prompt.
# Garante que Claude sempre sabe o estado atual do trabalho sem precisar ser instruído.
# Se houver tarefas concluídas/canceladas ainda em "Tarefas Ativas", injeta alerta urgente.

if ! command -v jq &>/dev/null; then
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

# Extrai apenas a seção de tarefas ativas (entre ## Tarefas Ativas e ## Histórico)
ACTIVE=$(awk '/^## Tarefas Ativas/{found=1; next} /^## Histórico/{found=0} found' "$TASKS_FILE" \
    | grep -v '^_Nenhuma' \
    | sed '/^[[:space:]]*$/d')

[ -z "$ACTIVE" ] && exit 0

# Detecta tarefas concluídas ou canceladas que ainda não foram movidas para o Histórico
STALE=$(echo "$ACTIVE" | grep -iE '\*\*Status:\*\*\s*(concluído|cancelado)')

CONTEXT=$(printf "Estado atual das tarefas (TASKS.md):\n%s" "$ACTIVE")

if [ -n "$STALE" ]; then
    CONTEXT=$(printf "ACAO OBRIGATORIA: ha tarefas com status 'concluido' ou 'cancelado' ainda em Tarefas Ativas.\nMova-as para ## Historico em TASKS.md ANTES de responder a qualquer outra coisa.\n\n%s" "$CONTEXT")
fi

jq -n --arg ctx "$CONTEXT" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $ctx
    }
}'
exit 0
