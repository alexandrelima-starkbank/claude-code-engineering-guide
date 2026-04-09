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
PIPELINE_DEST="${HOME}/.claude/pipeline"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[ok]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[erro]${NC} $1"; exit 1; }

_create_tasks_placeholder() {
    printf '# TASKS.md\n# Gerado por `pipeline export tasks-md` — NÃO EDITAR DIRETAMENTE\n# Fonte: ~/.claude/pipeline/pipeline.db\n\n---\n\n## Tarefas Ativas\n\n_Nenhuma tarefa ativa no momento._\n\n---\n\n## Histórico\n\n_Nenhuma tarefa concluída._\n' > "$1"
    ok "TASKS.md criado (placeholder)"
}

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

# ─── 2. python3 / pip3 ────────────────────────────────────────────────────────
echo ""
if command -v python3 &>/dev/null; then
    PY_VERSION=$(python3 --version | awk '{print $2}')
    ok "python3 ${PY_VERSION}"
else
    warn "python3 não encontrado"
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
        brew install python3 || fail "Falha ao instalar python3"
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y python3 python3-pip || fail "Falha ao instalar python3"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y python3 python3-pip || fail "Falha ao instalar python3"
    else
        fail "python3 não encontrado. Instale em https://www.python.org"
    fi
fi

PIP3=""
for _pip in pip3 pip; do
    if command -v "$_pip" &>/dev/null; then
        PIP3="$_pip"
        break
    fi
done
if [ -z "$PIP3" ] && python3 -m pip --version &>/dev/null 2>&1; then
    PIP3="python3 -m pip"
fi

if [ -n "$PIP3" ]; then
    ok "pip ($($PIP3 --version | awk '{print $2}'))"
else
    warn "pip não encontrado — pipeline CLI não poderá ser instalado automaticamente"
fi

# ─── 3. Template (clona ou atualiza no cache) ─────────────────────────────────
# GIT_SSL: tenta com SSL; em ambientes corporativos com proxy SSL, faz retry sem verificação
_git() { git "$@" 2>/dev/null || GIT_SSL_NO_VERIFY=true git "$@"; }

echo ""
if [ -d "${CACHE_DIR}/.git" ]; then
    echo "Atualizando template..."
    _git -C "$CACHE_DIR" pull --quiet origin main || warn "Falha ao atualizar — usando versão em cache"
    ok "template: $(git -C "$CACHE_DIR" rev-parse --short HEAD)"
else
    echo "Baixando template..."
    _git clone --quiet --depth 1 "$REPO_URL" "$CACHE_DIR" \
        || fail "Falha ao clonar repositório. Verifique sua conexão e tente novamente."
    ok "template baixado"
fi

# ─── 4. Pipeline CLI (global — ~/.claude/pipeline/) ───────────────────────────
echo ""
echo "── Pipeline CLI ─────────────────────────────────────────────────────────────"

PIPELINE_SRC="${CACHE_DIR}/pipeline-cli"

if [ -d "$PIPELINE_SRC" ]; then
    mkdir -p "$PIPELINE_DEST"
    cp -r "${PIPELINE_SRC}/." "$PIPELINE_DEST/"
    ok "pipeline-cli copiado para ${PIPELINE_DEST}"

    if [ -n "$PIP3" ]; then
        $PIP3 install -e "$PIPELINE_DEST" --quiet 2>/dev/null \
            && ok "pipeline CLI instalado" \
            || warn "pipeline CLI — falha na instalação (tente: pip3 install -e ${PIPELINE_DEST})"
    else
        warn "pip3 indisponível — instale manualmente: pip3 install -e ${PIPELINE_DEST}"
    fi

    # ChromaDB (obrigatório — contexto semântico do Intake Protocol)
    if [ -n "$PIP3" ]; then
        $PIP3 install chromadb --quiet 2>/dev/null \
            && ok "chromadb instalado" \
            || { warn "chromadb — falha na instalação. Tentando com --user..."; \
                 $PIP3 install chromadb --quiet --user 2>/dev/null \
                     && ok "chromadb instalado (--user)" \
                     || fail "chromadb — falha na instalação (tente: pip3 install chromadb)"; }
    else
        fail "chromadb não pode ser instalado — pip3 indisponível"
    fi
else
    warn "pipeline-cli não encontrado no template — pulando"
fi

# ─── 5. Copia arquivos para o destino ─────────────────────────────────────────
TARGET="${1:-$(pwd)}"
echo ""
echo "── Projeto destino ──────────────────────────────────────────────────────────"
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
chmod +x "${TARGET}/configure.sh" "${TARGET}/setup.sh" "${TARGET}/.claude/hooks/"*.sh

