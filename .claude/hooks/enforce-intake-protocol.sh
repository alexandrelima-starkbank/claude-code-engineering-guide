#!/bin/bash
# UserPromptSubmit — força o Intake Protocol quando não há tarefa ativa no banco.
# Injeta mandato obrigatório antes de qualquer trabalho técnico sem tarefa criada.

if ! command -v jq &>/dev/null || ! command -v pipeline &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Detecta intenção de trabalho (feature, bug, refactor, implementação)
WORK_PATTERN='(feature|funcionalidade|preciso de|quero que|implementar|implementa|criar|crie|adicionar|adicione|desenvolver|desenvolva|bug|erro|problema|quebrou|não funciona|refactor|refatorar|corrigir|corrige|fix|consertar|melhora|melhorar|otimizar)'
if ! echo "$PROMPT" | grep -qiE "$WORK_PATTERN"; then
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

# Sem tarefa ativa — injeta mandato de intake
jq -n '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: "INTAKE PROTOCOL — EXECUÇÃO OBRIGATÓRIA\n\nNenhuma tarefa ativa no banco de dados. Antes de qualquer trabalho técnico, execute o protocolo completo:\n\n1. Classifique a intenção: feature | bug | incident | investigation | question | refactor\n2. Consulte contexto existente: pipeline context search \"<resumo da solicitação>\"\n3. Entreviste (máx 3 perguntas por rodada) até artefato satisfatório\n4. Crie a tarefa: pipeline task create --title \"<título>\"\n\nNÃO escreva código. NÃO faça análise técnica. NÃO responda à questão técnica.\nResponda APENAS conduzindo o Intake Protocol acima."
    }
}'
