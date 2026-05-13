#!/usr/bin/env bash
# lib/commands/skills.sh — DEVORQ Skills Commands
#
# Comandos: skills
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

skills::help() {
    cat << 'EOF'
SKILLS COMMANDS:
  skills list              Listar skills disponíveis
  skills load <name>       Carregar skill específica
EOF
}

# ============================================================
# skills
# ============================================================

devorq::cmd_skills() {
    local sub="${1:-list}"
    case "$sub" in
        list)
            echo -e "${CYAN}[SKILLS]${RESET}"
            echo ""

            # Skills do framework (hardcoded)
            echo "Framework skills:"
            echo "  systemic-debugging, github-code-review, github-pr-workflow"
            echo "  plan, subagent-driven-development, test-driven-development"
            echo "  scope-guard, env-context, ddd-deep-domain"
            echo ""

            # Skills geradas (do index)
            local index_file="skills/.index.md"
            if [ -f "$index_file" ]; then
                echo "Skills geradas:"
                grep "^| " "$index_file" | grep -v "^| Skill" | grep -v "^|--" | while IFS='|' read -r _ name desc date _; do
                    name=$(echo "$name" | xargs)
                    desc=$(echo "$desc" | xargs)
                    [ -z "$name" ] && continue
                    echo -e "  ${GREEN}$name${RESET} — $desc ($date)"
                done
            else
                echo "Skills geradas: nenhuma (use 'devorq lessons compile' para gerar)"
            fi

            echo ""
            devorq::info "Use 'skill_view <name>' no Hermes Agent para carregar"
            ;;
        load)
            local name="${2:-}"
            [ -z "$name" ] && devorq::error "Uso: devorq skills load <name>"
            # Verificar se existe
            local skill_dir="${DEVORQ_ROOT}/skills/${name}"
            if [ -d "$skill_dir" ]; then
                devorq::success "Skill '$name' encontrada em: $skill_dir"
            else
                devorq::warn "Skill '$name' não encontrada no framework"
            fi
            devorq::info "Use 'skill_view $name' no Hermes Agent para carregar"
            ;;
        *)
            devorq::error "Uso: devorq skills list|load <name>"
            ;;
    esac
}
