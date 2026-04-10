---
description: Investigate a bug or unexpected behavior across platform services
allowed-tools: Read, Grep, Glob, Bash
---
# Investigate: $ARGUMENTS

1. Restate the problem — expected behavior vs. actual behavior

2. Buscar candidatos no índice semântico antes de ler arquivos:

   ```bash
   pipeline search "<termos-chave do problema>" --n 10
   ```

   Use os resultados para orientar os passos seguintes — priorize os arquivos
   retornados pelo índice antes de fazer grep amplo.

3. Read `.claude/skills/cross-service-analysis/SERVICE_MAP.md`.
   - The file is **not configured** if it does not exist or if the `## Diretórios dos Serviços` section still contains `<diretório-do-service-` placeholder paths.
   - If not configured: restrict the investigation to the current repository and note in the output: `SERVICE_MAP not configured — investigation limited to current repository. Run ./configure.sh to enable cross-service tracing.`
   - If configured: use the dependency graph and pipeline in `## Pipeline de Autorização` to trace the data flow.

4. Grep across all service directories for code paths related to the problem:
   - Entry point (API handler, queue consumer, cron)
   - Data flow through services following the pipeline in SERVICE_MAP.md
   - Models, gateways, and utils involved

5. Find and read existing tests covering the affected paths

6. Present findings:
   - What is happening and why
   - Which files are involved in each service
   - Cross-service impact (does fixing this require coordinated changes?)
   - Suggested fix — describe the change, do NOT implement it
