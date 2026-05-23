#!/usr/bin/env bash
# lib/commands/auto.sh — AUTO mode (Ralph default, --guided híbrido)
#
# shellcheck disable=SC1091

set -euo pipefail

devorq::cmd_auto() {
    local guided=false
    local force_continue=false
    local count="1"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                cat <<'EOF'
Usage: devorq auto [N|all|--continue|--guided|--force-continue]

  devorq auto [N]              Loop Ralph (loop-auto.sh), N stories (default: 1)
  devorq auto all              Todas as stories pendentes
  devorq auto --continue       Marca story atual após verify (modo guided)
  devorq auto --guided [N]     Tracker híbrido (implementação manual + verify visual)
  devorq auto --force-continue Loop Ralph: continua após falha de story

EOF
                return 0
                ;;
            --guided|--hybrid) guided=true; shift ;;
            --force-continue) force_continue=true; shift ;;
            --continue|-c)
                if [[ "$guided" == "true" ]]; then
                    source "${DEVORQ_LIB}/auto.sh"
                    source "${DEVORQ_LIB}/visual.sh" 2>/dev/null || true
                    devorq::cmd_auto_guided --continue
                    return $?
                fi
                force_continue=true
                shift
                ;;
            all) count="all"; shift ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    count="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ "$guided" == "true" ]]; then
        source "${DEVORQ_LIB}/auto.sh"
        source "${DEVORQ_LIB}/visual.sh" 2>/dev/null || true
        if [[ "$count" == "all" ]]; then
            devorq::cmd_auto_guided --all
        else
            devorq::cmd_auto_guided "$count"
        fi
        return $?
    fi

    local auto_root="${DEVORQ_ROOT}/skills/devorq-auto"
    local loop_script="${auto_root}/scripts/loop-auto.sh"

    if [[ ! -f "$loop_script" ]]; then
        devorq::error "loop-auto.sh não encontrado em ${auto_root}/scripts/"
    fi

    devorq::info "Executando AUTO mode Ralph ($count stories)..."

    if [[ "$count" == "all" ]]; then
        bash "$loop_script" "$PWD" --all
    elif [[ "$force_continue" == "true" ]]; then
        bash "$loop_script" "$PWD" --force-continue
    else
        bash "$loop_script" "$PWD" --iterations "${count:-1}"
    fi
}
