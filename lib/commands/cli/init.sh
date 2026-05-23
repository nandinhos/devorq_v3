#!/usr/bin/env bash
# lib/commands/cli/init.sh — Comando devorq init

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# Source the full implementation if it exists
if [[ -f "${DEVORQ_ROOT}/lib/commands/commands.sh" ]]; then
    source "${DEVORQ_ROOT}/lib/commands/commands.sh"
fi

# Fallback: inline implementation
if ! declare -f devorq::cmd_init >/dev/null 2>&1; then
    devorq::cmd_init() {
        local target="${1:-.}"
        if [[ ! -d "$target" ]]; then
            echo "[ERROR] Diretório não existe: $target" >&2
            return $EXIT_INVALID_ARGS
        fi
        mkdir -p "${target}/.devorq/state/lessons"
        mkdir -p "${target}/.devorq/state/sessions"
        cat > "${target}/.devorq/state/context.json" << 'JSONEOF'
{
  "project": "",
  "intent": "",
  "stack": [],
  "gates": {"0":false,"0.5":false,"1":false,"2":false,"3":false,"4":false,"5":false,"5.5":false,"6":false,"7":false}
}
JSONEOF
        echo "[OK] Inicializado .devorq/ em ${target}"
        echo "Edite .devorq/state/context.json com project, stack e intent"
    }
fi

export -f devorq::cmd_init 2>/dev/null || true
