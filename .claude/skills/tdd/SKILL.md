---
name: tdd
description: Guides a complete TDD cycle — spec, failing tests, implementation, mutation verification. Use when starting any new feature or behavior change.
---

# TDD: $ARGUMENTS

Assume que requisitos EARS já existem e foram aprovados em `$ARGUMENTS`.
Inicia diretamente na geração de critérios de aceite.

---

## Fase 1 — Spec (Critérios de Aceite)

```bash
TASK_ID=$(pipeline task list --status "em andamento" --format json | python3 -c "
import sys, json
tasks = json.load(sys.stdin)
print(tasks[0]['id'] if tasks else '')
")
pipeline ears list $TASK_ID
```

Para cada requisito EARS, derivar cenários Given/When/Then.
Cada "Então" mapeia para um método: `test<Cenário>_<Condição>`.

**Apresentar spec e aguardar confirmação explícita antes de continuar.**

Após aprovação:
```bash
pipeline criterion add $TASK_ID --ears <R_ID> --scenario "<nome>" \
    --given "<dado>" --when "<quando>" --then "<então>" --test "testXxx_Yyy"
# ... repetir para cada cenário

pipeline criterion approve $TASK_ID all
pipeline phase advance $TASK_ID --to tests
```

---

## Fase 2 — Testes que Falham

Para cada "Então" aprovado, escrever o método de teste:

```python
def test<Cenário>_<Condição>(self):
    # Critério: <Então do spec>

    # Arrange
    <setup>

    # Act
    <chamada>

    # Assert
    <assertion que verifica exatamente o "Então">
```

**Executar os testes — todos DEVEM falhar:**
```bash
python3 -m pytest tests/ -v
```

O hook `record-test-results.sh` registra os resultados automaticamente.

Após confirmar que todos falham pelo motivo correto:
```bash
pipeline phase advance $TASK_ID --to implementation
```

---

## Fase 3 — Implementação

Implementar o mínimo para os testes passarem:
- Nenhuma funcionalidade além do que os testes exigem
- Seguir convenções (camelCase, sem else, `.format()`, sem type hints, sem docstrings)
- Executar testes após cada mudança significativa

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

Para cada mutante sobrevivente:
- **Gap de teste:** adicionar assertion que mata o mutante
- **Equivalente:** `# pragma: no mutate — <justificativa>`

**Não concluir antes que o mutation score seja 100%.**

---

## Fase 5 — Conclusão

```bash
pipeline audit $TASK_ID
```

Se READY:
```bash
pipeline phase advance $TASK_ID --to done
pipeline task update $TASK_ID --status "concluído"
```

Checklist:
- [ ] `pipeline audit $TASK_ID` → READY ✓
- [ ] Todos os testes passam
- [ ] Mutation score: 100%
- [ ] Convenções seguidas
