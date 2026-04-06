---
description: Security-focused review of changed files — injection, auth, secrets, input validation
allowed-tools: Read, Grep, Glob, Bash
---
# Security Review: $ARGUMENTS

1. Identify the target branch or path:
   - If $ARGUMENTS is provided, use it as branch or path filter
   - Otherwise, detect the default branch and diff against it:
     ```bash
     DEFAULT=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's/origin\///' || echo "main")
     git diff "$DEFAULT" --name-only
     ```

2. For each changed file, check:
   - SQL/command/path injection
   - XSS and output encoding
   - Authentication and authorization gaps
   - Exposed secrets or credentials in code
   - Insecure deserialization
   - Missing input validation at system boundaries
   - Unsafe use of `shell=True`, `eval`, `exec`, or similar

3. Report each finding with: `file:line | HIGH/MEDIUM/LOW | issue | suggested fix`

Focus only on security. Skip style and logic issues — that's for /review.
