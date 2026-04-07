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
if [ "$CURRENT_KFP" != "[]" ] && [ -n "$CURRENT_KFP" ]; then
    ask "   Valor atual: ${CURRENT_KFP}"
    ask "   Novo valor (Enter para manter): "
    read -r INPUT_KFP
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
    ok "pyproject.toml → known-first-party = ${FORMATTED}"
else
    ok "pyproject.toml → mantido (${CURRENT_KFP})"
fi

echo ""

# ─── 2. paths_to_mutate ──────────────────────────────────────────────────────
info "2/4 — Diretório do código-fonte (mutmut)"
echo "   mutmut precisa saber onde está o código a ser mutado."
echo ""

CURRENT_PTM=$(grep -v '^#' mutmut.toml 2>/dev/null | grep 'paths_to_mutate' | sed 's/.*= //' | tr -d '"')
ask "   Valor atual: ${CURRENT_PTM}"
ask "   Exemplos: src/, myapp/, handlers/"
ask "   Caminho (Enter para manter): "
read -r INPUT_PTM

if [ -n "$INPUT_PTM" ]; then
    # Normaliza: garante barra no final
    INPUT_PTM="${INPUT_PTM%/}/"
    if [ ! -d "$INPUT_PTM" ]; then
        warn "   Diretório '${INPUT_PTM}' não existe — configurando mesmo assim."
    fi
    sed -i.bak "s|paths_to_mutate = .*|paths_to_mutate = \"${INPUT_PTM}\"|" mutmut.toml
    rm -f mutmut.toml.bak
    ok "mutmut.toml → paths_to_mutate = \"${INPUT_PTM}\""
else
    ok "mutmut.toml → mantido (${CURRENT_PTM})"
    INPUT_PTM="$CURRENT_PTM"
fi

echo ""

# ─── 3. tests_dir ────────────────────────────────────────────────────────────
info "3/4 — Diretório de testes (mutmut)"
echo ""

CURRENT_TD=$(grep -v '^#' mutmut.toml 2>/dev/null | grep 'tests_dir' | sed 's/.*= //' | tr -d '"')
ask "   Valor atual: ${CURRENT_TD}"
ask "   Diretório de testes (Enter para manter): "
read -r INPUT_TD

if [ -n "$INPUT_TD" ]; then
    INPUT_TD="${INPUT_TD%/}/"
    if [ ! -d "$INPUT_TD" ]; then
        warn "   Diretório '${INPUT_TD}' não existe — configurando mesmo assim."
    fi
    sed -i.bak "s|tests_dir = .*|tests_dir = \"${INPUT_TD}\"|" mutmut.toml
    rm -f mutmut.toml.bak
    ok "mutmut.toml → tests_dir = \"${INPUT_TD}\""
else
    ok "mutmut.toml → mantido (${CURRENT_TD})"
fi

echo ""

# ─── 4. SERVICE_MAP.md ───────────────────────────────────────────────────────
info "4/4 — Serviços da plataforma (SERVICE_MAP.md)"
echo "   Necessário apenas para projetos com múltiplos serviços."
echo "   Habilita /blast-radius, /investigate e /cross-service-analysis."
echo ""

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
    ok "SERVICE_MAP.md → não configurado (projeto single-service)"
fi

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
bash "$(dirname "$0")/setup.sh"
