#!/usr/bin/env bash
# lib/commands/workflow.sh — DEVORQ Workflow Commands
#
# Comandos: init, test, flow, gate
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

workflow::help() {
    cat << 'EOF'
WORKFLOW COMMANDS:
  init                       Inicializar .devorq/ no projeto
  test                       Testar estrutura do projeto
  flow "<intent>"           Workflow completo (gates 1-7)
  gate [0-7]                Executar gate específico
EOF
}

# ============================================================
# init
# ============================================================

devorq::cmd_init() {
    local project_root="${PWD}"
    local devorq_dir="${project_root}/.devorq"

    if [ -d "$devorq_dir" ]; then
        devorq::warn "Ja existe .devorq/ em ${project_root}"
    else
    mkdir -p "$devorq_dir/state/lessons/captured"
    mkdir -p "$devorq_dir/skills"
    mkdir -p "$devorq_dir/rules"

    if [ -f "${DEVORQ_ROOT}/.devorq/commit_convention.json" ]; then
        cp "${DEVORQ_ROOT}/.devorq/commit_convention.json" "$devorq_dir/"
    fi

    cat > "$devorq_dir/state/context.json" << 'EOFC'
{
  "project": "",
  "stack": [],
  "intent": "",
  "success_criteria": [],
  "commit_mode": "manual",
  "gates_completed": [],
  "last_updated": ""
}
EOFC

    cat > "$devorq_dir/state/session.json" << 'EOFS'
{
  "started_at": "",
  "ended_at": "",
  "handoff_id": null,
  "summary": ""
}
EOFS

    devorq::success "Inicializado .devorq/ em ${project_root}"
    devorq::info "Edite .devorq/state/context.json com project, stack e intent"

    local foundation_init="${DEVORQ_ROOT}/skills/project-foundation/scripts/foundation-init.sh"
    if [ -f "$foundation_init" ]; then
        if bash "$foundation_init" "$devorq_dir/state" "$(basename "$project_root")" 2>/dev/null; then
            devorq::info "Foundation docs criados em .devorq/state/"
            devorq::info "Execute: devorq foundation create para preencher"
        fi
    fi
    fi

    # Bootstrap regras + commit-msg hook (idempotente)
    if [ -f "${DEVORQ_LIB}/rules.sh" ]; then
        # shellcheck disable=SC1091
        source "${DEVORQ_LIB}/rules.sh"
        if declare -f devorq::rules::bootstrap_project &>/dev/null; then
            devorq::rules::bootstrap_project "$project_root" || devorq::warn "Bootstrap de regras falhou parcialmente"
        fi
    fi
}

# ============================================================
# test
# ============================================================

devorq::cmd_test() {
    devorq::info "Testando estrutura..."
    local errors=0

    bash -n "${DEVORQ_ROOT}/bin/devorq" 2>/dev/null || {
        devorq::warn "bin/devorq: syntax error"
        errors=$((errors+1))
    }
    
    for f in "${DEVORQ_LIB}"/*.sh; do
        bash -n "$f" 2>/dev/null || {
            devorq::warn "$f: syntax error"
            errors=$((errors+1))
        }
    done

    [ -f "${DEVORQ_LIB}/lessons.sh" ] || {
        devorq::warn "lib/lessons.sh: not found"
        errors=$((errors+1))
    }
    [ -f "${DEVORQ_LIB}/gates.sh" ] || {
        devorq::warn "lib/gates.sh: not found"
        errors=$((errors+1))
    }
    [ -f "${DEVORQ_LIB}/compact.sh" ] || {
        devorq::warn "lib/compact.sh: not found"
        errors=$((errors+1))
    }
    [ -f "${DEVORQ_LIB}/vps.sh" ] || {
        devorq::warn "lib/vps.sh: not found"
        errors=$((errors+1))
    }

    if [ $errors -eq 0 ]; then
        devorq::success "Estrutura OK (devorq v${DEVORQ_VERSION})"
    else
        devorq::error "$errors erro(s) encontrado(s)"
    fi
}

# ============================================================
# flow
# ============================================================

devorq::cmd_flow() {
    local intent="${1:-}"
    [ -z "$intent" ] && devorq::error "Uso: devorq flow \"<intent>\""

    devorq::log "Intent: ${intent}"
    devorq::log "Executando gates 0 -> 0.5 -> 1-7..."

    for gate in 0 0.5 1 2 3 4 5 6 7; do
        devorq::info "--- GATE ${gate} ---"
        if ! devorq::cmd_gate "$gate" 2>&1; then
            devorq::error "Gate ${gate} falhou"
        fi
    done

    devorq::success "Flow completo!"
}

# ============================================================
# gate
# ============================================================

devorq::cmd_gate() {
    local gate_num="${1:-}"
    local lib_gate="${DEVORQ_LIB}/gates.sh"

    if [ ! -f "$lib_gate" ]; then
        devorq::warn "lib/gates.sh nao encontrado - gate simulado"
        devorq::info "GATE-${gate_num}: (sem lib/gates.sh - implementar)"
        return 0
    fi

    source "$lib_gate"
    
    local rv=0
    case "$gate_num" in
        0)   gate_0;   rv=$? ;;
        0.5) gate_0_5; rv=$? ;;
        1)   gate_1;   rv=$? ;;
        2)   gate_2;   rv=$? ;;
        3)   gate_3;   rv=$? ;;
        4)   gate_4;   rv=$? ;;
        5)   gate_5;   rv=$? ;;
        5.5) gate_5_5; rv=$? ;;
        6)   gate_6;   rv=$? ;;
        7)   gate_7;   rv=$? ;;
        *)   devorq::fail "Gate invalido: $gate_num (aceitos: 0, 0.5, 1-7, 5.5)"; return 1 ;;
    esac
    
    return $rv
}
