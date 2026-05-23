#!/usr/bin/env bash
# lib/commands/commit.sh — Wrapper dispatch para lib/commit.sh
# shellcheck disable=SC1091

set -euo pipefail

source "${DEVORQ_LIB}/commit.sh"

devorq::cmd_commit_dispatch() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        devorq::commit::usage
        return 0
    fi
    devorq::cmd_commit "$@"
}
