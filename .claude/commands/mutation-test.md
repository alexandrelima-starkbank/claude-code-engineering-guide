---
description: Runs mutation testing on a file or module and diagnoses every surviving mutant
allowed-tools: Bash, Read
---
# Mutation Test: $ARGUMENTS

Target: **$ARGUMENTS**

1. Confirm mutmut is installed:
   ```bash
   mutmut --version
   ```
   If missing: `pip install mutmut`

2. Run mutations against the target:
   ```bash
   mutmut run --paths-to-mutate "$ARGUMENTS"
   ```

3. Get the summary:
   ```bash
   mutmut results
   ```

4. For each surviving mutant, run:
   ```bash
   mutmut show <id>
   ```
   Classify and diagnose:

   **Gap de teste** — o mutante sobreviveu porque nenhuma assertion cobre aquele comportamento:
   - Qual assertion está faltando
   - Qual cenário do spec não está coberto
   - Sugestão exata do assert a adicionar

   **Mutante equivalente** — a mutação produz código semanticamente idêntico ao original:
   - Explicar por que o comportamento é idêntico
   - Marcar no código com `# pragma: no mutate — <justificativa>`

5. Output format:
   ```
   Score: N killed / M total (X%)

   SURVIVING MUTANTS:

   #<id> <file>:<line>
   Mutation: <o que foi alterado>
   Sobreviveu porque: <qual assertion está faltando>
   Fix: <assert exato a adicionar>

   #<id> <file>:<line> [EQUIVALENTE]
   Mutation: <o que foi alterado>
   Equivalente porque: <razão>
   Ação: adicionar # pragma: no mutate
   ```

Target: **100%** de mutantes não-equivalentes mortos.
Score abaixo de 100% significa gaps de teste que devem ser corrigidos antes de concluir a tarefa.
