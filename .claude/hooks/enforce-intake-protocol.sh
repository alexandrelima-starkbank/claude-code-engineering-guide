#!/bin/bash
# UserPromptSubmit — força o Intake Protocol quando não há tarefa ativa no banco.
# Injeta mandato obrigatório antes de qualquer trabalho de produto sem tarefa criada.
# Operações administrativas e investigações são excluídas — executam diretamente.

if ! command -v jq &>/dev/null || ! command -v pipeline &>/dev/null; then
    exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Exclui operações administrativas do ambiente (intent=admin)
ADMIN_PATTERN='(^/|smoke.?test|testar.?ambiente|verificar.?install|verificar.?ambiente|audit|auditoria|atualizar.?ambiente|update.?ambiente|instalar|instalação|configurar|configure|setup|pipeline (task|ears|criterion|phase|context|audit|export)|/update|/my_tasks|/daily|/pipeline-audit)'
if echo "$PROMPT" | grep -qiE "$ADMIN_PATTERN"; then
    exit 0
fi

# Exclui perguntas e investigações (intent=question, intent=investigation)
QUESTION_PATTERN='(^como |^por que |^o que |^qual |^onde |^quando |^quem |^existe |^há |^tem |me (explica|explique|mostra|mostre)|o que (é|são|faz|acontece)|como funciona|entend)'
if echo "$PROMPT" | grep -qiE "$QUESTION_PATTERN"; then
    exit 0
fi

# Detecta intenção de trabalho de produto (feature, bug, refactor, incident)
WORK_PATTERN='(feature|funcionalidade|preciso (de|que)|quero (que|adicionar|implementar)|implementar|implementa|criar|crie|adicionar|adicione|desenvolver|desenvolva|bug|quebrou|não funciona|parou de funcionar|refactor|refatorar|corrigir|corrige|fix\b|consertar|em produção|clientes afetados|incidente)'
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
        additionalContext: "INTAKE PROTOCOL — EXECUÇÃO OBRIGATÓRIA\n\nNenhuma tarefa ativa no banco de dados. Antes de qualquer trabalho de produto, execute o protocolo completo:\n\n1. Classifique a intenção:\n   - feature | bug | incident | refactor → Intake obrigatório, criar tarefa\n   - investigation | question → responder diretamente, sem tarefa\n   - admin → executar diretamente, sem tarefa\n2. Se for trabalho de produto: consulte contexto — pipeline context search \"<resumo>\"\n3. Entreviste até artefato satisfatório (sem limite fixo de perguntas)\n4. Crie a tarefa: pipeline task create --title \"<título>\"\n\nNÃO escreva código. NÃO faça análise técnica antes do Intake.\nNÃO crie tarefas para operações administrativas ou investigações."
    }
}'
