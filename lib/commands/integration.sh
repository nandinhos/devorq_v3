#!/usr/bin/env bash
# lib/commands/integration.sh — DEVORQ Integration Commands
#
# Comandos: sync, vps, context7
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

integration::help() {
    cat << 'EOF'
INTEGRATION COMMANDS:
  sync push|pull            Sincronizar lições com HUB
  vps check                Testar conexão VPS
  context7 install|detect|check  Context7 API
EOF
}

# ============================================================
# vps
# ============================================================

devorq::cmd_vps() {
    local sub="${1:-check}"
    case "$sub" in
        check)
            source "${DEVORQ_LIB}/vps.sh" 2>/dev/null || true
            vps::check 2>/dev/null || devorq::info "VPS check: (lib não disponível)"
            ;;
        *)
            devorq::error "Uso: devorq vps check"
            ;;
    esac
}

# ============================================================
# context7
# ============================================================

devorq::cmd_context7() {
    local sub="${1:-help}"
    case "$sub" in
        install)
            source "${DEVORQ_LIB}/context7.sh" 2>/dev/null || true
            if declare -f ctx7_install &>/dev/null; then
                ctx7_install "${2:-}"
            else
                devorq::error "lib/context7.sh não disponível"
            fi
            ;;
        detect)
            source "${DEVORQ_LIB}/context7.sh" 2>/dev/null || true
            if declare -f ctx7_detect &>/dev/null; then
                local method; method=$(ctx7_detect)
                devorq::info "Método disponível: $method"
            else
                devorq::error "lib/context7.sh não disponível"
            fi
            ;;
        check)
            source "${DEVORQ_LIB}/context7.sh" 2>/dev/null || true
            if declare -f ctx7_check &>/dev/null; then
                ctx7_check
            else
                devorq::error "lib/context7.sh não disponível"
            fi
            ;;
        help|--help|-h|"")
            devorq::info "Uso: devorq context7 install|detect|check"
            devorq::info "  install    Instalar Context7 (cli|mcp|api)"
            devorq::info "  detect     Detectar método disponível"
            devorq::info "  check      Testar Context7"
            ;;
        *)
            devorq::error "Uso: devorq context7 install|detect|check"
            ;;
    esac
}

# ============================================================
# sync
# ============================================================

devorq::cmd_sync() {
    local action="${1:-}"
    [ -z "$action" ] && devorq::error "Uso: devorq sync push|pull"

    case "$action" in
        push|pull)
            local script="${DEVORQ_ROOT}/scripts/sync-${action}.py"
            if [ ! -f "$script" ]; then
                devorq::error "Script sync-${action}.py não encontrado"
            fi

            if command -v python3 &>/dev/null; then
                python3 "$script" "$@"
            else
                devorq::error "python3 não disponível"
            fi
            ;;
        *)
            devorq::error "Uso: devorq sync push|pull"
            ;;
    esac
}
