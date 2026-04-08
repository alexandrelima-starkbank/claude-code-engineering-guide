# TASKS.md — Controle de Tarefas

Este arquivo é o registro oficial de todas as tarefas de desenvolvimento neste repositório.
O modelo DEVE lê-lo no início de toda sessão que envolva implementação, investigação ou
entrega, e DEVE mantê-lo atualizado ao longo de todo o trabalho.

---

## Protocolo de Uso — LEIA ANTES DE INICIAR QUALQUER TAREFA

### Regra 1 — Leitura Obrigatória no Início da Sessão

Ao iniciar uma sessão de trabalho, o modelo DEVE ler este arquivo imediatamente.
Nenhuma tarefa de implementação, investigação ou entrega deve ser iniciada antes que
o modelo tenha lido o estado atual de todas as tarefas e compreendido o contexto.

### Regra 2 — Registro Antes de Executar

Toda tarefa nova DEVE ser registrada neste arquivo ANTES de o modelo começar a executá-la.
É proibido implementar qualquer coisa que não esteja registrada aqui.
Se o usuário pedir algo que ainda não está listado, o modelo DEVE adicioná-lo antes de agir.

### Regra 3 — Atualização de Status em Tempo Real

O status de cada tarefa DEVE ser atualizado no momento exato em que ocorre a transição:
- Ao INICIAR uma tarefa: mude o status para `em andamento` imediatamente.
- Ao CONCLUIR uma tarefa: mude o status para `concluído` imediatamente.
- Ao BLOQUEAR uma tarefa: mude o status para `bloqueado` e registre o motivo em Observações.

### Regra 4 — Granularidade

Cada tarefa deve representar uma unidade de trabalho claramente delimitada e verificável.
Tarefas grandes DEVEM ser decompostas em subtarefas antes de iniciar a execução.
Uma tarefa está concluída apenas quando o critério de aceitação pode ser confirmado
objetivamente (testes passando, comportamento verificado, arquivo commitado, etc.).

### Regra 5 — Nunca Apagar Tarefas Concluídas

Tarefas concluídas NÃO devem ser apagadas. Elas DEVEM ser movidas para `HISTORY_TASKS.md`,
que fica na mesma pasta que este arquivo. O histórico serve como registro permanente do que
foi feito e por quê, e DEVE ser preservado indefinidamente.

Este arquivo (`TASKS.md`) contém apenas tarefas ativas. O histórico completo está em
`HISTORY_TASKS.md`.

### Regra 6 — Campo Observações

Toda tarefa PODE ter um campo Observações. Esse campo DEVE ser usado para registrar:
- Decisões de design tomadas durante a execução
- Bloqueios e suas causas
- Dependências com outras tarefas
- Resultados de investigações relevantes para o contexto

### Regra 7 — Sessão Encerrada com Tarefas em Andamento

Se a sessão encerrar com tarefas com status `em andamento`, o modelo DEVE registrar
em Observações o ponto exato onde parou, o que foi feito até agora e o que falta
para concluir. Isso permite que a próxima sessão retome sem perda de contexto.

### Regra 8 — Manutenção Autônoma

A manutenção deste arquivo é responsabilidade autônoma do modelo. Nenhuma instrução
explícita do usuário é necessária — nem para registrar, nem para atualizar, nem para
mover para o Histórico.

O modelo DEVE, em toda resposta que envolva trabalho:
- Registrar a tarefa antes de iniciar (se ainda não registrada)
- Atualizar o status no momento exato de cada transição
- Mover para `## Histórico` imediatamente ao concluir — na mesma resposta, nunca depois

O usuário não precisa pedir. O modelo não pode aguardar ser questionado.

---

## Status Permitidos

| Status | Significado |
|--------|-------------|
| `pendente` | Tarefa registrada, ainda não iniciada |
| `em andamento` | Tarefa em execução nesta sessão |
| `bloqueado` | Tarefa não pode avançar — registrar motivo em Observações |
| `concluído` | Tarefa finalizada e critério de aceitação verificado |

---

## Formato de Tarefa

Cada tarefa deve seguir exatamente este formato:

```
### T<N> — <Título curto e descritivo>

- **Projeto:** <nome do projeto ou componente>
- **Status:** <pendente | em andamento | bloqueado | concluído>
- **Descrição:** <o que precisa ser feito e por quê, com contexto suficiente para
  retomar sem ajuda do usuário>
- **Requisitos EARS:**
  - WHEN <trigger>, o sistema SHALL <resposta>
  - IF <trigger>, THEN o sistema SHALL <resposta>
  *(gerado por /requirements — obrigatório antes de /spec)*
- **Critério de aceitação:**
  **Cenário: <nome>**
  - Dado: <pré-condições>
  - Quando: <ação>
  - Então: <resultado esperado> → `test<Cenário>_<Condição>`

  *(repetir para cada cenário — derivado dos Requisitos EARS)*
- **Observações:** <decisões, bloqueios, dependências, ponto de parada — omitir se vazio>
```

O campo **Requisitos EARS** é obrigatório e deve ser preenchido antes de `/spec`.
Use `/requirements <descrição>` para elicitar os requisitos no formato EARS.

O campo **Critério de aceitação** é obrigatório no formato Dado/Quando/Então e deve ser derivado dos Requisitos EARS.
Cada "Então" deve mapear para exatamente um método de teste (`test<Cenário>_<Condição>`).
Critérios vagos como "funciona corretamente" não são aceitos.
Use `/spec` para gerar os cenários automaticamente a partir dos requisitos.
Use `/feature <descrição>` para o fluxo completo: requirements → spec → tdd.

---

## Formato de Incidente

Para tarefas originadas de incidentes de produção (N3/N4), usar este formato:

```
### T<N> — <Título curto descrevendo o comportamento incorreto>

- **Projeto:** <nome do projeto ou componente>
- **Tipo:** incidente
- **Severidade:** crítico | alto | médio | baixo
- **Nível:** N3 | N4
- **Status:** <pendente | em andamento | bloqueado | concluído>
- **Comportamento atual:** <o que está acontecendo — sintoma observado>
- **Comportamento esperado:** <o que deveria acontecer>
- **Root cause:** <causa raiz identificada (alta | média | baixa confiança) — preenchido pelo N3>
- **Requisitos EARS:**
  - IF <condição do bug>, THEN o sistema SHALL <comportamento correto>
  - WHEN <trigger>, o sistema SHALL <resposta esperada>
  *(gerado pelo /support na escalação N4)*
- **Critério de aceitação:**
  **Cenário: <nome>**
  - Dado: <pré-condições que ativam o bug>
  - Quando: <ação>
  - Então: <comportamento correto> → `test<Cenário>_<Condição>`
- **Observações:** <evidências da investigação N3, workarounds, decisões — omitir se vazio>
```

O campo **Root cause** é preenchido durante a investigação N3 (via `/support`).
O campo **Requisitos EARS** é gerado na escalação N4 e serve de input para `/bugfix`.
Use `/support <sintoma>` para o ciclo N3 completo.
Use `/bugfix <título>` para o ciclo N4 a partir do root cause.

---

## Tarefas Ativas

_Nenhuma tarefa ativa no momento._
