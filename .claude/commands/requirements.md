---
description: Elicita e documenta requisitos no formato EARS. Grava no banco de dados após aprovação. Use antes de /spec.
allowed-tools: Read, Grep, Glob, Bash
---
# Requirements: $ARGUMENTS

## Responsabilidade

Produzir requisitos EARS completos, sem ambiguidade e aprovados pelo engenheiro.
Não gera spec, testes ou código.

---

## Processo

### 1. Leitura de contexto

- Ler `CLAUDE.md` para entender domínio e convenções
- Verificar se há tarefa ativa: `pipeline task list --status "em andamento" --format context`
- Buscar contexto semântico relevante: `pipeline context search "<tema>"`

### 2. Análise do problema

Mapear a partir de `$ARGUMENTS`:
- **Sistema/componente afetado**: qual módulo, serviço ou camada?
- **Triggers e eventos**: o que dispara o comportamento?
- **Respostas esperadas**: o que o sistema deve fazer em cada caso?
- **Comportamentos indesejados**: falhas, inputs inválidos, estados inesperados
- **Condicionais**: features opcionais, variações de contexto

### 3. Elicitação de gaps

Se informações críticas estiverem ausentes: fazer até 3 perguntas objetivas e aguardar
resposta antes de gerar os requisitos. Não inferir o que pode ser perguntado.

### 4. Geração dos requisitos EARS

| Padrão | Template |
|--------|----------|
| Ubíquo | `O <sistema> SHALL <resposta>` |
| Orientado a evento | `WHEN <trigger>, o <sistema> SHALL <resposta>` |
| Orientado a estado | `WHILE <estado>, o <sistema> SHALL <resposta>` |
| Comportamento indesejado | `IF <trigger>, THEN o <sistema> SHALL <resposta>` |
| Feature opcional | `WHERE <feature incluída>, o <sistema> SHALL <resposta>` |

**Regras:** um requisito = uma condição + uma resposta. Sem ambiguidade. Sem implementação. Testável.

### 5. Validação interna antes de apresentar

- [ ] Caminho feliz coberto
- [ ] Comportamentos de erro cobertos (IF/THEN)
- [ ] Nenhum requisito ambíguo
- [ ] Cada requisito é testável

### 6. Apresentação e aprovação

Apresentar os requisitos e aguardar aprovação explícita. Incorporar feedback e iterar.
Não avançar sem aprovação.

---

## Após aprovação

```bash
# 1. Garantir que a tarefa existe
TASK_ID=$(pipeline task list --status "em andamento" --format json | python3 -c "
import sys, json
tasks = json.load(sys.stdin)
print(tasks[0]['id'] if tasks else '')
")

# Se não existir tarefa ativa, criar
if [ -z "$TASK_ID" ]; then
    TASK_ID=$(pipeline task create --title "<título da feature>")
fi

# 2. Gravar cada EARS aprovado
pipeline ears add $TASK_ID --pattern event --text "WHEN ..."   # → R01
pipeline ears add $TASK_ID --pattern unwanted --text "IF ..."  # → R02
# ... repetir para cada requisito

# 3. Aprovar todos e avançar fase
pipeline ears approve $TASK_ID all
pipeline phase advance $TASK_ID --to spec
```

Confirmar ao engenheiro: "Requisitos gravados em $TASK_ID. Próximo passo: spec BDD."
