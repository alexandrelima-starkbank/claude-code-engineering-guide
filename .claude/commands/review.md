---
description: Review recent changes for correctness, security, and test coverage
allowed-tools: Read, Grep, Glob, Bash
---
# Review: $ARGUMENTS

1. Run `git diff` (or `git diff $ARGUMENTS` if a branch/commit was given) to identify changes

2. For each changed file: read it and review for correctness, security, and edge cases

3. Check test coverage:
   - Look for a `tests/` directory or `*Test.py` / `*.test.*` files
   - If a test suite exists, run it and flag missing coverage for the changed code
   - If no test suite exists, note which changes would benefit from tests

4. Report findings as: `MUST FIX | SHOULD FIX | NITPICK` — with `file:line`, issue, and fix
