#!/bin/bash
# PreToolUse/Bash — bloqueia comandos destrutivos sem confirmação explícita.

INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))")

# Deleção recursiva de arquivos
if echo "$CMD" | grep -qE '\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive.*--force|--force.*--recursive)\b|\brm\s+-rf\b|\brm\s+-fr\b'; then
    echo "BLOQUEADO: 'rm -rf' requer confirmação explícita do usuário." >&2
    exit 2
fi

# Operações git destrutivas
if echo "$CMD" | grep -qE '\bgit\s+(push\s+--force|push\s+-f|reset\s+--hard)\b'; then
    echo "BLOQUEADO: operação git destrutiva requer confirmação explícita." >&2
    exit 2
fi

# DDL destrutivo em banco de dados
if echo "$CMD" | grep -qiE '\b(DROP\s+(TABLE|DATABASE|SCHEMA)|TRUNCATE\s+TABLE)\b'; then
    echo "BLOQUEADO: operação DDL destrutiva requer confirmação explícita." >&2
    exit 2
fi

exit 0