# Restaura settings.local.json se havia backup
if [ -n "$SETTINGS_BACKUP" ]; then
    cp "$SETTINGS_BACKUP" "$SETTINGS_LOCAL"
    rm -f "$SETTINGS_BACKUP"
    ok ".claude/settings.local.json preservado"
fi

# pyproject.toml — não sobrescreve se já existir
if [ ! -f "${TARGET}/pyproject.toml" ]; then
    cp "${CACHE_DIR}/pyproject.toml" "${TARGET}/pyproject.toml"
    ok "pyproject.toml copiado"
else
    ok "pyproject.toml já existe — mantido"
fi

# CLAUDE.md — não sobrescreve (pode ter config específica do projeto)
if [ ! -f "${TARGET}/CLAUDE.md" ]; then
    cp "${CACHE_DIR}/CLAUDE.install.md" "${TARGET}/CLAUDE.md"
    ok "CLAUDE.md criado"
else
    ok "CLAUDE.md já existe — mantido"
fi

ok "arquivos instalados em ${TARGET}"

# ─── 6. TASKS.md — gerado pelo pipeline DB ────────────────────────────────────
echo ""
echo "── TASKS.md ─────────────────────────────────────────────────────────────────"

if [ ! -f "${TARGET}/TASKS.md" ]; then
    # Tenta gerar via pipeline CLI; fallback: cria placeholder correto
    if command -v pipeline &>/dev/null; then
        PROJECT_NAME="$(basename "$TARGET")"
        PROJECT_ID=$(pipeline project list 2>/dev/null | grep "^${PROJECT_NAME}" | awk '{print $1}')
        if [ -z "$PROJECT_ID" ]; then
            # Registra o projeto no DB e gera TASKS.md vazio
            pipeline task list --project "$PROJECT_NAME" --format json > /dev/null 2>&1 || true
        fi
        pipeline export tasks-md --project "$PROJECT_NAME" --output "${TARGET}/TASKS.md" 2>/dev/null \
            && ok "TASKS.md gerado pelo pipeline" \
            || _create_tasks_placeholder "${TARGET}/TASKS.md"
    else
        _create_tasks_placeholder "${TARGET}/TASKS.md"
    fi
else
    ok "TASKS.md já existe — mantido"
fi

# .gitignore — entradas para arquivos locais e gerados
GITIGNORE="${TARGET}/.gitignore"
{
    grep -q '.claude/settings.local.json' "$GITIGNORE" 2>/dev/null || echo ".claude/settings.local.json"
    grep -q 'TASKS.md' "$GITIGNORE" 2>/dev/null || echo "TASKS.md"
    grep -q 'CLAUDE.local.md' "$GITIGNORE" 2>/dev/null || echo "CLAUDE.local.md"
    grep -q '.mutmut-cache' "$GITIGNORE" 2>/dev/null || echo ".mutmut-cache"
} >> "$GITIGNORE"
ok ".gitignore atualizado"

# ─── 7. Configura pyproject.toml / mutmut.toml / SERVICE_MAP ─────────────────
echo ""
"${TARGET}/configure.sh"

# ─── 8. Claude Code ───────────────────────────────────────────────────────────
echo ""
echo "── Claude Code ──────────────────────────────────────────────────────────────"
if ! command -v claude &>/dev/null; then
    warn "Claude Code não encontrado — instalando..."

    if ! command -v npm &>/dev/null; then
        warn "npm não encontrado — instalando Node.js..."
        if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
            brew install node || fail "Falha ao instalar Node.js. Instale manualmente: https://nodejs.org"
        elif command -v apt-get &>/dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt-get install -y nodejs || fail "Falha ao instalar Node.js"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y nodejs || fail "Falha ao instalar Node.js"
        else
            fail "npm não encontrado. Instale o Node.js (https://nodejs.org) e rode:\n  npm install -g @anthropic-ai/claude-code"
        fi
    fi

    npm install -g @anthropic-ai/claude-code \
        || fail "Falha ao instalar Claude Code. Tente:\n  npm install -g @anthropic-ai/claude-code"
    ok "Claude Code instalado"
fi
ok "claude $(claude --version 2>/dev/null | head -1)"

# ─── 9. Abre Claude Code ──────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Ambiente pronto.${NC} Iniciando Claude Code em ${TARGET}..."
echo ""
cd "$TARGET" && exec claude
