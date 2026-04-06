#!/bin/bash
# PostToolUse/Edit|Write — enforce convenções de estilo Python.
# Detecta: f-strings, else blocks, type hints, docstrings.

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook check-python-style desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$FILE" =~ \.py$ ]] || exit 0
[ -f "$FILE" ] || exit 0

VIOLATIONS=""

# f-strings: f"..." ou f'...'
FSTR=$(grep -nP "\bf['\"]" "$FILE" 2>/dev/null | head -3)
[ -n "$FSTR" ] && VIOLATIONS="${VIOLATIONS}\n[f-string] Use .format() em vez de f-strings:\n${FSTR}"

# else blocks após if/for/while
ELSE=$(grep -nP '^\s+else\s*:' "$FILE" 2>/dev/null | head -3)
[ -n "$ELSE" ] && VIOLATIONS="${VIOLATIONS}\n[else] Evite else — use early return:\n${ELSE}"

# Type hints: retorno (->) ou parâmetros com anotação de tipo padrão
RETURN=$(grep -nP '\bdef \w+.*->' "$FILE" 2>/dev/null | head -3)
[ -n "$RETURN" ] && VIOLATIONS="${VIOLATIONS}\n[type hint] Return type hints não são usados:\n${RETURN}"

PARAM=$(grep -nP '\bdef \w+\([^)]*:\s*(str|int|float|bool|list|dict|tuple|set|Any|Optional|Union)\b' "$FILE" 2>/dev/null | head -3)
[ -n "$PARAM" ] && VIOLATIONS="${VIOLATIONS}\n[type hint] Parameter type hints não são usados:\n${PARAM}"

# Docstrings (triple quotes após def/class)
DOCS=$(grep -nP '^\s+"""' "$FILE" 2>/dev/null | head -3)
[ -n "$DOCS" ] && VIOLATIONS="${VIOLATIONS}\n[docstring] Não use docstrings — nomes descritivos bastam:\n${DOCS}"

if [ -n "$VIOLATIONS" ]; then
    REASON=$(printf "Violações de convenção em %s:%b\n\nCorrija antes de continuar." "$FILE" "$VIOLATIONS")
    jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
fi

exit 0
