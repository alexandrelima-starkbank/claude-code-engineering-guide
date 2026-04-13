# Arquitetura do Ambiente

Diagramas visuais do ambiente Claude Code Engineering.

---

## 1. Visão Geral

```mermaid
graph TB
    subgraph Engenheiro
        NL[Linguagem natural]
    end

    subgraph Claude Code
        CC[Claude Code CLI]
        CLAUDE_MD[CLAUDE.md]
        HOOKS[Hooks .claude/hooks/]
        AGENTS[Agentes .claude/agents/]
        COMMANDS[Commands .claude/commands/]
        SKILLS[Skills .claude/skills/]
    end

    subgraph Pipeline CLI
        CLI[pipeline CLI]
        DB[(SQLite pipeline.db)]
        CHROMA[(ChromaDB opcional)]
        TASKS_MD[TASKS.md view gerada]
    end

    subgraph Ferramentas
        PYTEST[pytest + json-report]
        MUTMUT[mutmut]
        RUFF[ruff]
        SHELLCHECK[shellcheck]
    end

    NL --> CC
    CC --> CLAUDE_MD
    CC --> HOOKS
    CC --> AGENTS
    CC --> COMMANDS
    CC --> SKILLS

    HOOKS -->|auto-registra| CLI
    SKILLS -->|orquestra| CLI
    COMMANDS -->|invoca| CLI
    CLI --> DB
    CLI --> CHROMA
    CLI -->|regenera| TASKS_MD

    HOOKS -->|dispara| PYTEST
    HOOKS -->|dispara| MUTMUT
    HOOKS -->|valida| RUFF
    HOOKS -->|valida| SHELLCHECK
```

---

## 2. Hook Lifecycle

```mermaid
flowchart LR
    subgraph SessionStart
        H1[inject-git-context]
        H2[mark-session-start]
    end

    subgraph UserPromptSubmit
        H3[check-for-update]
        H4[enforce-intake-protocol]
        H5[inject-tasks-context]
        H6[validate-requirements]
    end

    subgraph "PreToolUse (Bash)"
        H7[validate-destructive]
        H8[pre-commit-gate]
    end

    subgraph "PostToolUse (Edit/Write)"
        H9[check-bash-syntax]
        H10[check-python-style]
    end

    subgraph "PostToolUse (Bash)"
        H11[record-test-results]
        H12[record-mutation-results]
    end

    subgraph Stop
        H13[notify-done]
    end

    START((Sessão)) --> SessionStart
    SessionStart --> PROMPT((Prompt))
    PROMPT --> UserPromptSubmit
    UserPromptSubmit --> TOOL((Tool))
    TOOL -->|Bash| H7
    TOOL -->|Edit/Write| H9
    H7 --> EXEC((Execução))
    H9 --> EXEC
    EXEC -->|Bash| H11
    EXEC -->|Edit/Write| H10
    H11 --> FIM((Stop))
    FIM --> Stop

    style H4 fill:#f96,stroke:#333
    style H7 fill:#f96,stroke:#333
    style H8 fill:#f96,stroke:#333
```

> Hooks em laranja podem **bloquear** a operação (exit 2).

---

## 3. Pipeline EBTM

```mermaid
flowchart LR
    REQ[requirements]
    SPEC[spec]
    TESTS[tests]
    IMPL[implementation]
    MUT[mutation]
    DONE[done]

    REQ -->|"EARS aprovados"| SPEC
    SPEC -->|"critérios aprovados\ntestMethods mapeados"| TESTS
    TESTS -->|"qualidade ACCEPTABLE+\ntestes executados"| IMPL
    IMPL -->|"todos os testes passando"| MUT
    MUT -->|"score = 100%"| DONE

    REQ -.->|"👤 Engenheiro aprova"| SPEC
    SPEC -.->|"👤 Engenheiro aprova"| TESTS
    MUT -.->|"👤 Decide equivalentes"| DONE
```

### Papéis por fase

```mermaid
graph LR
    subgraph "👤 Engenheiro"
        E1[Descreve em linguagem natural]
        E2[Aprova EARS]
        E3[Aprova spec BDD]
        E4[Decide mutantes equivalentes]
    end

    subgraph "🤖 Modelo"
        M1[Classifica intent]
        M2[Entrevista]
        M3[Escreve EARS no DB]
        M4[Gera cenários BDD]
        M5[Escreve testes]
        M6[Implementa código]
        M7[Avança fases]
    end

    subgraph "⚙️ Ambiente"
        A1[Auto-registra pytest]
        A2[Auto-registra mutmut]
        A3[Regenera TASKS.md]
        A4[Bloqueia commit se testes falham]
    end

    E1 --> M1
    M1 --> M2
    M2 --> M3
    M3 --> E2
    E2 --> M4
    M4 --> E3
    E3 --> M5
    M5 --> A1
    M6 --> A1
    A1 --> A4
    M6 --> A2
    A2 --> E4
    M7 --> A3
```

