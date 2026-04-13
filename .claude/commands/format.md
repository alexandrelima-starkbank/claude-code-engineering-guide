---
description: Format Python files — sortImports + ruff check --fix. Usage: /format [outputType=names|json|report] [name=file1,file2,file3]
allowed-tools: Bash
---
# Format: $ARGUMENTS

## Parse arguments

Parse `$ARGUMENTS` for named parameters (any order, all optional):

- `outputType=<value>` — output format: `names`, `json`, or `report`. Default: `names`
- `name=<value>` — comma-separated list of file paths to format

## Collect files

If `name` was provided, use those files. Otherwise, find all `.py` files recursively from the current working directory:

```bash
find . -name "*.py" -not -path "*/__pycache__/*"
```

## Format each file

For each file:

1. Capture the file content before formatting
2. Run `python3 ~/.config/sortImports.py <file>`
3. Run `ruff check --fix <file> --quiet`
4. Capture content after formatting
5. Mark the file as **changed** if content differs, otherwise **unchanged**

## Produce output

**`names`** — print one path per line for each changed file (empty output if nothing changed)

**`json`** — print a single JSON object:
```json
{"changed": ["path/to/file.py"], "unchanged": ["path/to/other.py"]}
```

**`report`** — for each changed file, show:
- File path as header
- Unified diff of the import block (lines 1 through the first non-import line)
- Summary line: `N file(s) changed, M unchanged`
