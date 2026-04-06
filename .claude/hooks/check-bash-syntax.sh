#!/bin/bash
# PostToolUse/Edit|Write — verifica sintaxe de scripts bash após edição.
# Usa 'bash -n' (dry-run): detecta erros de sintaxe sem executar o script.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Só verifica arquivos shell
[[ "$FILE" =~ \.(sh|bash)$ ]] || exit 0
[ -f "$FILE" ] || exit 0

OUTPUT=$(bash -n "$FILE" 2>&1)
if [ $? -ne 0 ]; then
    jq -n --arg reason "Erro de sintaxe em ${FILE}:\n${OUTPUT}\n\nCorrija antes de continuar." \
       '{"decision":"block","reason":$reason}'
    exit 0
fi

exit 0
