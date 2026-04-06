---
description: Generates structured acceptance criteria (Given/When/Then) for a feature or task, ready to paste into TASKS.md
allowed-tools: Read, Grep, Glob
---
# Spec: $ARGUMENTS

Feature or behavior: **$ARGUMENTS**

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

4. Output as markdown, structured and ready to paste into TASKS.md as **Critério de aceitação**

Each "Então" must map to exactly one `assert` — if a "Então" needs two asserts, split it into two cenários.
