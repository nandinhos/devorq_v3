#!/usr/bin/env bash
# ============================================================================
# DEVORQ Security Test Suite — Regressão para patches de Code Review
# ============================================================================
# Uso: bash tests/test_F01_RCE_source.sh
#      bash tests/test_lib.sh  (roda todos)
#
# Cada teste é standalone: cria sandbox temporária, executa exploit,
# verifica o resultado. Exit 0 = passou, exit != 0 = falhou.
#
# Pré-requisito: shellcheck, jq, bash 5+
# ============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"

# Cores (se terminal suportar)
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi

# Contadores
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Verificar se repo existe
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${RED}[FATAL]${NC} Repo nao encontrado em $REPO_DIR"
    echo "  Set REPO_DIR=/path/to/devorq_v3 antes de rodar."
    exit 2
fi

# Verificar pré-requisitos
for cmd in shellcheck jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}[FATAL]${NC} Comando '$cmd' nao encontrado"
        exit 2
    fi
done

# Função de teste
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)

    echo ""
    echo "=========================================="
    echo -e "${YELLOW}[TEST]${NC} $test_name"
    echo "=========================================="

    if bash "$test_file" 2>&1; then
        echo -e "${GREEN}[PASS]${NC} $test_name"
        ((TESTS_PASSED++))
    else
        local exit_code=$?
        echo -e "${RED}[FAIL]${NC} $test_name (exit $exit_code)"
        ((TESTS_FAILED++))
    fi
}

# Main
echo "=========================================="
echo "DEVORQ Security Test Suite"
echo "Repo: $REPO_DIR"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=========================================="

for test_file in "$SCRIPT_DIR"/test_F*.sh "$SCRIPT_DIR"/test_D*.sh; do
    [ -f "$test_file" ] || continue
    run_test "$test_file"
done

# Resumo
echo ""
echo "=========================================="
echo "RESUMO"
echo "=========================================="
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}[FAIL]${NC} Alguns testes falharam. NAO aplicar patches ainda."
    exit 1
else
    echo -e "${GREEN}[OK]${NC} Todos os testes passaram. Patches seguros para aplicar."
    exit 0
fi
