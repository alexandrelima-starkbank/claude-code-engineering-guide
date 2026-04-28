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

# Sem tarefa ativa — injeta mandato específico por intent
case "$INTENT" in
    feature)
        TOOL_GUIDANCE="Ferramenta: /feature (orquestra EARS → spec → tdd end-to-end)\nAlternativamente: /requirements → /spec → /tdd em etapas separadas.\nSe a mudança tocar models, gateways, enums ou contratos de API: execute /blast-radius antes de implementar."
        ;;
    bug)
        TOOL_GUIDANCE="Ferramenta: depende do root cause.\n  Root cause DESCONHECIDO → /support (N3: investigação cross-service via support-investigator)\n  Root cause CONHECIDO   → /bugfix (N4: reproduzir com teste de regressão, então corrigir)"
        ;;
    incident)
        TOOL_GUIDANCE="Ferramenta: /support (N3: intake estruturado → investigação → root cause → gate N3/N4)"
        ;;
    refactor)
        TOOL_GUIDANCE="Ferramenta: AGENT-DEV para implementação.\nPré-requisito: /blast-radius se a mudança cruzar fronteiras de serviço.\nPós-implementação: /verify-delivery (obrigatório antes de concluído)."
        ;;
    *)
        TOOL_GUIDANCE="Classifique a intenção: feature | bug | incident | refactor"
        ;;
esac

jq -n --arg tool "$TOOL_GUIDANCE" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: ("INTAKE PROTOCOL — EXECUÇÃO OBRIGATÓRIA\n\nNenhuma tarefa ativa no banco. SUA PRÓXIMA RESPOSTA DEVE CONTER APENAS PERGUNTAS DE ESCLARECIMENTO.\n\nEXPLICITAMENTE PROIBIDO na próxima resposta:\n- Escrever qualquer código\n- Propor soluções técnicas\n- Analisar arquivos ou estruturas\n- Iniciar qualquer implementação\n\n\($tool)\n\nPassos obrigatórios:\n1. Consulte contexto: pipeline context search \"<resumo da solicitação>\"\n2. Entreviste até o comportamento esperado estar completamente sem ambiguidade\n3. Mostre o artefato provisional e aguarde confirmação explícita\n4. Crie a tarefa: pipeline task create --title \"<título>\" --type <intent>")
    }
}'
