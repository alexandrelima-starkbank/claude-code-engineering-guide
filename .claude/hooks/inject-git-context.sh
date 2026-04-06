#!/bin/bash
# SessionStart — injeta contexto git no início de cada sessão.

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "fora de um repositório git")
LAST_COMMITS=$(git log --oneline -5 2>/dev/null || echo "sem histórico")
MODIFIED=$(git status --short 2>/dev/null | head -10 || echo "")
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$(pwd)")

CONTEXT="Projeto: ${PROJECT}
Branch: ${BRANCH}

Últimos commits:
${LAST_COMMITS}"

if [ -n "$MODIFIED" ]; then
    CONTEXT="${CONTEXT}

Arquivos modificados (não commitados):
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
