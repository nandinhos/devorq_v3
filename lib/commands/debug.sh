#!/usr/bin/env bash
# lib/commands/debug.sh — DEVORQ Debug Commands
#
# Comandos: debug
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

debug::help() {
    cat << 'EOF'
DEBUG COMMANDS:
  debug                    Workflow de debug sistemático
  debug check             Verificar estado do sistema
  debug trace             Rastrear execução
EOF
}

# ============================================================
# debug
# ============================================================

devorq::cmd_debug() {
    source "${DEVORQ_LIB}/debug.sh" 2>/dev/null || true
    if declare -f devorq::debug &>/dev/null; then
        devorq::debug "${1:-}"
    else
        devorq::warn "lib/debug.sh não disponível"
    fi
}
