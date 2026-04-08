---
description: Analyze the cross-service impact of changing a field, enum, function, or contract
allowed-tools: Read, Grep, Glob
---
# Blast Radius: $ARGUMENTS

1. Read `.claude/skills/cross-service-analysis/SERVICE_MAP.md`.
   - The file is **not configured** if it does not exist or if the `## Diretórios dos Serviços` section still contains `<diretório-do-service-` placeholder paths.
   - If not configured: restrict the search to the current repository only and note in the output: `SERVICE_MAP not configured — analysis limited to current repository. Run ./configure.sh to enable cross-service analysis.`
   - If configured: use the service directories listed under `## Diretórios dos Serviços`.

2. Identify what is being changed: field, enum, queue message schema, API contract, or function signature

3. Grep ALL service directories for every reference to the target

4. For each hit, classify:
   - How it's used (reads, writes, validates, passes through)
   - What breaks if this service is NOT updated
   - Whether it's in a critical path (auth, financial mutation, billing)

5. If SERVICE_MAP is configured: determine safe deployment order using the rules in `## Regras de Deploy`.
   If not configured (single-repo mode): skip this step and omit DEPLOY ORDER from the output.

6. Output:
   ```
   TARGET: <what changes>
   RISK: LOW | MEDIUM | HIGH | CRITICAL

   AFFECTED: <service> — <files> — <break risk>

   DEPLOY ORDER:          ← omit if single-repo mode
     1. <service> — <reason>
     2. <service> — <reason>
   ```
