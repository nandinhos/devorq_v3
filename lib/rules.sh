#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/rules.sh — DEVORQ Rules System v1.0
#
# Sistema de regras ENFORCED: carrega, valida e aplica regras em runtime.
# Hierarquia: global (DEVORQ_ROOT/rules/) > local (.devorq/rules/)
#
# Regras disponíveis:
#   - commit-convention: Convenções de commit
#   - brainstorm: Gates de captura durante brainstorming
#   - grill: Regras de sparring estruturado
#   - visual-verification: Gate de verificação visual
#
#用法:
#   devorq rules list                    Lista regras disponíveis
#   devorq rules check <rule>           Valida se regra está sendo seguida
#   devorq rules apply <rule>           Aplica regra ao projeto atual
#   devorq rules help <rule>            Mostra documentação da regra

set -euo pipefail

# ============================================================
# devorq::rules::init — Bootstrap do sistema de regras
# ============================================================
# Chamado pelo bin/devorq durante inicialização.
# Carrega todas as regras globais e locais (se existirem).

devorq::rules::init() {
    local project_root="${PWD}"
    local devorq_dir="${project_root}/.devorq"

    if ! declare -p DEVORQ_RULES &>/dev/null; then
        declare -gA DEVORQ_RULES
    fi

    if [ -d "$devorq_dir" ]; then
        mkdir -p "${devorq_dir}/rules" 2>/dev/null || true
    fi

    # Carregar regras globais (DEVORQ_ROOT/rules/)
    devorq::rules::load_global

    # Carregar regras locais (.devorq/rules/) — sobrescreve global se conflitar
    devorq::rules::load_local "${devorq_dir}/rules"

    # Definir variáveis de ambiente para skills
    export DEVORQ_RULES_DIR="${DEVORQ_ROOT}/rules"
    export DEVORQ_RULES_LOCAL_DIR="${devorq_dir}/rules"

    devorq::debug::log "Rules system initialized" 2>/dev/null || true
}

# ============================================================
# devorq::rules::load_global
# ============================================================
# Carrega regras do DEVORQ_ROOT/rules/ (global, apenas leitura)

