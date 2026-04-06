#!/bin/bash
# setup.sh — configura o ambiente Claude Code para este projeto.
# Verifica dependências, instala o que falta (macOS/Linux) e torna hooks executáveis.
# Idempotente: pode rodar múltiplas vezes sem efeitos colaterais.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[ok]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[erro]${NC} $1"; FAILED=1; }

FAILED=0

echo "Configurando ambiente Claude Code..."
echo ""

# ─── git ──────────────────────────────────────────────────────────────────────
# Usado em: inject-git-context.sh
if command -v git &>/dev/null; then
    ok "git $(git --version | awk '{print $3}')"
else
    fail "git não encontrado — instale em https://git-scm.com"
fi

# ─── python3 ──────────────────────────────────────────────────────────────────
# Necessário para executar código Python e testes neste projeto
if command -v python3 &>/dev/null; then
    ok "python3 $(python3 --version | awk '{print $2}')"
else
    fail "python3 não encontrado"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        warn "  → brew install python3"
    else
        warn "  → sudo apt install python3   (Debian/Ubuntu)"
        warn "  → sudo dnf install python3   (Fedora/RHEL)"
    fi
fi

# ─── jq ───────────────────────────────────────────────────────────────────────
# Usado em: inject-git-context.sh (constrói JSON de saída do hook SessionStart)
#           check-bash-syntax.sh (parse do file_path via stdin)
if command -v jq &>/dev/null; then
    ok "jq $(jq --version)"
else
    warn "jq não encontrado — tentando instalar..."
    INSTALLED=0
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
        brew install jq && INSTALLED=1
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y jq && INSTALLED=1
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y jq && INSTALLED=1
    fi

    if [ "$INSTALLED" -eq 1 ] && command -v jq &>/dev/null; then
        ok "jq instalado ($(jq --version))"
    else
        fail "jq não encontrado e instalação automática falhou"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            warn "  → brew install jq   (requer Homebrew: https://brew.sh)"
        else
            warn "  → sudo apt install jq   (Debian/Ubuntu)"
            warn "  → sudo dnf install jq   (Fedora/RHEL)"
            warn "  → https://jqlang.github.io/jq/download/"
        fi
    fi
fi

# ─── osascript ────────────────────────────────────────────────────────────────
# Usado em: notify-done.sh (notificação macOS ao terminar tarefa)
# Opcional — o hook degrada silenciosamente se ausente.
if command -v osascript &>/dev/null; then
    ok "osascript (notificações macOS habilitadas)"
else
    ok "osascript não disponível — notificações desabilitadas (normal em Linux/CI)"
fi

# ─── hooks executáveis ────────────────────────────────────────────────────────
echo ""
echo "Tornando hooks executáveis..."
if chmod +x .claude/hooks/*.sh 2>/dev/null; then
    ok "permissões aplicadas em .claude/hooks/"
else
    fail "não foi possível aplicar permissões em .claude/hooks/ — rode a partir da raiz do projeto"
fi

# ─── resultado ────────────────────────────────────────────────────────────────
echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}Ambiente pronto.${NC} Abra o Claude Code na raiz do projeto:"
    echo "  claude"
else
    echo -e "${RED}Setup incompleto.${NC} Corrija os erros acima e rode novamente."
    exit 1
fi
