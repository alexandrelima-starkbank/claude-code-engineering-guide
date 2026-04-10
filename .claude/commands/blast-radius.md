---
description: Analyze the cross-service impact of changing a field, enum, function, or contract
allowed-tools: Read, Grep, Glob
---
# Blast Radius: $ARGUMENTS

## Passo 1 — Ler SERVICE_MAP

Read `.claude/skills/cross-service-analysis/SERVICE_MAP.md`.

A análise é **cross-service** se o arquivo existir e `## Diretórios dos Serviços` não contiver
placeholders `<diretório-do-service-`. Caso contrário: análise restrita ao repositório atual
(use Grep diretamente e pule o fan-out paralelo).

---

## Passo 2 — Fan-out paralelo (apenas se SERVICE_MAP configurado)

Extraia os serviços de `## Diretórios dos Serviços`. Para cada serviço, monte os argumentos:

```
TARGET=<alvo>  SERVICE_NAME=<nome>  SERVICE_PATH=<caminho>
```

**Dispare TODOS os agentes em um único lote — não sequencialmente.**
Invoque um `service-impact-analyzer` por serviço simultaneamente, antes de processar
qualquer resultado. Aguarde todos retornarem para então sintetizar.

Exemplo com 3 serviços:
```
Use the service-impact-analyzer agent to analyze: TARGET=CardStatus SERVICE_NAME=corporate SERVICE_PATH=~/projects/corporate
Use the service-impact-analyzer agent to analyze: TARGET=CardStatus SERVICE_NAME=billing SERVICE_PATH=~/projects/billing
Use the service-impact-analyzer agent to analyze: TARGET=CardStatus SERVICE_NAME=ledger SERVICE_PATH=~/projects/ledger
```

Se SERVICE_MAP não configurado: grep no repositório atual e note no output:
`SERVICE_MAP not configured — analysis limited to current repository. Run ./configure.sh to enable cross-service analysis.`

---

## Passo 3 — Sintetizar resultados

Após receber os blocos de todos os agentes:

1. **RISK global** — mapeie o maior BREAK_RISK individual:
   - Qualquer serviço em caminho crítico (auth, financeiro, billing) → CRITICAL
   - HIGH em qualquer serviço → HIGH
   - Apenas MEDIUM → MEDIUM
   - Apenas LOW/NONE → LOW

2. **AFFECTED** — liste apenas serviços com `STATUS: AFFECTED`.

3. **DEPLOY ORDER** — aplique as `## Regras de Deploy` do SERVICE_MAP.
   Omita esta seção em modo single-repo.

---

## Formato de saída

```
TARGET: <o que muda>
RISK: LOW | MEDIUM | HIGH | CRITICAL

AFFECTED:
  <serviço> — <arquivos> — <break risk>

DEPLOY ORDER:
  1. <serviço> — <motivo>
  2. <serviço> — <motivo>
```
