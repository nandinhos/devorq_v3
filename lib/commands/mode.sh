#!/usr/bin/env bash
# lib/commands/mode.sh — Seletor CLASSIC vs AUTO
#
# shellcheck disable=SC1091

set -euo pipefail

devorq::cmd_mode() {
    local mode="${1:-}"
    local mode_root="${DEVORQ_ROOT}/skills/devorq-mode"
    local selector="${mode_root}/mode-selector.sh"

    if [[ ! -f "$selector" ]]; then
        devorq::error "mode-selector.sh não encontrado em ${mode_root}"
    fi

    if [[ -z "$mode" ]]; then
        bash "$selector"
    else
        bash "$selector" "$mode" "$PWD"
    fi
}
