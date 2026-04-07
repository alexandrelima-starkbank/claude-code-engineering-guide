---
name: tdd
description: Guides a complete TDD cycle — spec, failing tests, implementation, mutation verification. Use when starting any new feature or behavior change.
---

# TDD: $ARGUMENTS

Feature: **$ARGUMENTS**

---

## Fase 1 — Especificação

Execute o workflow de /spec para: $ARGUMENTS

- Gere todos os cenários (Dado / Quando / Então)
- Mapeie cada "Então" para um nome de método de teste
- **Apresente a spec e aguarde confirmação explícita antes de continuar**

Não escreva código antes da spec ser aprovada.

---

## Fase 2 — Testes que Falham

Para cada "Então" aprovado, escreva o método de teste correspondente:

```python
def test<Cenário>_<Condição>(self):
    # Critério: <Então do spec — copie aqui>

    # Arrange
    <setup>

    # Act
    <chamada>

    # Assert
    <assertion que verifica exatamente o "Então">
```

**Execute os testes agora.** Todos DEVEM falhar:
```bash
python -m pytest tests/ -v
```

Se algum teste passar antes da implementação existir, ele não está testando o comportamento correto — corrija até falhar pelo motivo certo.

---

## Fase 3 — Implementação

Implemente o mínimo de código para fazer os testes passarem:
- Nenhuma funcionalidade além do que os testes exigem
- Siga todas as convenções (camelCase, sem else, .format(), sem type hints, sem docstrings)
- Execute os testes após cada mudança significativa
- Pare quando todos passarem — sem over-engineering

---

## Fase 4 — Verificação por Mutação

Antes de rodar, confirme que `mutmut.toml` aponta para diretórios reais:
```bash
cat mutmut.toml
```
Se `paths_to_mutate` ou `tests_dir` ainda contêm placeholders (`src/`, `tests/`),
atualize o arquivo antes de continuar.

Execute mutation testing no código implementado:
```bash
mutmut run --paths-to-mutate <arquivo-implementado>
mutmut results
```

Para cada mutante sobrevivente (`mutmut show <id>`):
- **Gap de teste:** adicione o assert que mata o mutante
- **Mutante equivalente:** adicione `# pragma: no mutate — <justificativa>`

**Não conclua a tarefa antes que o mutation score seja 100%** (exceto equivalentes justificados).

---

## Fase 5 — Conclusão

Confirme todos os gates:

- [ ] Todos os critérios de aceitação têm método de teste correspondente
- [ ] Todos os testes passam
- [ ] Mutation score: 100% (não-equivalentes)
- [ ] Convenções seguidas — rode `/review` para confirmar
- [ ] Tarefa atualizada como `concluído` no TASKS.md
