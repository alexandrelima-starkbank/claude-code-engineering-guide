#!/bin/bash
# UserPromptSubmit — força o Intake Protocol para qualquer prompt que envolva mudança.
# Isentos: slash commands puros e perguntas/investigações sem intenção de alterar.

if ! command -v jq &>/dev/null || ! command -v pipeline &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Isenta apenas slash commands puros (/update, /my_tasks, /daily, etc.)
if echo "$PROMPT" | grep -qE '^\s*/[a-z]'; then
    exit 0
fi

# Isenta perguntas e investigações que não contenham intenção de alterar algo
QUESTION_PATTERN='(^como |^por que |^o que |^qual |^onde |^quando |^quem |^existe |^há |^tem |me (explica|explique|mostra|mostre)|o que (é|são|faz|acontece)|como funciona|entend)'
CHANGE_PATTERN='(alter|mud|commit|push|implementa|cri[ae]\b|adicion|desenvolv|fix\b|corrij|refactor|instala|configura|setup|faça|faz\b|escreve|escreva|atualiz|remov|delet|apag|deploy|sobe\b|publ)'

if echo "$PROMPT" | grep -qiE "$QUESTION_PATTERN" && ! echo "$PROMPT" | grep -qiE "$CHANGE_PATTERN"; then
    exit 0
fi

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
