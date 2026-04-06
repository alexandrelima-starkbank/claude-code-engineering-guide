# Ambiente Claude Code

Este diretório configura o Claude Code para o projeto. Ao abrir o Claude Code
na raiz do repositório, tudo aqui é carregado automaticamente — sem configuração
manual.

---

## Como funciona

```
.claude/
├── settings.json     — hooks ativos (carregado automaticamente)
├── hooks/            — scripts executados em eventos do ciclo de vida
├── agents/           — subagentes especializados (contexto isolado)
└── commands/         — slash commands reutilizáveis (/nome)
```

O arquivo `settings.local.json` é pessoal e está no `.gitignore` — cada
desenvolvedor pode ter suas próprias permissões sem afetar o time.

---

## Hooks

Comportamentos **garantidos** — executam independentemente do que Claude decidir.

### `SessionStart` → `inject-git-context.sh`

Injeta automaticamente no início de cada sessão:
- Branch atual
- Últimos 5 commits
- Arquivos modificados (não commitados)

Claude começa cada sessão com contexto git sem precisar perguntar.

### `PreToolUse/Bash` → `validate-destructive.sh`

Bloqueia antes de executar:

| Comando | Motivo |
|---------|--------|
| `rm -rf` | Deleção irreversível |
| `git push --force` / `git reset --hard` | Reescrita de histórico publicado |
| `DROP TABLE` / `TRUNCATE TABLE` | DDL destrutivo |

Claude pode executar esses comandos se o usuário confirmar explicitamente.

### `Stop` → `notify-done.sh`

Notificação macOS quando Claude termina uma tarefa longa. Silencioso em
ambientes sem `osascript` (Linux/CI).

---

## Subagentes

Instâncias isoladas de Claude com ferramentas e modelo próprios. Úteis para
tarefas que geram muito output sem poluir o contexto principal.

### `code-reviewer` (sonnet)

Revisão de código em três tiers: **MUST FIX** / **SHOULD FIX** / **NITPICK**.

Foco em: corretude, segurança, consistência com padrões existentes e cobertura
de testes. Retorna `file:line`, o problema e uma correção concreta.

**Como usar:**
```
Use the code-reviewer agent to review my changes in src/auth/
```
```
@"code-reviewer (agent)" check the OAuth implementation for security issues
```

### `test-runner` (haiku)

Roda a suite de testes e reporta apenas falhas. Detecta o test runner do
projeto (pytest, jest, go test, etc.) automaticamente.

**Como usar:**
```
Use the test-runner agent to check if the tests pass
```

---

## Slash Commands

Invocados com `/nome` no prompt do Claude Code.

### `/review [branch ou commit]`

Revisão de changes recentes: corretude, segurança e cobertura de testes.

```
/review
/review main..feat/oauth
/review HEAD~3
```

Retorna: `MUST FIX | SHOULD FIX | NITPICK` com `file:line` e correção sugerida.

### `/security-review [branch ou path]`

Revisão focada em vulnerabilidades OWASP: injection, XSS, auth gaps, secrets
expostos, input validation, uso inseguro de `eval`/`exec`/`shell=True`.

```
/security-review
/security-review src/api/
```

Retorna: `file:line | HIGH/MEDIUM/LOW | issue | fix sugerido`.

---

## Adicionando ao seu projeto

Para usar este ambiente em outro projeto, copie o diretório `.claude/` para a
raiz do seu repositório e adicione ao `.gitignore`:

```bash
cp -r .claude/ /caminho/do/seu-projeto/
echo ".claude/settings.local.json" >> /caminho/do/seu-projeto/.gitignore
```

Os hooks usam caminhos relativos e funcionam de qualquer projeto.

---

## Pré-requisitos

| Ferramenta | Uso |
|------------|-----|
| `jq` | Parsing de JSON nos hooks |
| `python3` | Parsing de JSON no `validate-destructive.sh` |
| `osascript` | Notificação macOS (opcional) |

```bash
# macOS
brew install jq
```
