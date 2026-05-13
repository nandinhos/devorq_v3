#!/usr/bin/env bash
# lib/commands/context.sh — DEVORQ Context Commands
#
# Comandos: context, compact
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

context::help() {
    cat << 'EOF'
CONTEXT COMMANDS:
  context                 Mostrar contexto atual
  context lint           Validar contexto
  context stats          Estatísticas de contexto
  context pack           Comprimir contexto
  context merge          Merge contextos
  context set <key> <val>  Definir campo
  context clear          Limpar contexto
  compact                Gerar handoff para próxima sessão
EOF
}

# ============================================================
# context
# ============================================================

devorq::cmd_context() {
    local ctx_file="${PWD}/.devorq/state/context.json"
    local sub="${1:-}"

    source "${DEVORQ_LIB}/context.sh" 2>/dev/null || {
        # Fallback: apenas mostra arquivo
        if [ ! -f "$ctx_file" ]; then
            devorq::warn "nenhum .devorq/state/context.json encontrado"
            devorq::info "Execute 'devorq init' primeiro"
            return 0
        fi
        cat "$ctx_file"
        return 0
    }

    case "$sub" in
        lint)   ctx_lint ;;
        stats)  ctx_stats ;;
        pack)   ctx_pack "${2:-}" ;;
        merge)  ctx_merge "${2:-}" "${3:-}" ;;
        set)    ctx_set "${2:-}" "${3:-}" ;;
        clear)  ctx_clear ;;
        "")
            # Default: mostra stats e contexto
            if [ ! -f "$ctx_file" ]; then
                devorq::warn "nenhum context.json encontrado - iniciando contexto"
                ctx_set "project" "${PWD##*/}"
                ctx_set "stack" "[]"
                ctx_set "intent" ""
            fi
            ctx_stats
            echo ""
            cat "$ctx_file"
            ;;
        *)       echo "Uso: devorq context [lint|stats|pack|merge|set|clear]"; return 1 ;;
    esac
}

# ============================================================
# compact
# ============================================================

devorq::cmd_compact() {
    devorq::info "Gerando contexto compactado para handoff..."
    source "${DEVORQ_LIB}/compact.sh" 2>/dev/null || true
    compact::generate 2>/dev/null || {
        devorq::warn "lib/compact.sh nao disponivel - usando contexto direto"
        cat "${PWD}/.devorq/state/context.json" 2>/dev/null || echo "{}"
    }
}
