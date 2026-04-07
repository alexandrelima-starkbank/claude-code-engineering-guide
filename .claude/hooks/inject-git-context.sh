#!/bin/bash
# SessionStart — injeta contexto git no início de cada sessão.

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook inject-git-context desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "fora de um repositório git")
LAST_COMMITS=$(git log --oneline -5 2>/dev/null || echo "sem histórico")
MODIFIED_ALL=$(git status --short 2>/dev/null || echo "")
MODIFIED=$(echo "$MODIFIED_ALL" | head -10)
MODIFIED_COUNT=$(echo "$MODIFIED_ALL" | grep -c . 2>/dev/null || echo 0)
MODIFIED_TRUNCATED=""
if [ "$MODIFIED_COUNT" -gt 10 ]; then
    MODIFIED_TRUNCATED=" (mostrando 10 de ${MODIFIED_COUNT})"
fi
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$(pwd)")

CONTEXT="Projeto: ${PROJECT}
Branch: ${BRANCH}

Últimos commits:
${LAST_COMMITS}"

if [ -n "$MODIFIED" ]; then
    CONTEXT="${CONTEXT}

Arquivos modificados (não commitados)${MODIFIED_TRUNCATED}:
${MODIFIED}"
fi

jq -n \
  --arg ctx "$CONTEXT" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'

exit 0
