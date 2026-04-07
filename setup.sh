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
echo "── Dependências obrigatórias ──────────────────────────────────────────────"

# ─── git ──────────────────────────────────────────────────────────────────────
# Usado em: inject-git-context.sh
if command -v git &>/dev/null; then
    ok "git $(git --version | awk '{print $3}')"
else
    fail "git não encontrado — instale em https://git-scm.com"
fi

# ─── python3 ──────────────────────────────────────────────────────────────────
# Necessário para executar código Python, testes e o linter de convenções (python_style_check.py)
# Versão mínima: 3.8 (ast.arg.posonlyargs introduzido no 3.8)
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version | awk '{print $2}')
    PY_MINOR=$(echo "$PY_VERSION" | awk -F. '{print $2}')
    PY_MAJOR=$(echo "$PY_VERSION" | awk -F. '{print $1}')
    if [ "$PY_MAJOR" -gt 3 ] || ([ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -ge 8 ]); then
        ok "python3 ${PY_VERSION}"
    else
        fail "python3 ${PY_VERSION} — versão mínima requerida: 3.8"
        warn "  → brew upgrade python3   (macOS)"
    fi
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
# Usado em: todos os hooks (parse de JSON via stdin/stdout)
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
        fi
    fi
fi

echo ""
echo "── Ferramentas de qualidade (opcionais — hooks degradam silenciosamente) ──"

# ─── shellcheck ───────────────────────────────────────────────────────────────
# Usado em: check-bash-syntax.sh (análise de qualidade de scripts shell)
if command -v shellcheck &>/dev/null; then
    ok "shellcheck $(shellcheck --version | awk '/version:/{print $2}')"
else
    warn "shellcheck não encontrado — análise de qualidade shell desabilitada"
    INSTALLED=0
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
        brew install shellcheck && INSTALLED=1
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y shellcheck && INSTALLED=1
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y shellcheck && INSTALLED=1
    fi
    if [ "$INSTALLED" -eq 1 ] && command -v shellcheck &>/dev/null; then
        ok "shellcheck instalado"
    else
        warn "  → brew install shellcheck  (macOS)"
        warn "  → sudo apt install shellcheck  (Debian/Ubuntu)"
    fi
fi

# ─── ruff ─────────────────────────────────────────────────────────────────────
# Linter Python — configurado em pyproject.toml (ignora regras de nomenclatura)
if command -v ruff &>/dev/null; then
    ok "ruff $(ruff --version)"
else
    warn "ruff não encontrado — linting Python desabilitado"
    if command -v pip3 &>/dev/null; then
        pip3 install ruff --quiet 2>/dev/null || pip3 install ruff --quiet --user 2>/dev/null && ok "ruff instalado" || warn "  → pip3 install ruff --user"
    elif [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
        warn "  → brew install ruff   ou   pip3 install ruff"
    fi
fi

# ─── mutmut ───────────────────────────────────────────────────────────────────
# Mutation testing — usado em /mutation-test e /tdd (gate de qualidade)
if command -v mutmut &>/dev/null; then
    ok "mutmut $(mutmut --version 2>/dev/null | head -1)"
else
    warn "mutmut não encontrado — mutation testing desabilitado"
    if command -v pip3 &>/dev/null; then
        pip3 install mutmut --quiet 2>/dev/null || pip3 install mutmut --quiet --user 2>/dev/null && ok "mutmut instalado" || warn "  → pip3 install mutmut --user"
    else
        warn "  → pip3 install mutmut"
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
echo "── Permissões ──────────────────────────────────────────────────────────────"
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
