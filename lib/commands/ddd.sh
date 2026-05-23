#!/usr/bin/env bash
# lib/commands/ddd.sh — Domain-Driven Design commands

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# DDD validate — Validar SPEC.md
devorq::cmd_ddd_validate() {
    local spec_file="${1:-SPEC.md}"
    
    if [[ ! -f "$spec_file" ]]; then
        echo "[GATE-0] SPEC.md não encontrado"
        echo "Score: 0/10"
        return 1
    fi
    
    # Check if empty
    if [[ ! -s "$spec_file" ]]; then
        echo "[GATE-0] SPEC.md está vazio"
        echo "Score: 0/10"
        return 1
    fi
    
    # Basic DDD checks
    local score=5
    local issues=""
    
    # Check for domain model
    if grep -qi "model\|entity\|aggregate\|value object" "$spec_file"; then
        ((score+=2)) || true
    else
        issues="$issues sem modelo de domínio"
    fi
    
    # Check for bounded contexts
    if grep -qi "bounded context\|subdomain" "$spec_file"; then
        ((score+=2)) || true
    else
        issues="$issues sem bounded contexts"
    fi
    
    echo "[GATE-0] Validando DDD em SPEC.md..."
    echo "Score: ${score}/10"
    
    if [[ $score -ge 7 ]]; then
        echo "PASS: DDD bem estruturado"
    else
        echo "Score: ${score}/10"
    fi
    
    return 0
}

export -f devorq::cmd_ddd_validate 2>/dev/null || true
