---
description: Generates structured acceptance criteria (Given/When/Then) and writes them directly into TASKS.md. Derives from EARS requirements when available.
allowed-tools: Read, Grep, Glob, Edit
---
# Spec: $ARGUMENTS

Feature or behavior: **$ARGUMENTS**

Se existirem **Requisitos EARS** aprovados para esta feature (na seção `**Requisitos EARS:**` do TASKS.md),
usar os requisitos como base para derivar os cenários — cada requisito EARS origina um ou mais cenários,
mantendo rastreabilidade explícita entre requisito e cenário.

Se não existirem requisitos EARS, gerar os cenários a partir de `$ARGUMENTS` e recomendar `/requirements`
antes da próxima feature.

1. Read relevant existing code to understand the domain and constraints

2. For each meaningful scenario, write:

**Cenário: <nome descritivo>**
- Dado: <pré-condições — estado do sistema, dados existentes, contexto>
- Quando: <ação — chamada de função, requisição, evento>
- Então: <resultado esperado — resposta, mudança de estado, erro lançado>

Cover:
- Caminho feliz (pelo menos 1)
- Input vazio ou nulo
- Valores de fronteira (mínimo, máximo, um além do limite)
- Input inválido e casos de erro
- Edge cases de autorização ou permissão (se aplicável)

3. For each "Então", derive the test method name:
   `test<Cenário>_<Condição>` — e.g., `testGetItems_WithEmptyIds`

4. Editar `TASKS.md` diretamente — escrever na seção `**Critério de aceitação:**` da tarefa correspondente. Não apresentar output ao usuário sem ter escrito no arquivo.

Each "Então" must map to exactly one `assert` — if a "Então" needs two asserts, split it into two cenários.
