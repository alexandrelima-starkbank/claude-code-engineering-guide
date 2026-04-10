#!/bin/bash
# UserPromptSubmit — verifica se há atualização disponível na primeira mensagem da sessão.
# Disparado pela flag criada pelo hook SessionStart (mark-session-start.sh).

FLAG="${HOME}/.claude/pipeline/.check-update-pending"
CACHE_DIR="${HOME}/.cache/claude-code-guide"

[ -f "$FLAG" ] || exit 0
rm -f "$FLAG"

[ -d "${CACHE_DIR}/.git" ] || exit 0

git -C "$CACHE_DIR" fetch --quiet origin main 2>/dev/null || exit 0

localHead=$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null)
remoteHead=$(git -C "$CACHE_DIR" rev-parse origin/main 2>/dev/null)

[ -z "$localHead" ] || [ -z "$remoteHead" ] && exit 0
[ "$localHead" = "$remoteHead" ] && exit 0

jq -n \
  --arg msg "[AVISO DE SISTEMA] Ha uma nova versao do ecossistema Claude Code disponivel ($(echo "$remoteHead" | cut -c1-7)). Informe o usuario antes de responder e sugira executar /update." \
  '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $msg
    }
  }'
