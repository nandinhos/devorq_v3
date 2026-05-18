#!/usr/bin/env bash
# grill-detect.sh — Fase 1: Detecção de contexto + BREAK/warn forte
#
# Uso: grill-detect.sh <project_root> <intent> [--mode gate|pre-sprint]
#
# Modes:
#   gate        — dentro de gate_0() (default)
#   pre-sprint  — entre sprints (AUTO mode)
#
# Exit codes:
#   0 = Grill oferecido (sempre — não bloqueia)
#   1 = Skip (sem CONTEXT.md E sem código, ou intent é bugfix)

set -uo pipefail

PROJECT_ROOT="${1:-}"
INTENT="${2:-}"
MODE="${3:-gate}"

# Cores
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================
# Helpers
# ============================================================

has_command() {
    command -v "$1" &>/dev/null
}

count_terms() {
    local file="$1"
    [ -f "$file" ] || echo "0"
    grep -c "^**" "$file" 2>/dev/null || echo "0"
}

list_contexts() {
    local root="$1"
    find "$root/src" -maxdepth 2 -name "CONTEXT.md" 2>/dev/null | while read -r f; do
        dirname "$f" | sed "s|$root/||"
    done
}

list_adrs() {
    local adr_dir="$1"
    [ -d "$adr_dir" ] || return
    find "$adr_dir" -name "*.md" -type f 2>/dev/null | sort
}

extract_intent_terms() {
    local intent="$1"
    # Extrai substantivos кандидатов do intent
    # Filtra palavras genéricas e retorna termos únicos
    echo "$intent" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -s ' .,?!:;()[]{}' '\n' \
        | grep -vE "^(o|a|os|as|um|uma|é|foi|ser|ter|fazer|de|para|com|em|no|na|que|qual|qualquer|todo|toda|novo|nova|implementar|criar|adicionar|feature|módulo|sistema|projeto|parte|tela|página|página|botão|campo|campo|campo|input|form|o_|a_|um_|uma_|para_|com_|em_|no_|na_|de_|do_|da_|um|uma|e|ou|se|então|depois|antes|durante|entre|sobre|com|por|via|através|através)$" \
        | sort -u
}

# ============================================================
# Skip logic
# ============================================================

[ -z "$PROJECT_ROOT" ] && exit 1
[ -z "$INTENT" ] && exit 1

# Skip se intent é bugfix/hotfix
if echo "$INTENT" | grep -qiE "bug|fix|corrigir|typo|erro|hotfix|debug"; then
    exit 1
fi

# Skip se intent não contém feature keywords
if ! echo "$INTENT" | grep -qiE "implementar|criar|adicionar|feature|novo|domínio"; then
    exit 1
fi

# Skip se não tem CONTEXT.md NEM código fonte
CONTEXT_FILE="$PROJECT_ROOT/CONTEXT.md"
CONTEXT_MAP="$PROJECT_ROOT/CONTEXT-MAP.md"
ADR_DIR="$PROJECT_ROOT/docs/adr"
HAS_SRC=false

[ -d "$PROJECT_ROOT/src" ] && HAS_SRC=true
[ -f "$CONTEXT_FILE" ] || [ -f "$CONTEXT_MAP" ] || $HAS_SRC || exit 1

# ============================================================
# Setup
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRILL_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================================
# Header
# ============================================================

echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}[BREAK]${RESET} ${BOLD}GATE-0: grill-with-docs — Recomendação forte${RESET}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# ============================================================
# 1. CONTEXT.md status
# ============================================================

if [ -f "$CONTEXT_FILE" ]; then
    terms_count=$(count_terms "$CONTEXT_FILE")
    echo -e "  ${GREEN}✓${RESET} CONTEXT.md encontrado"
    echo -e "    Termos definidos: $terms_count"

    # Mostrar termos existentes (primeiros 10)
    if [ "$terms_count" -gt 0 ]; then
        echo -e "    Primeiros termos:"
        grep "^**" "$CONTEXT_FILE" | head -5 | sed 's/^/      /'
        [ "$terms_count" -gt 5 ] && echo -e "      ... e mais $((terms_count - 5))"
    fi
else
    echo -e "  ${YELLOW}⚠${RESET} CONTEXT.md não encontrado"
    echo -e "    Sem glossário, grill não consegue validar terminologia."
    echo -e "    ${CYAN}AÇÃO:${RESET} grill-init-context.sh pode gerar template inicial."
fi
echo ""

# ============================================================
# 2. CONTEXT-MAP.md status (multi-contexto)
# ============================================================

if [ -f "$CONTEXT_MAP" ]; then
    echo -e "  ${GREEN}✓${RESET} CONTEXT-MAP.md encontrado (multi-contexto)"
    contexts=$(list_contexts "$PROJECT_ROOT")
    if [ -n "$contexts" ]; then
        echo -e "    Contextos encontrados:"
        echo "$contexts" | sed 's/^/      - /'
    fi
