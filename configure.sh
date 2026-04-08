#!/bin/bash
# configure.sh — ponto de entrada único do ecossistema Claude Code.
# Detecta automaticamente se está num workspace (múltiplos serviços) ou
# num projeto Python único e age de forma diferente em cada caso.
# Chama setup.sh internamente para instalar dependências e permissões.
# Idempotente: pode rodar múltiplas vezes sem efeitos colaterais.

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
EXCLUDED_DIRS=".git .venv venv .env google-cloud-sdk node_modules"

echo ""
echo -e "${BOLD}Configuração do ecossistema Claude Code${NC}"
echo "────────────────────────────────────────"
echo ""

# ─── Funções de detecção ─────────────────────────────────────────────────────

# Lista pacotes Python na raiz do diretório atual (maxdepth 2).
detect_packages() {
    find . -maxdepth 2 -name '__init__.py' \
        ! -path './.venv/*' ! -path './venv/*' ! -path './.env/*' \
        ! -path './.git/*' ! -path './.*' \
        ! -path './tests/*' ! -path './test/*' ! -path './spec/*' \
        2>/dev/null \
        | sed 's|/__init__.py$||' | sed 's|^\./||' | sort -u
}

# Verifica se um diretório contém código Python (tem __init__.py até depth 3).
dir_has_python() {
    find "$1" -maxdepth 3 -name '__init__.py' \
        ! -path '*/.venv/*' ! -path '*/venv/*' \
        2>/dev/null | grep -q .
}

# Retorna true se este diretório parece um workspace (múltiplos sub-repos com Python).
detect_workspace() {
    local count=0
    for d in */; do
        [ -d "$d" ] || continue
        local name="${d%/}"
        # Pula diretórios excluídos e ocultos
        [[ "$name" == .* ]] && continue
        local skip=0
        for excl in $EXCLUDED_DIRS; do
            [ "$name" = "$excl" ] && skip=1 && break
        done
        [ "$skip" -eq 1 ] && continue
        dir_has_python "$d" && count=$((count + 1))
        [ "$count" -gt 1 ] && return 0
    done
    return 1
}

# Lista subdiretórios do workspace que parecem serviços Python.
detect_service_dirs() {
    for d in */; do
        [ -d "$d" ] || continue
        local name="${d%/}"
        [[ "$name" == .* ]] && continue
        local skip=0
        for excl in $EXCLUDED_DIRS; do
            [ "$name" = "$excl" ] && skip=1 && break
        done
        [ "$skip" -eq 1 ] && continue
        dir_has_python "$d" && echo "$name"
    done
}

# Detecta o diretório de testes (tests/, test/, spec/).
detect_tests_dir() {
    for d in tests test spec; do
        [ -d "$d" ] && echo "${d}/" && return
    done
}

is_kfp_placeholder() {
    grep 'known-first-party' pyproject.toml 2>/dev/null | sed 's/#.*//' | grep -q '\[\]'
}

is_ptm_placeholder() {
    grep -v '^#' mutmut.toml 2>/dev/null | grep 'paths_to_mutate' | grep -q '"src/"'
}

apply_kfp() {
    local pkgs_csv="$1"
    local formatted
    formatted=$(echo "$pkgs_csv" | sed 's/,/", "/g')
    formatted="[\"${formatted}\"]"
    sed -i.bak "s|known-first-party = .*|known-first-party = ${formatted}|" pyproject.toml
    rm -f pyproject.toml.bak
    ok "pyproject.toml → known-first-party = ${formatted}"
}

apply_ptm() {
    local ptm="$1"
    sed -i.bak "s|paths_to_mutate = .*|paths_to_mutate = \"${ptm}\"|" mutmut.toml
    rm -f mutmut.toml.bak
    ok "mutmut.toml → paths_to_mutate = \"${ptm}\""
}

apply_td() {
    local td="$1"
    sed -i.bak "s|tests_dir = .*|tests_dir = \"${td}\"|" mutmut.toml
    rm -f mutmut.toml.bak
    ok "mutmut.toml → tests_dir = \"${td}\""
}

