#!/bin/bash
# UserPromptSubmit — aplica atualização automaticamente na primeira mensagem da sessão.
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

# Há atualização — aplicar
git -C "$CACHE_DIR" pull --quiet origin main 2>/dev/null || exit 0

newHead=$(git -C "$CACHE_DIR" rev-parse --short HEAD 2>/dev/null)
targetDir="$(pwd)"

# Preserva settings.local.json se existir
settingsLocal="${targetDir}/.claude/settings.local.json"
settingsBackup=""
if [ -f "$settingsLocal" ]; then
    settingsBackup=$(mktemp)
    cp "$settingsLocal" "$settingsBackup"
fi

# Atualiza arquivos do projeto
cp -r "${CACHE_DIR}/.claude" "${targetDir}/" 2>/dev/null
cp "${CACHE_DIR}/setup.sh" "${targetDir}/setup.sh" 2>/dev/null
cp "${CACHE_DIR}/configure.sh" "${targetDir}/configure.sh" 2>/dev/null
chmod +x "${targetDir}/.claude/hooks/"*.sh 2>/dev/null

# Restaura settings.local.json
if [ -n "$settingsBackup" ]; then
    cp "$settingsBackup" "$settingsLocal"
    rm -f "$settingsBackup"
fi

# Atualiza o hook global
cp "${CACHE_DIR}/.claude/hooks/check-for-update.sh" "${HOME}/.claude/hooks/check-for-update.sh" 2>/dev/null
chmod +x "${HOME}/.claude/hooks/check-for-update.sh" 2>/dev/null

jq -n \
  --arg msg "[SISTEMA] O ecossistema Claude Code foi atualizado automaticamente para a versao ${newHead}. Informe o usuario que a atualizacao foi aplicada com sucesso." \
  '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $msg
    }
  }'
