#!/usr/bin/env bash
# lib/commands/rules.sh — Wrapper dispatch para lib/rules.sh
# shellcheck disable=SC1091

set -euo pipefail

if ! declare -p DEVORQ_RULES &>/dev/null; then
    declare -gA DEVORQ_RULES
fi

source "${DEVORQ_LIB}/rules.sh"

devorq::cmd_rules_dispatch() {
    devorq::rules::init
    devorq::cmd_rules "$@"
}
