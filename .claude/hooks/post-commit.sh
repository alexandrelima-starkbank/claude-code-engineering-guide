#!/bin/bash
# post-commit — re-indexa arquivos Python modificados no ChromaDB.
# Instalado em .git/hooks/post-commit de cada projeto por `pipeline index`.

if ! command -v pipeline &>/dev/null; then
    exit 0
fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$ROOT" ] && exit 0

MODIFIED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null | grep '\.py$')
[ -z "$MODIFIED" ] && exit 0

for file in $MODIFIED; do
    ABS="${ROOT}/${file}"
    [ -f "$ABS" ] && pipeline index-file "$ABS" 2>/dev/null || true
done
