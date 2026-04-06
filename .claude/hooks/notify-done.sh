#!/bin/bash
# Stop — notificação macOS quando Claude termina uma tarefa.
# Silencioso em ambientes sem osascript (CI/Linux).

if command -v osascript &>/dev/null; then
    osascript -e 'display notification "Tarefa concluída" with title "Claude Code" sound name "Glass"' 2>/dev/null
fi

exit 0
