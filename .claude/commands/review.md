---
description: Review recent changes for correctness, security, and test coverage
allowed-tools: Read, Grep, Glob, Bash
---
# Review: $ARGUMENTS

1. Run `git diff` (or `git diff $ARGUMENTS` if a branch/commit was given) to identify changes
2. For each changed file: read it and review for correctness, security, and edge cases
3. Check test coverage: are the changes covered? Run the suite and flag missing tests
4. Report findings as: MUST FIX | SHOULD FIX | NITPICK — with file:line, issue, fix
