#!/bin/bash
# PostToolUse/Edit|Write — verifica scripts shell após edição.
# Passo 1: bash -n  — sintaxe (obrigatório, sem dependências externas)
# Passo 2: shellcheck — qualidade e bugs latentes (se disponível)

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook check-bash-syntax desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$FILE" =~ \.(sh|bash)$ ]] || exit 0
[ -f "$FILE" ] || exit 0

# Passo 1 — sintaxe básica
SYNTAX=$(bash -n "$FILE" 2>&1)
if [ $? -ne 0 ]; then
    REASON=$(printf "Erro de sintaxe em %s:\n%s\n\nCorrija antes de continuar." "$FILE" "$SYNTAX")
    jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
    exit 0
fi

# Passo 2 — shellcheck (se disponível)
if command -v shellcheck &>/dev/null; then
    SC=$(shellcheck --severity=warning --format=gcc "$FILE" 2>&1)
    if [ $? -ne 0 ]; then
        REASON=$(printf "shellcheck encontrou problemas em %s:\n%s\n\nCorrija antes de continuar." "$FILE" "$SC")
        jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
        exit 0
    fi
fi

exit 0
