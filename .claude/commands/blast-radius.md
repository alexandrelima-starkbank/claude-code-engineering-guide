---
description: Analyze the cross-service impact of changing a field, enum, function, or contract
allowed-tools: Read, Grep, Glob
---
# Blast Radius: $ARGUMENTS

1. Read `.claude/skills/cross-service-analysis/SERVICE_MAP.md` to get the list of services and their directories

2. Identify what is being changed: field, enum, queue message schema, API contract, or function signature

3. Grep ALL service directories for every reference to the target

4. For each hit, classify:
   - How it's used (reads, writes, validates, passes through)
   - What breaks if this service is NOT updated
   - Whether it's in a critical path (auth, financial mutation, billing)

5. Determine safe deployment order using the rules in SERVICE_MAP.md

6. Output:
   ```
   TARGET: <what changes>
   RISK: LOW | MEDIUM | HIGH | CRITICAL

   AFFECTED: <service> — <files> — <break risk>

   DEPLOY ORDER:
     1. <service> — <reason>
     2. <service> — <reason>
   ```
