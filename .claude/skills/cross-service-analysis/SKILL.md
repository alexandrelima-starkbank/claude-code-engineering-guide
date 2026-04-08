---
name: cross-service-analysis
description: >
  Analyze cross-service impact of a change across platform microservices.
  Use when modifying fields, enums, queue messages, API contracts, or any
  code shared across service boundaries. Also use when planning deployment
  order for multi-service changes.
---

# Cross-Service Impact Analysis

## Before you start

Read [SERVICE_MAP.md](SERVICE_MAP.md) to understand:
- The list of services and what each does
- The dependency graph and authorization pipeline
- Shared contracts (enums, queue messages, API schemas)
- Deployment rules for your platform

**To check if SERVICE_MAP is configured:** look at the `## Diretórios dos Serviços` section. If it still contains `<diretório-do-service-` placeholder paths, the file is not configured.

**If SERVICE_MAP.md is not configured:**
- Do NOT stop. Degrade gracefully.
- Restrict the analysis to the current repository only.
- In the output, add a note: `SERVICE_MAP not configured — analysis limited to current repository. Run ./configure.sh to enable cross-service analysis.`
- Omit the DEPLOYMENT ORDER section (no cross-service deploy reasoning is possible without the map).

---

## Analysis Protocol

### 1. Identify the change target

Determine what is being changed:
- Field addition, rename, or removal in a model
- Enum value addition or modification
- Queue message schema (async payload shape)
- API contract between services (request/response)
- Shared utility function signature
- Authorization or validation logic

### 2. Search all services

Use Grep across all service directories listed in SERVICE_MAP.md.

For each service, search in order:
- `models/` — field definitions, entity schemas
- `gateways/` — data access, queries, saves, factory methods
- `handlers/` — API endpoints, workers, queue consumers
- `middlewares/` — validation, auth, decorators
- `utils/` — shared helpers
- `tests/` — assertions, fixtures, mocked values

### 3. Classify each reference

For every hit, determine:
- **Usage type:** reads, writes, filters, validates, passes through
- **Criticality:** is this in the authorization path? financial mutation? billing cycle?
- **Break risk:** what happens if this service is NOT updated before deploy?

### 4. Determine deployment sequence

**Skip this step if SERVICE_MAP is not configured** (single-repo mode). Omit the DEPLOYMENT ORDER block from the output entirely.

Apply the rules from `## Regras de Deploy` in SERVICE_MAP.md. Default rules:
- Consumers of a new field deploy **before** the producer starts sending it
- If removing a field: producer stops sending **before** consumers stop expecting it
- Enum additions: all consumers must handle the new value before producer sends it
- Highest-risk services (ledger, financial) always deploy last and with coordination

### 5. Present findings

```
TARGET: <what is being changed>
RISK: LOW | MEDIUM | HIGH | CRITICAL

AFFECTED SERVICES:
  <service>
    Files: <list of files>
    Usage: <how it uses the target>
    Break risk: <what happens without update>

DEPLOYMENT ORDER:          ← omit if single-repo mode
  1. <service> — <reason>
  2. <service> — <reason>

BACKWARD COMPATIBILITY:
  <is the change backward-compatible? can it be made so?>

TESTS TO UPDATE:
  <list test files that need updates>
```

---

## When NOT to use this skill

- Changes fully isolated to one service with no shared contracts
- Pure formatting or internal refactoring with no interface changes
- Test-only changes that don't modify behavior
