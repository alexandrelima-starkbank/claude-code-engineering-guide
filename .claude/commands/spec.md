---
description: Gera critérios de aceite BDD (Given/When/Then) a partir dos EARS aprovados. Grava no banco de dados após aprovação.
allowed-tools: Read, Grep, Glob, Bash
---
# Spec: $ARGUMENTS

Feature ou comportamento: **$ARGUMENTS**

---

## Processo

### 1. Ler os EARS aprovados da tarefa ativa

```bash
TASK_ID=$(pipeline task list --status "em andamento" --format json | python3 -c "
import sys, json
tasks = json.load(sys.stdin)
print(tasks[0]['id'] if tasks else '')
")
pipeline ears list $TASK_ID
```

Se não existirem requisitos EARS aprovados, interromper e redirecionar para `/requirements`.

### 2. Ler código relevante

Ler os arquivos de código afetados para entender domínio, restrições e comportamentos existentes.

### 3. Derivar cenários dos EARS

Para cada requisito EARS, derivar um ou mais cenários Given/When/Then:
- Cada "Então" mapeia para exatamente um método de teste: `test<Cenário>_<Condição>`
- Cada cenário indica o requisito EARS de origem
- Cobrir: caminho feliz, erros (IF/THEN), edge cases, valores de fronteira

Formato de apresentação:

```
**Cenário: <nome descritivo>** ← <EARS ID>
- Dado: <pré-condições>
- Quando: <ação>
- Então: <resultado esperado> → `testXxx_Yyy`
```

### 4. Apresentar e aguardar aprovação

Apresentar todos os cenários ao engenheiro. Aguardar aprovação explícita.
Não avançar sem aprovação.

---

## Após aprovação

```bash
# Gravar cada cenário aprovado
pipeline criterion add $TASK_ID \
    --ears R01 \
    --scenario "Criação bem-sucedida" \
    --given "body válido com external_id único" \
    --when "POST /items" \
    --then "status 201, item persisted no banco" \
    --test "testCreate_Success"

# Repetir para cada cenário

# Aprovar todos e avançar fase
pipeline criterion approve $TASK_ID all
pipeline phase advance $TASK_ID --to tests
```

Confirmar ao engenheiro: "Spec gravada em $TASK_ID. Próximo passo: testes que falham."
