# Claude Code Engineering Environment

Ambiente Claude Code pronto para times Python — hooks de proteção, linting
automático, injeção de contexto, agentes especializados, slash commands para
TDD, revisão de código e mutation testing.

---

## Quick Start

```bash
rm -rf /tmp/cce-guide && git clone --depth 1 https://github.com/alexandrelima-starkbank/claude-code-engineering-guide.git /tmp/cce-guide && bash /tmp/cce-guide/install.sh
```

Detecta o contexto (projeto único ou workspace), instala dependências, configura
`pyproject.toml` e `mutmut.toml` automaticamente e ativa os hooks. Idempotente.

---

## O que está incluído

| Componente | Quantidade | Documentação |
|------------|-----------|--------------|
| Hooks | 14 scripts | [`.claude/README.md`](.claude/README.md#hooks) |
| Agentes | 7 especializados | [`.claude/README.md`](.claude/README.md#subagentes) |
| Slash Commands | 13 comandos | [`.claude/README.md`](.claude/README.md#slash-commands) |
| Skills | 6 workflows | [`.claude/README.md`](.claude/README.md#skills) |
| Pipeline CLI | 20+ subcomandos | [`.claude/PIPELINE.md`](.claude/PIPELINE.md) |

Catálogo completo de entry points por caso de uso: [`.claude/CATALOG.md`](.claude/CATALOG.md)

---

## Guia de Claude Code para Engenharia

O guia completo de Claude Code — filosofia, setup, CLAUDE.md, hooks, prompt
engineering, fluxo agêntico, MCP, tool use, otimização e referência de modelos:

**[GUIDE.md](GUIDE.md)**

---

## Documentação do Ambiente

Documentação detalhada de cada hook, agente, comando e skill:

**[.claude/README.md](.claude/README.md)**

---

## Licença

[Apache 2.0](LICENSE)
