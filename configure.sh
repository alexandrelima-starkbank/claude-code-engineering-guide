#!/bin/bash
# configure.sh — configura o ecossistema Claude Code para este projeto.
# Preenche os placeholders em pyproject.toml, mutmut.toml e SERVICE_MAP.md.
# Idempotente: pode rodar múltiplas vezes para atualizar valores.
# Rode após ./setup.sh.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[ok]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${CYAN}${BOLD}$1${NC}"; }
ask()  { echo -e "${BOLD}$1${NC}"; }

SERVICE_MAP=".claude/skills/cross-service-analysis/SERVICE_MAP.md"

echo ""
echo -e "${BOLD}Configuração do ecossistema Claude Code${NC}"
echo "────────────────────────────────────────"
echo ""

# ─── 1. known-first-party ────────────────────────────────────────────────────
info "1/4 — Pacotes locais (isort)"
echo "   isort precisa saber quais pacotes são locais para separar os imports"
echo "   em três grupos: stdlib → dependências externas → código do projeto."
echo ""

CURRENT_KFP=$(grep 'known-first-party' pyproject.toml 2>/dev/null | sed 's/.*= //' | tr -d ' ')
INPUT_KFP=""

if [ -n "$CURRENT_KFP" ] && [ "$CURRENT_KFP" != "[]" ]; then
    ask "   Já configurado: ${CURRENT_KFP}"
    ask "   Alterar? (s/N): "
    read -r CHANGE_KFP
    if [[ "$CHANGE_KFP" =~ ^[sS]$ ]]; then
        ask "   Novo valor (separados por vírgula): "
        read -r INPUT_KFP
    else
        ok "pyproject.toml → mantido (${CURRENT_KFP})"
    fi
else
    ask "   Exemplos: myapp, myapp_utils, core"
    ask "   Pacotes (separados por vírgula): "
    read -r INPUT_KFP
fi

if [ -n "$INPUT_KFP" ]; then
    # Converte "pkg1, pkg2" em ["pkg1", "pkg2"]
    FORMATTED=$(echo "$INPUT_KFP" | sed 's/[[:space:]]//g' | sed 's/,/", "/g')
    FORMATTED="[\"${FORMATTED}\"]"
    sed -i.bak "s|known-first-party = .*|known-first-party = ${FORMATTED}|" pyproject.toml
    rm -f pyproject.toml.bak
    VERIFY_KFP=$(grep 'known-first-party' pyproject.toml 2>/dev/null | sed 's/.*= //' | tr -d ' ')
    if [ "$VERIFY_KFP" = "$FORMATTED" ]; then
        ok "pyproject.toml → known-first-party = ${FORMATTED}"
    else
        warn "pyproject.toml → substituição pode ter falhado — verifique o arquivo manualmente"
    fi
fi

echo ""

# ─── 2. paths_to_mutate ──────────────────────────────────────────────────────
info "2/4 — Diretório do código-fonte (mutmut)"
echo "   mutmut precisa saber onde está o código a ser mutado."
echo ""

CURRENT_PTM=$(grep -v '^#' mutmut.toml 2>/dev/null | grep 'paths_to_mutate' | sed 's/.*= //' | tr -d '"')
INPUT_PTM=""

if [ -n "$CURRENT_PTM" ] && [ "$CURRENT_PTM" != "src/" ]; then
    ask "   Já configurado: ${CURRENT_PTM}"
    ask "   Alterar? (s/N): "
    read -r CHANGE_PTM
    if [[ "$CHANGE_PTM" =~ ^[sS]$ ]]; then
        ask "   Novo caminho: "
        read -r INPUT_PTM
    else
        ok "mutmut.toml → mantido (${CURRENT_PTM})"
        INPUT_PTM="$CURRENT_PTM"
    fi
else
    ask "   Exemplos: src/, myapp/, handlers/"
    ask "   Caminho: "
    read -r INPUT_PTM
fi

if [ -n "$INPUT_PTM" ] && [ "$INPUT_PTM" != "$CURRENT_PTM" ]; then
    INPUT_PTM="${INPUT_PTM%/}/"
    if [ ! -d "$INPUT_PTM" ]; then
        warn "   Diretório '${INPUT_PTM}' não existe — configurando mesmo assim."
    fi
    sed -i.bak "s|paths_to_mutate = .*|paths_to_mutate = \"${INPUT_PTM}\"|" mutmut.toml
    rm -f mutmut.toml.bak
    VERIFY_PTM=$(grep -v '^#' mutmut.toml 2>/dev/null | grep 'paths_to_mutate' | sed 's/.*= //' | tr -d '"')
    if [ "$VERIFY_PTM" = "$INPUT_PTM" ]; then
        ok "mutmut.toml → paths_to_mutate = \"${INPUT_PTM}\""
    else
        warn "mutmut.toml → substituição pode ter falhado — verifique o arquivo manualmente"
    fi
