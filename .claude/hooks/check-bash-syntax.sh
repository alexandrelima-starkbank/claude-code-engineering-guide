#!/bin/bash
# PostToolUse/Edit|Write — verifica sintaxe de scripts bash após edição.
# Usa 'bash -n' (dry-run): detecta erros de sintaxe sem executar o script.

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook check-bash-syntax desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Só verifica arquivos shell
[[ "$FILE" =~ \.(sh|bash)$ ]] || exit 0
[ -f "$FILE" ] || exit 0

OUTPUT=$(bash -n "$FILE" 2>&1)
if [ $? -ne 0 ]; then
    REASON=$(printf "Erro de sintaxe em %s:\n%s\n\nCorrija antes de continuar." "$FILE" "$OUTPUT")
    jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
    exit 0
fi

exit 0
