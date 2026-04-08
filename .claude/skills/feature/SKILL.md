---
name: feature
description: Desenvolvimento end-to-end de uma feature — da elicitação de requisitos EARS ao código testado. Orquestra requirements → spec → tdd. Use quando começar qualquer feature nova.
---

# Feature: $ARGUMENTS

Desenvolvimento completo com rastreabilidade total: requisitos EARS → critérios de aceite → testes → código.

---

## Fase 0 — Requisitos EARS

**Responsabilidade:** produzir requisitos EARS aprovados antes de qualquer spec ou código.

Executar o fluxo de `/requirements`:

1. Ler `CLAUDE.md` e `TASKS.md` para entender domínio e contexto existente
2. Analisar `$ARGUMENTS` — mapear o que está claro e o que está ambíguo
3. Se houver gaps críticos, fazer até 5 perguntas objetivas e aguardar resposta
4. Gerar requisitos nos padrões EARS aplicáveis (ubíquo, evento, estado, indesejado, opcional)
5. Validar completude internamente (caminho feliz, erros, sem ambiguidade, testáveis)
6. **Apresentar requisitos e aguardar aprovação explícita antes de continuar**

Não avançar para a Fase 1 sem aprovação explícita dos requisitos.

**GATE:** ao receber aprovação, editar `TASKS.md` agora:
- Se não houver tarefa correspondente, criar antes de editar
- Escrever os requisitos aprovados na seção `**Requisitos EARS:**`
- Só então confirmar ao usuário e avançar para a Fase 1

---

## Fase 1 — Spec (Critérios de Aceite)

**Responsabilidade:** derivar cenários Given/When/Then rastreáveis aos requisitos EARS aprovados.

Executar o fluxo de `/spec` tendo os requisitos da Fase 0 como input:

1. Para cada requisito EARS, derivar um ou mais cenários Given/When/Then
2. Cada "Então" mapeia para exatamente um método de teste: `test<Cenário>_<Condição>`
3. Cobrir: caminho feliz, erros (IF/THEN), edge cases, valores de fronteira
4. Manter rastreabilidade — cada cenário indica o requisito EARS de origem
5. **Apresentar spec e aguardar aprovação explícita antes de continuar**

Não avançar para a Fase 2 sem aprovação explícita da spec.

**GATE:** ao receber aprovação, editar `TASKS.md` agora:
- Escrever os cenários aprovados na seção `**Critério de aceitação:**`
- Só então avançar para a Fase 2

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
Se algum passar antes da implementação existir, ele não testa o comportamento correto — corrigir até falhar pelo motivo certo.

---

## Fase 3 — Implementação

Implementar o mínimo de código para os testes passarem:
- Nenhuma funcionalidade além do que os testes exigem
- Seguir todas as convenções do `CLAUDE.md` (camelCase, sem else, `.format()`, sem type hints, sem docstrings)
- Executar os testes após cada mudança significativa
- Parar quando todos passarem — sem over-engineering

---

## Fase 4 — Verificação por Mutação

Antes de executar, confirmar que `mutmut.toml` aponta para diretórios reais:
```bash
cat mutmut.toml
```
Se `paths_to_mutate` ou `tests_dir` contêm placeholders, atualizar antes de continuar.

Executar mutation testing:
```bash
mutmut run --paths-to-mutate <arquivo-implementado>
mutmut results
```

Para cada mutante sobrevivente (`mutmut show <id>`):
- **Lacuna no teste**: adicionar assertion que mata o mutante
- **Equivalente**: adicionar `# pragma: no mutate — <justificativa>`

**Não concluir antes que o mutation score seja 100%** (exceto equivalentes justificados).

---

## Fase 5 — Checklist Final

Confirmar todos os gates antes de marcar como concluído:

- [ ] Todos os requisitos EARS têm cenários Given/When/Then correspondentes
- [ ] Todos os cenários têm método de teste correspondente
- [ ] Todos os testes passam
- [ ] Mutation score: 100% (exceto equivalentes justificados)
- [ ] Convenções seguidas — executar `/review` para confirmar
- [ ] Tarefa atualizada como `concluído` em `TASKS.md`
