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

### `PostToolUse/Edit|Write` → `check-bash-syntax.sh`

Após qualquer edição em arquivos `.sh` ou `.bash`, executa `bash -n` (syntax check
sem executar). Se encontrar erros, retorna feedback para Claude corrigir antes de
continuar. Não bloqueia tecnicamente (PostToolUse não pode impedir uma edição
já executada), mas instrui Claude a corrigir antes de prosseguir.

Não tem dependências externas — `bash` já está presente em qualquer ambiente.

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

## Instalação

Execute o script de setup na raiz do projeto:

```bash
./setup.sh
```

O script verifica e instala as dependências, torna os hooks executáveis e
reporta o que está faltando. É idempotente — pode rodar múltiplas vezes.

### Dependências

| Ferramenta | Obrigatório | Usado em | Instalação |
|------------|-------------|----------|------------|
| `git` | sim | `inject-git-context.sh` | https://git-scm.com |
| `python3` | sim | `validate-destructive.sh` | `brew install python3` |
| `jq` | sim | `inject-git-context.sh` | `brew install jq` |
| `osascript` | não | `notify-done.sh` | nativo macOS |

---

## Adicionando ao seu projeto

Para usar este ambiente em outro projeto:

```bash
cp -r .claude/ /caminho/do/seu-projeto/
cp setup.sh /caminho/do/seu-projeto/
echo ".claude/settings.local.json" >> /caminho/do/seu-projeto/.gitignore
cd /caminho/do/seu-projeto && ./setup.sh
```

Os hooks usam caminhos relativos e funcionam de qualquer projeto.
