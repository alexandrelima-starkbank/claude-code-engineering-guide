#!/bin/bash
# configure.sh — configura o ecossistema Claude Code para este projeto.
# Auto-detecta pacotes Python, diretório de testes e código-fonte.
# Só pergunta quando não consegue inferir do projeto.
# Idempotente: pode rodar múltiplas vezes sem efeitos colaterais.
# Rode após ./setup.sh.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[ok]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[erro]${NC} $1"; }
info() { echo -e "${CYAN}${BOLD}$1${NC}"; }
ask()  { echo -e "${BOLD}$1${NC}"; }

SERVICE_MAP=".claude/skills/cross-service-analysis/SERVICE_MAP.md"

echo ""
echo -e "${BOLD}Configuração do ecossistema Claude Code${NC}"
echo "────────────────────────────────────────"
echo ""

# ─── Funções de detecção ─────────────────────────────────────────────────────

detect_packages() {
    # Pacotes Python = diretórios com __init__.py no nível raiz do projeto.
    # Exclui: ambientes virtuais, .git, diretórios de teste, diretórios ocultos.
    find . -maxdepth 2 -name '__init__.py' \
        ! -path './.venv/*' ! -path './venv/*' ! -path './.env/*' \
        ! -path './.git/*' ! -path './.*' \
        ! -path './tests/*' ! -path './test/*' ! -path './spec/*' \
        2>/dev/null \
        | sed 's|/__init__.py$||' | sed 's|^\./||' | sort -u
}

detect_tests_dir() {
    for d in tests test spec; do
        [ -d "$d" ] && echo "${d}/" && return
    done
}

is_kfp_placeholder() {
    # Retorna 0 (true) se known-first-party ainda é o placeholder vazio.
    grep 'known-first-party' pyproject.toml 2>/dev/null | sed 's/#.*//' | grep -q '\[\]'
}

is_ptm_placeholder() {
    # Retorna 0 (true) se paths_to_mutate ainda é o placeholder src/.
    grep -v '^#' mutmut.toml 2>/dev/null | grep 'paths_to_mutate' | grep -q '"src/"'
}

# ─── 1. known-first-party ────────────────────────────────────────────────────
info "1/3 — Pacotes locais (isort)"

if ! is_kfp_placeholder; then
    CURRENT_KFP=$(grep 'known-first-party' pyproject.toml 2>/dev/null | sed 's/#.*//' | sed 's/.*= //' | tr -d ' ')
    ok "pyproject.toml → known-first-party = ${CURRENT_KFP} (já configurado)"
else
    PKGS_RAW=$(detect_packages)
    if [ -n "$PKGS_RAW" ]; then
        PKGS_CSV=$(echo "$PKGS_RAW" | tr '\n' ',' | sed 's/,$//')
        FORMATTED=$(echo "$PKGS_CSV" | sed 's/,/", "/g')
        FORMATTED="[\"${FORMATTED}\"]"
        sed -i.bak "s|known-first-party = .*|known-first-party = ${FORMATTED}|" pyproject.toml
        rm -f pyproject.toml.bak
        ok "pyproject.toml → known-first-party = ${FORMATTED}"
    else
        warn "Nenhum pacote Python detectado (nenhum __init__.py encontrado)."
        ask "   Informe os nomes dos pacotes locais (ex: myapp, utils): "
        read -r INPUT_KFP
        if [ -n "$INPUT_KFP" ]; then
            FORMATTED=$(echo "$INPUT_KFP" | sed 's/[[:space:]]//g' | sed 's/,/", "/g')
            FORMATTED="[\"${FORMATTED}\"]"
            sed -i.bak "s|known-first-party = .*|known-first-party = ${FORMATTED}|" pyproject.toml
            rm -f pyproject.toml.bak
            ok "pyproject.toml → known-first-party = ${FORMATTED}"
        else
            fail "known-first-party não configurado — isort não separará imports locais corretamente"
        fi
    fi
fi

echo ""

# ─── 2. paths_to_mutate ──────────────────────────────────────────────────────
info "2/3 — Mutation testing (mutmut)"

if ! is_ptm_placeholder; then
    CURRENT_PTM=$(grep -v '^#' mutmut.toml 2>/dev/null | grep 'paths_to_mutate' | sed 's/.*= //' | tr -d '"')
    ok "mutmut.toml → paths_to_mutate = ${CURRENT_PTM} (já configurado)"
