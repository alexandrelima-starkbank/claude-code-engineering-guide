#!/bin/bash
# PreToolUse/Bash — bloqueia comandos destrutivos sem confirmação explícita.
# Nota: validação é baseada em texto (best-effort).
#   - Comandos via eval/bash -c não são interceptados (falso negativo esperado).
#   - Padrões sem aspas (ex: echo rm -rf /tmp) podem ser bloqueados erroneamente.
#     Strings com aspas (ex: echo "rm -rf /tmp") não são afetadas pois a aspa não é
#     reconhecida como separador de palavra pela regex.

if ! command -v jq &>/dev/null; then
    echo "AVISO: jq não encontrado — hook validate-destructive desabilitado. Execute ./setup.sh" >&2
    exit 0
fi

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Deleção recursiva — cobre: rm -rf, rm -fr, rm -r -f, sudo rm -rf e variantes
# Exceção: /tmp/ é diretório temporário do sistema, sempre seguro para deletar
if echo "$CMD" | grep -qE '(^|[[:space:];|&])(sudo[[:space:]]+)?rm[[:space:]]+[^;&|]*(-[a-zA-Z]*rf|-[a-zA-Z]*fr|-r[[:space:]]+-f|-f[[:space:]]+-r|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)'; then
    if ! echo "$CMD" | grep -qE 'rm[[:space:]]+[^;&|]*/tmp/'; then
        echo "BLOQUEADO: 'rm -rf' requer confirmação explícita do usuário." >&2
        exit 2
    fi
fi

# git push destrutivo — --force, -f ou --force-with-lease em qualquer posição após push
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+push([[:space:]]|$)' && \
   echo "$CMD" | grep -qE '[[:space:]](--force|--force-with-lease)([[:space:]]|$)|[[:space:]]-f([[:space:]]|$)'; then
    echo "BLOQUEADO: 'git push --force' requer confirmação explícita." >&2
    exit 2
fi

# git reset --hard
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+reset[[:space:]]+--hard([[:space:]]|$)'; then
    echo "BLOQUEADO: 'git reset --hard' requer confirmação explícita." >&2
    exit 2
fi

# git checkout -- descarta alterações não commitadas
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+checkout[[:space:]]+--[[:space:]]'; then
    echo "BLOQUEADO: 'git checkout --' descarta alterações não commitadas. Requer confirmação explícita." >&2
    exit 2
fi

# git restore — bloqueia exceto --staged sem --worktree/-W (unstage é operação segura)
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+restore([[:space:]]|$)'; then
    if ! (echo "$CMD" | grep -qE '[[:space:]]--staged([[:space:]]|$)' && \
          ! echo "$CMD" | grep -qE '[[:space:]](--worktree|-W)([[:space:]]|$)'); then
        echo "BLOQUEADO: 'git restore' descarta alterações não commitadas. Requer confirmação explícita." >&2
        exit 2
    fi
fi

# git clean -f descarta arquivos não rastreados
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+clean[[:space:]]+[^|;&]*-[a-zA-Z]*f'; then
    echo "BLOQUEADO: 'git clean -f' descarta arquivos não rastreados. Requer confirmação explícita." >&2
    exit 2
fi

# git branch -D — deleta branch sem verificar merge, trabalho não mergeado é perdido
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+branch[[:space:]]+-D([[:space:]]|$)'; then
    echo "BLOQUEADO: 'git branch -D' deleta branch irreversivelmente. Requer confirmação explícita." >&2
    exit 2
fi

# git stash drop/clear descartam stashes irreversivelmente
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+stash[[:space:]]+(drop|clear)([[:space:]]|$)'; then
    echo "BLOQUEADO: 'git stash drop/clear' descarta trabalho salvo irreversivelmente. Requer confirmação explícita." >&2
    exit 2
fi

# git commit com Co-Authored-By — proibido por convenção do projeto
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)' && \
   echo "$CMD" | grep -qi 'Co-Authored-By'; then
    echo "BLOQUEADO: mensagem de commit não pode conter 'Co-Authored-By'." >&2
    exit 2
fi

# git commit -F <arquivo> ou --file=<arquivo> com Co-Authored-By no conteúdo
if echo "$CMD" | grep -qE '(^|[[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    COMMIT_FILE=$(echo "$CMD" | grep -oE '(-F[[:space:]]+[^[:space:];&|]+|--file=[^[:space:];&|]+)' | \
        sed 's/^-F[[:space:]]*//' | sed 's/^--file=//' | head -1)
    if [ -n "$COMMIT_FILE" ] && [ -f "$COMMIT_FILE" ] && grep -qi 'Co-Authored-By' "$COMMIT_FILE"; then
        echo "BLOQUEADO: arquivo '${COMMIT_FILE}' contém 'Co-Authored-By'." >&2
        exit 2
    fi
fi

# DDL destrutivo
if echo "$CMD" | grep -qiE 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)|TRUNCATE[[:space:]]+TABLE'; then
    echo "BLOQUEADO: operação DDL destrutiva requer confirmação explícita." >&2
    exit 2
fi

exit 0
