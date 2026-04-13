# CONVENTIONS.md

Convenções de código deste projeto.
Curadoria do time — não modificar sem decisão explícita.

---

## Nomenclatura

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

---

## Ordenação

Aplicada em todo o codebase. Reduz conflitos de merge e facilita busca visual.

| Elemento | Regra |
|----------|-------|
| Imports | 3 grupos (third-party → externas → locais), sem linha em branco entre grupos; dentro de cada grupo: comprimento crescente, depois alfabético em caso de empate |
| Atributos de classe | Alfabética na declaração |
| Métodos de classe | Alfabética (exceto `__init__` e dunder methods, que vêm primeiro) |
| Parâmetros de função | Alfabética quando não há dependência de ordem |
| Chaves de dict literal | Alfabética |
| Variáveis de módulo | Alfabética por bloco lógico |

```python
# CORRETO — imports: 3 grupos contíguos, comprimento crescente dentro de cada grupo
from requests import get
from click import command, option
from server.middlewares.limit import validateLimit
from server.middlewares.expand import validateExpand
from server.middlewares.queryString import validateQueryIds, validateQueryString
from handlers.base import MsBaseHandler
from models.card import CardStatus, CardType
from utils.holderPermission import getSafeHolderIds
from middlewares.card import validatePostCards, validatePatchCards
from middlewares.general import validateOptionalIds, validateOptionalStatus, validateReferenceIds

# CORRETO — atributos e métodos alfabéticos
class ItemGateway:
    defaultLimit = 100
    maxLimit = 1000

    def approve(self, ...): ...
    def create(self, ...): ...
    def delete(self, ...): ...
    def list(self, ...): ...
```

---

## Sem `else` — Early Return

`else` é proibido. Limpe os caminhos de erro primeiro e continue sem aninhamento.

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
    ...
    if ids is not None and len(ids) == 0:
        return ...
    else:          # ← nunca
        ...
```

---

## String Formatting

<!-- Decisão: .format() mantido para consistência. Não migrar para f-strings sem decisão explícita. -->

Use `.format()`. Não use f-strings nem `%`.

```python
# CORRETO
cacheKey = "items/{entityId}".format(entityId=entityId)

# ERRADO
cacheKey = f"items/{entityId}"
cacheKey = "items/%s" % entityId
```

---

## Indentação e Espaçamento

- **4 espaços** (sem tabs)
- **Trailing comma** em toda lista/chamada multilinha
- Uma linha em branco entre métodos de classe
- Sem espaço antes de `:` em slices e dict literals

```python
# CORRETO
items, nextCursor = ItemGateway.getAll(
    filter=filter,
    entityId=entityId,
    limit=limit,
    startCursor=cursor,    # ← trailing comma
)
```

---

## Type Hints

Não são usados nesta codebase.

---

## Comentários e Docstrings

Código deve ser auto-explicativo via nomes descritivos.
Não adicionar comentários nem docstrings — exceto decisões não óbvias marcadas com `<!-- Decisão: ... -->`.

---

## Testes

| Elemento | Convenção | Exemplo |
|----------|-----------|---------|
| Arquivo | `<Domínio>Test.py` | `parserTest.py` |
| Classe | `<Domínio>Test` | `ParserTest` |
| Método | `test<Cenário>_<Condição>` | `testParse_WithEmptyInput` |

Estrutura obrigatória: **Arrange / Act / Assert** — sem exceção.

---

## Linting

```bash
ruff check .        # verificar
ruff check --fix .  # corrigir
```

Regras ativas: `E`, `F`, `W`, `I`. Regras `N` (nomenclatura) desabilitadas — codebase usa camelCase.
