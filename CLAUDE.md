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
from server.utils.enum import Enum
from server.handlers.base import BaseHandler

# 3. Módulos locais do projeto
from handlers.base import BaseItemHandler
from models.item import Item, ItemStatus
from gateways.item import ItemGateway
from middlewares.validation import validateQueryString
```

### Type Hints

Type hints não são usados nesta codebase.

### Comentários e Docstrings

Código deve ser auto-explicativo via nomes descritivos. Não adicionar comentários
nem docstrings.

---

## Arquitetura

### Padrão Handler → Gateway → Model

Todo código Python neste repositório segue a mesma separação de responsabilidades:

```
handlers/     — recebem requisição, delegam para gateways, retornam resposta
gateways/     — lógica de negócio e acesso a dados (métodos @classmethod)
models/       — definição de entidades e serialização
middlewares/  — decoradores de validação (aplicados nos handlers)
utils/        — funções puras sem estado, organizadas por domínio
```

**Handlers devem ser finos** — lógica de negócio fica nos gateways e utils.

### Handlers

Herdam de `BaseHandler`. Decoradores de validação em cascata, do mais externo
para o mais interno.

```python
class ItemHandler(BaseHandler):

    @validatePermission(permission=ItemPermission.view)
    @validateQueryString("status", "ids", "limit", "cursor")
    @validateLimit()
    @validateCursor
    def get(self, **data):
        items, nextCursor = ItemGateway.getAll(
            entityId=self.entityId(),
            status=data["status"],
            limit=data["limit"],
            startCursor=data["cursor"],
        )
        return self.sendJson({"cursor": nextCursor, "items": [i.json() for i in items]})
```

### Gateways

Classes com métodos `@classmethod`. Responsabilidades:

- `new()` — factory, cria instância sem persistir
- `getById()` / `getAll()` — queries com filtros e cursor pagination
- `save()` — persiste
- `set()` — builder pattern para atualizações parciais (só atualiza campos não-None)

```python
class ItemGateway:

    @classmethod
    def set(cls, item, status=None, tags=None, name=None):
        if status is not None:
            item.status = status
        if tags is not None:
            item.tags = tags
        if name is not None:
            item.name = name
        return item
```

### Enums

```python
from server.utils.enum import Enum

class ItemStatus(Enum):
    pending  = "pending"
    active   = "active"
    blocked  = "blocked"
    canceled = "canceled"
```

### Fixtures de Teste

Use `Enum` para fixtures estáticas reutilizáveis:

```python
class DefaultItems(Enum):
    activeItem = Item(
        id="item-1234567890",
        entityId="entity-1234567890",
        status=ItemStatus.active,
    )
```

---

## Testes Unitários

### Configuração (`pytest.ini`)

```ini
[pytest]
testpaths = tests
python_files = *Test.py
python_classes = *Test*
python_functions = test*
addopts =
    -v
    --tb=short
    -W ignore::DeprecationWarning
```

### Nomenclatura

| Elemento | Convenção | Exemplo |
|----------|-----------|---------|
| Arquivo | `<Domínio>Test.py` | `itemHandlerTest.py`, `parseUtilsTest.py` |
| Classe | `<Domínio>Test` | `ItemHandlerTest`, `ParseUtilsTest` |
| Método | `test<Cenário>` | `testGetItems_WithEmptyIds`, `testValidate_InvalidStatus` |

### Estrutura (Arrange / Act / Assert)

```python
# tests/handlers/itemHandlerTest.py
from unittest import TestCase
from unittest.mock import patch

class ItemHandlerTest(TestCase):

    @patch("gateways.item.ItemGateway.getAll")
    def testGetItems_WithEmptyIds(self, mockedGetAll):
        # Arrange
        mockedGetAll.return_value = ([], None)

        # Act
        response = self.client.get("/items", query_string={"ids": ""})

        # Assert
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["items"], [])
```

### Rodar Testes

```bash
# Toda a suite
.venv/bin/python -m pytest

# Teste individual
.venv/bin/python -m pytest tests/handlers/itemHandlerTest.py::ItemHandlerTest::testGetItems_WithEmptyIds -v
```

### Medir Cobertura

```bash
.venv/bin/python -m pytest --cov=utils --cov=handlers --cov=gateways --cov=middlewares --cov=models
```

Nunca reportar cobertura medida sobre um subconjunto de módulos.

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
