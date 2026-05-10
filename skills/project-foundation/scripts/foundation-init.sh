#!/usr/bin/env bash
# skills/project-foundation/scripts/foundation-init.sh
#
# Cria os 5 foundation docs (templates vazios) em .devorq/state/
# Chamado por devorq init automaticamente
#
# Uso: foundation-init.sh <project_dir> <project_name>

set -euo pipefail

FOUNDATION_DIR="${1:-.devorq/state}"
PROJECT_NAME="${2:-$(basename "$(pwd)")}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES_DIR="${SKILL_DIR}/templates"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Cores
RED='' GREEN='' YELLOW='' CYAN='' RESET=''

# Logging
log()   { echo "[DEVORQ] $*"; }
info()  { echo "${CYAN}[INFO]${RESET} $*"; }
success(){ echo "${GREEN}[OK]${RESET} $*"; }
warn()  { echo "${YELLOW}[WARN]${RESET} $*"; }
error() { echo "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# Validate templates exist
validate_templates() {
    local missing=0
    for doc in 5w2h premissas riscos requisitos restricoes; do
        local tpl="${TEMPLATES_DIR}/${doc}.json"
        if [ ! -f "$tpl" ]; then
            error "Template não encontrado: ${tpl}"
            missing=$((missing + 1))
        fi
    done
    [ $missing -eq 0 ]
}

# Populate template with project name and timestamp
populate_template() {
    local tpl="$1"
    local out="$2"
    local project="$3"
    local ts="$4"

    if command -v jq &>/dev/null; then
        # Usar --argfile para ler o template e update com --arg
        jq --arg project "$project" \
           --arg ts "$ts" \
           '
           .project = $project | .created_at = $ts | .updated_at = $ts
           ' "$tpl" > "$out"
    else
        # Fallback sem jq — substituição simples com sed
        sed "s/\"project\": \"\"/\"project\": \"$project\"/g; s/\"created_at\": \"\"/\"created_at\": \"$ts\"/g; s/\"updated_at\": \"\"/\"updated_at\": \"$ts\"/g" "$tpl" > "$out"
    fi
}

# Main
main() {
    info "Inicializando project foundation..."
    info "Diretório: ${FOUNDATION_DIR}"
    info "Projeto: ${PROJECT_NAME}"

    validate_templates

    mkdir -p "${FOUNDATION_DIR}"

    local count=0
    for doc in 5w2h premissas riscos requisitos restricoes; do
        local tpl="${TEMPLATES_DIR}/${doc}.json"
        local out="${FOUNDATION_DIR}/${doc}.json"

        if [ -f "$out" ]; then
            warn "${doc}.json já existe — pulando"
            continue
        fi

        populate_template "$tpl" "$out" "$PROJECT_NAME" "$TIMESTAMP"
        success "Criado: ${out}"
        count=$((count + 1))
    done

    if [ $count -eq 5 ]; then
        info "Todos os 5 foundation docs criados"
    else
        info "${count} de 5 foundation docs criados"
    fi
}

main "$@"
