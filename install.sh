#!/bin/bash
# install.sh — instala o ecossistema Claude Code em qualquer diretório.
# Não cria nem altera o versionamento do diretório de destino.
#
# Uso direto (sem clonar o repositório):
#   bash <(curl -fsSL https://raw.githubusercontent.com/alexandrelima-starkbank/claude-code-engineering-guide/main/install.sh)
#
# Uso com destino explícito:
#   bash install.sh /caminho/destino

REPO_URL="https://github.com/alexandrelima-starkbank/claude-code-engineering-guide.git"
CACHE_DIR="${HOME}/.cache/claude-code-guide"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[ok]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[erro]${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}Instalação do ecossistema Claude Code${NC}"
echo "────────────────────────────────────────"
echo ""

# ─── 1. git ───────────────────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
    warn "git não encontrado — tentando instalar..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        xcode-select --install 2>/dev/null
        command -v git &>/dev/null || fail "git não encontrado após instalação. Instale manualmente: https://git-scm.com"
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y git || fail "Falha ao instalar git"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y git || fail "Falha ao instalar git"
    else
        fail "git não encontrado. Instale em https://git-scm.com e rode novamente."
    fi
fi
ok "git $(git --version | awk '{print $3}')"

# ─── 2. Template (clona ou atualiza no cache) ─────────────────────────────────
echo ""
if [ -d "${CACHE_DIR}/.git" ]; then
    echo "Atualizando template..."
    git -C "$CACHE_DIR" pull --quiet origin main || warn "Falha ao atualizar — usando versão em cache"
    ok "template: $(git -C "$CACHE_DIR" rev-parse --short HEAD)"
else
    echo "Baixando template..."
    git clone --quiet --depth 1 "$REPO_URL" "$CACHE_DIR" \
        || fail "Falha ao clonar repositório. Verifique sua conexão e tente novamente."
    ok "template baixado"
fi

# ─── 3. Copia arquivos para o destino ─────────────────────────────────────────
TARGET="${1:-$(pwd)}"
echo ""
echo "Destino: ${TARGET}"
echo ""

# Preserva settings.local.json se já existir
SETTINGS_LOCAL="${TARGET}/.claude/settings.local.json"
SETTINGS_BACKUP=""
if [ -f "$SETTINGS_LOCAL" ]; then
    SETTINGS_BACKUP=$(mktemp)
    cp "$SETTINGS_LOCAL" "$SETTINGS_BACKUP"
fi

# Copia .claude/ e scripts
cp -r "${CACHE_DIR}/.claude" "${TARGET}/"
cp "${CACHE_DIR}/setup.sh" "${TARGET}/setup.sh"
cp "${CACHE_DIR}/configure.sh" "${TARGET}/configure.sh"
cp "${CACHE_DIR}/mutmut.toml" "${TARGET}/mutmut.toml"
chmod +x "${TARGET}/configure.sh" "${TARGET}/setup.sh"

# Restaura settings.local.json se havia backup
if [ -n "$SETTINGS_BACKUP" ]; then
    cp "$SETTINGS_BACKUP" "$SETTINGS_LOCAL"
    rm -f "$SETTINGS_BACKUP"
    ok ".claude/settings.local.json preservado"
fi

# pyproject.toml — não sobrescreve se já existir (pode ter config do projeto)
if [ ! -f "${TARGET}/pyproject.toml" ]; then
    cp "${CACHE_DIR}/pyproject.toml" "${TARGET}/pyproject.toml"
    ok "pyproject.toml copiado"
else
    warn "pyproject.toml já existe — não sobrescrito"
fi

# CLAUDE.md — não sobrescreve (pode ter config específica do projeto)
if [ ! -f "${TARGET}/CLAUDE.md" ]; then
    cp "${CACHE_DIR}/CLAUDE.install.md" "${TARGET}/CLAUDE.md"
    ok "CLAUDE.md criado"
else
    warn "CLAUDE.md já existe — não sobrescrito"
fi

# TASKS.md — não sobrescreve (pode ter tarefas ativas)
if [ ! -f "${TARGET}/TASKS.md" ]; then
    cp "${CACHE_DIR}/TASKS.md" "${TARGET}/TASKS.md"
    ok "TASKS.md criado"
else
    ok "TASKS.md já existe"
fi

# HISTORY_TASKS.md — cria vazio se não existir
if [ ! -f "${TARGET}/HISTORY_TASKS.md" ]; then
    printf '# HISTORY_TASKS.md — Histórico de Tarefas Concluídas\n\nRegistro permanente de todas as tarefas concluídas.\n' \
        > "${TARGET}/HISTORY_TASKS.md"
    ok "HISTORY_TASKS.md criado"
fi

# .gitignore — adiciona entradas para arquivos locais
GITIGNORE="${TARGET}/.gitignore"
{
    grep -q '.claude/settings.local.json' "$GITIGNORE" 2>/dev/null || echo ".claude/settings.local.json"
    grep -q 'TASKS.md' "$GITIGNORE" 2>/dev/null || echo "TASKS.md"
    grep -q 'HISTORY_TASKS.md' "$GITIGNORE" 2>/dev/null || echo "HISTORY_TASKS.md"
    grep -q 'CLAUDE.local.md' "$GITIGNORE" 2>/dev/null || echo "CLAUDE.local.md"
} >> "$GITIGNORE"
ok ".gitignore atualizado"

ok "arquivos instalados em ${TARGET}"

# ─── 4. Configura ─────────────────────────────────────────────────────────────
echo ""
"${TARGET}/configure.sh"

# ─── 5. Claude Code ───────────────────────────────────────────────────────────
echo ""
if ! command -v claude &>/dev/null; then
    warn "Claude Code não encontrado — instalando..."

    if ! command -v npm &>/dev/null; then
        warn "npm não encontrado — instalando Node.js..."
        if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
            brew install node || fail "Falha ao instalar Node.js. Instale manualmente: https://nodejs.org"
        elif command -v apt-get &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs || fail "Falha ao instalar Node.js. Instale manualmente: https://nodejs.org"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y nodejs || fail "Falha ao instalar Node.js. Instale manualmente: https://nodejs.org"
        else
            fail "npm não encontrado. Instale o Node.js (https://nodejs.org) e rode:\n  npm install -g @anthropic-ai/claude-code"
        fi
    fi

    npm install -g @anthropic-ai/claude-code \
        || fail "Falha ao instalar Claude Code. Tente manualmente:\n  npm install -g @anthropic-ai/claude-code"
    ok "Claude Code instalado"
fi

ok "claude $(claude --version 2>/dev/null | head -1)"

# ─── 6. Abre Claude Code ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Ambiente pronto.${NC} Iniciando Claude Code em ${TARGET}..."
echo ""
cd "$TARGET" && exec claude
