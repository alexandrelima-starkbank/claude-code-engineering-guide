#!/bin/bash
# PostToolUse/Edit|Write|MultiEdit — enforce convenções de estilo Python.
# Passo 1: ruff (qualidade geral — imports, pyflakes, pycodestyle)
# Passo 2: python_style_check.py (convenções da codebase — sem f-strings, else, type hints, docstrings)
#
# Edit/Write: tool_input.file_path (string)
# MultiEdit:  tool_input.edits[].file_path (array) — ambos são tratados abaixo.

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook check-python-style desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
HOOK_DIR="$(dirname "$0")"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SORT_SCRIPT="${PROJECT_ROOT}/config/sortImports.py"
VIOLATIONS=""
SEEN_FILES=$(mktemp)
trap 'rm -f "$SEEN_FILES"' EXIT

check_file() {
    local FILE="$1"
    [[ "$FILE" =~ \.py$ ]] || return
    [ -f "$FILE" ] || return
    # Deduplicar arquivos repetidos em MultiEdit (compatível com bash 3.2/macOS)
    grep -qxF "$FILE" "$SEEN_FILES" && return
    echo "$FILE" >> "$SEEN_FILES"

    if [ -f "$SORT_SCRIPT" ]; then
        python3 "$SORT_SCRIPT" "$FILE" 2>/dev/null
    fi

    if command -v ruff &>/dev/null; then
        local RUFF_OUT
        RUFF_OUT=$(ruff check "$FILE" --output-format=text 2>/dev/null)
        [ -n "$RUFF_OUT" ] && VIOLATIONS="${VIOLATIONS}[ruff] ${FILE}\n${RUFF_OUT}\n"
    fi

    local CUSTOM_STDERR CUSTOM_ERR_FILE
    CUSTOM_ERR_FILE=$(mktemp)
    local CUSTOM_OUT
    CUSTOM_OUT=$(python3 "${HOOK_DIR}/python_style_check.py" "$FILE" 2>"$CUSTOM_ERR_FILE")
    CUSTOM_STDERR=$(cat "$CUSTOM_ERR_FILE")
    rm -f "$CUSTOM_ERR_FILE"
    [ -n "$CUSTOM_STDERR" ] && VIOLATIONS="${VIOLATIONS}[checker error] ${FILE}\n${CUSTOM_STDERR}\n"
    [ -n "$CUSTOM_OUT" ] && VIOLATIONS="${VIOLATIONS}[convenções] ${FILE}\n${CUSTOM_OUT}\n"
}

# Edit / Write — file_path é string
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [ -n "$FILE" ]; then
    check_file "$FILE"
fi

# MultiEdit — edits[].file_path é array
MULTI_FILES=$(echo "$INPUT" | jq -r '.tool_input.edits[]?.file_path // empty' 2>/dev/null)
while IFS= read -r F; do
    [ -n "$F" ] && check_file "$F"
done <<< "$MULTI_FILES"

if [ -n "$VIOLATIONS" ]; then
    REASON=$(printf "Violações de estilo Python:\n\n%bCorrija antes de continuar." "$VIOLATIONS")
    jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
fi

exit 0
