# CLAUDE.md

Guia de referência para desenvolvimento neste repositório.
Cobre convenções de código, arquitetura, testes e ciclo de entrega.

---

## Contexto

Este repositório contém o guia de engenharia para uso do Claude Code e o ambiente
de desenvolvimento pronto para uso (hooks, agentes, slash commands).

```
claude-code-enginnering-guide/
├── README.md          # O guia principal
├── setup.sh           # Instala dependências e configura o ambiente
├── .claude/           # Ambiente Claude Code (hooks, agents, commands, skills)
└── CLAUDE.md          # Este arquivo
```

---

## Setup

```bash
./setup.sh
```

Verifica e instala dependências (`jq`, `python3`), torna hooks executáveis.
Veja `.claude/README.md` para documentação completa do ambiente.

---

## Gestão de Tarefas — OBRIGATÓRIO

**Toda sessão de trabalho deve ser gerenciada explicitamente através de `TASKS.md`.**

O modelo DEVE ler `TASKS.md` no início de qualquer sessão que envolva implementação,
investigação ou entrega. O protocolo completo está definido no próprio arquivo e deve
ser seguido à risca. Não inicie nenhuma tarefa sem primeiro registrá-la lá.

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

```python
# CORRETO
def getItems(self, **data):
    ids = getSafeIds(data.get("ids"))
    if ids is not None and len(ids) == 0:
        return self.sendJson({"cursor": None, "items": []})

    items, nextCursor = ItemGateway.getAllByIds(ids=ids, limit=data["limit"])
    return self.sendJson({"cursor": nextCursor, "items": [i.json() for i in items]})

# ERRADO
def getItems(self, **data):
    ids = getSafeIds(data.get("ids"))
    if ids is not None and len(ids) == 0:
        return self.sendJson({"cursor": None, "items": []})
    else:                          # ← nunca usar else aqui
        items, nextCursor = ...
        return self.sendJson(...)
```

### String Formatting

<!-- Para mantenedores: .format() é convenção do time, mantida para consistência.
     Não migrar para f-strings sem decisão explícita. -->
Use `.format()`. Não use f-strings.

```python
# CORRETO
cacheKey = "items/{entityId}".format(entityId=entityId)
logMessage = "Processing item {id} with status {status}".format(id=item.id, status=item.status)

# ERRADO
cacheKey = f"items/{entityId}"   # ← evitar
```

### Indentação e Espaçamento

- **4 espaços** (sem tabs)
- **Trailing comma** em toda lista/chamada multilinha
- Uma linha em branco entre métodos de classe
- Sem espaço antes de `:` em slices e dict literals

```python
# CORRETO — trailing comma no último argumento
items, nextCursor = ItemGateway.getAll(
    filter=filter,
    entityId=entityId,
    limit=limit,
    startCursor=cursor,          # ← trailing comma
)
```

### Imports

Três grupos separados por uma linha em branco, nesta ordem:

```python
# 1. Standard library
from json import loads
from datetime import datetime
from collections import Counter

# 2. Dependências externas
from requests import get
from click import command, option

# 3. Módulos locais do projeto
from utils.parser import parseInput
from models.item import Item, ItemStatus
```

### Type Hints

Type hints não são usados nesta codebase.

### Comentários e Docstrings

Código deve ser auto-explicativo via nomes descritivos. Não adicionar comentários
nem docstrings.

---

## Testes Unitários

<!-- Para mantenedores: este repositório não tem testes atualmente.
     A seção abaixo define as convenções a seguir quando forem adicionados. -->

Quando adicionados ao projeto, os testes devem seguir estas convenções:

### Nomenclatura

| Elemento | Convenção | Exemplo |
|----------|-----------|---------|
| Arquivo | `<Domínio>Test.py` | `parserTest.py`, `validatorTest.py` |
| Classe | `<Domínio>Test` | `ParserTest`, `ValidatorTest` |
| Método | `test<Cenário>` | `testParse_WithEmptyInput`, `testValidate_InvalidFormat` |

### Estrutura (Arrange / Act / Assert)

```python
from unittest import TestCase
from unittest.mock import patch

class ParserTest(TestCase):

    def testParse_WithEmptyInput(self):
        # Arrange
        input = ""

        # Act
        result = parseInput(input)

        # Assert
        self.assertIsNone(result)
```

### Rodar Testes

```bash
# Toda a suite (da raiz do projeto, com venv ativo)
python -m pytest

# Teste individual
python -m pytest tests/parserTest.py::ParserTest::testParse_WithEmptyInput -v
```

---

## Git e Commits

### Padrão de Mensagem

- Verbo no imperativo, capitalizado
- Descritivo e conciso
- Sem ponto final
- Sem emojis
- Sem `Co-Authored-By`

```
Fix incorrect JSON output in SessionStart hook
Add security-review slash command
Update setup.sh to support apt and dnf package managers
Refactor validate-destructive to use script instead of inline bash
```

### Verbos Usados

`Fix`, `Add`, `Update`, `Change`, `Refactor`, `Remove`, `Merge`

### Branch Naming

```
feat/<descricao>
fix/<descricao>
chore/<descricao>
```

---

## Customização Local

Cada desenvolvedor pode criar `CLAUDE.local.md` na raiz do projeto para preferências
pessoais (atalhos, contexto local, notas de sessão). Este arquivo está no `.gitignore`
e não é compartilhado com o time.

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
