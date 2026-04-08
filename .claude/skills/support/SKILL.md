---
name: support
description: Ciclo N3 completo para incidentes de produção. Intake estruturado → investigação cross-service via sub-agente → root cause → gate de escalação N3/N4. Use para qualquer sintoma de produção antes de tocar em código.
---

# Support: $ARGUMENTS

Ciclo N3 — investigação especializada sem geração de código.

---

## Fase 1 — Intake

Coletar o contexto estruturado do incidente. Se `$ARGUMENTS` contiver uma descrição
completa, extrair os campos abaixo. Se estiver incompleto, perguntar o que falta.

**Campos obrigatórios:**
- **Sintoma**: o que está sendo observado (erro, comportamento inesperado, ausência de comportamento esperado)
- **Comportamento esperado**: o que deveria acontecer
- **Impacto**: quem está afetado e em que escala (todos os usuários? segmento específico? ambiente?)
- **Desde quando**: quando o problema começou ou foi detectado pela primeira vez
- **Ambiente**: produção / staging / ambos

**Campos opcionais — coletar se disponíveis:**
- **Reprodução**: passos para reproduzir
- **Mudanças recentes**: deploys, migrações ou configurações alteradas no período relevante

Não avançar para a Fase 2 sem todos os campos obrigatórios preenchidos.

**GATE:** editar `TASKS.md` agora com o formato de incidente antes de continuar. Não avançar sem ter escrito no arquivo.

---

## Fase 2 — Investigação

Invocar o agente `support-investigator` com o contexto coletado:

```
Use the support-investigator agent to investigate this production incident:

Sintoma: <sintoma>
Comportamento esperado: <comportamento esperado>
Impacto: <impacto>
Desde quando: <timeline>
Ambiente: <ambiente>
Mudanças recentes: <mudanças ou "não informado">
Reprodução: <passos ou "não informado">

Investigate: trace the data flow across services, form at least 3 hypotheses,
collect evidence for each, and report the ranked root cause analysis with
confidence level and evidence trail.
```

Aguardar o relatório completo do agente antes de continuar.

---

## Fase 3 — Root Cause e Gate de Escalação

Apresentar os achados ao usuário em formato estruturado:

```
INCIDENTE: <título>
SEVERIDADE: crítico | alto | médio | baixo

ROOT CAUSE:
  <causa raiz identificada>
  Confiança: alta | média | baixa
  Evidências: <arquivo:linha — descrição>

HIPÓTESES DESCARTADAS:
  <outras hipóteses investigadas e por que foram descartadas>

RESOLUÇÃO NO N3:
  <workaround disponível, rollback de config, ajuste de dados>
  <ou: "não identificado — requer mudança de código">

GATE:
  Este incidente pode ser resolvido no N3? sim / não
```

Aguardar decisão explícita do usuário antes de continuar.

---

## Fase 4a — Resolução N3 (sem código)

Se a decisão for resolver no N3:

1. Documentar a solução (workaround, rollback, ajuste de configuração ou dados)
2. **GATE:** editar `TASKS.md` agora:
   - `**Root cause:**` com causa raiz e nível de confiança
   - `**Observações:**` com os passos da solução aplicada
   - Status para `concluído`
3. Invocar o agente `tasks-maintainer` para mover a tarefa para `HISTORY_TASKS.md`
4. Confirmar apenas após as edições: "Incidente resolvido no N3. Documentado em T<N>."

---

## Fase 4b — Escalação N4 (código necessário)

Se a decisão for escalar para N4:

1. Derivar Requisitos EARS do bug a partir do root cause:
   - Foco nos padrões `IF/THEN` (comportamento indesejado) e `WHEN` (comportamento esperado)
   - Cada requisito descreve o que o sistema DEVE fazer — não o que está fazendo
   - Cada requisito é testável e implementável

2. **GATE:** editar `TASKS.md` agora:
   - `**Root cause:**` com causa raiz e nível de confiança
   - `**Nível:**` N4
   - `**Requisitos EARS:**` gerados nesta fase (prontos para `/bugfix`)

3. Confirmar:
   ```
   Incidente escalado para N4.
   Root cause e Requisitos EARS registrados em T<N>.
   Execute: /bugfix <título do incidente>
   ```