else
    INPUT_PTM="$CURRENT_PTM"
fi

echo ""

# ─── 3. tests_dir ────────────────────────────────────────────────────────────
info "3/4 — Diretório de testes (mutmut)"
echo ""

CURRENT_TD=$(grep -v '^#' mutmut.toml 2>/dev/null | grep 'tests_dir' | sed 's/.*= //' | tr -d '"')
INPUT_TD=""

if [ -n "$CURRENT_TD" ] && [ "$CURRENT_TD" != "tests/" ]; then
    ask "   Já configurado: ${CURRENT_TD}"
    ask "   Alterar? (s/N): "
    read -r CHANGE_TD
    if [[ "$CHANGE_TD" =~ ^[sS]$ ]]; then
        ask "   Novo diretório: "
        read -r INPUT_TD
    else
        ok "mutmut.toml → mantido (${CURRENT_TD})"
    fi
else
    ask "   Exemplos: tests/, test/, spec/"
    ask "   Diretório de testes: "
    read -r INPUT_TD
fi

if [ -n "$INPUT_TD" ]; then
    INPUT_TD="${INPUT_TD%/}/"
    if [ ! -d "$INPUT_TD" ]; then
        warn "   Diretório '${INPUT_TD}' não existe — configurando mesmo assim."
    fi
    sed -i.bak "s|tests_dir = .*|tests_dir = \"${INPUT_TD}\"|" mutmut.toml
    rm -f mutmut.toml.bak
    VERIFY_TD=$(grep -v '^#' mutmut.toml 2>/dev/null | grep 'tests_dir' | sed 's/.*= //' | tr -d '"')
    if [ "$VERIFY_TD" = "$INPUT_TD" ]; then
        ok "mutmut.toml → tests_dir = \"${INPUT_TD}\""
    else
        warn "mutmut.toml → substituição pode ter falhado — verifique o arquivo manualmente"
    fi
fi

echo ""

# ─── 4. SERVICE_MAP.md ───────────────────────────────────────────────────────
info "4/4 — Serviços da plataforma (SERVICE_MAP.md)"
echo "   Necessário apenas para projetos com múltiplos serviços."
echo "   Habilita /blast-radius, /investigate e /cross-service-analysis."
echo ""

SKIP_SERVICE_MAP=0

# Detecta se seção 4 já foi respondida (marcador presente em qualquer variante)
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

    # Coleta diretórios para cada serviço
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
        # Gera lista de serviços
        SVC_LIST=""
        SVC_DIRS_LIST=""
        for ENTRY in "${SERVICE_DIRS[@]}"; do
            SVC=$(echo "$ENTRY" | cut -d'|' -f1)
            DIR=$(echo "$ENTRY" | cut -d'|' -f2)
            SVC_LIST="${SVC_LIST}- ${SVC} — <descrição do serviço>\n"
            SVC_DIRS_LIST="${SVC_DIRS_LIST}- ${SVC}: ${DIR}\n"
        done

        # Gera pipeline (primeiro → último serviço)
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
    # Grava marcador para garantir idempotência em re-execuções
    sed -i.bak "1s|^|<!-- configure.sh: single-service -->\n\n|" "$SERVICE_MAP"
    rm -f "${SERVICE_MAP}.bak"
    ok "SERVICE_MAP.md → marcado como single-service (não será perguntado novamente)"
fi

fi # SKIP_SERVICE_MAP

echo ""
echo "────────────────────────────────────────"
echo -e "${BOLD}Resumo${NC}"
echo ""

KFP_FINAL=$(grep 'known-first-party' pyproject.toml | sed 's/.*= //')
PTM_FINAL=$(grep -v '^#' mutmut.toml | grep 'paths_to_mutate' | sed 's/.*= //' | tr -d '"')
TD_FINAL=$(grep -v '^#' mutmut.toml | grep 'tests_dir' | sed 's/.*= //' | tr -d '"')

echo "  known-first-party  → ${KFP_FINAL}"
echo "  paths_to_mutate    → ${PTM_FINAL}"
echo "  tests_dir          → ${TD_FINAL}"
echo ""

echo "Verificando com setup.sh..."
echo ""
bash "${CONFIGURE_SETUP_SH:-"$(dirname "$0")/setup.sh"}"