else
    PKGS_RAW=$(detect_packages)
    if [ -n "$PKGS_RAW" ]; then
        PTM=$(echo "$PKGS_RAW" | tr '\n' ',' | sed 's/,$//')
        sed -i.bak "s|paths_to_mutate = .*|paths_to_mutate = \"${PTM}\"|" mutmut.toml
        rm -f mutmut.toml.bak
        ok "mutmut.toml → paths_to_mutate = \"${PTM}\""
    else
        warn "Nenhum pacote Python detectado para paths_to_mutate."
        ask "   Informe o diretório do código-fonte (ex: myapp/): "
        read -r INPUT_PTM
        if [ -n "$INPUT_PTM" ]; then
            INPUT_PTM="${INPUT_PTM%/}/"
            sed -i.bak "s|paths_to_mutate = .*|paths_to_mutate = \"${INPUT_PTM}\"|" mutmut.toml
            rm -f mutmut.toml.bak
            ok "mutmut.toml → paths_to_mutate = \"${INPUT_PTM}\""
        else
            fail "paths_to_mutate não configurado"
        fi
    fi
fi

# tests_dir — sempre detecta (idempotente, nenhuma ambiguidade de placeholder)
TESTS=$(detect_tests_dir)
CURRENT_TD=$(grep -v '^#' mutmut.toml 2>/dev/null | grep 'tests_dir' | sed 's/.*= //' | tr -d '"')

if [ -n "$TESTS" ]; then
    if [ "$TESTS" != "$CURRENT_TD" ]; then
        sed -i.bak "s|tests_dir = .*|tests_dir = \"${TESTS}\"|" mutmut.toml
        rm -f mutmut.toml.bak
        ok "mutmut.toml → tests_dir = \"${TESTS}\""
    else
        ok "mutmut.toml → tests_dir = ${CURRENT_TD} (já configurado)"
    fi
else
    warn "Nenhum diretório de testes encontrado (tests/, test/, spec/)."
    ask "   Informe o diretório de testes: "
    read -r INPUT_TD
    if [ -n "$INPUT_TD" ]; then
        INPUT_TD="${INPUT_TD%/}/"
        sed -i.bak "s|tests_dir = .*|tests_dir = \"${INPUT_TD}\"|" mutmut.toml
        rm -f mutmut.toml.bak
        ok "mutmut.toml → tests_dir = \"${INPUT_TD}\""
    else
        fail "tests_dir não configurado"
    fi
fi

echo ""

# ─── 3. SERVICE_MAP.md ───────────────────────────────────────────────────────
info "3/3 — Serviços da plataforma (SERVICE_MAP.md)"
echo "   Necessário apenas para projetos com múltiplos serviços."
echo "   Habilita /blast-radius, /investigate e /cross-service-analysis."
echo ""

SKIP_SERVICE_MAP=0

if [ -f "$SERVICE_MAP" ] && grep -q 'configure\.sh' "$SERVICE_MAP"; then
    if grep -q 'single-service' "$SERVICE_MAP"; then
        echo "   Configurado como: single-service"
    else
        echo "   SERVICE_MAP.md já configurado. Serviços atuais:"
        awk '/^## Diretórios dos Serviços/{found=1; next} /^(##|---)/{found=0} found && /^- /' "$SERVICE_MAP" | sed 's/^/   /'
    fi
    echo ""
    ask "   Reconfigurar do zero? (s/N): "
    read -r RECONFIG
    if [[ ! "$RECONFIG" =~ ^[sS]$ ]]; then
        ok "SERVICE_MAP.md → mantido sem alteração"
        SKIP_SERVICE_MAP=1
    fi
fi

if [ "$SKIP_SERVICE_MAP" -eq 0 ]; then

ask "   Este projeto tem múltiplos serviços? (s/N): "
read -r IS_MULTI

