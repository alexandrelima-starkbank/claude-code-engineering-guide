---
description: Elicita e documenta requisitos no formato EARS para uma feature ou problema. Escreve diretamente em TASKS.md após aprovação. Use antes de /spec.
allowed-tools: Read, Grep, Glob, Edit
---
# Requirements: $ARGUMENTS

## Responsabilidade

Produzir requisitos EARS completos, sem ambiguidade e aprovados pelo usuário.
Não gera spec, testes ou código.

---

## Processo

### 1. Leitura de contexto

- Ler `CLAUDE.md` para entender domínio, arquitetura e convenções do projeto
- Ler `TASKS.md` para verificar se há tarefa ativa relacionada ao tema
- Ler código relevante se necessário para entender restrições e comportamentos existentes

### 2. Análise do problema

Analisar `$ARGUMENTS` e mapear o que está claro e o que está ambíguo:

- **Sistema/componente afetado**: qual módulo, serviço ou camada?
- **Estados relevantes**: em que estados o sistema pode estar durante esta operação?
- **Triggers e eventos**: o que dispara o comportamento?
- **Respostas esperadas**: o que o sistema deve fazer em cada caso?
- **Comportamentos indesejados**: o que acontece em falha, input inválido ou estado inesperado?
- **Condicionais**: há features opcionais, flags de configuração ou variações de contexto?

### 3. Elicitação de gaps

Se informações críticas estiverem ausentes, fazer perguntas objetivas e aguardar resposta antes de gerar os requisitos.
Não inferir o que pode ser perguntado. Máximo 5 perguntas por rodada.

### 4. Geração dos requisitos EARS

Gerar requisitos nos padrões aplicáveis ao problema:

| Padrão | Template | Quando usar |
|--------|----------|-------------|
| Ubíquo | `O <sistema> SHALL <resposta>` | Comportamento sempre ativo, sem condição |
| Orientado a evento | `WHEN <trigger>, o <sistema> SHALL <resposta>` | Resposta a um evento específico |
| Orientado a estado | `WHILE <estado>, o <sistema> SHALL <resposta>` | Comportamento dependente de estado |
| Comportamento indesejado | `IF <trigger>, THEN o <sistema> SHALL <resposta>` | Falhas, erros, entradas inválidas |
| Feature opcional | `WHERE <feature incluída>, o <sistema> SHALL <resposta>` | Comportamento condicional |

**Regras de escrita:**
- Um requisito = uma condição + uma resposta
- `SHALL` = obrigatório. `SHOULD` = desejável (usar com parcimônia, justificar)
- Sem ambiguidade: nunca usar "rápido", "apropriado", "geralmente", "quando necessário"
- Sem implementação: descrever **o quê**, não **como**
- Sem compostos: um AND entre respostas = dois requisitos separados

### 5. Validação de completude

Antes de apresentar, verificar internamente:

- [ ] Caminho feliz coberto (pelo menos 1 requisito de evento ou ubíquo)
- [ ] Comportamentos de erro cobertos (IF/THEN)
- [ ] Estados relevantes cobertos (WHILE), se aplicável
- [ ] Nenhum requisito ambíguo ou inimplementável
- [ ] Cada requisito é testável — é possível escrever um teste que verifica seu cumprimento

### 6. Apresentação e aprovação

Apresentar os requisitos no formato abaixo e aguardar aprovação explícita.
Incorporar feedback e iterar até aprovação. Não avançar sem aprovação.

---

## Formato de saída

```
## Requisitos EARS — <título da feature>

**Contexto:** <qual sistema, qual problema, premissas assumidas>

**Ubíquos:**
- O sistema SHALL <resposta>

**Orientados a evento:**
- WHEN <trigger>, o sistema SHALL <resposta>

**Orientados a estado:**
- WHILE <estado>, o sistema SHALL <resposta>

**Comportamentos indesejados:**
- IF <trigger>, THEN o sistema SHALL <resposta>

**Features opcionais:**
- WHERE <feature>, o sistema SHALL <resposta>
```

Omitir seções que não se aplicam ao problema.

---

## Após aprovação

Editar `TASKS.md` imediatamente — não confirmar ao usuário sem ter escrito no arquivo.

1. Se não houver tarefa correspondente, criar uma no formato adequado (feature ou incidente)
2. Editar a seção `**Requisitos EARS:**` da tarefa com os requisitos aprovados
3. Confirmar apenas após a edição: "Requisitos escritos em T<N>. Próximo passo: `/spec` ou `/tdd`"