# ─── Detecção de modo ────────────────────────────────────────────────────────

if detect_workspace; then
    MODE="workspace"
    echo -e "Modo: ${CYAN}${BOLD}workspace${NC} (múltiplos serviços detectados)"
else
    MODE="single"
    echo -e "Modo: ${CYAN}${BOLD}projeto único${NC}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# MODO WORKSPACE
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "workspace" ]; then

    info "pyproject.toml e mutmut.toml"
    echo "   No workspace, essas configurações pertencem a cada serviço individualmente."
    echo "   Rode ./configure.sh dentro de cada serviço para configurá-los."
    echo ""

    # ─── SERVICE_MAP.md ───────────────────────────────────────────────────────
    info "SERVICE_MAP.md — Mapa de serviços"
    echo ""

    SKIP_SERVICE_MAP=0

    if [ -f "$SERVICE_MAP" ] && grep -q 'configure\.sh' "$SERVICE_MAP"; then
        echo "   SERVICE_MAP.md já configurado. Serviços atuais:"
        awk '/^## Diretórios dos Serviços/{found=1; next} /^(##|---)/{found=0} found && /^- /' \
            "$SERVICE_MAP" | sed 's/^/   /'
        echo ""
        ask "   Reconfigurar do zero? (s/N): "
        read -r RECONFIG
        if [[ ! "$RECONFIG" =~ ^[sS]$ ]]; then
            ok "SERVICE_MAP.md → mantido sem alteração"
            SKIP_SERVICE_MAP=1
        fi
    fi

    if [ "$SKIP_SERVICE_MAP" -eq 0 ]; then
        DETECTED_SVCS=$(detect_service_dirs)

        if [ -n "$DETECTED_SVCS" ]; then
            echo "   Serviços detectados:"
            echo "$DETECTED_SVCS" | sed 's/^/   - /'
            echo ""
            ask "   Usar esses serviços? (S/n): "
            read -r USE_DETECTED

            if [[ ! "$USE_DETECTED" =~ ^[nN]$ ]]; then
                SVC_NAMES="$DETECTED_SVCS"
            else
                ask "   Nomes dos serviços (separados por vírgula): "
                read -r INPUT_SVCS
                SVC_NAMES=$(echo "$INPUT_SVCS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi
        else
            ask "   Nenhum serviço detectado. Informe os nomes (separados por vírgula): "
            read -r INPUT_SVCS
            SVC_NAMES=$(echo "$INPUT_SVCS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi

        # Coleta diretório de cada serviço (auto-detecta se existir)
        declare -a SERVICE_ENTRIES
        CWD=$(pwd)
        echo ""
        while IFS= read -r SVC; do
            [ -z "$SVC" ] && continue
            if [ -d "$SVC" ]; then
                SVC_DIR="${CWD}/${SVC}"
                ok "  ${SVC} → ${SVC_DIR}"
                SERVICE_ENTRIES+=("${SVC}|${SVC_DIR}")
            else
                ask "   Diretório de '${SVC}': "
                read -r SVC_DIR
                SERVICE_ENTRIES+=("${SVC}|${SVC_DIR}")
            fi
        done <<< "$SVC_NAMES"

        echo ""
        ask "   Gerar SERVICE_MAP.md? (S/n): "
        read -r CONFIRM_MAP

        if [[ ! "$CONFIRM_MAP" =~ ^[nN]$ ]]; then
            SVC_LIST=""
            SVC_DIRS_LIST=""
            PIPELINE=""
            PREV=""

            for ENTRY in "${SERVICE_ENTRIES[@]}"; do
                SVC=$(echo "$ENTRY" | cut -d'|' -f1)
                DIR=$(echo "$ENTRY" | cut -d'|' -f2)
                SVC_LIST="${SVC_LIST}- ${SVC} — <descrição do serviço>\n"
                SVC_DIRS_LIST="${SVC_DIRS_LIST}- ${SVC}: ${DIR}\n"
                [ -n "$PREV" ] && PIPELINE="${PIPELINE} -> "
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
            SVC_COUNT=${#SERVICE_ENTRIES[@]}
            ok "SERVICE_MAP.md → configurado (${SVC_COUNT} serviços)"
        fi
    fi

    # Conta serviços do SERVICE_MAP se não foi gerado agora
    if [ -z "$SVC_COUNT" ] && [ -f "$SERVICE_MAP" ]; then
        SVC_COUNT=$(awk '/^## Diretórios dos Serviços/{found=1; next} /^(##|---)/{found=0} found && /^- /' \
            "$SERVICE_MAP" | wc -l | tr -d ' ')
    fi

    # ─── Configurar pyproject.toml e mutmut.toml por serviço ─────────────────
    echo ""
    info "Configurando serviços"
    echo ""

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PYPROJECT_TMPL="${SCRIPT_DIR}/pyproject.toml"
    MUTMUT_TMPL="${SCRIPT_DIR}/mutmut.toml"

    while IFS= read -r svc_line; do
        SVC=$(echo "$svc_line" | sed 's/^- \([^:]*\):.*/\1/' | sed 's/[[:space:]]*$//')
        DIR=$(echo "$svc_line" | sed 's/^- [^:]*: *//' | sed 's/[[:space:]]*$//')
        DIR="${DIR/#\~/$HOME}"

        [ -z "$SVC" ] || [ -z "$DIR" ] && continue

        echo -e "  ${BOLD}${SVC}${NC}"

        if [ ! -d "$DIR" ]; then
            warn "    diretório não encontrado: ${DIR} — pulando"
            echo ""
            continue
        fi

        # Copia templates se ausentes
        [ ! -f "${DIR}/pyproject.toml" ] && [ -f "$PYPROJECT_TMPL" ] && \
            cp "$PYPROJECT_TMPL" "${DIR}/pyproject.toml"
        [ ! -f "${DIR}/mutmut.toml" ] && [ -f "$MUTMUT_TMPL" ] && \
            cp "$MUTMUT_TMPL" "${DIR}/mutmut.toml"

        # Detecta pacotes Python do serviço
        PKGS=$(find "$DIR" -maxdepth 2 -name '__init__.py' \
            ! -path '*/.venv/*' ! -path '*/venv/*' ! -path '*/.git/*' \
            ! -path '*/tests/*' ! -path '*/test/*' ! -path '*/spec/*' \
            2>/dev/null \
            | sed "s|^${DIR}/||" | sed 's|/__init__.py$||' | sort -u)

        # pyproject.toml — known-first-party
        if [ -f "${DIR}/pyproject.toml" ]; then
            if grep "${DIR}/pyproject.toml" 2>/dev/null | sed 's/#.*//' | grep -q '\[\]' \
               || grep 'known-first-party' "${DIR}/pyproject.toml" | sed 's/#.*//' | grep -q '\[\]'; then
                if [ -n "$PKGS" ]; then
                    PKGS_CSV=$(echo "$PKGS" | tr '\n' ',' | sed 's/,$//')
                    FORMATTED=$(echo "$PKGS_CSV" | sed 's/,/", "/g')
                    FORMATTED="[\"${FORMATTED}\"]"
                    sed -i.bak "s|known-first-party = .*|known-first-party = ${FORMATTED}|" "${DIR}/pyproject.toml"
                    rm -f "${DIR}/pyproject.toml.bak"
                    ok "    pyproject.toml → known-first-party = ${FORMATTED}"
                else
                    warn "    pyproject.toml → nenhum pacote detectado em ${DIR}"
                fi
            else
                KFP=$(grep 'known-first-party' "${DIR}/pyproject.toml" | sed 's/#.*//' | sed 's/.*= //' | tr -d ' ')
                ok "    pyproject.toml → known-first-party = ${KFP} (já configurado)"
            fi
        fi

        # mutmut.toml — paths_to_mutate e tests_dir
        if [ -f "${DIR}/mutmut.toml" ]; then
            if grep -v '^#' "${DIR}/mutmut.toml" | grep 'paths_to_mutate' | grep -q '"src/"'; then
                if [ -n "$PKGS" ]; then
                    PTM=$(echo "$PKGS" | tr '\n' ',' | sed 's/,$//')
                    sed -i.bak "s|paths_to_mutate = .*|paths_to_mutate = \"${PTM}\"|" "${DIR}/mutmut.toml"
                    rm -f "${DIR}/mutmut.toml.bak"
                    ok "    mutmut.toml → paths_to_mutate = \"${PTM}\""
                fi
            else
                PTM=$(grep -v '^#' "${DIR}/mutmut.toml" | grep 'paths_to_mutate' | sed 's/.*= //' | tr -d '"')
                ok "    mutmut.toml → paths_to_mutate = ${PTM} (já configurado)"
            fi

            TESTS=""
            for d in tests test spec; do
                [ -d "${DIR}/${d}" ] && TESTS="${d}/" && break
            done
            if [ -n "$TESTS" ]; then
                CURRENT_TD=$(grep -v '^#' "${DIR}/mutmut.toml" | grep 'tests_dir' | sed 's/.*= //' | tr -d '"')
                if [ "$TESTS" != "$CURRENT_TD" ]; then
                    sed -i.bak "s|tests_dir = .*|tests_dir = \"${TESTS}\"|" "${DIR}/mutmut.toml"
                    rm -f "${DIR}/mutmut.toml.bak"
                    ok "    mutmut.toml → tests_dir = \"${TESTS}\""
                else
                    ok "    mutmut.toml → tests_dir = \"${TESTS}\" (já configurado)"
                fi
            fi
        fi

        echo ""
    done < <(awk '/^## Diretórios dos Serviços/{found=1; next} /^(##|---)/{found=0} found && /^- /' "$SERVICE_MAP")

    echo "────────────────────────────────────────"
    echo -e "${BOLD}Resumo${NC}"
    echo ""
    echo "  Workspace com ${SVC_COUNT:-0} serviços configurados."
    echo ""
    echo "Verificando com setup.sh..."
    echo ""
    bash "${CONFIGURE_SETUP_SH:-"$(dirname "$0")/setup.sh"}"

# ═══════════════════════════════════════════════════════════════════════════════
# MODO PROJETO ÚNICO
# ═══════════════════════════════════════════════════════════════════════════════
else

    # ─── 1. known-first-party ─────────────────────────────────────────────────
    info "1/3 — Pacotes locais (isort)"

    if [ -f "pyproject.toml" ]; then
        if ! is_kfp_placeholder; then
            CURRENT_KFP=$(grep 'known-first-party' pyproject.toml 2>/dev/null \
                | sed 's/#.*//' | sed 's/.*= //' | tr -d ' ')
            ok "pyproject.toml → known-first-party = ${CURRENT_KFP} (já configurado)"
        else
            PKGS_RAW=$(detect_packages)
            if [ -n "$PKGS_RAW" ]; then
                PKGS_CSV=$(echo "$PKGS_RAW" | tr '\n' ',' | sed 's/,$//')
                apply_kfp "$PKGS_CSV"
            else
                warn "Nenhum pacote Python detectado (nenhum __init__.py na raiz)."
                ask "   Informe os nomes dos pacotes (ex: myapp, utils): "
                read -r INPUT_KFP
                if [ -n "$INPUT_KFP" ]; then
                    PKGS_CSV=$(echo "$INPUT_KFP" | sed 's/[[:space:]]//g')
                    apply_kfp "$PKGS_CSV"
                else
                    fail "known-first-party não configurado"
                fi
            fi
        fi
    else
        warn "pyproject.toml não encontrado — pulando"
    fi

    echo ""

    # ─── 2. mutmut ────────────────────────────────────────────────────────────
    info "2/3 — Mutation testing (mutmut)"

    if [ -f "mutmut.toml" ]; then
        # paths_to_mutate
        if ! is_ptm_placeholder; then
            CURRENT_PTM=$(grep -v '^#' mutmut.toml | grep 'paths_to_mutate' \
                | sed 's/.*= //' | tr -d '"')
            ok "mutmut.toml → paths_to_mutate = ${CURRENT_PTM} (já configurado)"
        else
            PKGS_RAW=$(detect_packages)
            if [ -n "$PKGS_RAW" ]; then
                PTM=$(echo "$PKGS_RAW" | tr '\n' ',' | sed 's/,$//')
                apply_ptm "$PTM"
            else
                warn "Nenhum pacote Python detectado para paths_to_mutate."
                ask "   Informe o diretório do código (ex: myapp/): "
                read -r INPUT_PTM
                if [ -n "$INPUT_PTM" ]; then
                    INPUT_PTM="${INPUT_PTM%/}/"
                    apply_ptm "$INPUT_PTM"
                else
                    fail "paths_to_mutate não configurado"
                fi
            fi
        fi

        # tests_dir — sempre detecta (idempotente)
        TESTS=$(detect_tests_dir)
        CURRENT_TD=$(grep -v '^#' mutmut.toml | grep 'tests_dir' \
            | sed 's/.*= //' | tr -d '"')
        if [ -n "$TESTS" ]; then
            [ "$TESTS" != "$CURRENT_TD" ] && apply_td "$TESTS" \
                || ok "mutmut.toml → tests_dir = ${CURRENT_TD} (já configurado)"
        else
            warn "Nenhum diretório de testes encontrado (tests/, test/, spec/)."
            ask "   Informe o diretório de testes: "
            read -r INPUT_TD
            if [ -n "$INPUT_TD" ]; then
                INPUT_TD="${INPUT_TD%/}/"
                apply_td "$INPUT_TD"
            else
                fail "tests_dir não configurado"
            fi
        fi
    else
        warn "mutmut.toml não encontrado — pulando"
    fi

    echo ""

    # ─── 3. SERVICE_MAP.md ────────────────────────────────────────────────────
    info "3/3 — Serviços da plataforma (SERVICE_MAP.md)"
    echo "   Necessário apenas para projetos multi-serviço."
    echo ""

    SKIP_SERVICE_MAP=0

    if [ -f "$SERVICE_MAP" ] && grep -q 'configure\.sh' "$SERVICE_MAP"; then
        if grep -q 'single-service' "$SERVICE_MAP"; then
            ok "SERVICE_MAP.md → single-service (já configurado)"
        else
            echo "   SERVICE_MAP.md já configurado."
            ok "SERVICE_MAP.md → mantido sem alteração"
        fi
        SKIP_SERVICE_MAP=1
    fi

    if [ "$SKIP_SERVICE_MAP" -eq 0 ]; then
        ask "   Este projeto tem múltiplos serviços? (s/N): "
        read -r IS_MULTI

        if [[ ! "$IS_MULTI" =~ ^[sS]$ ]]; then
            sed -i.bak "1s|^|<!-- configure.sh: single-service -->\n\n|" "$SERVICE_MAP"
            rm -f "${SERVICE_MAP}.bak"
            ok "SERVICE_MAP.md → single-service"
        else
            echo "   Para projetos multi-serviço, rode configure.sh a partir do"
            echo "   diretório pai que contém todos os serviços."
        fi
    fi

    echo ""
    echo "────────────────────────────────────────"
    echo -e "${BOLD}Resumo${NC}"
    echo ""

    if [ -f "pyproject.toml" ]; then
        KFP_FINAL=$(grep 'known-first-party' pyproject.toml | sed 's/#.*//' | sed 's/.*= //' | tr -d ' ')
        echo "  known-first-party  → ${KFP_FINAL}"
    fi
    if [ -f "mutmut.toml" ]; then
        PTM_FINAL=$(grep -v '^#' mutmut.toml | grep 'paths_to_mutate' | sed 's/.*= //' | tr -d '"')
        TD_FINAL=$(grep -v '^#' mutmut.toml | grep 'tests_dir' | sed 's/.*= //' | tr -d '"')
        echo "  paths_to_mutate    → ${PTM_FINAL}"
        echo "  tests_dir          → ${TD_FINAL}"
    fi
    echo ""

    echo "Verificando com setup.sh..."
    echo ""
    bash "${CONFIGURE_SETUP_SH:-"$(dirname "$0")/setup.sh"}"

fi
