#!/bin/bash
# SessionStart — sinaliza que o check de atualização deve ocorrer na próxima mensagem.
touch "${HOME}/.claude/pipeline/.check-update-pending" 2>/dev/null
