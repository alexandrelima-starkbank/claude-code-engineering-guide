#!/bin/bash
# PostToolUse/Edit|Write|MultiEdit — verifica scripts shell após edição.
# Passo 1: bash -n  — sintaxe (obrigatório, sem dependências externas)
# Passo 2: shellcheck — qualidade e bugs latentes (se disponível)
#
# Edit/Write: tool_input.file_path (string)
# MultiEdit:  tool_input.edits[].file_path (array) — ambos são tratados abaixo.

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook check-bash-syntax desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
VIOLATIONS=""
declare -A SEEN_FILES

check_file() {
    local FILE="$1"
    [[ "$FILE" =~ \.(sh|bash)$ ]] || return
    [ -f "$FILE" ] || return
    # Deduplicar arquivos repetidos em MultiEdit
    [ -n "${SEEN_FILES[$FILE]}" ] && return
    SEEN_FILES["$FILE"]=1

    local SYNTAX
    SYNTAX=$(bash -n "$FILE" 2>&1)
    if [ $? -ne 0 ]; then
        VIOLATIONS="${VIOLATIONS}\n[sintaxe] ${FILE}\n${SYNTAX}"
        return
    fi

    if command -v shellcheck &>/dev/null; then
        local SC
        SC=$(shellcheck --severity=warning --format=gcc "$FILE" 2>&1)
        if [ $? -ne 0 ]; then
            VIOLATIONS="${VIOLATIONS}\n[shellcheck] ${FILE}\n${SC}"
        fi
    fi
}

# Edit / Write
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -n "$FILE" ] && check_file "$FILE"

# MultiEdit
MULTI_FILES=$(echo "$INPUT" | jq -r '.tool_input.edits[]?.file_path // empty' 2>/dev/null)
while IFS= read -r F; do
    [ -n "$F" ] && check_file "$F"
done <<< "$MULTI_FILES"

if [ -n "$VIOLATIONS" ]; then
    REASON=$(printf "Problemas em scripts shell:%b\n\nCorrija antes de continuar." "$VIOLATIONS")
    jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
fi

exit 0
