---
description: Security-focused review of changed files — injection, auth, secrets, input validation
allowed-tools: Read, Grep, Glob, Bash
---
# Security Review: $ARGUMENTS

1. Run `git diff main --name-only` (or use $ARGUMENTS as branch/path) to get changed files
2. For each file, check:
   - SQL/command/path injection
   - XSS and output encoding
   - Authentication and authorization gaps
   - Exposed secrets or credentials in code
   - Insecure deserialization
   - Missing input validation at system boundaries
   - Unsafe use of `shell=True`, `eval`, `exec`, or similar
3. Report each finding with: file:line | severity (HIGH/MEDIUM/LOW) | issue | suggested fix

Focus only on security. Skip style and logic issues — that's for /review.
