#!/usr/bin/env bash
# lib/commands/cli/version.sh — Comando devorq version

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

devorq::cmd_version() {
    local version
    version=$(cat "${DEVORQ_ROOT}/VERSION" 2>/dev/null || echo "unknown")
    echo "DEVORQ v${version}"
    echo ""
    echo "Use 'devorq upgrade' para atualizar"
}

export -f devorq::cmd_version 2>/dev/null || true
