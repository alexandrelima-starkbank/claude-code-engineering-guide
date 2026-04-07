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

Tarefas concluídas NÃO devem ser apagadas. Elas DEVEM ser movidas para a seção
`## Histórico` ao final deste arquivo. O histórico serve como registro do que foi
feito e por quê, e DEVE ser preservado indefinidamente.

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
- **Critério de aceitação:**
  **Cenário: <nome>**
  - Dado: <pré-condições>
  - Quando: <ação>
  - Então: <resultado esperado> → `test<Cenário>_<Condição>`

  *(repetir para cada cenário — caminho feliz, erros, edge cases)*
- **Observações:** <decisões, bloqueios, dependências, ponto de parada — omitir se vazio>
```

O campo **Critério de aceitação** é obrigatório no formato Dado/Quando/Então.
Cada "Então" deve mapear para exatamente um método de teste (`test<Cenário>_<Condição>`).
Critérios vagos como "funciona corretamente" não são aceitos.
Use `/spec <descrição>` para gerar os cenários automaticamente.

---

## Tarefas Ativas

_Nenhuma tarefa ativa no momento._

---

## Histórico

_Nenhuma tarefa concluída ainda._
