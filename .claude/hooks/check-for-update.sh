#!/bin/bash
# SessionStart — verifica se o ecossistema Claude Code tem atualização disponível.
# Executa no máximo uma vez por dia. Silencioso se tudo está atualizado ou sem rede.

STAMP_FILE="${HOME}/.claude/pipeline/.last-update-check"
CACHE_DIR="${HOME}/.cache/claude-code-guide"
TODAY=$(date +%Y-%m-%d)

# Throttle: uma verificação por dia (por data de calendário)
if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$TODAY" ]; then
    exit 0
fi

# Cache inexistente — ambiente não instalado, nada a verificar
[ -d "${CACHE_DIR}/.git" ] || exit 0

# Registra data antes do fetch (não bloqueia se a rede demorar)
echo "$TODAY" > "$STAMP_FILE" 2>/dev/null

# Fetch silencioso — falha silenciosa se offline
git -C "$CACHE_DIR" fetch --quiet origin main 2>/dev/null || exit 0

localHead=$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null)
remoteHead=$(git -C "$CACHE_DIR" rev-parse origin/main 2>/dev/null)

[ -z "$localHead" ] || [ -z "$remoteHead" ] && exit 0
[ "$localHead" = "$remoteHead" ] && exit 0

# Há atualização disponível
MSG="[update disponivel] O ecossistema Claude Code tem uma nova versao.
  instalado: ${localHead}
  disponivel: ${remoteHead}
  Execute /update para atualizar sem sair do ambiente."

if command -v jq &>/dev/null; then
    jq -n --arg msg "$MSG" '{
        hookSpecificOutput: {
            hookEventName: "SessionStart",
            additionalContext: $msg
        }
    }'
else
    echo "$MSG" >&2
fi
