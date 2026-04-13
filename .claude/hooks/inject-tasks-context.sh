#!/bin/bash
# UserPromptSubmit — injeta contexto das tarefas ativas e mandato de atualização.
# Tenta pipeline CLI primeiro; cai no TASKS.md como fallback.

if ! command -v jq &>/dev/null; then
    exit 0
fi

MANDATORY="

GESTÃO DE TAREFAS — OBRIGATÓRIO:
Antes de finalizar esta resposta, verifique o status da tarefa ativa:
  • Trabalho completado nesta resposta → pipeline task update <ID> --status \"concluído\"
  • Fase concluída nesta resposta     → pipeline phase advance <ID> --to <próxima-fase>
  • Bloqueado                         → pipeline task update <ID> --status \"bloqueado\"
Nunca encerre uma resposta com trabalho concluído sem executar o comando acima."

CONTEXT=""

# --- Tentativa 1: pipeline CLI (fonte de verdade) ---
if command -v pipeline &>/dev/null; then
    ACTIVE=$(pipeline task list --status "em andamento" --format context 2>/dev/null)
    if [ -n "$ACTIVE" ]; then
        echo "[inject-tasks] source=pipeline-cli" >&2
        CONTEXT=$(printf "Tarefas ativas (pipeline DB):\n%s\n%s" "$ACTIVE" "$MANDATORY")
        jq -n --arg ctx "$CONTEXT" '{
            hookSpecificOutput: {
                hookEventName: "UserPromptSubmit",
                additionalContext: $ctx
            }
        }'
        exit 0
    fi
fi

# --- Fallback: TASKS.md ---
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -n "$GIT_ROOT" ] && [ -f "${GIT_ROOT}/TASKS.md" ]; then
    TASKS_FILE="${GIT_ROOT}/TASKS.md"
elif [ -f "TASKS.md" ]; then
    TASKS_FILE="TASKS.md"
else
    exit 0
fi

ACTIVE=$(awk '/^## Tarefas Ativas/{found=1; next} /^## Histórico/{found=0} found' "$TASKS_FILE" \
    | grep -v '^_Nenhuma' \
    | grep -v '^# Gerado' \
    | sed '/^[[:space:]]*$/d')

if [ -z "$ACTIVE" ]; then
    echo "[inject-tasks] skip: no active tasks in TASKS.md" >&2
    exit 0
fi

echo "[inject-tasks] source=TASKS.md" >&2
STALE=$(echo "$ACTIVE" | grep -iE '\*\*Status:\*\*\s*(concluído|cancelado)')
CONTEXT=$(printf "Tarefas ativas (TASKS.md):\n%s\n%s" "$ACTIVE" "$MANDATORY")

if [ -n "$STALE" ]; then
    CONTEXT=$(printf "ACAO OBRIGATORIA: tarefas concluídas ainda em Tarefas Ativas. Mova para Histórico ANTES de responder.\n\n%s" "$CONTEXT")
fi

jq -n --arg ctx "$CONTEXT" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $ctx
    }
}'
