#!/bin/bash
# SessionStart — marca que um check de update deve ocorrer na próxima mensagem.
touch "${HOME}/.claude/pipeline/.check-update-pending" 2>/dev/null
