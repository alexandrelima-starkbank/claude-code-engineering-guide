---
name: feature
description: Desenvolvimento end-to-end de uma feature — da elicitação de requisitos EARS ao código testado. Orquestra requirements → spec → tdd. Use quando começar qualquer feature nova.
---

# Feature: $ARGUMENTS

Desenvolvimento completo com rastreabilidade total: requisitos EARS → critérios de aceite → testes → código.

---

## Fase 0 — Intake e Requisitos EARS

### 0a. Consultar contexto semântico

```bash
pipeline context search "$ARGUMENTS"
```

Se encontrar requisitos similares ou decisões relevantes: apresentar ao engenheiro antes de perguntar.

### 0b. Elicitar e aprovar EARS

1. Analisar `$ARGUMENTS` — mapear o que está claro e o que está ambíguo
2. Se houver gaps críticos, fazer até 3 perguntas objetivas e aguardar resposta
3. Gerar requisitos nos padrões EARS aplicáveis
4. Validar completude internamente (caminho feliz, erros, sem ambiguidade, testáveis)
5. **Apresentar e aguardar aprovação explícita**

### 0c. Gravar no banco (após aprovação)

```bash
# Criar task se não existir
TASK_ID=$(pipeline task create --title "<título>")

# Gravar cada EARS
pipeline ears add $TASK_ID --pattern <padrão> --text "<requisito>"
# ... repetir para cada requisito

# Aprovar e avançar fase
pipeline ears approve $TASK_ID all
pipeline phase advance $TASK_ID --to spec
```

**GATE:** não avançar para Fase 1 sem aprovação explícita e fase = `spec` no DB.

---

## Fase 1 — Spec (Critérios de Aceite)

### 1a. Derivar cenários dos EARS aprovados

```bash
pipeline ears list $TASK_ID
```

Para cada requisito EARS, derivar um ou mais cenários Given/When/Then.
Cada "Então" mapeia para exatamente um método de teste: `test<Cenário>_<Condição>`.
Manter rastreabilidade — cada cenário indica o EARS de origem.

### 1b. Apresentar e aguardar aprovação explícita

### 1c. Gravar no banco (após aprovação)

```bash
pipeline criterion add $TASK_ID \
    --ears <R_ID> \
    --scenario "<nome>" \
    --given "<dado>" \
    --when "<quando>" \
    --then "<então>" \
    --test "testXxx_Yyy"
# ... repetir para cada cenário

pipeline criterion approve $TASK_ID all
pipeline phase advance $TASK_ID --to tests
```

**GATE:** não avançar para Fase 2 sem aprovação explícita e fase = `tests` no DB.

---

## Fase 2 — Testes que Falham

Para cada "Então" aprovado, escrever o método de teste correspondente:

```python
def test<Cenário>_<Condição>(self):
    # Requisito: <EARS de origem>
    # Critério: <Então do spec>

    # Arrange
    <setup>

    # Act
    <chamada>

    # Assert
    <assertion que verifica exatamente o "Então">
```

**Executar os testes — todos DEVEM falhar.**
Se algum passar antes da implementação existir, ele não está testando corretamente.

Após confirmar que todos falham pelo motivo correto, **avaliar a qualidade de cada teste**:

Para cada critério com `testMethod`, responder: *"esta assertion detectaria o bug descrito no 'Então' se a implementação estivesse errada?"*

```bash
# Registrar qualidade de cada critério (STRONG / ACCEPTABLE / WEAK)
pipeline criterion set-quality $TASK_ID <C_ID> STRONG

# STRONG     — assertion verifica o comportamento exato do "Então"
# ACCEPTABLE — verifica o comportamento mas poderia ser mais precisa
# WEAK       — verifica apenas que não lançou exceção ou que algo retornou
```

Critérios WEAK devem ter a assertion reescrita antes de avançar.

Após qualidade avaliada (o hook `record-test-results.sh` registra automaticamente):
```bash
pipeline phase advance $TASK_ID --to implementation
```

---

## Fase 3 — Implementação

Implementar o mínimo de código para os testes passarem:
- Nenhuma funcionalidade além do que os testes exigem
- Seguir todas as convenções (camelCase, sem else, `.format()`, sem type hints, sem docstrings)
- Executar os testes após cada mudança significativa
- Parar quando todos passarem

Após todos os testes passarem:
```bash
pipeline phase advance $TASK_ID --to mutation
```

---

## Fase 4 — Verificação por Mutação

```bash
mutmut run --paths-to-mutate <arquivo-implementado>
mutmut results
```

O hook `record-mutation-results.sh` registra o score automaticamente.

Para cada mutante sobrevivente (`mutmut show <id>`):
- **Lacuna no teste:** adicionar assertion que mata o mutante
- **Equivalente:** adicionar `# pragma: no mutate — <justificativa>`

**Não concluir antes que o mutation score seja 100%.**

---

## Fase 5 — Conclusão

```bash
# Verificar gates
pipeline audit $TASK_ID

# Se READY, registrar decisões relevantes e concluir
pipeline context add --text "<decisão arquitetural>" --type decision --task $TASK_ID
pipeline phase advance $TASK_ID --to done
pipeline task update $TASK_ID --status "concluído"
```

Checklist final:
- [ ] `pipeline audit $TASK_ID` → READY ✓
- [ ] Todos os requisitos EARS têm cenários correspondentes
- [ ] Mutation score: 100%
- [ ] Convenções seguidas
