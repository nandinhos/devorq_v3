#!/usr/bin/env bash
# ddd-validate-spec.sh — GATE-0 validator for ddd-deep-domain
# Validates that SPEC.md has "soul" (domain model) not just "skeleton" (structure)
#
# Exit codes:
#   0 = SPEC.md has valid domain model (PASS)
#   1 = SPEC.md lacks domain model (FAIL)
#   2 = SPEC.md does not exist
#
# Usage:
#   ddd-validate-spec.sh /path/to/SPEC.md

set -eEo pipefail

SPEC="${1:-SPEC.md}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check 1: SPEC.md exists
if [ ! -f "$SPEC" ]; then
    echo -e "${RED}❌ GATE-0 FAIL${NC}: SPEC.md não encontrado em: $SPEC"
    echo "   Crie o SPEC.md primeiro: devorq ddd init"
    exit 2
fi

# Helper to count matches (returns single integer)
count_matches() {
    local count
    count=$(grep -ciE "$1" "$SPEC" 2>/dev/null) || count=0
    echo "$count"
}

# Check 2: Has entities section or entity declarations
entities_count=$(count_matches '(entidade|entity|entities|modelo|domain model|agregado|aggregate|root)')
has_entities=$([ "$entities_count" -ge 2 ] && echo 1 || echo 0)

# Check 3: Has bounded contexts or contexts section
contexts_count=$(count_matches '(contexto|bounded context|contexts|delimitado|delimited)')
has_contexts=$([ "$contexts_count" -ge 2 ] && echo 1 || echo 0)

# Check 4: Has invariants or business rules
invariants_count=$(count_matches '(invariante|regra|regras|constraint|rule|business|negócio|always|never)')
has_invariants=$([ "$invariants_count" -ge 2 ] && echo 1 || echo 0)

# Check 5: Not just CRUD (heuristic)
crud_count=$(count_matches '(criar|create|ler|read|listar|list|buscar|find|atualizar|update|delete|destroy|remover|remove)')
is_likely_crud=$([ "$crud_count" -gt 5 ] && [ "$entities_count" -lt 3 ] && echo 1 || echo 0)

# Scoring
score=0
[ "$has_entities" -eq 1 ] && score=$((score + 1))
[ "$has_contexts" -eq 1 ] && score=$((score + 1))
[ "$has_invariants" -eq 1 ] && score=$((score + 1))

# Report
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GATE-0: DDD Domain Model Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  SPEC: $SPEC"
echo ""
printf "  %-30s %s\n" "Entidades encontradas:" "$entities_count $([ "$has_entities" -eq 1 ] && echo '✅' || echo '❌')"
printf "  %-30s %s\n" "Contextos encontrados:" "$contexts_count $([ "$has_contexts" -eq 1 ] && echo '✅' || echo '❌')"
printf "  %-30s %s\n" "Invariantes encontradas:" "$invariants_count $([ "$has_invariants" -eq 1 ] && echo '✅' || echo '❌')"
printf "  %-30s %s\n" "CRUD detectado:" "$crud_count $([ "$is_likely_crud" -eq 1 ] && echo '⚠️ ALERTA' || echo '✅')"
echo ""
echo "  Score: $score/3"
echo ""

# Warnings
if [ "$is_likely_crud" -eq 1 ]; then
    echo -e "  ${YELLOW}⚠️  ALERTA: Parece CRUD mais que domínio${NC}"
    echo "     SPEC.md pode ter estrutura sem alma."
    echo "     Considere: devorq ddd explore"
    echo ""
fi

# Final verdict
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$score" -ge 2 ]; then
    echo -e "  ${GREEN}✅ GATE-0 PASS${NC}: SPEC.md tem modelo de domínio"
    echo "     O SPEC.md contém: $([ "$has_entities" -eq 1 ] && echo 'entidades, ')$([ "$has_contexts" -eq 1 ] && echo 'contextos, ')$([ "$has_invariants" -eq 1 ] && echo 'invariantes' | sed 's/, $//')"
    echo ""
    exit 0
else
    echo -e "  ${RED}❌ GATE-0 FAIL${NC}: SPEC.md sem modelo de domínio"
    echo "     Falta: $([ "$has_entities" -eq 0 ] && echo 'entidades, ')$([ "$has_contexts" -eq 0 ] && echo 'contextos, ')$([ "$has_invariants" -eq 0 ] && echo 'invariantes' | sed 's/, $//')"
    echo ""
    echo "     Ações sugeridas:"
    echo "       1. devorq ddd explore  — workshop de domínio"
    echo "       2. Adicione seções ao SPEC.md:"
    echo "          - ## Entidades (quem são, exemplos reais)"
    echo "          - ## Contextos Delimitados (onde muda)"
    echo "          - ## Invariantes (regras que não mudam)"
    echo ""
    exit 1
fi
