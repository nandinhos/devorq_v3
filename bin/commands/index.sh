#!/usr/bin/env bash
# bin/commands/index.sh — Índice de comandos DEVORQ
#
# Este arquivo carrega todos os comandos modulares para bin/devorq
# Mantém backward compatibility enquanto permite organização modular

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# Get DEVORQ_ROOT from parent bin/ directory
DEVORQ_BIN_COMMANDS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all command modules
# Note: For now, commands are still in bin/devorq
# This index will be populated as commands are migrated

# Helper functions are defined in lib/helpers.sh
if [[ -f "${DEVORQ_ROOT}/lib/helpers.sh" ]]; then
    source "${DEVORQ_ROOT}/lib/helpers.sh" 2>/dev/null || true
fi

# Export for subshells
export DEVORQ_BIN_COMMANDS_DIR
