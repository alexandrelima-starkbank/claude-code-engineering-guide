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
├── commands/         — slash commands reutilizáveis (/nome)
└── skills/           — skills multi-fase reutilizáveis (/skill-name)
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

### `UserPromptSubmit` → `inject-tasks-context.sh`

Em cada prompt, injeta o estado atual das tarefas ativas do `TASKS.md`.
Claude sempre sabe quais tarefas estão em andamento sem precisar ler o arquivo.

Degrada silenciosamente se `TASKS.md` não existir.

### `PreToolUse/Bash` → `validate-destructive.sh`

Bloqueia antes de executar:

| Comando | Motivo |
|---------|--------|
| `rm -rf` (e variantes com `sudo`) | Deleção irreversível |
| `git push --force` / `--force-with-lease` | Reescrita de histórico publicado |
| `git reset --hard` | Descarta commits locais |
| `git checkout -- .` / `git restore` | Descarta alterações não commitadas |
| `git clean -f` | Descarta arquivos não rastreados |
| `git stash drop` / `git stash clear` | Descarta stashes irreversivelmente |
| `DROP TABLE` / `TRUNCATE TABLE` | DDL destrutivo |

O hook retorna `exit 2`, que o Claude Code interpreta como bloqueio. Claude não executa
o comando — reporta o bloqueio ao usuário para que ele decida como prosseguir.

> **Limitação:** a validação é baseada em texto. Comandos compostos via `eval`, `bash -c`
> ou variáveis indiretas não são interceptados. O hook é uma camada de proteção
> contra erros acidentais, não um controle de segurança rígido.

### `PostToolUse/Edit|Write|MultiEdit` → `check-bash-syntax.sh`

Após qualquer edição em arquivos `.sh` ou `.bash`:
1. `bash -n` — verificação de sintaxe
2. `shellcheck` — análise estática profunda (se disponível)

Retorna feedback para Claude corrigir antes de continuar.

### `PostToolUse/Edit|Write|MultiEdit` → `check-python-style.sh`

Após qualquer edição em arquivos `.py`, detecta violações das convenções:

| Violação | Padrão esperado |
|----------|-----------------|
| f-strings | Use `.format()` |
| blocos `else` | Use early return |
| type hints em funções | Sem type hints |
| docstrings | Sem docstrings |

Retorna `{"decision":"block","reason":"..."}` com a lista de violações.

### `Stop` → `notify-done.sh`

Notificação macOS quando Claude termina uma tarefa longa. Silencioso em
ambientes sem `osascript` (Linux/CI).

---

## Subagentes

Instâncias isoladas de Claude com ferramentas e modelo próprios. Úteis para
tarefas que geram muito output sem poluir o contexto principal.

### `tasks-maintainer` (haiku)

Mantém `TASKS.md` de forma autônoma. Recebe uma descrição do trabalho concluído,
lê o estado atual de TASKS.md e aplica as atualizações necessárias:
atualiza status, move tasks concluídas para `## Histórico`.

Invocado pelo modelo principal ao final de qualquer trabalho concreto — sem pedido
do usuário. Não executa código, não lê outros arquivos além de TASKS.md.

**Como usar (invocado pelo modelo, não pelo usuário):**
```
Use the tasks-maintainer agent to update TASKS.md: task T2 was completed — all hooks verified and pushed.
```

---

### `code-reviewer` (sonnet)

Revisão de código em três tiers: **MUST FIX** / **SHOULD FIX** / **NITPICK**.

Para arquivos de teste (`*Test.py`), avalia adicionalmente:
- Assertions triviais que passariam mesmo com implementação errada
- Testes excessivamente mockados
- Cenários ausentes (empty, None, boundary values)
- Rastreabilidade para critérios de aceite

**Como usar:**
```
Use the code-reviewer agent to review my changes in src/auth/
```

### `test-reviewer` (sonnet)

Avalia **qualidade de assertions** — não apenas cobertura. Para cada método de
teste reporta: `WEAK` / `ACCEPTABLE` / `STRONG` com justificativa.

Não executa testes. Não escreve código.

