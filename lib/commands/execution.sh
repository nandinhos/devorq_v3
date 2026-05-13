#!/usr/bin/env bash
# lib/commands/execution.sh — DEVORQ Execution Commands
#
# Comandos: mode, auto, review
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

execution::help() {
    cat << 'EOF'
EXECUTION COMMANDS:
  mode                     Seletor AUTO/CLASSIC
  auto                     Modo AUTO (story-by-story)
  review                   Code review multi-agente
EOF
}

# ============================================================
# mode
# ============================================================

devorq::cmd_mode() {
    source "${DEVORQ_LIB}/auto.sh" 2>/dev/null || true
    if declare -f devorq::mode &>/dev/null; then
        devorq::mode "${1:-}"
    else
        devorq::warn "lib/auto.sh não disponível"
        devorq::info "Use: devorq auto para modo automático"
    fi
}

# ============================================================
# auto
# ============================================================

devorq::cmd_auto() {
    source "${DEVORQ_LIB}/auto.sh" 2>/dev/null || {
        devorq::error "lib/auto.sh não disponível"
    }

    if declare -f auto::run &>/dev/null; then
        auto::run "${@:-}"
    else
        devorq::error "Função auto::run não encontrada"
    fi
}

# ============================================================
# review
# ============================================================

devorq::cmd_review() {
    devorq::info "DEVORQ Code Review"
    echo ""
    devorq::info "O code review é feito via GitHub Actions quando um PR é aberto"
    devorq::info ""
    devorq::info "Para acionar manualmente:"
    devorq::info "  gh run list --workflow=code-review.yml"
    devorq::info "  gh run watch <run-id>"
}
