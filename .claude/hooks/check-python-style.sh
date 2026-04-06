#!/bin/bash
# PostToolUse/Edit|Write|MultiEdit — enforce convenções de estilo Python.
# Detecta: f-strings, else blocks, type hints, docstrings.
# Usa python3 para detecção — compatível com macOS (BSD grep não suporta -P).

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook check-python-style desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$FILE" =~ \.py$ ]] || exit 0
[ -f "$FILE" ] || exit 0

# python3 é dependência obrigatória (verificada em setup.sh)
VIOLATIONS=$(python3 - "$FILE" <<'PYEOF'
import sys, re

path = sys.argv[1]
try:
    lines = open(path).readlines()
except Exception:
    sys.exit(0)

violations = []
prev_was_def_or_class = False

for i, line in enumerate(lines, 1):
    stripped = line.rstrip()

    # f-strings: f"..." ou f'...' — exige que 'f' não seja precedido por letra/número
    if re.search(r'(?<![a-zA-Z0-9_])f["\']', stripped):
        violations.append("[f-string] linha {}: Use .format() em vez de f-strings".format(i))

    # else blocks — exclui for/else e try/except/else via contexto simples
    if re.match(r'^\s+else\s*:', stripped):
        violations.append("[else] linha {}: Evite else — use early return".format(i))

    # Return type hints: def func(...) -> Type:
    if re.match(r'^\s*def\s+\w+.*->', stripped):
        violations.append("[type hint] linha {}: Return type hints não são usados".format(i))

    # Parameter type hints com anotações de tipo padrão
    if re.match(r'^\s*def\s+\w+\(', stripped):
        if re.search(r':\s*(str|int|float|bool|list|dict|tuple|set|Any|Optional|Union)\b', stripped):
            violations.append("[type hint] linha {}: Parameter type hints não são usados".format(i))

    # Docstrings: triple-quote apenas quando linha anterior era def/class
    if prev_was_def_or_class and re.match(r'^\s+"""', stripped):
        violations.append("[docstring] linha {}: Não use docstrings — nomes descritivos bastam".format(i))

    prev_was_def_or_class = bool(
        re.match(r'^\s*(def|class)\s+', stripped) and stripped.rstrip().endswith(':')
    )

for v in violations[:9]:
    print(v)
PYEOF
)

if [ -n "$VIOLATIONS" ]; then
    REASON=$(printf "Violações de convenção em %s:\n\n%s\n\nCorrija antes de continuar." "$FILE" "$VIOLATIONS")
    jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
fi

exit 0
