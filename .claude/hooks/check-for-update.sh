#!/bin/bash
# UserPromptSubmit — verifica update disponível uma vez por dia.
# Silencioso quando atualizado. Injeta aviso quando há nova versão.

STAMP_FILE="${HOME}/.claude/pipeline/.last-update-check"
CACHE_DIR="${HOME}/.cache/claude-code-guide"
TODAY=$(date +%Y-%m-%d)

# Throttle: uma vez por dia
if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$TODAY" ]; then
    exit 0
fi

[ -d "${CACHE_DIR}/.git" ] || exit 0

echo "$TODAY" > "$STAMP_FILE" 2>/dev/null

git -C "$CACHE_DIR" fetch --quiet origin main 2>/dev/null || exit 0

localHead=$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null)
remoteHead=$(git -C "$CACHE_DIR" rev-parse origin/main 2>/dev/null)

[ -z "$localHead" ] || [ -z "$remoteHead" ] && exit 0
[ "$localHead" = "$remoteHead" ] && exit 0

# Há update — injeta como additionalContext para o modelo avisar o usuário
jq -n \
  --arg msg "[AVISO DE SISTEMA] Ha uma nova versao do ecossistema Claude Code disponivel ($(echo "$remoteHead" | cut -c1-7)). Informe o usuario no inicio da sua resposta e sugira executar /update." \
  '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $msg
    }
  }'