devorq::rules::load_global() {
    local rules_dir="${DEVORQ_ROOT}/rules"

    if [ ! -d "$rules_dir" ]; then
        return 0
    fi

    for rule_file in "${rules_dir}"/*.md; do
        if [ -f "$rule_file" ]; then
            local rule_name
            rule_name="$(basename "$rule_file" .md)"
            DEVORQ_RULES["$rule_name"]="$(cat "$rule_file")"
            devorq::debug::log "Loaded global rule: $rule_name" 2>/dev/null || true
        fi
    done
}

# ============================================================
# devorq::rules::load_local
# ============================================================
# Carrega regras de .devorq/rules/ (local, sobrescreve global)

devorq::rules::load_local() {
    local local_rules_dir="${1:-}"

    if [ ! -d "$local_rules_dir" ]; then
        return 0
    fi

    for rule_file in "${local_rules_dir}"/*.md; do
        if [ -f "$rule_file" ]; then
            local rule_name
            rule_name="$(basename "$rule_file" .md)"
            # Local sobrescreve global
            DEVORQ_RULES["$rule_name"]="$(cat "$rule_file")"
            devorq::debug::log "Loaded local rule (override): $rule_name" 2>/dev/null || true
        fi
    done
}

# ============================================================
# devorq::rules::get
# ============================================================
# Retorna conteúdo de uma regra pelo nome

devorq::rules::get() {
    local rule_name="${1:-}"
    echo "${DEVORQ_RULES[$rule_name]:-}"
}

# ============================================================
# devorq::rules::exists
# ============================================================
# Retorna 0 se regra existe, 1 se não

devorq::rules::exists() {
    local rule_name="${1:-}"
    [ -n "${DEVORQ_RULES[$rule_name]:-}" ]
}

# ============================================================
# devorq::rules::list
# ============================================================
# Lista todas as regras disponíveis (global + local)

devorq::rules::list() {
    local rule_name

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  DEVORQ Rules — Lista de Regras"
    echo "═══════════════════════════════════════════"
    echo ""

    for rule_name in "${!DEVORQ_RULES[@]}"; do
        local content="${DEVORQ_RULES[$rule_name]}"
        local first_line
        first_line="$(echo "$content" | head -1)"
        echo "  $rule_name"
        echo "    $first_line"
        echo ""
    done

    echo "───────────────────────────────────────────"
    echo "Global: ${DEVORQ_ROOT}/rules/"
    echo "Local:  ${PWD}/.devorq/rules/"
    echo "───────────────────────────────────────────"
    echo ""
}

# ============================================================
# devorq::rules::check
# ============================================================
# Valida se uma regra está sendo seguida no projeto atual

devorq::rules::check() {
    local rule_name="${1:-}"
    local strict="${2:-false}"

    if ! devorq::rules::exists "$rule_name"; then
        echo "[ERROR] Regra '$rule_name' não encontrada."
        echo "Execute 'devorq rules list' para ver regras disponíveis."
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Validando regra: $rule_name"
    echo "═══════════════════════════════════════════"
    echo ""

    case "$rule_name" in
        commit-convention)
            devorq::rules::check_commit_convention "$strict"
            ;;
        brainstorm)
            devorq::rules::check_brainstorm "$strict"
            ;;
        grill)
            devorq::rules::check_grill "$strict"
            ;;
        visual-verification)
            devorq::rules::check_visual_verification "$strict"
            ;;
        *)
            echo "[WARN] Regra '$rule_name' não tem validador implementado."
            echo "Consulte a documentação:"
            echo "  devorq rules help $rule_name"
            ;;
    esac
}

# ============================================================
# devorq::rules::check_commit_convention
# ============================================================

devorq::rules::check_commit_convention() {
    local strict="${1:-false}"
    local problems=0

    echo "[CHECK] Verificando commits recentes..."

    if [ ! -d ".git" ]; then
        echo "[WARN] Não é um repositório Git. Pulando validação."
        return 0
    fi

    # Verificar últimos 10 commits
    local commits
    commits=$(git log --oneline -10 2>/dev/null || echo "")

    if [ -z "$commits" ]; then
        echo "[INFO] Nenhum commit recente encontrado."
        return 0
    fi

    echo "$commits" | while read -r line; do
        local commit_msg
        commit_msg=$(echo "$line" | sed 's/^[a-f0-9]* //')
        
        # Validar formato: escopo(fase): descrição
        if ! echo "$commit_msg" | grep -qE '^[a-z]+\([a-z]+\):'; then
            echo "[FAIL] Commit fora do formato: $commit_msg"
            ((problems++)) || true
        fi
    done

    echo ""

    if [ "$problems" -gt 0 ]; then
        echo "[FAIL] $problems commit(s) fora da convenção."
        echo "Consulte: rules/commit-convention.md"
        echo ""
        echo "Formato correto:"
        echo "  escopo(fase): descrição (detalhamento)"
        echo ""
        if [ "$strict" = "true" ]; then
            return 1
        fi
    else
        echo "[OK] Todos os commits seguem a convenção."
    fi

    return 0
}

# ============================================================
# devorq::rules::check_brainstorm
# ============================================================

devorq::rules::check_brainstorm() {
    local strict="${1:-false}"
    local devorq_dir="${PWD}/.devorq"

    echo "[CHECK] Verificando sessões de brainstorm..."

    if [ ! -d "${devorq_dir}/rules" ]; then
        echo "[WARN] .devorq/rules/ não existe. Nenhuma regra local."
    fi

    # Verificar se existe contexto de brainstorm
    local context_file="${devorq_dir}/state/context.json"
    if [ -f "$context_file" ]; then
        local brainstorm_count
        brainstorm_count=$(jq -r '.brainstorm_sessions // 0' "$context_file" 2>/dev/null || echo "0")
        echo "[INFO] Sesses de brainstorm registradas: $brainstorm_count"
    fi

    echo ""
    echo "[HINT] Para iniciar brainstorm: devorq brainstorm"
    echo ""

    return 0
}

# ============================================================
# devorq::rules::check_grill
# ============================================================

devorq::rules::check_grill() {
    local strict="${1:-false}"
    local devorq_dir="${PWD}/.devorq"

    echo "[CHECK] Verificando sessões de grill..."

    if [ ! -d "${devorq_dir}/rules" ]; then
        echo "[WARN] .devorq/rules/ não existe. Nenhuma regra local."
    fi

    # Verificar ADRs criados
    if [ -d "docs/adr" ]; then
        local adr_count
        adr_count=$(find docs/adr -name "*.md" 2>/dev/null | wc -l || echo "0")
        echo "[INFO] ADRs encontrados: $adr_count"
    else
        echo "[INFO] Nenhum docs/adr/ encontrado."
    fi

    echo ""
    echo "[HINT] Para iniciar grill: devorq grill <topic>"
    echo ""

    return 0
}

# ============================================================
# devorq::rules::check_visual_verification
# ============================================================

devorq::rules::check_visual_verification() {
    local strict="${1:-false}"

    echo "[CHECK] Verificando gate de verificação visual..."

    # Verificar se devorq verify está configurado
    if command -v devorq &>/dev/null; then
        echo "[OK] devorq está disponível."
    else
        echo "[FAIL] devorq não encontrado no PATH."
        return 1
    fi

    # Verificar se existe playwright config
    if [ -f "playwright.config.ts" ] || [ -f "playwright.config.js" ]; then
        echo "[OK] Playwright configurado."
    elif [ -d "playwright_tests" ]; then
        echo "[OK] Diretório playwright_tests encontrado."
    else
        echo "[WARN] Playwright não configurado. Use modo manual."
    fi

    echo ""

    return 0
}

# ============================================================
# devorq::rules::apply
# ============================================================
# Copia uma regra global para o projeto local

devorq::rules::apply() {
    local rule_name="${1:-}"

    if ! devorq::rules::exists "$rule_name"; then
        echo "[ERROR] Regra '$rule_name' não encontrada."
        return 1
    fi

    local devorq_dir="${PWD}/.devorq"
    local local_rules_dir="${devorq_dir}/rules"

    mkdir -p "$local_rules_dir"

    # Copiar regra (sobrescreve se existir)
    devorq::rules::get "$rule_name" > "${local_rules_dir}/${rule_name}.md"

    echo "[OK] Regra '$rule_name' aplicada ao projeto."
    echo "Local: ${local_rules_dir}/${rule_name}.md"

    # Re-carregar com nova regra local
    DEVORQ_RULES["$rule_name"]="$(cat "${local_rules_dir}/${rule_name}.md")"
}

# ============================================================
# devorq::rules::help
# ============================================================
# Mostra documentação de uma regra

devorq::rules::help() {
    local rule_name="${1:-}"

    if ! devorq::rules::exists "$rule_name"; then
        echo "[ERROR] Regra '$rule_name' não encontrada."
        echo "Execute 'devorq rules list' para ver regras disponíveis."
        return 1
    fi

    echo ""
    devorq::rules::get "$rule_name"
    echo ""
}

# ============================================================
# devorq::cmd_rules — Comando principal
# ============================================================

devorq::cmd_rules() {
    local action="${1:-}"
    local rule_name="${2:-}"

    case "$action" in
        list)
            devorq::rules::list
            ;;
        check)
            devorq::rules::check "$rule_name" "${3:-false}"
            ;;
        apply)
            devorq::rules::apply "$rule_name"
            ;;
        help)
            devorq::rules::help "$rule_name"
            ;;
        init)
            devorq::rules::init
            ;;
        install-hook)
            devorq::rules::install_commit_msg_hook
            ;;
        uninstall-hook)
            devorq::rules::uninstall_commit_msg_hook
            ;;
        bootstrap)
            devorq::rules::bootstrap_project "${PWD}"
            ;;
        "")
            echo "Uso: devorq rules <action> [args]"
            echo ""
            echo "Ações:"
            echo "  list                      Lista todas as regras"
            echo "  check <rule> [--strict]   Valida se regra está sendo seguida"
            echo "  apply <rule>              Copia regra global para .devorq/rules/"
            echo "  bootstrap                 Aplica regras essenciais + commit-msg hook"
            echo "  install-hook              Instala git commit-msg hook (formato commit)"
            echo "  uninstall-hook            Remove git commit-msg hook"
            echo "  help <rule>               Mostra documentação da regra"
            echo ""
            echo "Exemplos:"
            echo "  devorq rules list"
            echo "  devorq rules bootstrap"
            echo "  devorq rules check commit-convention"
            echo "  devorq rules apply commit-convention"
            ;;
        *)
            echo "[ERROR] Ação '$action' desconhecida."
            echo "Execute 'devorq rules' para ajuda."
            return 1
            ;;
    esac
}

# ============================================================
# devorq::rules::enforce_commit
# ============================================================
# Valida mensagem de commit antes de executar git commit
# Chamado pelo pre-commit hook

devorq::rules::enforce_commit() {
    local commit_msg="${1:-}"

    if [ -z "$commit_msg" ]; then
        return 0  # Sem mensagem, deixa git reclamar
    fi

    # Validar formato: escopo(fase): descrição
    if ! echo "$commit_msg" | grep -qE '^[a-z]+\([a-z]+\):'; then
        echo ""
        echo "[DEVORQ RULES] Mensagem de commit fora do formato."
        echo ""
        echo "Formato esperado:"
        echo "  escopo(fase): descrição (detalhamento)"
        echo ""
        echo "Escopos válidos:"
        echo "  core | models | services | livewire | notifications | routes | config |"
        echo "  database | tests | bdd | gates | unify | docs | debug | spec | lessons |"
        echo "  compact | vps | hub | context"
        echo ""
        echo "Fases válidas:"
        echo "  impl | test | verify | docs | unify | debug | fix | refactor"
        echo ""
        echo "Consulte: rules/commit-convention.md"
        echo ""
        echo "Abortar commit."
        return 1
    fi

    return 0
}

# ============================================================
# devorq::rules::bootstrap_project
# ============================================================

devorq::rules::bootstrap_project() {
    local project_root="${1:-$PWD}"

    if [[ ! -d "${project_root}/.devorq" ]]; then
        echo "[WARN] .devorq/ não encontrado — execute 'devorq init' primeiro"
        return 1
    fi

    (
        cd "$project_root"
        devorq::rules::init
        mkdir -p ".devorq/rules"

        for rule in commit-convention manual-commit; do
            if [[ -f "${DEVORQ_ROOT}/rules/${rule}.md" ]]; then
                cp "${DEVORQ_ROOT}/rules/${rule}.md" ".devorq/rules/${rule}.md"
                DEVORQ_RULES["$rule"]="$(cat ".devorq/rules/${rule}.md")"
                echo "[OK] Regra aplicada: ${rule}"
            fi
        done

        if [[ -d ".git" ]]; then
            devorq::rules::install_commit_msg_hook
        else
            echo "[INFO] Sem .git — commit-msg hook não instalado"
        fi
    )

    echo "[OK] Bootstrap de regras concluído"
}

# ============================================================
# devorq::rules::install_commit_msg_hook
# ============================================================

devorq::rules::install_commit_msg_hook() {
    local project_root="${PWD}"
    local hooks_dir="${project_root}/.git/hooks"

    mkdir -p "$hooks_dir"

    cat > "${hooks_dir}/commit-msg" << 'HOOK'
#!/usr/bin/env bash
# DEVORQ commit-msg hook — valida rules/commit-convention.md

COMMIT_MSG_FILE="$1"
COMMIT_MSG="$(head -1 "$COMMIT_MSG_FILE")"

if [[ "$COMMIT_MSG" =~ ^Merge|^Revert|^fixup!|^squash! ]]; then
    exit 0
fi

if ! echo "$COMMIT_MSG" | grep -qE '^[a-z]+\([a-z]+\):'; then
    echo ""
    echo "[DEVORQ RULES] Mensagem de commit fora do formato."
    echo ""
    echo "Formato esperado:"
    echo "  escopo(fase): descrição (detalhamento)"
    echo ""
    echo "Use: devorq commit --story <id>"
    echo "Consulte: devorq rules help commit-convention"
    echo ""
    exit 1
fi

exit 0
HOOK

    chmod +x "${hooks_dir}/commit-msg"

    echo "[OK] commit-msg hook instalado."
    echo "Local: ${hooks_dir}/commit-msg"
}

# ============================================================
# devorq::rules::uninstall_commit_msg_hook
# ============================================================

devorq::rules::uninstall_commit_msg_hook() {
    local hooks_dir="${PWD}/.git/hooks"

    if [[ -f "${hooks_dir}/commit-msg" ]] && grep -q "DEVORQ commit-msg hook" "${hooks_dir}/commit-msg" 2>/dev/null; then
        rm "${hooks_dir}/commit-msg"
        echo "[OK] commit-msg hook removido."
    else
        echo "[INFO] commit-msg hook DEVORQ não estava instalado."
    fi
}

# ============================================================
# devorq::rules::install_pre_commit_hook (legado)
# ============================================================

devorq::rules::install_pre_commit_hook() {
    devorq::warn "install_pre_commit_hook obsoleto — use: devorq rules install-hook"
    devorq::rules::install_commit_msg_hook
}

# ============================================================
# devorq::rules::uninstall_pre_commit_hook (legado)
# ============================================================

devorq::rules::uninstall_pre_commit_hook() {
    devorq::rules::uninstall_commit_msg_hook
}