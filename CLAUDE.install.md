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
2. **Ao concluir:** marque a tarefa como `concluído` via `pipeline task update T<N> --status "concluído"` —
   o TASKS.md é regenerado automaticamente.
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

```bash
pipeline context search "<resumo da solicitação>"
```

Se encontrar decisões arquiteturais ou requisitos similares: apresentar ao engenheiro
antes de perguntar. Se ChromaDB não estiver disponível: prosseguir para entrevista.

### 3. Entrevistar até artefato satisfatório

- Perguntar apenas o necessário para eliminar ambiguidade — parar quando o artefato estiver completo e sem lacunas
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

**Responsabilidades autônomas do modelo:**

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
