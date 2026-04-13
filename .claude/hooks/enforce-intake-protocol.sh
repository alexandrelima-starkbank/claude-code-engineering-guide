#!/bin/bash
# UserPromptSubmit — força o Intake Protocol para qualquer prompt que envolva mudança.
# Usa modelo menor (haiku) para classificação de intent quando disponível.
# Fallback para heurísticas regex se API indisponível.

if ! command -v jq &>/dev/null || ! command -v pipeline &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Isenta slash commands puros (/update, /my_tasks, /daily, etc.)
if echo "$PROMPT" | grep -qE '^\s*/[a-z]'; then
    exit 0
fi

# Classificação de intent via modelo menor (haiku)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTENT=$(echo "$PROMPT" | python3 "${SCRIPT_DIR}/classify_intent.py" 2>/dev/null)

# Fallback para heurísticas se modelo indisponível
if [ "$INTENT" = "unknown" ] || [ -z "$INTENT" ]; then
    QUESTION_PATTERN='(^como |^por que |^o que |^qual |^onde |^quando |^quem |^existe |^há |^tem |me (explica|explique|mostra|mostre)|o que (é|são|faz|acontece)|como funciona|entend|^how |^why |^what |^where |^when |^who |^is there |^does |^can you explain|^show me|how does)'
    CHANGE_PATTERN='(alter|mud|commit|push|implementa|cri[ae]\b|adicion|desenvolv|fix\b|corrij|refactor|instala|configura|setup|faça|faz\b|escreve|escreva|atualiz|remov|delet|apag|deploy|sobe\b|publ|implement|create|add|write|build|develop|install|configure|make|update|remove|delete|publish)'

    if echo "$PROMPT" | grep -qiE "$QUESTION_PATTERN" && ! echo "$PROMPT" | grep -qiE "$CHANGE_PATTERN"; then
        INTENT="question"
    else
        INTENT="change"
    fi
    CLASSIFICATION_SOURCE="heuristic"
else
    CLASSIFICATION_SOURCE="haiku"
fi

# Log da classificação (stderr — visível em verbose)
echo "[intake] intent=${INTENT} source=${CLASSIFICATION_SOURCE}" >&2

# Isentar intents que não requerem tarefa
case "$INTENT" in
    question|investigation|admin)
        exit 0
        ;;
esac

# Verifica se há tarefa ativa
ACTIVE_COUNT=$(pipeline task list --status "em andamento" --format json 2>/dev/null | python3 -c "
import sys, json
try:
    tasks = json.load(sys.stdin)
    print(len(tasks))
except:
    print(0)
" 2>/dev/null || echo "0")

[ "${ACTIVE_COUNT:-0}" -gt 0 ] && exit 0

# Sem tarefa ativa — injeta mandato obrigatório
jq -n '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: "INTAKE PROTOCOL — EXECUÇÃO OBRIGATÓRIA\n\nNenhuma tarefa ativa no banco. SUA PRÓXIMA RESPOSTA DEVE CONTER APENAS PERGUNTAS DE ESCLARECIMENTO.\n\nEXPLICITAMENTE PROIBIDO na próxima resposta:\n- Escrever qualquer código\n- Propor soluções técnicas\n- Analisar arquivos ou estruturas\n- Iniciar qualquer implementação\n- Fazer alterações de qualquer natureza\n\nEsta restrição se aplica a QUALQUER prompt — incluindo operações de ambiente, testes e alterações descritas como triviais.\n\nPassos obrigatórios:\n1. Classifique a intenção: feature | bug | incident | refactor | investigation | question\n2. Consulte contexto: pipeline context search \"<resumo da solicitação>\"\n3. Entreviste até o comportamento esperado estar completamente sem ambiguidade\n4. Mostre o artefato provisional e aguarde confirmação explícita\n5. Somente então crie a tarefa: pipeline task create --title \"<título>\" --type <intent>"
    }
}'
