#!/bin/bash
# PostToolUse/Edit|Write|MultiEdit — enforce convenções de estilo Python.
# Passo 1: ruff (qualidade geral — imports, pyflakes, pycodestyle)
# Passo 2: python_style_check.py (convenções da codebase — sem f-strings, else, type hints, docstrings)

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook check-python-style desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$FILE" =~ \.py$ ]] || exit 0
[ -f "$FILE" ] || exit 0

VIOLATIONS=""

# ── Passo 1: ruff ─────────────────────────────────────────────────────────────
if command -v ruff &>/dev/null; then
    RUFF_OUT=$(ruff check "$FILE" --output-format=text 2>/dev/null)
    if [ -n "$RUFF_OUT" ]; then
        VIOLATIONS="${VIOLATIONS}\n[ruff]\n${RUFF_OUT}"
    fi
fi

# ── Passo 2: convenções da codebase (AST — sem falsos positivos de regex) ────
HOOK_DIR="$(dirname "$0")"
CUSTOM_OUT=$(python3 "${HOOK_DIR}/python_style_check.py" "$FILE" 2>/dev/null)
if [ -n "$CUSTOM_OUT" ]; then
    VIOLATIONS="${VIOLATIONS}\n[convenções]\n${CUSTOM_OUT}"
fi

# ── Resultado ─────────────────────────────────────────────────────────────────
if [ -n "$VIOLATIONS" ]; then
    REASON=$(printf "Violações em %s:%b\n\nCorrija antes de continuar." "$FILE" "$VIOLATIONS")
    jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
fi

exit 0
