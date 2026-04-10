#!/bin/bash
# SessionStart — verifica se o ecossistema Claude Code tem atualização disponível.
# Executa no máximo uma vez por dia. Sempre reporta o resultado da verificação.

STAMP_FILE="${HOME}/.claude/pipeline/.last-update-check"
CACHE_DIR="${HOME}/.cache/claude-code-guide"
TODAY=$(date +%Y-%m-%d)

_output() {
    if command -v jq &>/dev/null; then
        jq -n --arg msg "$1" '{
            hookSpecificOutput: {
                hookEventName: "SessionStart",
                additionalContext: $msg
            }
        }'
    else
        echo "$1" >&2
    fi
}

# Throttle: uma verificação por dia (por data de calendário)
if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$TODAY" ]; then
    exit 0
fi

# Cache inexistente — ambiente não instalado
[ -d "${CACHE_DIR}/.git" ] || exit 0

# Registra data antes do fetch
echo "$TODAY" > "$STAMP_FILE" 2>/dev/null

# Fetch silencioso — falha silenciosa se offline
if ! git -C "$CACHE_DIR" fetch --quiet origin main 2>/dev/null; then
    _output "[update check] nao foi possivel verificar atualizacoes (sem rede)."
    exit 0
fi

localHead=$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null)
remoteHead=$(git -C "$CACHE_DIR" rev-parse origin/main 2>/dev/null)

[ -z "$localHead" ] || [ -z "$remoteHead" ] && exit 0

if [ "$localHead" = "$remoteHead" ]; then
    _output "[update check] ecossistema Claude Code atualizado ($(echo "$localHead" | cut -c1-7))."
else
    _output "[update disponivel] Nova versao do ecossistema Claude Code disponivel.
  instalado:  $(echo "$localHead" | cut -c1-7)
  disponivel: $(echo "$remoteHead" | cut -c1-7)
  Execute /update para atualizar sem sair do ambiente."
fi
