#!/usr/bin/env bash
# lib/commands/review.sh — Code review multi-agente
#
# shellcheck disable=SC1091

set -euo pipefail

devorq::cmd_review() {
    local branch="HEAD"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch) branch="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local review_root="${DEVORQ_ROOT}/skills/devorq-code-review"
    local review_script="${review_root}/scripts/review.sh"

    if [[ ! -f "$review_script" ]]; then
        devorq::error "review.sh não encontrado em ${review_root}/scripts/"
    fi

    devorq::info "Executando Code Review (branch: $branch)..."
    bash "$review_script" "$PWD" --branch "$branch"
}
