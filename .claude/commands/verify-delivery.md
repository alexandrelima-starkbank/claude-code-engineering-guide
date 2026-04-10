---
description: Checklist pré-merge — convenções, review e testes em paralelo. Use antes de qualquer commit ou declaração de conclusão.
allowed-tools: Read, Grep, Glob, Bash
---
# Verify Delivery

## Passo 1 — Identificar mudanças

```bash
git diff --name-only
git diff --staged --name-only
```

Se não houver mudanças: reportar `Nenhuma mudança detectada` e encerrar.

---

## Passo 2 — Convenções (bloqueante)

```bash
python3 .claude/skills/verify-delivery/scripts/verify.py --git
```

Se houver violações: reportar e **parar aqui**. Não avançar para review/testes
enquanto houver violações de convenção — seria desperdício de contexto.

---

## Passo 3 — Fan-out paralelo

Se convenções passaram: disparar `code-reviewer` e `test-runner` **simultaneamente**,
em um único lote — não esperar um para iniciar o outro.

```
Use the code-reviewer agent to review: <lista dos arquivos modificados>
Use the test-runner agent to run the test suite
```

Aguardar ambos retornarem antes de sintetizar.

---

## Passo 4 — Sintetizar

```
VERIFY DELIVERY
Task: <descrição da mudança ou task ID se disponível>

CONVENTIONS: PASS | N violation(s)
  <violações se houver>

REVIEW:
  MUST FIX: <lista ou "none">
  SHOULD FIX: <lista ou "none">

TESTS: PASS | FAIL
  <falhas se houver>

VERDICT: READY | NOT READY
```

`READY` apenas se CONVENTIONS=PASS, REVIEW sem MUST FIX e TESTS=PASS.
