#!/usr/bin/env bash
# lib/commands/cli/index.sh — Índice de comandos CLI DEVORQ

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# Get CLI commands directory
CLI_COMMANDS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all CLI command modules
for cmd_file in "$CLI_COMMANDS_DIR"/*.sh; do
    if [[ -f "$cmd_file" ]] && [[ "$(basename "$cmd_file")" != "index.sh" ]]; then
        source "$cmd_file"
    fi
done

# Export directory for reference
export CLI_COMMANDS_DIR
