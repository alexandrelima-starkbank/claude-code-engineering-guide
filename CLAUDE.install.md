# CLAUDE.md

Guia de referência para desenvolvimento neste repositório.
Cobre convenções de código, arquitetura, testes e ciclo de entrega.

---

## Contexto

<!-- Descreva aqui o projeto: domínio, responsabilidades, arquitetura de alto nível. -->

---

## Catálogo de Capacidades

@.claude/CATALOG.md

---

## Gestão de Tarefas — OBRIGATÓRIO

O modelo é o responsável exclusivo pela manutenção de `TASKS.md`. Não é necessária
nenhuma solicitação do usuário — a manutenção é autônoma e ocorre em toda resposta.

**Em toda resposta que envolva qualquer trabalho:**

1. **Antes de agir:** registre a tarefa com status `em andamento`. Se já existir,
   confirme que o status está correto.
2. **Ao concluir:** use o agente `tasks-maintainer` para atualizar TASKS.md — ele
   move para `concluído` e para `HISTORY_TASKS.md` na mesma operação.
3. **Se bloquear:** mude para `bloqueado` e registre o motivo em Observações.

Invocar o `tasks-maintainer` não requer pedido do usuário. É parte do fluxo normal
de toda resposta que produza trabalho concreto.

O protocolo completo (formato, critérios de aceite, regras de sessão) está em `TASKS.md`.

---

## Ciclo de Vida

```
Planejamento → Implementação → Testes Unitários → Commit → Pull Request
```

---

## Convenções de Código

### Nomenclatura

**Esta codebase usa camelCase para tudo em Python — diferente do PEP 8.**

| Elemento | Convenção | Exemplos |
|----------|-----------|---------|
| Funções | camelCase | `parseInputData`, `getByFilter`, `validateRequest` |
| Variáveis | camelCase | `itemId`, `nextCursor`, `startCursor`, `resultList` |
| Parâmetros | camelCase | `entityId`, `filterType`, `externalId` |
| Classes | PascalCase | `ItemHandler`, `ItemGateway`, `ItemModel` |
| Enums (classe) | PascalCase | `ItemStatus`, `FilterType` |
| Enums (valores) | camelCase | `ItemStatus.active`, `FilterType.byDate` |
| Arquivos | camelCase | `itemHandler.py`, `userGateway.py`, `parseUtils.py` |
| Diretórios | snake_case | `handlers/`, `gateways/`, `middlewares/`, `utils/` |

### Sem `else` — Early Return

`else` é evitado. Limpe os caminhos de erro primeiro e continue com a lógica
principal sem aninhamento.

### String Formatting

Use `.format()`. Não use f-strings.

### Indentação e Espaçamento

- **4 espaços** (sem tabs)
- **Trailing comma** em toda lista/chamada multilinha
- Uma linha em branco entre métodos de classe

### Imports

Três grupos separados por uma linha em branco: stdlib → dependências externas → módulos locais.

### Type Hints e Docstrings

Não são usados nesta codebase.

---

## Testes Unitários

### Nomenclatura

| Elemento | Convenção | Exemplo |
|----------|-----------|---------|
| Arquivo | `<Domínio>Test.py` | `parserTest.py` |
| Classe | `<Domínio>Test` | `ParserTest` |
| Método | `test<Cenário>` | `testParse_WithEmptyInput` |

### Estrutura

Arrange / Act / Assert em todo teste.

### Rodar Testes

```bash
python -m pytest
```

---

## Linting

```bash
ruff check .        # verificar
ruff check --fix .  # corrigir
```

---

## Testes de Mutação

Meta: **100%** de score. `# pragma: no mutate` é decisão do engenheiro, nunca do modelo.

```bash
mutmut run
mutmut results
mutmut show <id>
```

---

## Git e Commits

- Verbo no imperativo, capitalizado, sem ponto final, sem emojis
- **Sem `Co-Authored-By` — em nenhuma circunstância**
- Verbos: `Fix`, `Add`, `Update`, `Change`, `Refactor`, `Remove`, `Merge`

```
Fix incorrect JSON output in SessionStart hook
Add security-review slash command
```

### Branch Naming

```
feat/<descricao>
fix/<descricao>
chore/<descricao>
```

---

## Customização Local

Crie `CLAUDE.local.md` na raiz para preferências pessoais. Está no `.gitignore`.

---

## Pull Request

PR descriptions must always be written in English.

```markdown
# Description and impact

<description of the change and expected impact>

# Change

<list of changes made>

# Rollback Plan

<how to revert if necessary>

# Acceptance Criteria

- [ ] <criterion 1>
- [ ] <criterion 2>
```
