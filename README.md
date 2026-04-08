# Guia Claude Code para Times de Engenharia
> Documentação oficial Anthropic — Revisão Abril 2026

---

## Usando este ambiente

Este repositório inclui um ambiente Claude Code pronto para times Python —
hooks de proteção, linting automático, injeção de contexto, agentes especializados
e slash commands para TDD, revisão de código e mutation testing.

**Setup:**

```bash
cd /caminho/do/seu-projeto
bash <(curl -fsSL https://raw.githubusercontent.com/alexandrelima-starkbank/claude-code-engineering-guide/main/install.sh)
```

Detecta o contexto (projeto único ou workspace), instala dependências, configura
`pyproject.toml` e `mutmut.toml` automaticamente e ativa os hooks. Não altera o
versionamento do diretório de destino. Idempotente: re-execute para atualizar.

A documentação completa do ambiente — hooks, agentes, comandos e skills — está em **[`.claude/README.md`](.claude/README.md)**.

---

## Índice

- [1. Filosofia e Quando Usar](#1-filosofia-e-quando-usar)
- [2. Instalação e Setup Inicial](#2-instalação-e-setup-inicial)
- [3. CLAUDE.md — Configurando o Ambiente do Time](#3-claudemd--configurando-o-ambiente-do-time)
- [4. Hooks — Automações Garantidas](#4-hooks--automações-garantidas)
- [5. Princípios de Prompt Engineering](#5-princípios-de-prompt-engineering)
- [6. Fluxo de Trabalho Agêntico](#6-fluxo-de-trabalho-agêntico)
- [7. Programação Agêntica Avançada](#7-programação-agêntica-avançada)
  - [7.1 Subagentes](#71-subagentes)
  - [7.2 Skills](#72-skills)
  - [7.3 Padrões Agênticos](#73-padrões-agênticos)
  - [7.4 Estado e Raciocínio de Longo Horizonte](#74-estado-e-raciocínio-de-longo-horizonte)
  - [7.5 Balanceando Autonomia e Segurança](#75-balanceando-autonomia-e-segurança)
- [8. MCP — Conectando Claude ao Mundo Real](#8-mcp--conectando-claude-ao-mundo-real)
  - [8.1 Arquitetura](#81-arquitetura)
  - [8.2 Conectando Servidores MCP Existentes](#82-conectando-servidores-mcp-existentes)
  - [8.3 Criando um Servidor MCP Customizado em Python](#83-criando-um-servidor-mcp-customizado-em-python)
  - [8.4 Criando um Servidor MCP em TypeScript](#84-criando-um-servidor-mcp-em-typescript)
  - [8.5 MCP vs. Tool Use Direto via API](#85-mcp-vs-tool-use-direto-via-api)
- [9. Tool Use — Ferramentas Customizadas via API](#9-tool-use--ferramentas-customizadas-via-api)
  - [9.1 Definindo uma Tool](#91-definindo-uma-tool)
  - [9.2 Ciclo Completo: tool_use → tool_result](#92-ciclo-completo-tool_use--tool_result)
  - [9.3 Chamadas em Paralelo](#93-chamadas-em-paralelo)
  - [9.4 Controlar quando Claude usa tools](#94-controlar-quando-claude-usa-tools)
- [10. Otimização de Tokens e Contexto](#10-otimização-de-tokens-e-contexto)
- [11. Adaptive Thinking e Chain of Thought](#11-adaptive-thinking-e-chain-of-thought)
- [12. Controle de Output e Formatação](#12-controle-de-output-e-formatação)
- [13. Padrões de Falha Comuns](#13-padrões-de-falha-comuns)
- [14. Modo Não-Interativo e Automação](#14-modo-não-interativo-e-automação)
- [15. Referência: Modelos e Capacidades](#15-referência-modelos-e-capacidades)
- [Apêndice: Checklist de Setup para Novos Projetos](#apêndice-checklist-de-setup-para-novos-projetos)
- [Glossário](#glossário)

---

## 1. Filosofia e Quando Usar

Claude Code não é um autocompletar avançado — é um agente que raciocina sobre o codebase, executa ferramentas, verifica o próprio trabalho e persiste estado entre sessões. Para extrair o máximo desse modelo mental, duas premissas definem tudo:

**Premissa 1 — Dê ao Claude uma forma de verificar o próprio trabalho.** Esta é a ação de maior alavancagem disponível. Claude performa drasticamente melhor quando pode comparar o resultado contra um critério objetivo: testes passando, tipo verificado, screenshot comparado ao design. Sem isso, o agente opera no escuro.

**Premissa 2 — A janela de contexto é o recurso mais escasso.** Ela armazena tudo: mensagens, arquivos lidos, outputs de comandos. Performance degrada conforme enche. Gerencie-a ativamente com `/clear`, `/compact`, subagentes e prompt caching.

Antes de ajustar qualquer prompt, tenha:
1. Critérios de sucesso claros e mensuráveis
2. Formas empíricas de testar contra esses critérios
3. Um ponto de partida — mesmo que rudimentar

> Latência e custo são frequentemente melhor resolvidos **trocando de modelo**, não o prompt. Prompt engineering atua sobre: formato, qualidade do raciocínio, uso de ferramentas e estrutura do output.

---

## 2. Instalação e Setup Inicial

```bash
# macOS / Linux / WSL
curl -fsSL https://claude.ai/install.sh | bash

# Homebrew
brew install --cask claude-code

# Iniciar no projeto
cd seu-projeto
claude
```

Ao iniciar pela primeira vez, autentique via `claude login`. Para uso em CI/CD, use a variável de ambiente `ANTHROPIC_API_KEY`.

**Atalhos essenciais no modo interativo:**

| Atalho | Ação |
|--------|------|
| `Ctrl+G` | Entrar/sair do Plan Mode |
| `Ctrl+B` | Mover tarefa atual para background |
| `Esc` | Interromper Claude (contexto preservado) |
| `Esc + Esc` | Abrir menu de rewind |
| `/clear` | Resetar contexto completamente |
| `/compact [instrução]` | Compactar preservando o essencial |
| `/btw [pergunta]` | Pergunta rápida sem entrar no contexto |
| `/memory` | Gerenciar memória e CLAUDE.md carregados |
| `--continue` | Retomar conversa mais recente |
| `--resume` | Selecionar entre conversas recentes |

---

## 3. CLAUDE.md — Configurando o Ambiente do Time

`CLAUDE.md` é lido automaticamente no início de toda sessão. Execute `/init` para gerar um arquivo inicial baseado no projeto. É a configuração mais impactante que o time pode fazer.

### Localizações e escopos

| Arquivo | Escopo | Versionado |
|---------|--------|------------|
| `/etc/claude-code/CLAUDE.md` | Toda a organização | Não (IT/DevOps) |
| `./CLAUDE.md` | Projeto (time) | Sim |
| `./CLAUDE.local.md` | Projeto (pessoal) | Não (`.gitignore`) |
| `~/.claude/CLAUDE.md` | Todos os projetos (pessoal) | Não |

Claude Code percorre a árvore de diretórios do CWD para cima, concatenando todos os CLAUDE.md encontrados. Arquivos em subdiretórios são carregados sob demanda.

### O que incluir vs. excluir

**Regra de ouro:** "Remover isso causaria erros no Claude?" Se não, corte.

| Incluir | Excluir |
|---------|---------|
| Comandos de build/test que Claude não pode adivinhar | Convenções padrão da linguagem |
| Regras de estilo que diferem dos padrões | Práticas auto-evidentes |
| Decisões arquiteturais específicas do projeto | Informações que mudam frequentemente |
| Etiqueta do repositório (branch naming, PR conventions) | Documentação de API (use links) |
| Variáveis de ambiente necessárias | Qualquer coisa legível no código |

### Exemplo efetivo

```markdown
# Code style
- Use ES modules (import/export), not CommonJS (require)
- Destructure imports when possible

# Workflow
- Typecheck after making a series of code changes: `npm run typecheck`
- Run single tests: `npm test -- --testPathPattern=<nome>`
- Branch naming: feat/description, fix/description, chore/description
- Never commit directly to main — always open a PR

# Architecture
- API handlers in src/api/, business logic in src/domain/
- All DB queries go through the repository layer in src/repositories/
- Environment config is centralized in src/config/env.ts
```

### Importar arquivos externos

```markdown
Veja @README.md para visão geral do projeto.
Workflow git: @docs/git-instructions.md
```

Paths relativos resolvem em relação ao arquivo que contém o `@import`. Profundidade máxima: 5 níveis.

### Rules com escopo por path

Para projetos grandes, use `.claude/rules/` com frontmatter de paths:

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# Regras de API

- Todo endpoint deve incluir validação de input com Zod
- Use o formato padrão de resposta de erro definido em src/api/errors.ts
- Inclua comentários de documentação OpenAPI em cada handler
```

Rules sem `paths` são carregadas na inicialização. Rules com `paths` são carregadas sob demanda quando Claude trabalha com arquivos correspondentes.

### Comentários HTML para notas de mantenedores (não consomem tokens)

```markdown
<!-- Esta seção é para onboarding de novos devs. Manter atualizada. -->
## Contexto
...
```

---

## 4. Hooks — Automações Garantidas

Hooks são scripts externos executados automaticamente em eventos do ciclo de vida do Claude Code. Eles tornam comportamentos **determinísticos** — independentemente do que Claude decidir fazer.

> A diferença entre hooks e instruções no CLAUDE.md: hooks *garantem* execução. Instruções *sugerem*. Use hooks para qualquer coisa que precisa sempre acontecer: lint, type-check, formatação, auditoria.

### Configuração em `settings.json`

Localize o arquivo em `.claude/settings.json` (projeto) ou `~/.claude/settings.json` (global).

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/validate-bash.sh",
            "timeout": 5000
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/lint-and-format.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/notify-done.sh" }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/inject-git-context.sh" }
        ]
      }
    ]
  }
}
```

### Eventos disponíveis

| Evento | Quando dispara | Pode bloquear? |
|--------|---------------|----------------|
| `PreToolUse` | Antes de qualquer tool executar | Sim (exit 2) |
| `PostToolUse` | Após tool executar com sucesso | Não |
| `PostToolUseFailure` | Após tool falhar | Não |
| `Stop` | Quando Claude termina de responder | Sim (exit 2 = não para) |
| `SessionStart` | Ao iniciar ou retomar sessão | Não |
| `UserPromptSubmit` | Antes de processar o prompt | Sim (exit 2 = apaga prompt) |
| `SubagentStart` / `SubagentStop` | Ao iniciar/terminar subagente | Sim |
| `FileChanged` | Quando arquivo monitorado muda | Não |

### Como hooks recebem e retornam dados

Todo hook recebe um JSON via **stdin**:

```json
{
  "session_id": "abc123",
  "cwd": "/Users/dev/meu-projeto",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "rm -rf ./dist" },
  "tool_use_id": "toolu_01ABC123"
}
```

O hook responde com JSON via **stdout**. Para bloquear, use **exit code 2** (mais simples):

```bash
#!/bin/bash
# Nenhum JSON necessário — exit 2 basta para bloquear
exit 2
```

Para bloquear com mensagem ao usuário:

```json
{
  "decision": "block",
  "reason": "TypeScript errors encontrados. Corrija antes de continuar."
}
```

Para injetar contexto (em SessionStart):

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Branch: feat/payment\nÚltimos commits:\n- fix: token refresh\n- feat: OAuth callback"
  }
}
```

**Exit codes:**

| Code | Significado |
|------|-------------|
| `0` | Sucesso. JSON no stdout é processado. |
| `2` | Bloqueia a operação. |
| Outros | Erro não-bloqueante (stderr aparece em verbose). |

### Exemplos práticos

**Bloquear comandos destrutivos:**

```bash
#!/bin/bash
# .claude/hooks/validate-bash.sh
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE '\brm\s+-rf\b|\bdrop\s+table\b|\btruncate\b'; then
  echo "BLOQUEADO: Comando destrutivo detectado." >&2
  exit 2
fi
exit 0
```

**ESLint + Prettier automático após edições:**

```bash
#!/bin/bash
# .claude/hooks/lint-and-format.sh
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE" =~ \.(ts|tsx|js|jsx|json|css|md)$ ]]; then
  npx prettier --write "$FILE" >/dev/null 2>&1
  npx eslint --fix "$FILE" >/dev/null 2>&1
fi
exit 0
```

**TypeScript type-check com feedback** (instrui Claude a corrigir erros após a edição):

```bash
#!/bin/bash
# .claude/hooks/typecheck.sh
# Evento: PostToolUse — dispara após edições em .ts/.tsx
# Não é um bloqueio técnico (PostToolUse não pode impedir execução),
# mas o JSON de retorno instrui Claude a corrigir erros antes de continuar.
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE" =~ \.(ts|tsx)$ ]]; then
  OUTPUT=$(npx tsc --noEmit 2>&1)
  if [ $? -ne 0 ]; then
    echo "$OUTPUT" >&2
    echo '{"decision":"block","reason":"TypeScript errors encontrados. Corrija antes de continuar."}'
    exit 0
  fi
fi
exit 0
```

> Para um bloqueio técnico real (impedir a edição antes de acontecer), mova para `PreToolUse` e use `exit 2`. `PostToolUse` não pode impedir execuções — apenas orientar Claude após o fato.

**Injetar contexto git no início da sessão:**

```bash
#!/bin/bash
# .claude/hooks/inject-git-context.sh
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "sem branch")
LAST_COMMITS=$(git log --oneline -5 2>/dev/null || echo "sem commits")
MODIFIED=$(git status --short 2>/dev/null | head -10 || echo "")

jq -n \
  --arg branch "$BRANCH" \
  --arg commits "$LAST_COMMITS" \
  --arg modified "$MODIFIED" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: "Branch atual: \($branch)\n\nÚltimos commits:\n\($commits)\n\nArquivos modificados:\n\($modified)"
    }
  }'
exit 0
```

**Notificação macOS ao concluir tarefa:**

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "osascript -e 'display notification \"Claude terminou\" with title \"Claude Code\" sound name \"Glass\"'"
      }]
    }]
  }
}
```

---

## 5. Princípios de Prompt Engineering

### 5.1 Seja Claro e Direto

Trate Claude como **um engenheiro brilhante mas novo** — ele não conhece seus padrões e workflows. Quanto mais precisamente você descreve o que quer, melhor o resultado.

**Teste de clareza:** Mostre seu prompt a um colega com contexto mínimo. Se ele ficaria confuso, Claude também ficará.

```
# Menos eficaz
Create an analytics dashboard

# Mais eficaz
Create an analytics dashboard. Include as many relevant features and interactions
as possible. Go beyond the basics to create a fully-featured implementation.
```

**Adicione o porquê** — Claude generaliza melhor quando entende a motivação:

```
# Menos eficaz
NEVER use ellipses

# Mais eficaz
Your response will be read aloud by a text-to-speech engine, so never use
ellipses since the engine won't know how to pronounce them.
```

### 5.2 Estruture com Tags XML

Essencial para prompts que misturam instruções, contexto, exemplos e inputs variáveis:

```xml
<instructions>
  Classifique o sentimento do comentário abaixo e explique brevemente.
</instructions>

<examples>
  <example>
    <input>Adorei a feature de OAuth, funcionou na primeira tentativa!</input>
    <output>positivo — usuário satisfeito com implementação técnica</output>
  </example>
  <example>
    <input>O deploy quebrou o ambiente de staging novamente.</input>
    <output>negativo — problema recorrente de infraestrutura</output>
  </example>
</examples>

<input>A documentação da API está desatualizada, mas o endpoint funciona bem.</input>
```

Use nomes de tag consistentes em todos os seus prompts. Aninhe quando há hierarquia natural.

### 5.3 Few-Shot Prompting (3–5 exemplos)

Exemplos são a forma mais confiável de dirigir formato, tom e estrutura. Boas características:
- **Relevantes:** espelham o caso de uso real
- **Diversos:** cobrem edge cases sem criar padrões não intencionais
- **Estruturados:** envoltos em tags `<example>` para que Claude os distinga das instruções

### 5.4 System Prompts

Defina papel, tom e comportamento padrão no system prompt. Até uma frase faz diferença:

```python
import anthropic

client = anthropic.Anthropic()

response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=1024,
    system="You are a senior software engineer specializing in Python backend systems. "
           "Be direct and concrete. Prefer showing code over explaining it.",
    messages=[
        {"role": "user", "content": "How should I structure error handling in our FastAPI app?"}
    ],
)
```

**System prompt para ação proativa (Claude Code CLI):**

```xml
<default_to_action>
By default, implement changes rather than only suggesting them. If the user's
intent is unclear, infer the most useful likely action and proceed, using tools
to discover any missing details instead of guessing.
</default_to_action>
```

**System prompt para comportamento conservador:**

```xml
<do_not_act_before_instructions>
Do not jump into implementation or change files unless clearly instructed.
When the user's intent is ambiguous, default to providing information,
doing research, and providing recommendations rather than taking action.
</do_not_act_before_instructions>
```

---

## 6. Fluxo de Trabalho Agêntico

O fluxo mais produtivo no Claude Code separa exploração, planejamento e execução em fases distintas.

### Fluxo recomendado em 4 fases

**Fase 1 — Explorar `[Plan Mode: Ctrl+G]`**

Deixe Claude ler o código antes de qualquer decisão:

```
read /src/auth and understand how we handle sessions, token refresh,
and environment variables for secrets. don't make any changes yet.
```

**Fase 2 — Planejar `[Plan Mode: Ctrl+G]`**

Com contexto estabelecido, Claude propõe a abordagem:

```
I want to add Google OAuth. What files need to change?
What's the token flow? Create a step-by-step plan before touching any code.
```

**Fase 3 — Implementar `[Normal Mode: Ctrl+G]`**

Execute o plano com critérios de verificação embutidos:

```
implement the OAuth flow from your plan. write tests for the callback
handler. run the test suite and fix any failures before stopping.
```

**Fase 4 — Commitar**

```
commit with a descriptive message and open a PR
```

> Plan Mode é mais útil quando você está incerto sobre a abordagem ou a mudança afeta múltiplos arquivos. Para tarefas com escopo claro (corrigir typo, renomear variável), peça diretamente — Plan Mode adiciona overhead desnecessário.

### Dê ao Claude critérios de verificação

Esta é a ação de maior alavancagem disponível:

| Situação | Sem verificação | Com verificação |
|----------|----------------|-----------------|
| Validação de input | "implement email validation" | "write validateEmail. test cases: user@example.com → true, invalid → false. run tests after implementing" |
| UI | "make the dashboard look better" | "[screenshot] implement this design. take a screenshot of the result. list differences and fix them" |
| Bug | "the build is failing" | "build fails with [error]. fix it and verify build succeeds. address root cause, don't suppress the error" |
| Refactor | "improve the auth module" | "refactor auth to use the repository pattern. existing tests must still pass. run them before finishing" |

### Forneça contexto específico

| Estratégia | Antes | Depois |
|-----------|-------|--------|
| Escopo da tarefa | "add tests for foo.py" | "write a test for foo.py covering the edge case where the user is logged out. avoid mocks." |
| Aponte para fontes | "why does ExecutionFactory have a weird api?" | "look through ExecutionFactory's git history and summarize how its api came to be" |
| Referencie padrões | "add a calendar widget" | "look at HotDogWidget.php as a good pattern for widgets. follow it to implement a calendar widget" |
| Descreva o sintoma | "fix the login bug" | "users report login fails after session timeout. check token refresh in src/auth/. write a failing test, then fix it" |

### Forneça conteúdo rico

- Use `@arquivo` para referenciar arquivos — Claude lê antes de responder
- Cole imagens diretamente (copy/paste ou drag and drop)
- Forneça URLs de documentação e APIs como contexto
- Pipe data: `tail -200 app.log | claude -p "identify anomalies"`
- Git context: `git diff main --name-only | claude -p "review changed files for security issues"`

---

## 7. Programação Agêntica Avançada

### 7.1 Subagentes

Subagentes são instâncias de Claude rodando em seu próprio context window, com system prompt, tools e permissões independentes. São ideais para tarefas que geram muito output (investigações, análises extensas) sem poluir o contexto principal.

**Diferença de skills:** Skills são prompts reutilizáveis que rodam no contexto principal. Subagentes são contextos isolados.

**Subagentes não podem spawnar outros subagentes.** Para delegação aninhada, encadeie a partir da conversa principal.

**Criar um subagente em `.claude/agents/`:**

```markdown
---
name: code-reviewer
description: Reviews code for quality, security, and best practices. Use proactively after code changes.
tools: Read, Glob, Grep
model: sonnet
memory: project
color: blue
---

You are a senior code reviewer. Focus on:
1. Code quality and maintainability
2. Security vulnerabilities (injection, auth flaws, exposed secrets)
3. Performance issues
4. Consistency with existing patterns in the codebase

Provide specific line references and actionable fixes. Be direct — no filler.
Update your agent memory with recurring patterns and team conventions you discover.
```

**Subagente de testes (executor isolado):**

```markdown
---
name: test-runner
description: Runs tests and reports failures. Use to verify test status without polluting main context.
tools: Bash, Read
model: haiku
permissionMode: acceptEdits
maxTurns: 10
---

Run the test suite and report only failing tests with their error messages.
Keep your response concise: list failures, error messages, and file locations.
```

**Subagente de banco de dados (read-only garantido via hook):**

```markdown
---
name: db-reader
description: Executes read-only database queries for investigation and reporting.
tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
---

Execute only SELECT queries. Never modify data. Return results in a clear,
structured format.
```

```bash
#!/bin/bash
# ./scripts/validate-readonly-query.sh
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if echo "$COMMAND" | grep -qiE '\b(INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|TRUNCATE)\b'; then
  echo "Blocked: Only SELECT queries are allowed." >&2
  exit 2
fi
exit 0
```

**Campos de frontmatter completos:**

| Campo | Descrição |
|-------|-----------|
| `name` | Identificador único (lowercase + hifens) |
| `description` | Quando Claude deve delegar para este agente |
| `tools` | Tools disponíveis (herda todas se omitido) |
| `disallowedTools` | Tools negadas |
| `model` | `sonnet`, `opus`, `haiku`, ID completo, ou `inherit` |
| `permissionMode` | `default`, `acceptEdits`, `auto`, `bypassPermissions`, `plan` |
| `maxTurns` | Número máximo de turnos agênticos |
| `memory` | `user`, `project`, ou `local` |
| `mcpServers` | Servidores MCP disponíveis para este agente |
| `hooks` | Hooks escopados para este agente |
| `background` | `true` para sempre rodar em background |
| `isolation` | `worktree` para rodar em git worktree isolada |

**Invocar explicitamente:**

```
Use the code-reviewer subagent to look at my recent changes in src/auth/
```

```
@"code-reviewer (agent)" check the OAuth implementation for security issues
```

**Escopo de memória do subagente:**

| Escopo | Localização | Compartilhado via git |
|--------|-------------|----------------------|
| `user` | `~/.claude/agent-memory/<nome>/` | Não |
| `project` | `.claude/agent-memory/<nome>/` | Sim |
| `local` | `.claude/agent-memory-local/<nome>/` | Não |

### 7.2 Skills

Skills são prompts reutilizáveis invocados com `/skill-name`. Rodam no contexto principal — ideais para workflows curtos e repetíveis.

```markdown
# .claude/skills/fix-issue/SKILL.md
---
name: fix-issue
description: Fix a GitHub issue end-to-end
---

Analyze and fix the GitHub issue: $ARGUMENTS.

1. Use `gh issue view $ARGUMENTS` to get the details
2. Understand the problem and search for relevant code
3. Implement the fix
4. Write a test that verifies the fix
5. Run tests: if they fail, iterate
6. Create a descriptive commit and open a PR
```

```markdown
# .claude/skills/security-review/SKILL.md
---
name: security-review
description: Security review of changed files
---

Review the files changed in the current branch for security vulnerabilities.

1. Run `git diff main --name-only` to get changed files
2. Read each changed file
3. Check for: SQL injection, XSS, command injection, exposed secrets,
   auth flaws, insecure deserialization, missing input validation
4. Report findings with file path, line number, severity (high/medium/low),
   and suggested fix
```

### 7.3 Padrões Agênticos

**Padrão Fan-out — migrações em larga escala:**

```bash
# Migrar arquivos em paralelo com Claude não-interativo
# IFS= read -r preserva espaços e caracteres especiais em nomes de arquivo
while IFS= read -r file; do
  claude -p "Migrate $file from CommonJS to ES modules. Return 'OK' or 'FAIL: <reason>'." \
    --allowedTools "Edit" \
    --permission-mode auto &
done < files-to-migrate.txt
wait  # aguarda todos os processos paralelos
```

**Padrão Writer/Reviewer — separação de geração e revisão:**

```
# Sessão A — Writer
Implement a rate limiter middleware for our Express API.
Use the token bucket algorithm. Store state in Redis.
```

```
# Sessão B — Reviewer (contexto limpo, sem viés do writer)
Review the rate limiter implementation in @src/middleware/rateLimiter.ts.
Focus on: race conditions, edge cases at limit boundaries,
consistency with our existing middleware patterns in @src/middleware/.
Report issues with file:line references.
```

```
# Sessão A — refinamento
Address this feedback from the code review:
[output da Sessão B]
```

**Padrão Pipeline — encadeamento sequencial:**

```bash
# Cada etapa salva em arquivo e passa via pipe para a próxima
# (pipe é mais robusto que interpolação — não quebra com aspas simples no conteúdo)
claude -p "Create a technical spec for a rate limiter middleware" > spec.md
{ echo "Write failing tests for this spec:"; cat spec.md; } | claude -p - > tests.md
{ echo "Implement the rate limiter to pass these tests:"; cat tests.md; } | claude -p -
```

**Padrão Verificador — auto-correção em loop:**

```python
import subprocess

def run_with_verification(task: str, verify_cmd: str, max_retries: int = 3):
    for attempt in range(max_retries):
        subprocess.run(["claude", "-p", task])
        result = subprocess.run(verify_cmd, shell=True, capture_output=True)
        if result.returncode == 0:
            print(f"Verificação passou na tentativa {attempt + 1}")
            return True
        task = f"{task}\n\nVerification failed:\n{result.stdout.decode()}\nFix the issues."
    return False

run_with_verification(
    task="implement the rate limiter",
    verify_cmd="npm test -- --testPathPattern=rateLimiter",
)
```

### 7.4 Estado e Raciocínio de Longo Horizonte

Para tarefas que abrangem múltiplas sessões ou janelas de contexto:

**Estado estruturado em arquivo JSON:**

```json
{
  "task": "migrate_to_typescript",
  "files": [
    { "path": "src/auth/login.js", "status": "done" },
    { "path": "src/auth/token.js", "status": "in_progress" },
    { "path": "src/api/users.js", "status": "pending" }
  ],
  "total": 47,
  "done": 23,
  "errors": ["src/utils/legacy.js: circular import — needs manual review"]
}
```

**Notas de progresso legíveis por Claude:**

```
Session 4 progress (2026-04-03):
- Completed: src/auth/login.js — added strict types, fixed 3 implicit any
- In progress: src/auth/token.js — token payload type needs refinement
- Blocked: src/utils/legacy.js — circular import, needs architect decision
- Next session: continue from src/auth/token.js line 45
```

**Instrução de persistência no prompt:**

```
As you approach your context limit, write your current progress to progress.txt
and update task-state.json before stopping. The next session will pick up from there.
Always be persistent — do not stop early due to token concerns.
```

**Primeira sessão como setup:**

Use a primeira janela para criar a estrutura que sessões futuras usam: `init.sh` para setup do ambiente, `tests.json` com estado dos testes, `progress.txt` com checkpoint da tarefa atual.

### 7.5 Balanceando Autonomia e Segurança

Claude Opus 4.6 é proativo por natureza. Use este system prompt para controlar o escopo de autonomia:

```
Consider the reversibility and impact of your actions.

Take local, reversible actions freely (editing files, running tests, reading code).

For actions that are hard to reverse or affect shared systems, ask before proceeding:
- Destructive: deleting files/branches, dropping database tables, rm -rf
- Hard to reverse: git push --force, git reset --hard, amending published commits
- Visible to the team: pushing code, commenting on PRs/issues, sending messages
```

**Quando subagente vs. ação direta:**

```
Use subagents when tasks can run in parallel, require isolated context,
or involve independent workstreams that don't need to share state.
For simple tasks, single-file edits, or tasks where you need to maintain
context across steps, work directly rather than delegating.
```

---

## 8. MCP — Conectando Claude ao Mundo Real

O Model Context Protocol (MCP) é um protocolo aberto que conecta Claude a sistemas externos — bancos de dados, APIs internas, ferramentas de CI/CD, Jira, Slack — com uma interface padronizada. Funciona como um "USB-C para IA": qualquer cliente MCP conecta a qualquer servidor MCP.

### 8.1 Arquitetura

```
Claude Code (MCP Host)
  ├── MCP Client → Servidor MCP A (local/STDIO)
  ├── MCP Client → Servidor MCP B (remoto/HTTP)
  └── MCP Client → Servidor MCP C (local/STDIO)
```

**Primitivas que um servidor MCP pode expor:**

| Primitiva | Descrição | Quem chama |
|-----------|-----------|------------|
| **Tools** | Funções executáveis (buscar dados, criar issues, rodar scripts) | Claude |
| **Resources** | Dados para contexto (arquivos, schemas, respostas de API) | Aplicação host |
| **Prompts** | Templates reutilizáveis de interação | Usuário |

**Transports disponíveis:**
- **STDIO** — comunicação via stdin/stdout; local, zero overhead de rede
- **Streamable HTTP** — HTTP POST; suporta autenticação OAuth, Bearer tokens, API keys

### 8.2 Conectando Servidores MCP Existentes

**Via Claude Code CLI (configuração local):**

Arquivo: `~/.claude/settings.json` (global) ou `.claude/settings.json` (projeto).
Adicione o campo `mcpServers` no JSON raiz:

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "seu-token-aqui"
      }
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "postgresql://user:pass@localhost:5432/mydb"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/caminho/permitido"]
    },
    "meu-servidor-interno": {
      "command": "uv",
      "args": ["--directory", "/absolute/path/to/meu-servidor", "run", "server.py"]
    }
  }
}
```

**Via API Anthropic (clientes programáticos):**

Requer o beta header `"anthropic-beta": "mcp-client-2025-11-20"`.

```python
import anthropic

client = anthropic.Anthropic()

response = client.beta.messages.create(
    model="claude-opus-4-6",
    max_tokens=1000,
    messages=[{"role": "user", "content": "Quais issues estão abertas no repositório?"}],
    mcp_servers=[
        {
            "type": "url",
            "url": "https://meu-servidor-mcp.empresa.com/sse",
            "name": "internal-tools",
            "authorization_token": "MEU_TOKEN"  # apenas o token — a API adiciona "Bearer " automaticamente
        }
    ],
    tools=[
        {
            "type": "mcp_toolset",
            "mcp_server_name": "internal-tools"
        }
    ],
    betas=["mcp-client-2025-11-20"]
)
```

**Controlar quais tools do servidor são expostas:**

```python
# Allowlist — expor apenas tools específicas
tools=[{
    "type": "mcp_toolset",
    "mcp_server_name": "internal-tools",
    "default_config": {"enabled": False},
    "configs": {
        "list_issues": {"enabled": True},
        "create_issue": {"enabled": True}
        # delete_all_issues fica bloqueada
    }
}]

# Denylist — bloquear tools perigosas
tools=[{
    "type": "mcp_toolset",
    "mcp_server_name": "internal-tools",
    "configs": {
        "delete_all_issues": {"enabled": False}
    }
}]
```

### 8.3 Criando um Servidor MCP Customizado em Python

Use quando quiser expor sua API interna, banco de dados ou qualquer sistema como tools que Claude pode usar.

**Setup:**

```bash
uv init meu-servidor-mcp
cd meu-servidor-mcp
uv add "mcp[cli]" httpx
```

**Servidor completo — expondo API interna:**

```python
# server.py
import httpx
import os
import sys
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("internal-api")

API_BASE = "https://api.empresa.com/v1"
API_KEY = os.environ.get("API_KEY", "")  # definido em mcpServers.env no settings.json

async def api_request(path: str, method: str = "GET", data: dict = None) -> dict:
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    async with httpx.AsyncClient() as client:
        response = await client.request(method, f"{API_BASE}{path}", headers=headers, json=data)
        response.raise_for_status()
        return response.json()


@mcp.tool()
async def list_deployments(environment: str = "production") -> str:
    """Lista os deployments de um ambiente.

    Args:
        environment: Ambiente a consultar (production, staging, dev)
    """
    data = await api_request(f"/deployments?env={environment}")
    deployments = data.get("items", [])
    if not deployments:
        return f"Nenhum deployment em {environment}"
    lines = [f"- {d['name']} v{d['version']} ({d['status']}) — {d['deployed_at']}" for d in deployments]
    return f"Deployments em {environment}:\n" + "\n".join(lines)


@mcp.tool()
async def get_service_logs(service: str, lines: int = 100) -> str:
    """Busca logs recentes de um serviço.

    Args:
        service: Nome do serviço
        lines: Número de linhas a retornar (máximo 500)
    """
    max_lines = min(lines, 500)
    data = await api_request(f"/services/{service}/logs?lines={max_lines}")
    return data.get("content", "Sem logs disponíveis")


@mcp.tool()
async def create_incident(title: str, severity: str, description: str) -> str:
    """Cria um incidente no sistema de on-call.

    Args:
        title: Título curto do incidente
        severity: Severidade: critical, high, medium, low
        description: Descrição detalhada do problema
    """
    data = await api_request("/incidents", method="POST", data={
        "title": title,
        "severity": severity,
        "description": description
    })
    return f"Incidente criado: #{data['id']} — {data['url']}"


def main():
    # IMPORTANTE: use stderr para logs — stdout é reservado para JSON-RPC
    print("Servidor MCP iniciado", file=sys.stderr)
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
```

**Regra crítica para servidores STDIO:**

```python
# NUNCA — corrompe o protocolo JSON-RPC via stdout
print("Server started")

# SEMPRE — stderr é seguro para logs
print("Server started", file=sys.stderr)
import logging
logging.info("Server started")  # logging vai para stderr por padrão
```

**Configurar no Claude Code:**

```json
{
  "mcpServers": {
    "internal-api": {
      "command": "uv",
      "args": ["--directory", "/absolute/path/to/meu-servidor-mcp", "run", "server.py"],
      "env": {
        "API_KEY": "minha-api-key"
      }
    }
  }
}
```

### 8.4 Criando um Servidor MCP em TypeScript

```bash
mkdir meu-servidor-mcp && cd meu-servidor-mcp
npm init -y
npm install @modelcontextprotocol/sdk zod
npm install -D @types/node typescript
```

**`tsconfig.json`** (obrigatório para `npx tsc` funcionar):

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./build",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
```

**`src/index.ts`:**

```typescript
// src/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "internal-api", version: "1.0.0" });

const API_BASE = "https://api.empresa.com/v1";
const API_KEY = process.env.API_KEY!;

async function apiRequest(path: string, method = "GET", data?: object) {
  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers: { Authorization: `Bearer ${API_KEY}`, "Content-Type": "application/json" },
    body: data ? JSON.stringify(data) : undefined,
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}

server.registerTool(
  "list_deployments",
  {
    description: "Lista os deployments de um ambiente",
    inputSchema: {
      environment: z
        .enum(["production", "staging", "dev"])
        .default("production")
        .describe("Ambiente a consultar"),
    },
  },
  async ({ environment }) => {
    const data = await apiRequest(`/deployments?env=${environment}`);
    const lines = data.items.map(
      (d: any) => `- ${d.name} v${d.version} (${d.status}) — ${d.deployed_at}`
    );
    return {
      content: [{ type: "text", text: `Deployments em ${environment}:\n${lines.join("\n")}` }],
    };
  }
);

server.registerTool(
  "create_incident",
  {
    description: "Cria um incidente no sistema de on-call",
    inputSchema: {
      title: z.string().describe("Título curto do incidente"),
      severity: z.enum(["critical", "high", "medium", "low"]),
      description: z.string().describe("Descrição detalhada do problema"),
    },
  },
  async ({ title, severity, description }) => {
    const data = await apiRequest("/incidents", "POST", { title, severity, description });
    return {
      content: [{ type: "text", text: `Incidente criado: #${data.id} — ${data.url}` }],
    };
  }
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("MCP Server running on stdio"); // SEMPRE stderr
}

main().catch((e) => { console.error(e); process.exit(1); });
```

```bash
npx tsc  # build obrigatório antes de usar
```

### 8.5 MCP vs. Tool Use Direto via API

| Aspecto | Tool Use (API) | MCP |
|---------|---------------|-----|
| Onde a lógica executa | No seu código (client-side) | Em servidor separado |
| Reutilização | Específico da sua app | Qualquer cliente MCP |
| Primitivas | Apenas tools | Tools + Resources + Prompts |
| Descoberta dinâmica | Não | Sim (tools/list, listChanged) |
| Ecosistema | Apenas Claude | Claude, VS Code Copilot, Cursor, etc. |
| Melhor para | Integrações simples, uma app | Ferramentas compartilhadas, múltiplos clientes |

---

## 9. Tool Use — Ferramentas Customizadas via API

`[API]` — Esta seção é para quem usa a API da Anthropic diretamente.

### 9.1 Definindo uma Tool

```python
tools = [
    {
        "name": "search_codebase",
        "description": (
            "Searches the codebase for files containing a specific pattern. "
            "Use when you need to find where a function, class, or concept is defined or used. "
            "Returns file paths and matching line numbers. "
            "Does NOT search inside node_modules or build directories."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "pattern": {
                    "type": "string",
                    "description": "Regex pattern to search for"
                },
                "file_extension": {
                    "type": "string",
                    "description": "Filter by extension, e.g. '.ts', '.py'. Optional.",
                    "enum": [".ts", ".tsx", ".js", ".py", ".go", ".java"]
                }
            },
            "required": ["pattern"]
        }
    }
]
```

**Boas práticas para descrições de tools:**
- 3–4 frases mínimo — a descrição é o fator mais crítico para performance
- Inclua: o que faz, quando usar, quando NÃO usar, limitações
- Use `input_examples` para tools com inputs complexos ou formatos específicos

### 9.2 Ciclo Completo: tool_use → tool_result

```python
import anthropic
import subprocess

client = anthropic.Anthropic()

def execute_tool(name: str, inputs: dict) -> str:
    """Executa a tool localmente e retorna resultado como string."""
    if name == "search_codebase":
        pattern = inputs["pattern"]
        ext = inputs.get("file_extension", "")
        include = f"*{ext}" if ext else "*"
        # Usando lista de argumentos (shell=False) para evitar injeção de shell
        result = subprocess.run(
            ["grep", "-rn", pattern, f"--include={include}",
             ".", "--exclude-dir=node_modules"],
            capture_output=True, text=True
        )
        return result.stdout or "No matches found"
    raise ValueError(f"Unknown tool: {name}")


messages = [{"role": "user", "content": "Where is the JWT token validation implemented?"}]

while True:
    response = client.messages.create(
        model="claude-opus-4-6",
        max_tokens=1024,
        tools=tools,
        messages=messages
    )

    if response.stop_reason == "end_turn":
        # Claude terminou — extraia a resposta final
        for block in response.content:
            if hasattr(block, "text"):
                print(block.text)
        break

    if response.stop_reason == "tool_use":
        # Claude quer executar tools
        messages.append({"role": "assistant", "content": response.content})

        tool_use_blocks = [b for b in response.content if b.type == "tool_use"]
        tool_results = []

        for tool_use in tool_use_blocks:
            try:
                result = execute_tool(tool_use.name, tool_use.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_use.id,
                    "content": result
                })
            except Exception as e:
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_use.id,
                    "content": f"Error: {str(e)}",
                    "is_error": True
                })

        # CRÍTICO: todos os results em UMA única mensagem de user
        messages.append({"role": "user", "content": tool_results})
```

**Estruturas de dados:**

```json
// Tool use block (retornado por Claude)
{
  "type": "tool_use",
  "id": "toolu_01ABC",
  "name": "search_codebase",
  "input": {"pattern": "validateJWT", "file_extension": ".ts"}
}

// Tool result block (enviado de volta)
{
  "type": "tool_result",
  "tool_use_id": "toolu_01ABC",
  "content": "src/auth/jwt.ts:45: export function validateJWT(token: string)..."
}

// Tool result com erro
{
  "type": "tool_result",
  "tool_use_id": "toolu_01ABC",
  "content": "Error: grep command failed",
  "is_error": true
}
```

### 9.3 Chamadas em Paralelo

Claude pode executar múltiplas tools em um único turno — todos os `tool_result` devem retornar em **uma única mensagem**:

```python
# CORRETO — todos os results em uma única mensagem
messages.extend([
    {"role": "assistant", "content": response.content},           # múltiplos tool_use
    {"role": "user", "content": [result_1, result_2, result_3]}  # todos de uma vez
])

# ERRADO — results em mensagens separadas (impede paralelismo no próximo turno)
messages.extend([
    {"role": "assistant", "content": response.content},
    {"role": "user", "content": [result_1]},
    {"role": "user", "content": [result_2]}  # NUNCA faça isso
])
```

**System prompt para maximizar paralelismo:**

```xml
<use_parallel_tool_calls>
For maximum efficiency, whenever you need to perform multiple independent operations,
invoke all relevant tools simultaneously rather than sequentially.
For example, when reading 3 files, run 3 tool calls in parallel.
Never use placeholders or guess missing parameters in tool calls.
</use_parallel_tool_calls>
```

**Controlar paralelismo:**

```python
# Máximo 1 tool por turno
tool_choice={"type": "auto", "disable_parallel_tool_use": True}

# Exatamente 1 tool por turno (garante uso)
tool_choice={"type": "any", "disable_parallel_tool_use": True}

# Forçar uso de tool específica
tool_choice={"type": "tool", "name": "search_codebase"}
```

### 9.4 Controlar quando Claude usa tools

```python
# auto — Claude decide (padrão)
tool_choice={"type": "auto"}

# any — Claude DEVE usar pelo menos uma tool
tool_choice={"type": "any"}

# none — Claude NÃO pode usar tools neste turno
tool_choice={"type": "none"}
```

---

## 10. Otimização de Tokens e Contexto

### 10.1 Como tokens são contados

Cada resposta retorna quatro campos de uso:

| Campo | Descrição |
|-------|-----------|
| `input_tokens` | Tokens de input não-cacheados |
| `cache_creation_input_tokens` | Tokens novos escritos no cache |
| `cache_read_input_tokens` | Tokens lidos do cache (custo ~10× menor) |
| `output_tokens` | Tokens gerados na resposta |

**Total real de input = `cache_read` + `cache_creation` + `input_tokens`**

### 10.2 Contar tokens antes de enviar

Use o endpoint `/v1/messages/count_tokens` para validar tamanho antes de requests caros (é gratuito):

```python
import anthropic
client = anthropic.Anthropic()

count = client.messages.count_tokens(
    model="claude-opus-4-6",
    system="Você é um engenheiro de software senior...",
    tools=tools,
    messages=[{"role": "user", "content": "Analise o codebase inteiro..."}],
)
print(f"Este request usaria {count.input_tokens} tokens de input")

# Referências de tamanho:
# Imagem típica: ~1.551 tokens
# PDF típico: ~2.188 tokens
# Tools adicionam tokens automáticos do sistema (346 para Opus/Sonnet 4.6)
```

### 10.3 Prompt Caching

O prompt caching evita reprocessar conteúdo idêntico entre requests, armazenando prefixos e relendo-os por uma fração do custo.

**Caching automático (recomendado):**

```python
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=1024,
    cache_control={"type": "ephemeral"},  # TTL: 5 minutos
    system="[System prompt longo com contexto do projeto — 5000+ tokens]",
    messages=[{"role": "user", "content": "Pergunta do usuário"}]
)
```

**Cache com TTL estendido (1 hora) para documentação:**

```python
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": "[Documentação da API interna — raramente muda]",
            "cache_control": {"type": "ephemeral", "ttl": "1h"}  # 1 hora
        },
        {
            "type": "text",
            "text": "[Contexto específico da sessão — muda com frequência]",
            "cache_control": {"type": "ephemeral"}  # 5 minutos
        }
    ],
    messages=[{"role": "user", "content": "Pergunta"}]
)
```

**Regra de ordenação:** TTL mais longo deve vir **antes** de TTL mais curto.

**Monitorar uso do cache:**

```python
usage = response.usage
print(f"Cache read:     {usage.cache_read_input_tokens:,} tokens")
print(f"Cache write:    {usage.cache_creation_input_tokens:,} tokens")
print(f"Não-cacheado:   {usage.input_tokens:,} tokens")
print(f"Output:         {usage.output_tokens:,} tokens")
```

**Tokens mínimos para cache por modelo:**

| Modelo | Mínimo |
|--------|--------|
| Claude Opus 4.6, 4.5 | 4.096 tokens |
| Claude Sonnet 4.6 | 2.048 tokens |
| Claude Haiku 4.5 | 4.096 tokens |

**O que pode ser cacheado:** definições de tools, system messages, mensagens de texto, imagens, tool use e tool results de turnos anteriores.

**Invalidação:** o cache é invalidado quando definições de tools mudam, toggle de web search, tool choice ou parâmetros de thinking.

### 10.4 Estratégias de Gerenciamento de Contexto (Claude Code CLI)

| Comando | Quando usar |
|---------|-------------|
| `/clear` | Entre tarefas não relacionadas — reseta completamente |
| `/compact Focus on the API changes` | Compactar preservando o que importa |
| `/btw pergunta rápida` | Perguntas que não precisam ficar no histórico |
| Subagentes para investigação | Preserva o contexto principal limpo |
| `--continue` / `--resume` | Retomar sessões salvas |

**Use subagentes para investigações pesadas:**

```
Use a subagent to investigate how our authentication system handles token refresh,
and whether we have any existing OAuth utilities to reuse.
```

O subagente lê centenas de arquivos e retorna apenas o sumário — sem poluir a conversa principal.

**Contexto longo vs. múltiplas sessões curtas:** com cache habilitado, manter uma sessão longa é mais barato — o conteúdo estático fica cacheado. Múltiplas sessões curtas desperdiçam o cache write inicial.

**Personalize a compactação no CLAUDE.md:**

```markdown
When compacting, always preserve:
- The full list of modified files
- Any failing test names and error messages
- The current task step and next action
```

---

## 11. Adaptive Thinking e Chain of Thought

### Adaptive Thinking (Claude 4.6+)

Claude 4.6 decide dinamicamente quando e quanto pensar, com base na complexidade da query.
O modelo calibra o esforço de raciocínio — em queries simples responde diretamente, em queries
complexas pensa mais antes de responder.

> **Configuração via API:** A sintaxe exata dos parâmetros de adaptive thinking está disponível
> em `docs.anthropic.com/en/api/messages`. Consulte a documentação oficial antes de usar em
> produção, pois esta é uma área com evolução ativa.

**Orientação de uso por caso:**

| Caso de uso | Effort |
|-------------|--------|
| Maioria das aplicações | `medium` |
| Alto volume / sensível a latência | `low` |
| Coding agêntico, tool-heavy | `medium` |
| Chat, classificação, busca | `low` |
| Problemas complexos de arquitetura | `high` |

### Dicas para qualidade do raciocínio

**Prefira instruções gerais a passos prescritivos.** "Think thoroughly before answering" frequentemente supera um plano passo-a-passo manual.

**Peça auto-verificação explicitamente:**

```
Before you finish, verify your implementation against these test cases:
[teste 1], [teste 2]. If any fails, fix it.
```

**Evite revisitar decisões desnecessariamente (útil com Opus 4.6 em high effort):**

```
When deciding how to approach a problem, choose an approach and commit to it.
Avoid revisiting decisions unless you encounter new information that directly
contradicts your reasoning.
```

**Chain of thought manual (sem thinking ativado):**

```xml
Before answering, think through this step by step in <thinking> tags.
Then provide your final answer in <answer> tags.
```

---

## 12. Controle de Output e Formatação

### Diga o que fazer, não o que evitar

```
# Menos eficaz
Do not use markdown in your response

# Mais eficaz
Your response should be composed of smoothly flowing prose paragraphs.
```

### System prompt para minimizar markdown excessivo

```xml
<avoid_excessive_markdown>
When writing reports, documents, or analyses, write in clear, flowing prose
using complete paragraphs. Reserve markdown for inline code, code blocks,
and simple headings (###). Avoid **bold** and *italics*.

DO NOT use ordered or unordered lists unless:
a) presenting truly discrete items where list format is the best option, or
b) the user explicitly requests a list.
</avoid_excessive_markdown>
```

### Migração de prefills `[API]`

Prefills na última mensagem do assistant não são mais suportados em Claude 4.6+.

| Padrão anterior | Migração |
|----------------|----------|
| Forçar JSON/YAML via prefill | Use Structured Outputs ou instrua: "Respond only with valid JSON" |
| Pular preâmbulos | System prompt: "Respond directly without preamble" |
| Continuação interrompida | Mensagem do user: "Your previous response was interrupted ending with `[texto]`. Continue from where you left off." |

### Exemplos antes/depois — Prompt Improver

O Console da Anthropic (`console.anthropic.com`) oferece um Prompt Improver automático. Exemplo do padrão que ele aplica:

```
# Antes
Identify which Wikipedia article this sentence came from.
Article titles: {{titles}}
Sentence: {{sentence}}
```

```
# Depois
You are a text classification system specialized in matching sentences to
Wikipedia article titles.

<article_titles>
{{titles}}
</article_titles>

<sentence_to_classify>
{{sentence}}
</sentence_to_classify>

Step-by-step:
1. List key concepts from the sentence
2. Compare each concept with the article titles
3. Select the most appropriate match

Provide your reasoning in <analysis> tags, then output ONLY the article title.
```

---

## 13. Padrões de Falha Comuns

| Padrão | Sintoma | Solução |
|--------|---------|---------|
| "Kitchen sink session" | Começa uma tarefa, pede algo não relacionado, volta à primeira | `/clear` entre tarefas não relacionadas |
| Correções repetidas | Claude erra o mesmo ponto repetidamente | Após 2 correções: `/clear` + prompt mais específico |
| CLAUDE.md sobrecarregado | Claude ignora regras importantes | Corte tudo que Claude já faz corretamente sem instrução |
| Gap de verificação | Implementação plausível sem tratar edge cases | Sempre forneça critérios de verificação (testes, scripts) |
| Exploração infinita | "investigate X" → Claude lê centenas de arquivos | Escope a investigação ou use um subagente |
| Overengineering agêntico | Claude spawna subagente para fazer um grep simples | Instrua: use subagents only for parallel or isolated workstreams |
| Hard-coding para testes | Claude implementa apenas o que os testes cobrem | "Write a general-purpose solution, not one tailored to the test inputs" |

**Anti-padrão: overengineering**

```xml
<avoid_overengineering>
Only make changes that are directly requested or clearly necessary:
- Scope: Don't add features or refactor beyond what was asked
- Documentation: Don't add docstrings/comments to code you didn't change
- Defensive coding: Don't add error handling for scenarios that can't happen
- Abstractions: Don't create helpers for one-time operations
</avoid_overengineering>
```

**Anti-padrão: alucinação de código**

```xml
<investigate_before_answering>
Never speculate about code you have not opened. If the user references a specific
file, you MUST read the file before answering. Investigate relevant files BEFORE
answering questions about the codebase.
</investigate_before_answering>
```

---

## 14. Modo Não-Interativo e Automação

```bash
# Query única
claude -p "Explain what this project does"

# Output estruturado para scripts
claude -p "List all API endpoints" --output-format json

# Streaming para processamento em tempo real
claude -p "Analyze this log" --output-format stream-json

# Pipe de dados
tail -200 app.log | claude -p "Identify anomalies and suggest root causes"

# Review de segurança em batch
git diff main --name-only | claude -p "Review changed files for security issues"

# Fan-out paralelo (com controle de concorrência)
cat files.txt | xargs -P 4 -I{} \
  claude -p "Migrate {} to TypeScript. Return OK or FAIL: <reason>." \
    --allowedTools "Edit" --permission-mode auto
```

**Automatizar com CI/CD:**

```yaml
# .github/workflows/claude-review.yml
- name: Security Review
  run: |
    git diff origin/main --name-only | \
    claude -p "Review for OWASP Top 10 vulnerabilities. List findings with severity." \
      --output-format json > security-report.json
```

---

## 15. Referência: Modelos e Capacidades

| Modelo | ID da API | Uso ideal |
|--------|-----------|-----------|
| Claude Opus 4.6 | `claude-opus-4-6` | Problemas difíceis, agentes de longo horizonte, coding complexo |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | Equilíbrio velocidade + inteligência — padrão para a maioria dos workloads |
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` | Alta velocidade, alto volume, latência sensível |

Todos os modelos atuais suportam: context window de 1M tokens, visão, multilíngue, MCP, tool use, subagentes.

**Guia de seleção:**

```
Opus 4.6  → arquitetura de sistemas, migrações grandes, pesquisa profunda,
             trabalho autônomo estendido, problemas com múltiplos constraints
Sonnet 4.6 → desenvolvimento do dia a dia, code review, geração de testes,
              debugging, tasks de médio prazo
Haiku 4.5  → classificação, extração de dados, tasks repetitivas em batch,
              onde latência e custo são prioritários
```

---

## Apêndice: Checklist de Setup para Novos Projetos

```bash
# 1. Criar CLAUDE.md com /init
claude
> /init

# 2. Criar hooks essenciais
mkdir -p .claude/hooks
# Adicionar: lint-and-format.sh, validate-bash.sh, inject-git-context.sh

# 3. Configurar settings.json
cat > .claude/settings.json << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "PostToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": ".claude/hooks/lint-and-format.sh"}]}],
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": ".claude/hooks/validate-bash.sh"}]}],
    "SessionStart": [{"hooks": [{"type": "command", "command": ".claude/hooks/inject-git-context.sh"}]}]
  }
}
EOF

# 4. Criar subagentes para o time
mkdir -p .claude/agents
# Adicionar: code-reviewer.md, test-runner.md, security-auditor.md

# 5. Criar skills reutilizáveis
mkdir -p .claude/skills/fix-issue
# Adicionar: fix-issue/SKILL.md, security-review/SKILL.md

# 6. Versionar tudo exceto local
echo "CLAUDE.local.md" >> .gitignore
echo ".claude/agent-memory-local/" >> .gitignore
git add .claude/settings.json .claude/agents/ .claude/skills/ CLAUDE.md
git commit -m "chore: configure Claude Code for the team"
```

---

*Fonte: docs.anthropic.com, modelcontextprotocol.io, code.claude.com — Abril 2026*

---

## Glossário

**Adaptive Thinking** — Modo de raciocínio estendido disponível no Claude 4.6+. O modelo "pensa" internamente antes de responder, explorando múltiplos caminhos e verificando o próprio raciocínio. Ativado via parâmetro `thinking` na API.

**Agente** — Claude operando de forma autônoma: lê arquivos, executa comandos, verifica resultados e itera sem intervenção humana em cada passo. Contraste com uso pontual (single-turn).

**Chain of Thought (CoT)** — Técnica que instrui o modelo a externalizar o raciocínio passo a passo antes de apresentar a resposta final. Melhora qualidade em problemas de múltiplos passos.

**CLAUDE.md** — Arquivo de texto lido automaticamente pelo Claude Code no início de cada sessão. Define convenções do projeto, comandos de build/test e regras de estilo. Equivalente a "instruções de sistema persistentes do time".

**Claude Code** — CLI da Anthropic que permite usar Claude como agente de desenvolvimento diretamente no terminal, com acesso ao sistema de arquivos, shell e ferramentas de desenvolvimento.

**Context Window (Janela de Contexto)** — Quantidade máxima de tokens que Claude pode processar em uma única interação — mensagens, arquivos lidos e outputs de comandos somados. Modelos atuais suportam 1M tokens. Performance degrada conforme a janela enche.

**Few-Shot Prompting** — Técnica de incluir exemplos de input/output no prompt para demonstrar o padrão de resposta esperado. Mais eficaz que descrições abstratas para formatos não convencionais.

**Hook** — Script externo executado automaticamente em eventos do ciclo de vida do Claude Code (`PreToolUse`, `PostToolUse`, `SessionStart`, etc.). Torna comportamentos determinísticos independente das decisões do modelo.

**MCP (Model Context Protocol)** — Protocolo aberto para conectar Claude a sistemas externos: bancos de dados, APIs, sistemas de arquivos, ferramentas internas. O servidor MCP expõe recursos e ferramentas que o modelo usa durante a sessão.

**Mutation Testing** — Técnica para verificar a qualidade de uma suite de testes: introduz pequenas alterações ("mutantes") no código e verifica se os testes detectam cada mutação. Score 100% significa que nenhum bug desse tipo escaparia da suite.

**Plan Mode** — Modo do Claude Code em que o modelo planeja as ações antes de executá-las. Ativado com `Ctrl+G`. Útil para tarefas complexas onde validar o plano reduz erros e retrabalho.

**Prompt Caching** — Mecanismo da API que cacheia prefixos de prompt repetidos (system prompt, documentos fixos). Reduz latência e custo em chamadas que reutilizam o mesmo contexto estático.

**settings.json** — Arquivo de configuração do Claude Code (`.claude/settings.json` para o projeto, `~/.claude/settings.json` para configuração global). Define hooks ativos, permissões e timeouts.

**Skill** — Workflow multi-fase reutilizável invocado com `/nome`. Diferente de slash commands simples, skills têm pontos de verificação explícitos e aguardam aprovação entre fases antes de prosseguir.

**Slash Command** — Comando iniciado com `/` no Claude Code. Pode ser built-in (`/clear`, `/compact`, `/init`) ou customizado em `.claude/commands/` (simples) e `.claude/skills/` (multi-fase).

**Subagente** — Instância isolada de Claude invocada pelo modelo principal para tarefas específicas. Tem seu próprio contexto, ferramentas e modelo. Usado para paralelizar trabalho ou isolar outputs volumosos sem poluir o contexto principal.

**Token** — Unidade básica de processamento de texto. Aproximadamente 3/4 de uma palavra em português. Custo e latência são proporcionais ao total de tokens de input + output.

**Tool Use** — Mecanismo pelo qual Claude chama funções definidas pela aplicação durante uma conversa. Claude emite um bloco `tool_use`; a aplicação executa e devolve `tool_result`. Permite integração com sistemas arbitrários via API.

**UserPromptSubmit** — Evento de hook disparado antes de Claude processar o prompt do usuário. Permite injetar contexto adicional ou bloquear o prompt antes que o modelo o receba.