elif [ -d "$PROJECT_ROOT/src" ]; then
    contexts_count=$(find "$PROJECT_ROOT/src" -maxdepth 2 -name "CONTEXT.md" 2>/dev/null | wc -l)
    if [ "$contexts_count" -gt 1 ]; then
        echo -e "  ${YELLOW}⚠${RESET} Multi-contexto detectado ($contexts_count CONTEXT.md em src/)"
        echo -e "    CONSELHO: crie CONTEXT-MAP.md na raiz para documentar relationships"
    fi
fi
echo ""

# ============================================================
# 3. ADR status
# ============================================================

if [ -d "$ADR_DIR" ]; then
    adr_count=$(find "$ADR_DIR" -name "*.md" -type f 2>/dev/null | wc -l)
    if [ "$adr_count" -gt 0 ]; then
        echo -e "  ${GREEN}✓${RESET} docs/adr/ existe ($adr_count ADR(s))"
        echo -e "    ADRs existentes:"
        list_adrs "$ADR_DIR" | while read -r f; do
            echo -e "      - $(basename "$f")"
        done
    else
        echo -e "  ${YELLOW}⚠${RESET} docs/adr/ existe, mas vazio (0 ADRs)"
    fi
else
    echo -e "  ${YELLOW}⚠${RESET} docs/adr/ não existe"
    echo -e "    ADRs serão criados aqui se decisões qualificarem."
fi
echo ""

# ============================================================
# 4. Termos detectados no INTENT (candidatos)
# ============================================================

intent_terms=$(extract_intent_terms "$INTENT")
intent_terms_count=$(echo "$intent_terms" | grep -c . || echo "0")

if [ "$intent_terms_count" -gt 0 ]; then
    echo -e "  ${CYAN}ℹ${RESET} Termos detectados no intent: $intent_terms_count"
    echo -e "    Candidatos a validar no glossário:"
    echo "$intent_terms" | head -8 | sed 's/^/      /'
    [ "$intent_terms_count" -gt 8 ] && echo -e "      ... e mais $((intent_terms_count - 8))"
fi
echo ""

# ============================================================
# 5. Modo pre-sprint: detectar mudanças
# ============================================================

if [ "$MODE" = "pre-sprint" ]; then
    echo -e "${BOLD}Modo: pré-sprint (entre sprints)${RESET}"
    echo -e "  Verificando se vocabulário da nova SPEC.md está afiado..."
    echo ""

    # TODO: Implementar detecção de mudanças
    # Por ora, apenas indica que está disponível
    echo -e "  ${CYAN}AÇÃO:${RESET} Se houver termos vagos na nova SPEC.md,"
    echo -e "    grill-refine.sh vai questionar cada um."
fi

# ============================================================
# BREAK: Recomendação forte
# ============================================================

echo -e "${YELLOW}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${YELLOW}⚠${RESET} ${BOLD}RECOMENDAÇÃO FORTE: Execute grill-with-docs antes de prosseguir.${RESET}"
echo ""
echo -e "  NÃO FAZER O GRILL PODE RESULTAR EM:"
echo -e "  ${RED}✗${RESET} Termos vagos usados de formas inconsistentes"
echo -e "  ${RED}✗${RESET} Código que contradiz o plano (sem validação)"
echo -e "  ${RED}✗${RESET} Decisões arquiteturais perdidas (sem ADR)"
echo -e "  ${RED}✗${RESET} SPEC.md com vocabulário impossível de validar"
echo ""
echo -e "  AÇÃO RECOMENDADA:"
echo -e "  ${GREEN}1.${RESET} Carregar skill grill-with-docs"
echo -e "  ${GREEN}2.${RESET} Executar grill-init-context.sh (se CONTEXT.md não existe)"
echo -e "  ${GREEN}3.${RESET} Executar grill-refine.sh para refinar termos"
echo -e "  ${GREEN}4.${RESET} Confirmar ADRs necessários"
echo -e "  ${GREEN}5.${RESET} Atualizar CONTEXT.md com termos resolvidos"
echo ""

# ============================================================
# Modo gate: instrução para o agente
# ============================================================

if [ "$MODE" = "gate" ]; then
    echo -e "${CYAN}Para o agente (orquestrador):${RESET}"
    echo -e "  O fluxo vai CONTINUAR, mas a qualidade do vocabulário"
    echo -e "  NÃO será validada automaticamente."
    echo ""
    echo -e "  Se quiser fazer grill AGORA:"
    echo -e "    1. Carregue a skill: skills load grill-with-docs"
    echo -e "    2. Execute: bash skills/grill-with-docs/scripts/grill-init-context.sh"
    echo -e "    3. Execute: bash skills/grill-with-docs/scripts/grill-refine.sh"
    echo ""
    echo -e "  O grill é conversacional — questão por questão, até entendimento compartilhado."
fi

echo -e "${YELLOW}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Sempre exit 0 — o BREAK é só um warn, não bloqueia
exit 0
