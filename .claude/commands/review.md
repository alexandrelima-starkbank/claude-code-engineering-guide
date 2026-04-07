---
description: Review recent changes for correctness, security, test coverage, and project conventions
allowed-tools: Read, Grep, Glob, Bash
---
# Review: $ARGUMENTS

1. Run `git diff` (or `git diff $ARGUMENTS` if a branch/commit was given) to identify changes.

2. For each changed file, review for:
   - **Correctness** — does the code do what it intends? Edge cases handled?
   - **Security** — injection, auth flaws, exposed secrets, unsafe input handling
   - **Project conventions** — camelCase, no else blocks, .format() over f-strings,
     no type hints, no docstrings, trailing commas in multiline calls, 4-space indent,
     import order (stdlib → external → local, separated by blank lines)

3. Check test coverage:
   - Look for `tests/` or `*Test.py` files
   - If a test suite exists, run it and flag missing coverage for changed code
   - If no test suite exists, note which changes would benefit from tests

4. Report findings as `MUST FIX | SHOULD FIX | NITPICK` — with `file:line`, issue, and fix.
