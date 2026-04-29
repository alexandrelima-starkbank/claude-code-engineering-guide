#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

if [[ "$FILE_PATH" != *.py ]]; then
    exit 0
fi

SORT_SCRIPT=""
if [ -f "$HOME/.config/sortImports.py" ]; then
    SORT_SCRIPT="$HOME/.config/sortImports.py"
elif [ -f ".claude/hooks/sortImports.py" ]; then
    SORT_SCRIPT=".claude/hooks/sortImports.py"
fi

if [ -z "$SORT_SCRIPT" ]; then
    exit 0
fi

python3 "$SORT_SCRIPT" "$FILE_PATH" 2>/dev/null
exit 0
