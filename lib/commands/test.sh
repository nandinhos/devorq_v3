#!/usr/bin/env bash
# lib/commands/test.sh — Wrapper para executar testes

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

devorq::cmd_test() {
    echo "Executando testes..."
    echo ""
    
    # Executar unit tests
    if [[ -f "${DEVORQ_ROOT}/scripts/unit-tests.sh" ]]; then
        bash "${DEVORQ_ROOT}/scripts/unit-tests.sh"
    else
        echo "[ERROR] Unit tests não encontrados"
        return 1
    fi
}

export -f devorq::cmd_test 2>/dev/null || true
