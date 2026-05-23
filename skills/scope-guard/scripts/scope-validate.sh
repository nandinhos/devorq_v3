#!/usr/bin/env bash
# scope-validate.sh — GATE-0 validator for scope-guard
# Validates that a scope contract has all required sections
#
# Exit codes:
#   0 = Contract is valid (PASS)
#   1 = Contract is incomplete (FAIL)
#   2 = Contract file not found

set -euo pipefail

CONTRACT="${1:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Uso: scope-validate.sh <arquivo-contrato.md>"
    exit 2
}

[ -z "$CONTRACT" ] && usage
[ ! -f "$CONTRACT" ] && echo -e "${RED}❌ NÃO ENCONTRADO: $CONTRACT${NC}" && exit 2

# Section checks (case-insensitive, flexible: ## 1. FAZER, ## FAZER, etc.)
has_fazer=$(grep -cEi "^##[[:space:]]+[0-9]*\.?[[:space:]]*FAZER" "$CONTRACT" 2>/dev/null || true)
has_nao_fazer=$(grep -cEi "^##[[:space:]]+[0-9]*\.?[[:space:]]*NÃO FAZER" "$CONTRACT" 2>/dev/null || true)
has_arquivos=$(grep -cEi "^##[[:space:]]+[0-9]*\.?[[:space:]]*ARQUIVOS" "$CONTRACT" 2>/dev/null || true)
has_criteria=$(grep -cEi "^##[[:space:]]+[0-9]*\.?[[:space:]]*DONE_CRITERIA" "$CONTRACT" 2>/dev/null || true)
has_identificacao=$(grep -cEi "^##[[:space:]]+[0-9]*\.?[[:space:]]*IDENTIFICAÇÃO" "$CONTRACT" 2>/dev/null || true)

# Score: 4 required + 1 optional = max 5
score=0
[ "$has_fazer" -ge 1 ] && score=$((score + 1))
[ "$has_nao_fazer" -ge 1 ] && score=$((score + 1))
[ "$has_arquivos" -ge 1 ] && score=$((score + 1))
[ "$has_criteria" -ge 1 ] && score=$((score + 1))
[ "$has_identificacao" -ge 1 ] && score=$((score + 1))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🛡️  SCOPE-GUARD — Validação"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Contrato: $CONTRACT"
echo ""

[ "$has_identificacao" -ge 1 ] && echo "  ✅ ## Identificação" || echo "  ❌ ## Identificação"
[ "$has_fazer" -ge 1 ] && echo "  ✅ ## FAZER" || echo "  ❌ ## FAZER"
[ "$has_nao_fazer" -ge 1 ] && echo "  ✅ ## NÃO FAZER" || echo "  ❌ ## NÃO FAZER"
[ "$has_arquivos" -ge 1 ] && echo "  ✅ ## ARQUIVOS" || echo "  ❌ ## ARQUIVOS"
[ "$has_criteria" -ge 1 ] && echo "  ✅ ## DONE_CRITERIA" || echo "  ❌ ## DONE_CRITERIA"

echo ""
echo "  Score: $score/5  (4+ required)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Minimum 4 required: FAZER, NÃO FAZER, ARQUIVOS, DONE_CRITERIA
required_score=0
[ "$has_fazer" -ge 1 ] && required_score=$((required_score + 1))
[ "$has_nao_fazer" -ge 1 ] && required_score=$((required_score + 1))
[ "$has_arquivos" -ge 1 ] && required_score=$((required_score + 1))
[ "$has_criteria" -ge 1 ] && required_score=$((required_score + 1))

if [ "$required_score" -ge 4 ]; then
    echo -e "  ${GREEN}✅ CONTRATO VÁLIDO${NC}"
    exit 0
else
    echo -e "  ${RED}❌ CONTRATO INCOMPLETO${NC}"
    echo "  Mínimo: FAZER + NÃO FAZER + ARQUIVOS + DONE_CRITERIA"
    exit 1
fi
