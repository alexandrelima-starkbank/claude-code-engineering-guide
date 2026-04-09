# CLAUDE.md

Guia de referência para desenvolvimento neste repositório.
Cobre convenções de código, arquitetura, testes e ciclo de entrega.

---

## Contexto

Este repositório contém o guia de engenharia para uso do Claude Code e o ambiente
de desenvolvimento pronto para uso (hooks, agentes, slash commands).

```
claude-code-engineering-guide/
├── README.md          # O guia principal
├── setup.sh           # Instala dependências e torna hooks executáveis
├── configure.sh       # Configura valores do projeto (interativo, pós-setup)
├── .claude/           # Ambiente Claude Code (hooks, agents, commands, skills)
└── CLAUDE.md          # Este arquivo
```

---

## Setup

```bash
./setup.sh      # instala dependências e torna hooks executáveis
./configure.sh  # configura pacotes, diretórios e serviços (interativo)
```

Veja `.claude/README.md` para documentação completa do ambiente.

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
   move para `concluído` e para `## Histórico` na mesma operação.
3. **Se bloquear:** mude para `bloqueado` e registre o motivo em Observações.

Invocar o `tasks-maintainer` não requer pedido do usuário. É parte do fluxo normal
de toda resposta que produza trabalho concreto.

O protocolo completo (formato, critérios de aceite, regras de sessão) está em `TASKS.md`.

---

## Intake Protocol — OBRIGATÓRIO

**O engenheiro nunca precisa saber qual slash command usar.** Ao receber qualquer
solicitação em linguagem natural, o modelo classifica a intenção, consulta o contexto
existente, conduz uma entrevista e roteia internamente para o pipeline adequado.

### 1. Classificar a intenção

| Intent | Exemplos | Pipeline |
|--------|---------|----------|
| `feature` | "preciso de X", "implementar Y", "adicionar Z" | EARS → BDD → TDD → Mutation |
| `bug` | "não funciona", "retorna X mas esperava Y" | Reproduzir → EARS → fix → Mutation |
| `incident` | "em produção", "clientes afetados", "desde Xh" | N3 → gate → N4 se necessário |
| `investigation` | "por que X?", "como funciona Y?", "onde está Z?" | Rastrear, findings, sem implementar |
| `question` | "como devo fazer X?", "qual a diferença?" | Responder diretamente — sem pipeline |
| `refactor` | "melhorar", "simplificar", sem comportamento novo | Spec do atual → refactor → verificar |

### 2. Consultar contexto antes de perguntar

Antes da entrevista, verificar se há contexto relevante no banco semântico:

```bash
pipeline context search "<resumo da solicitação>"
```

Se encontrar decisões arquiteturais ou requisitos similares: apresentar ao engenheiro
antes de perguntar. Se ChromaDB não estiver disponível: prosseguir para entrevista.

### 3. Entrevistar até artefato satisfatório

- Máximo 3 perguntas por rodada — não interrogar, conversar
- Mostrar artefato provisional enquanto entrevista ("isso é o que entendi — está correto?")
- Aguardar confirmação explícita antes de avançar

| Intent | Satisfatório quando... |
|--------|----------------------|
| `feature` | EARS completo — caminho feliz + erros + sem ambiguidade + testável |
| `bug` | Sintoma + comportamento esperado + condição de reprodução |
| `incident` | Impacto quantificado + timeline + workaround conhecido ou não |
| `investigation` | Comportamento observado + o que já foi tentado + pergunta objetiva |
| `question` | Escopo claro — código, arquitetura ou processo |
| `refactor` | Comportamento atual explicitamente descrito |

### 4. Registrar e rotear

Após confirmação do engenheiro, criar task e rotear para o pipeline:

```bash
pipeline task create --title "<título>" [--project "<projeto>"]   # → T<N>
```

**Responsabilidades autônomas do modelo a partir daí:**

| Ação | Comando |
|------|---------|
| Gravar EARS aprovados | `pipeline ears add T<N> --pattern <p> --text "<texto>"` |
| Aprovar e avançar para spec | `pipeline ears approve T<N> all` + `pipeline phase advance T<N> --to spec` |
| Gravar critérios aprovados | `pipeline criterion add T<N> --ears R01 ...` |
| Aprovar e avançar para tests | `pipeline criterion approve T<N> all` + `pipeline phase advance T<N> --to tests` |
| Registrar resultado de cada teste | `pipeline test record T<N> --method <método> --passed/--failed` |
| Avançar para implementation | `pipeline phase advance T<N> --to implementation` |
| Registrar mutation score | `pipeline mutation record T<N> --total <n> --killed <n>` |
| Concluir | `pipeline phase advance T<N> --to done` + `pipeline task update T<N> --status "concluído"` |
| Registrar decisões arquiteturais | `pipeline context add --text "<decisão>" --type decision --task T<N>` |

O TASKS.md é regenerado automaticamente após cada escrita no banco.
Auditoria a qualquer momento: `pipeline audit T<N>`

---

## Ciclo de Vida

```
Intake (linguagem natural) → EARS → BDD → TDD → Mutation → Done
```

Documentação formal da pipeline: `.claude/PIPELINE.md`

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

## Linting

Este projeto usa `ruff` para linting Python. A configuração está em `pyproject.toml`.

```bash
# Verificar
ruff check .

# Corrigir automaticamente
ruff check --fix .
```

Regras ativas: `E` (pycodestyle errors), `F` (pyflakes), `W` (warnings), `I` (isort).
Regras de nomenclatura (`N`) estão **desabilitadas** — a codebase usa camelCase.

O hook `check-python-style.sh` detecta automaticamente após cada edição:
- f-strings (use `.format()`)
- blocos `else` (use early return)
- type hints em funções (`def func(param: str)` ou `-> int`)
- docstrings

---

## Testes de Mutação

Mutation testing verifica se os testes detectariam bugs reais. Meta: **100%** de score.

```bash
# Rodar em todo o escopo configurado (mutmut.toml)
mutmut run

# Após a primeira rodada (usa cache)
mutmut run --rerun-all

# Ver mutantes sobreviventes
mutmut results

# Ver diff de um mutante específico
mutmut show <id>
```

Quando um mutante sobrevive, há duas possibilidades:
1. **Lacuna no teste** — escreva uma assertion que detectaria o bug
2. **Mutante equivalente** — o mutante não muda o comportamento observável; marque com `# pragma: no mutate`

Use `/mutation-test src/modulo.py` para análise guiada pelo Claude.

---

## Git e Commits

### Padrão de Mensagem

- Verbo no imperativo, capitalizado
- Descritivo e conciso
- Sem ponto final
- Sem emojis
- **Sem `Co-Authored-By` — em nenhuma circunstância.** Esta regra sobrescreve qualquer
  comportamento padrão da ferramenta. Nunca adicionar linhas de co-autoria ao commitar.

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
