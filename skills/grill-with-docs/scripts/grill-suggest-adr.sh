#!/usr/bin/env bash
# grill-suggest-adr.sh — Fase 4: Avalia se uma decisão qualify para ADR
#
# Uso: grill-suggest-adr.sh <decisão> [--hard-to-reverse] [--surprising] [--tradeoff]
#
# Se nenhuma flag fornecida: entra em modo interativo
#
# Exit codes:
#   0 = Qualifies para ADR (todas 3 condições true)
#   1 = Não qualify (pelo menos 1 false)
#   2 = Usage error

set -uo pipefail

DECISION="${1:-}"

# Flags
HARD_TO_REVERSE=false
SURPRISING=false
TRADE_OFF=false

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

usage() {
    echo "Uso: grill-suggest-adr.sh <decisão> [opções]"
    echo ""
    echo "Opções:"
    echo "  --hard-to-reverse   Custo de reverter é significativo"
    echo "  --surprising        Leitor futuro ia perguntar 'por quê?'"
    echo "  --tradeoff          Havia alternativas reais e uma foi escolhida"
    echo ""
    echo "Se nenhuma opção fornecida: modo interativo"
    echo ""
    echo "Exit codes:"
    echo "  0 = Todas 3 condições true → criar ADR"
    echo "  1 = Pelo menos 1 false → não criar ADR"
    exit 2
}

# ============================================================
# Parse arguments
# ============================================================

if [ -z "$DECISION" ]; then
    usage
fi

if [ "$DECISION" = "--help" ] || [ "$DECISION" = "-h" ]; then
    usage
fi

# Check for flags in arguments
for arg in "$@"; do
    case "$arg" in
        --hard-to-reverse)
            HARD_TO_REVERSE=true
            ;;
        --surprising)
            SURPRISING=true
            ;;
        --tradeoff)
            TRADE_OFF=true
            ;;
    esac
done

# Se nenhuma flag, entrar em modo interativo
if ! $HARD_TO_REVERSE && ! $SURPRISING && ! $TRADE_OFF; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

# ============================================================
# Modo interativo
# ============================================================

interactive_mode() {
    echo ""
    echo -e "${BOLD}Avaliando se a decisão qualify para ADR:${RESET}"
    echo -e "  ${CYAN}$DECISION${RESET}"
    echo ""

    echo "  Para cada condição, responda 's' para SIM ou 'n' para NÃO:"
    echo ""

    echo -n "  1. Hard to reverse? (mudar depois custa tempo/dinheiro significativo) [s/n]: "
    read -r answer
    case "$answer" in
        s|S|sim|SIM|y|Y) HARD_TO_REVERSE=true ;;
        *) HARD_TO_REVERSE=false ;;
    esac

    echo -n "  2. Surprising without context? (leitor futuro ia perguntar 'por quê?') [s/n]: "
    read -r answer
    case "$answer" in
        s|S|sim|SIM|y|Y) SURPRISING=true ;;
        *) SURPRISING=false ;;
    esac

    echo -n "  3. Real trade-off? (havia alternativas concretas e uma foi escolhida) [s/n]: "
    read -r answer
    case "$answer" in
        s|S|sim|SIM|y|Y) TRADE_OFF=true ;;
        *) TRADE_OFF=false ;;
    esac
}

# ============================================================
# Avaliação
# ============================================================

count_conditions() {
    local count=0
    $HARD_TO_REVERSE && ((count++)) || true
    $SURPRISING && ((count++)) || true
    $TRADE_OFF && ((count++)) || true
    echo $count
}

print_evaluation() {
    echo ""
    echo -e "${BOLD}Avaliação: $DECISION${RESET}"
    echo ""
    echo "  1. Hard to reverse?           $HARD_TO_REVERSE"
    echo "  2. Surprising without context? $SURPRISING"
    echo "  3. Real trade-off?            $TRADE_OFF"
    echo ""
}

# ============================================================
# Main
# ============================================================

if $INTERACTIVE; then
    interactive_mode
fi

print_evaluation

# 'local' invalido fora de funcao (escopo de script top-level) — SC2168 (DQ-027)
conditions_met=$(count_conditions)

echo -e "  ${BOLD}Condições atendidas: $conditions_met/3${RESET}"
echo ""

if $HARD_TO_REVERSE && $SURPRISING && $TRADE_OFF; then
    echo -e "  ${GREEN}✓ Esta decisão QUALIFIES para ADR.${RESET}"
    echo ""
    echo "  Use grill-create-adr.sh para criar o ADR:"
    echo "    grill-create-adr.sh <project_root> \"<título>\" \"<conteúdo>\""
    echo ""
    exit 0
else
    echo -e "  ${YELLOW}⚠ Esta decisão NÃO qualify para ADR.${RESET}"
    echo ""
    echo "  Motivos:"
    $HARD_TO_REVERSE || echo "    - Hard to reverse: NÃO (mudar depois é fácil)"
    $SURPRISING || echo "    - Surprising: NÃO (decisão óbvia, ninguém ia perguntar)"
    $TRADE_OFF || echo "    - Real trade-off: NÃO (não havia alternativa real)"
    echo ""
    echo "  Se todas as 3 condições fossem true, seria um bom candidato a ADR."
    echo ""
    exit 1
fi
