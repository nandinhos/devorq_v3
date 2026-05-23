#!/usr/bin/env bash
# lib/commands/info.sh — Informações do ambiente DEVORQ
#
# shellcheck disable=SC1091

set -euo pipefail

devorq::cmd_info() {
    devorq::info "DEVORQ v${DEVORQ_VERSION}"
    echo "  DEVORQ_ROOT: ${DEVORQ_ROOT}"
    echo "  PWD:         ${PWD}"
    echo "  Bash:        $(bash --version | head -1)"
    command -v jq >/dev/null 2>&1 && echo "  jq:          $(jq --version)" || echo "  jq:          (não instalado)"
    if [[ -f "${PWD}/.devorq/state/context.json" ]]; then
        echo "  .devorq:     sim"
    else
        echo "  .devorq:     não (rode devorq init)"
    fi
    if [[ -f "${PWD}/prd.json" ]]; then
        local pending
        pending=$(jq '[.stories[] | select((.passes != true) and (.status != "done" and .status != "complete"))] | length' "${PWD}/prd.json" 2>/dev/null || echo "?")
        echo "  prd.json:    ${pending} story(s) pendente(s)"
    fi
}