if [[ "$IS_MULTI" =~ ^[sS]$ ]]; then
    echo ""
    ask "   Nomes dos serviços (separados por vírgula):"
    ask "   Exemplo: payments, accounts, ledger"
    ask "   Serviços: "
    read -r INPUT_SERVICES

    IFS=',' read -ra SERVICE_ARRAY <<< "$INPUT_SERVICES"

    declare -a SERVICE_DIRS
    echo ""
    for SVC in "${SERVICE_ARRAY[@]}"; do
        SVC=$(echo "$SVC" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        ask "   Diretório de '${SVC}' (ex: ~/projects/api-ms-${SVC}): "
        read -r SVC_DIR
        SERVICE_DIRS+=("${SVC}|${SVC_DIR}")
    done

    echo ""
    ask "   Gerar SERVICE_MAP.md com esses dados? (S/n): "
    read -r CONFIRM_MAP

    if [[ ! "$CONFIRM_MAP" =~ ^[nN]$ ]]; then
        SVC_LIST=""
        SVC_DIRS_LIST=""
        for ENTRY in "${SERVICE_DIRS[@]}"; do
            SVC=$(echo "$ENTRY" | cut -d'|' -f1)
            DIR=$(echo "$ENTRY" | cut -d'|' -f2)
            SVC_LIST="${SVC_LIST}- ${SVC} — <descrição do serviço>\n"
            SVC_DIRS_LIST="${SVC_DIRS_LIST}- ${SVC}: ${DIR}\n"
        done

        PIPELINE=""
        PREV=""
        for ENTRY in "${SERVICE_DIRS[@]}"; do
            SVC=$(echo "$ENTRY" | cut -d'|' -f1)
            if [ -n "$PREV" ]; then
                PIPELINE="${PIPELINE} -> "
            fi
            PIPELINE="${PIPELINE}${SVC}"
            PREV="$SVC"
        done

        cat > "$SERVICE_MAP" << MAPEOF
# Service Dependency Map

<!-- Gerado por configure.sh — atualize conforme necessário. -->

---

## Serviços

$(printf '%b' "$SVC_LIST")
---

## Pipeline de Autorização / Fluxo Principal

<!-- Ajuste a sequência conforme a arquitetura real da plataforma. -->

${PIPELINE}

---

## Contratos Compartilhados

<!-- Preencha com enums, mensagens de fila e schemas compartilhados. -->

**Enums compartilhados:**
- \`<NomeDoEnum>\` — usado em: <service-a>, <service-b>

**Mensagens de fila (async):**
- \`<TipoMensagem>\` — producer: <service-a>, consumer: <service-b>

**Schemas de API entre serviços:**
- \`GET /internal/<recurso>\` — chamado por: <service-b>

---

## Regras de Deploy

1. **Campo novo (aditivo):** consumers fazem deploy antes do producer começar a enviar
2. **Remoção de campo:** producer para de enviar antes dos consumers removerem a leitura
3. **Enum novo:** todos os consumers devem suportar o novo valor antes do producer enviar
4. **Mudança de schema de fila:** coordenar janela de deploy ou usar versionamento
5. **Serviço de ledger / financeiro:** maior risco — sempre coordenar e testar em staging

---

## Diretórios dos Serviços

$(printf '%b' "$SVC_DIRS_LIST")
MAPEOF
        SVC_COUNT=${#SERVICE_DIRS[@]}
        ok "SERVICE_MAP.md → configurado (${SVC_COUNT} serviços)"
    else
        ok "SERVICE_MAP.md → mantido sem alteração"
    fi
else
    sed -i.bak "1s|^|<!-- configure.sh: single-service -->\n\n|" "$SERVICE_MAP"
    rm -f "${SERVICE_MAP}.bak"
    ok "SERVICE_MAP.md → marcado como single-service"
fi

fi # SKIP_SERVICE_MAP

echo ""
echo "────────────────────────────────────────"
echo -e "${BOLD}Resumo${NC}"
echo ""

KFP_FINAL=$(grep 'known-first-party' pyproject.toml | sed 's/#.*//' | sed 's/.*= //' | tr -d ' ')
PTM_FINAL=$(grep -v '^#' mutmut.toml | grep 'paths_to_mutate' | sed 's/.*= //' | tr -d '"')
TD_FINAL=$(grep -v '^#' mutmut.toml | grep 'tests_dir' | sed 's/.*= //' | tr -d '"')

echo "  known-first-party  → ${KFP_FINAL}"
echo "  paths_to_mutate    → ${PTM_FINAL}"
echo "  tests_dir          → ${TD_FINAL}"
echo ""

echo "Verificando com setup.sh..."
echo ""
bash "${CONFIGURE_SETUP_SH:-"$(dirname "$0")/setup.sh"}"
