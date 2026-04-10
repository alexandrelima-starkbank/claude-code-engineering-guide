#!/bin/bash
# SessionStart — verifica se o ecossistema Claude Code tem atualização disponível.
# Executa no máximo uma vez por dia. Plain stdout — aparece no transcript da sessão.

STAMP_FILE="${HOME}/.claude/pipeline/.last-update-check"
CACHE_DIR="${HOME}/.cache/claude-code-guide"
TODAY=$(date +%Y-%m-%d)

# Throttle: uma verificação por dia
if [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$TODAY" ]; then
    exit 0
fi

[ -d "${CACHE_DIR}/.git" ] || exit 0

echo "$TODAY" > "$STAMP_FILE" 2>/dev/null

git -C "$CACHE_DIR" fetch --quiet origin main 2>/dev/null || {
    echo "[update check] sem rede — nao foi possivel verificar atualizacoes."
    exit 0
}

localHead=$(git -C "$CACHE_DIR" rev-parse HEAD 2>/dev/null)
remoteHead=$(git -C "$CACHE_DIR" rev-parse origin/main 2>/dev/null)

[ -z "$localHead" ] || [ -z "$remoteHead" ] && exit 0

if [ "$localHead" = "$remoteHead" ]; then
    echo "[update check] ecossistema Claude Code atualizado ($(echo "$localHead" | cut -c1-7))."
else
    echo "[update disponivel] Nova versao disponivel: $(echo "$remoteHead" | cut -c1-7). Execute /update."
fi
