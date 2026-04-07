---
description: Investigate a bug or unexpected behavior across platform services
allowed-tools: Read, Grep, Glob, Bash
---
# Investigate: $ARGUMENTS

1. Restate the problem — expected behavior vs. actual behavior

2. Read `.claude/skills/cross-service-analysis/SERVICE_MAP.md` to understand the service dependency graph and the data flow path relevant to this bug

3. Grep across all service directories for code paths related to the problem:
   - Entry point (API handler, queue consumer, cron)
   - Data flow through services following the pipeline in SERVICE_MAP.md
   - Models, gateways, and utils involved

4. Find and read existing tests covering the affected paths

5. Present findings:
   - What is happening and why
   - Which files are involved in each service
   - Cross-service impact (does fixing this require coordinated changes?)
   - Suggested fix — describe the change, do NOT implement it
