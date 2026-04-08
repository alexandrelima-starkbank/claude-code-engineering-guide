#!/bin/bash
# PreToolUse/Bash — bloqueia git commit se os testes falharem.
# Intercepta qualquer "git commit" e roda a suite de testes antes de permitir.

CMD=$(cat | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null)

# Só intercepta git commit
echo "$CMD" | grep -qE "git\s+commit" || exit 0

# Encontra a raiz do projeto (pytest.ini, pyproject.toml ou Pipfile)
DIR=$(pwd)
while [ "$DIR" != "/" ]; do
    { [ -f "$DIR/pytest.ini" ] || [ -f "$DIR/pyproject.toml" ] || [ -f "$DIR/Pipfile" ]; } && break
    DIR=$(dirname "$DIR")
done

# Detecta o runner Python disponível
if [ -f "$DIR/.venv/bin/python" ]; then
    PYTHON="$DIR/.venv/bin/python"
elif command -v python3 &>/dev/null; then
    PYTHON="python3"
else
    echo "Python não encontrado — gate de testes ignorado" >&2
    exit 0
fi

echo "Rodando suite de testes antes do commit..." >&2
cd "$DIR" && $PYTHON -m pytest -q --tb=line 2>&1 | tail -5 >&2
RESULT=${PIPESTATUS[0]}

if [ $RESULT -ne 0 ]; then
    echo "" >&2
    echo "BLOQUEADO: testes falhando. Corrija antes de commitar." >&2
    exit 2
fi

echo "Testes passando. Commit permitido." >&2
exit 0
