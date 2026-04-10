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

Apenas **trabalho de produto** exige tarefa no banco: `feature`, `bug`, `incident`, `refactor`.

**Não criar tarefa para:**
- `question` e `investigation` — responder diretamente, sem pipeline
- `admin` — operações do ambiente: install, update, verify, audit, configure, smoke test,
  inspecionar logs, rodar comandos pontuais, verificar se algo está funcionando

**Para trabalho de produto:**

1. **Antes de agir:** registre a tarefa com status `em andamento`. Se já existir,
   confirme que o status está correto.
2. **Ao concluir:** atualize o status via `pipeline task update <ID> --status "concluído"`.
3. **Se bloquear:** mude para `bloqueado` e registre o motivo em Observações.

O protocolo completo (formato, critérios de aceite, regras de sessão) está em `TASKS.md`.

---

## Intake Protocol — OBRIGATÓRIO

**O engenheiro nunca precisa saber qual slash command usar.** Ao receber qualquer
solicitação em linguagem natural, o modelo classifica a intenção, consulta o contexto
existente, conduz uma entrevista e roteia internamente para o pipeline adequado.

### 1. Classificar a intenção

| Intent | Exemplos | Pipeline | Tarefa? |
|--------|---------|----------|---------|
| `feature` | "preciso de X", "implementar Y", "adicionar Z" | EARS → BDD → TDD → Mutation | sim |
| `bug` | "não funciona", "retorna X mas esperava Y" | Reproduzir → EARS → fix → Mutation | sim |
| `incident` | "em produção", "clientes afetados", "desde Xh" | N3 → gate → N4 se necessário | sim |
| `refactor` | "melhorar", "simplificar", sem comportamento novo | Spec do atual → refactor → verificar | sim |
| `investigation` | "por que X?", "como funciona Y?", "onde está Z?" | Rastrear, findings, sem implementar | **não** |
| `question` | "como devo fazer X?", "qual a diferença?" | Responder diretamente | **não** |
| `admin` | "verificar install", "rodar smoke test", "auditar ambiente", "/update", "/my_tasks" | Executar diretamente | **não** |

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
pipeline task create --title "<título>" --type <intent> [--project "<projeto>"]   # → T<N>
# intent: feature | bug | incident | refactor
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

@CONVENTIONS.md

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
