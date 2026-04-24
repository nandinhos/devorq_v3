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

# Section checks
has_fazer=$(grep -cE "^##[[:space:]]*FAZER" "$CONTRACT" 2>/dev/null || echo 0)
has_nao_fazer=$(grep -cE "^##[[:space:]]*NÃO FAZER" "$CONTRACT" 2>/dev/null || echo 0)
has_arquivos=$(grep -cE "^##[[:space:]]*ARQUIVOS" "$CONTRACT" 2>/dev/null || echo 0)
has_criteria=$(grep -cE "^##[[:space:]]*DONE_CRITERIA" "$CONTRACT" 2>/dev/null || echo 0)
has_identificacao=$(grep -cE "^##[[:space:]]*IDENTIFICAÇÃO" "$CONTRACT" 2>/dev/null || echo 0)

# Score
score=0
[ "$has_fazer" -ge 1 ] && score=$((score + 1))
[ "$has_nao_fazer" -ge 1 ] && score=$((score + 1))
[ "$has_arquivos" -ge 1 ] && score=$((score + 1))
[ "$has_criteria" -ge 1 ] && score=$((score + 1))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🛡️  SCOPE-GUARD — Validação"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Contrato: $CONTRACT"
echo ""

[ "$has_identificacao" -ge 1 ] && echo "  ✅ ## IDENTIFICAÇÃO" || echo "  ❌ ## IDENTIFICAÇÃO"
[ "$has_fazer" -ge 1 ] && echo "  ✅ ## FAZER" || echo "  ❌ ## FAZER"
[ "$has_nao_fazer" -ge 1 ] && echo "  ✅ ## NÃO FAZER" || echo "  ❌ ## NÃO FAZER"
[ "$has_arquivos" -ge 1 ] && echo "  ✅ ## ARQUIVOS" || echo "  ❌ ## ARQUIVOS"
[ "$has_criteria" -ge 1 ] && echo "  ✅ ## DONE_CRITERIA" || echo "  ❌ ## DONE_CRITERIA"

echo ""
echo "  Score: $score/5"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$score" -ge 4 ]; then
    echo -e "  ${GREEN}✅ CONTRATO VÁLIDO${NC}"
    exit 0
else
    echo -e "  ${RED}❌ CONTRATO INCOMPLETO${NC}"
    exit 1
fi