---

## 4. Fluxo de Feature (/feature)

```mermaid
sequenceDiagram
    participant E as 👤 Engenheiro
    participant C as 🤖 Claude
    participant DB as 📦 Pipeline DB
    participant T as ⚙️ Testes

    E->>C: "preciso de um endpoint de criação de item"

    Note over C: Fase 0 — Requirements
    C->>E: Perguntas de esclarecimento
    E->>C: Respostas
    C->>DB: pipeline ears add T1 --pattern event --text "..."
    C->>E: EARS para aprovação
    E->>C: ✓ Aprovado
    C->>DB: pipeline ears approve T1 all
    C->>DB: pipeline phase advance T1 --to spec

    Note over C: Fase 1 — Spec
    C->>DB: pipeline criterion add T1 --ears R01 --scenario "..."
    C->>E: Cenários BDD para aprovação
    E->>C: ✓ Aprovado
    C->>DB: pipeline criterion approve T1 all
    C->>DB: pipeline phase advance T1 --to tests

    Note over C: Fase 2 — Tests
    C->>T: Escreve testes (devem falhar)
    T-->>DB: Hook auto-registra resultados
    C->>DB: pipeline phase advance T1 --to implementation

    Note over C: Fase 3 — Implementation
    C->>T: Implementa código mínimo
    T-->>DB: Hook auto-registra (todos passam)
    C->>DB: pipeline phase advance T1 --to mutation

    Note over C: Fase 4 — Mutation
    C->>T: mutmut run
    T-->>DB: Hook auto-registra score
    C->>E: Score 100% — 8/8 mutantes mortos
    C->>DB: pipeline phase advance T1 --to done

    Note over C: Checklist
    C->>C: /verify-delivery
    C->>E: ✓ READY
```

---

## 5. Fluxo de Incidente (/support → /bugfix)

```mermaid
flowchart TB
    subgraph "/support — N3"
        I1[Intake estruturado]
        I2[Investigação cross-service]
        I3{Root cause encontrado?}
        I4[Resolução N3\nworkaround/rollback]
        I5[Escalação N4\ngera EARS do bug]
    end

    subgraph "/bugfix — N4"
        B1[Teste de regressão\ndeve falhar]
        B2[EARS do fix]
        B3[Spec BDD]
        B4[Implementação\nteste passa]
        B5[Mutation 100%]
        B6[Blast radius]
        B7[Checklist]
    end

    INCIDENT((Incidente\nprodução)) --> I1
    I1 -->|"support-investigator\nagent"| I2
    I2 --> I3
    I3 -->|"Sim — fix N3\ndisponível"| I4
    I3 -->|"Não — requer\ncódigo"| I5
    I5 --> B1
    B1 --> B2
    B2 --> B3
    B3 --> B4
    B4 --> B5
    B5 --> B6
    B6 --> B7

    style I3 fill:#ff9,stroke:#333
    style I4 fill:#9f9,stroke:#333
    style I5 fill:#f96,stroke:#333
```

---

## 6. Banco de Dados

```mermaid
erDiagram
    projects ||--o{ tasks : contains
    tasks ||--o{ earsRequirements : has
    tasks ||--o{ acceptanceCriteria : has
    tasks ||--o{ testResults : records
    tasks ||--o{ mutationResults : records
    tasks ||--o{ phaseTransitions : tracks
    tasks ||--o| incidents : may_have
    earsRequirements ||--o{ acceptanceCriteria : traces_to

    projects {
        text id PK
        text name
        text path
    }

    tasks {
        text id PK
        text projectId FK
        text title
        text type
        text status
        text phase
    }

    earsRequirements {
        text id PK
        text taskId FK
        text pattern
        text text
        int approved
    }

    acceptanceCriteria {
        text id PK
        text taskId FK
        text earsId FK
        text scenarioName
        text thenText
        text testMethod
        text testQuality
    }

    testResults {
        int id PK
        text taskId FK
        text testMethod
        int passed
    }

    mutationResults {
        int id PK
        text taskId FK
        int totalMutants
        int killed
        real score
    }
```