**Como usar:**
```
Use the test-reviewer agent to evaluate tests/parserTest.py
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

### `/spec <descrição>`

Gera critérios de aceite no formato Dado/Quando/Então para uma funcionalidade.
Cada "Então" mapeia para exatamente um método de teste (`test<Cenário>_<Condição>`).

Cobre: caminho feliz, inputs inválidos, valores de fronteira, erros esperados,
edge cases de autorização.

```
/spec endpoint de criação de item com validação de duplicatas
```

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

### `/mutation-test [path]`

Executa `mutmut` no path especificado, mostra resultados e diagnostica cada
mutante sobrevivente como lacuna de teste ou mutante equivalente.

Meta: 100% de score. Mutantes equivalentes devem ser justificados com
`# pragma: no mutate`.

```
/mutation-test src/parser.py
```

### `/blast-radius <alvo>`

Analisa o impacto de mudar um campo, enum, função ou contrato em todos os
serviços da plataforma. Usa `SERVICE_MAP.md` para descobrir serviços e regras
de deploy.

```
/blast-radius CardStatus enum
/blast-radius campo purchase_amount no modelo Purchase
```

Retorna: serviços afetados, risco (LOW/MEDIUM/HIGH/CRITICAL) e ordem de deploy.

### `/investigate <problema>`

Investiga um bug ou comportamento inesperado rastreando o fluxo de dados
através dos serviços conforme o pipeline em `SERVICE_MAP.md`.

```
/investigate autorização falhando para cartões pré-pagos
/investigate saldo não atualiza após pagamento de fatura
```

Apresenta o que está acontecendo, por quê, quais arquivos, impacto cross-service
e sugestão de fix — sem implementar.

---

## Skills

Skills são workflows multi-fase com pontos de verificação explícitos.

### `/tdd`

Workflow TDD completo em 5 fases:

| Fase | O que acontece |
|------|----------------|
| 1. Spec | Gera critérios de aceite (aguarda aprovação) |
| 2. Testes | Escreve testes que **devem falhar** |
| 3. Implementação | Código mínimo para passar os testes |
| 4. Mutação | `mutmut` — 100% exigido |
| 5. Checklist | Verifica convenções antes de commitar |

```
/tdd endpoint de criação de item
```

### `/cross-service-analysis`

Análise completa de impacto cross-service em 5 passos: identifica o alvo,
busca referências em todos os serviços, classifica cada hit por criticidade,
determina ordem de deploy e apresenta o resultado estruturado.

Requer `SERVICE_MAP.md` preenchido com os serviços da plataforma.

```
/cross-service-analysis remover campo legacy_id do modelo Card
```

---

## Configuração Cross-Service

Para projetos com múltiplos serviços, preencha
`.claude/skills/cross-service-analysis/SERVICE_MAP.md` com:

- Lista de serviços e seus diretórios
- Grafo de dependências (qual serviço chama qual)
- Contratos compartilhados (enums, mensagens de fila, schemas de API)
- Regras de deploy específicas da plataforma

Sem esse arquivo preenchido, os comandos `/blast-radius`, `/investigate` e a
skill `/cross-service-analysis` operam sem contexto da plataforma.

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
| `python3` | sim | testes e linting | `brew install python3` |
| `jq` | sim | hooks (parse JSON) | `brew install jq` |
| `shellcheck` | não | `check-bash-syntax.sh` | `brew install shellcheck` |
| `ruff` | não | `check-python-style.sh` | `pip3 install ruff` |
| `mutmut` | não | `/mutation-test`, `/tdd` | `pip3 install mutmut` |
| `osascript` | não | `notify-done.sh` | nativo macOS |

---

## Adicionando ao seu projeto

Para usar este ambiente em outro projeto:

```bash
cp -r .claude/ /caminho/do/seu-projeto/
cp setup.sh /caminho/do/seu-projeto/
cp mutmut.toml /caminho/do/seu-projeto/
cp pyproject.toml /caminho/do/seu-projeto/
echo ".claude/settings.local.json" >> /caminho/do/seu-projeto/.gitignore
cd /caminho/do/seu-projeto && ./setup.sh
```

Os hooks usam caminhos relativos e funcionam de qualquer projeto.
Ajuste `mutmut.toml` para apontar para os seus diretórios de código e testes.
