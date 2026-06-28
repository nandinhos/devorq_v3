#!/usr/bin/env bash
#============================================================
# scripts/adapters/run-all-tests.sh
#
# Runner agregado dos tests de adapter/panes. Sai 0 somente
# se TODOS passarem; imprime resumo final.
#============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT

G="\033[32m"; R="\033[31m"; Y="\033[33m"; N="\033[0m"
declare -a RESULTS=()

run_test() {
    local name="$1"
    local script="$2"
    echo ""
    echo -e "${Y}=== ${name} ===${N}"
    if bash "$script" 2>&1 | tail -8; then
        RESULTS+=("PASS ${name}")
    else
        RESULTS+=("FAIL ${name}")
    fi
}

run_test "DQ-022 adapter opencode (e2e)" "${REPO_ROOT}/scripts/adapters/test-opencode-delegate.sh"
run_test "Panes bash->Python interpolation (sys.argv)" "${REPO_ROOT}/scripts/adapters/test-panes-bash-python.sh"

echo ""
echo "=============================================="
echo "RESUMO"
echo "=============================================="
fail=0
for r in "${RESULTS[@]}"; do
    if [[ "$r" == PASS* ]]; then
        echo -e "${G}${r}${N}"
    else
        echo -e "${R}${r}${N}"
        fail=1
    fi
done
echo ""
if [[ $fail -eq 0 ]]; then
    echo -e "${G}TODOS OS TESTS PASSARAM — codigo 100% verde${N}"
    exit 0
else
    echo -e "${R}FALHA — verifique os testes acima${N}"
    exit 1
fi