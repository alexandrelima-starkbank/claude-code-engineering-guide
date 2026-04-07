#!/bin/bash
# PreToolUse/Bash — bloqueia comandos destrutivos sem confirmação explícita.

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook validate-destructive desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Deleção recursiva — cobre: rm -rf, rm -fr, rm -r -f, sudo rm -rf e variantes com flags combinadas
if echo "$CMD" | grep -qE '(^|[[:space:];|&])(sudo[[:space:]]+)?rm[[:space:]]+[^;&|]*(-[a-zA-Z]*rf|-[a-zA-Z]*fr|-r[[:space:]]+-f|-f[[:space:]]+-r|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)'; then
    echo "BLOQUEADO: 'rm -rf' requer confirmação explícita do usuário." >&2
    exit 2
fi

# git push destrutivo — cobre --force, -f e --force-with-lease em qualquer posição após push
if echo "$CMD" | grep -qE '\bgit\s+push\b' && echo "$CMD" | grep -qE '[[:space:]](--force|-f|--force-with-lease)\b'; then
    echo "BLOQUEADO: 'git push --force' requer confirmação explícita." >&2
    exit 2
fi

# git reset destrutivo
if echo "$CMD" | grep -qE '\bgit\s+reset\s+--hard\b'; then
    echo "BLOQUEADO: 'git reset --hard' requer confirmação explícita." >&2
    exit 2
fi

# git checkout -- e git restore — descartam alterações não commitadas irreversivelmente
# Exceção: git restore --staged (sem --worktree/-W) apenas remove do staging — operação segura
if echo "$CMD" | grep -qE '\bgit\s+checkout\s+--\s+'; then
    echo "BLOQUEADO: 'git checkout --' descarta alterações não commitadas. Requer confirmação explícita." >&2
    exit 2
fi

if echo "$CMD" | grep -qE '\bgit\s+restore\b'; then
    if ! (echo "$CMD" | grep -qE '\bgit\s+restore\b.*--staged' && ! echo "$CMD" | grep -qE '\bgit\s+restore\b.*(--worktree|-W)\b'); then
        echo "BLOQUEADO: 'git restore' descarta alterações não commitadas. Requer confirmação explícita." >&2
        exit 2
    fi
fi

# git clean — descarta arquivos não rastreados irreversivelmente
if echo "$CMD" | grep -qE '\bgit\s+clean\s+[^|;&]*-[a-zA-Z]*f'; then
    echo "BLOQUEADO: 'git clean -f' descarta arquivos não rastreados. Requer confirmação explícita." >&2
    exit 2
fi

# git stash drop/clear — descartam stashes irreversivelmente
if echo "$CMD" | grep -qE '\bgit\s+stash\s+(drop|clear)\b'; then
    echo "BLOQUEADO: 'git stash drop/clear' descarta trabalho salvo irreversivelmente. Requer confirmação explícita." >&2
    exit 2
fi

# DDL destrutivo em banco de dados
if echo "$CMD" | grep -qiE '\b(DROP\s+(TABLE|DATABASE|SCHEMA)|TRUNCATE\s+TABLE)\b'; then
    echo "BLOQUEADO: operação DDL destrutiva requer confirmação explícita." >&2
    exit 2
fi

exit 0
