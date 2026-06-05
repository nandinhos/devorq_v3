#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2086
# lib/lessons.sh - DEVORQ Lessons (agregador)
#
# Story 3 - dogfooding: refatorado em 4 modulos por responsabilidade.
# Original: arquivo unico com 1045 LOC. Agora:
#   lib/lessons/crud.sh    - capture, list, apply, export, from_unify
#                            + devorq::sanitize_input (helper)
#   lib/lessons/search.sh  - approve, help
#   lib/lessons/validate.sh - validate, _fuzzy_check, _suggest_tags
#   lib/lessons/sync.sh    - sync_vps, compile, migrate
#
# lessons::search vive no agregador (F-06 grep injection test extrai via sed).
# Os 3 modulos sao sourceados primeiro; a definicao abaixo sobrescreve qualquer
# copia vinda de search.sh. Mantem 100% das funcoes publicas acessiveis.

# Exit codes (preservados do header original)
[ -z "${EXIT_SUCCESS:-}" ] && readonly EXIT_SUCCESS=0
[ -z "${EXIT_ERROR:-}" ] && readonly EXIT_ERROR=1
[ -z "${EXIT_INVALID_ARGS:-}" ] && readonly EXIT_INVALID_ARGS=2
[ -z "${EXIT_NOT_FOUND:-}" ] && readonly EXIT_NOT_FOUND=3
[ -z "${EXIT_VALIDATION_FAILED:-}" ] && readonly EXIT_VALIDATION_FAILED=4

# Cores (sem ANSI - compatibilidade maxima)
GREEN='' CYAN='' RED='' YELLOW='' RESET='' BOLD=''

# Variaveis de ambiente (preservadas do header original)
DEVORQ_LESSONS_DIR="${DEVORQ_LESSONS_DIR:-${PWD}/.devorq/state/lessons}"
DEVORQ_HUB_HOST="${DEVORQ_HUB_HOST:-}"
DEVORQ_HUB_PORT="${DEVORQ_HUB_PORT:-5432}"

# devorq::sanitize_input - definido em lib/lessons/crud.sh
# (helper usado por lessons::capture; coesao mantida no modulo CRUD)
# crud.sh e sourceado abaixo.


# Carrega os 3 modulos por responsabilidade
# shellcheck source=lib/lessons/crud.sh
source "${BASH_SOURCE[0]%/*}/lessons/crud.sh"
# shellcheck source=lib/lessons/search.sh
source "${BASH_SOURCE[0]%/*}/lessons/search.sh"
# shellcheck source=lib/lessons/validate.sh
source "${BASH_SOURCE[0]%/*}/lessons/validate.sh"
# shellcheck source=lib/lessons/sync.sh
source "${BASH_SOURCE[0]%/*}/lessons/sync.sh"

# ============================================================
# lessons::search — wrapper no agregador (F-06 test compat)
# Implementacao real abaixo (mantida identica ao codigo original).
# A definicao aqui sobrescreve a copia vinda de search.sh (se houver).
# ============================================================

lessons::search() {
    # Validação
    if [[ -z "${1:-}" ]]; then
        echo "[ERROR] Query e obrigatoria" >&2
        return $EXIT_INVALID_ARGS
    fi

    local query="$1"
    local dir="${DEVORQ_LESSONS_DIR}/captured"

    if [ ! -d "$dir" ]; then
        echo "Nenhuma lição capturada ainda."
        return 0
    fi

    echo -e "${CYAN}[LESSONS]${RESET} Busca: $query"
    echo ""

    # Busca local via grep nos arquivos JSON
    local results
    # PATCH F-06: -F (literal) impede regex injection, -- encerra opcoes
    results=$(grep -l -iF -- "$query" "$dir"/*.json 2>/dev/null || true)

    if [ -z "$results" ]; then
        echo "Nenhuma lição encontrada."
        return 0
    fi

    while read -r f; do
        [ -z "$f" ] && continue
        if command -v jq &>/dev/null; then
            local title validated ts
            title=$(jq -r '.title' "$f" 2>/dev/null || echo "???")
            validated=$(jq -r '.validated' "$f" 2>/dev/null || echo "false")
            ts=$(jq -r '.timestamp' "$f" 2>/dev/null || echo "???")
        else
            local title validated ts
            title=$(grep '"title"' "$f" | cut -d'"' -f4 || echo "???")
            validated=$(grep '"validated"' "$f" | cut -d' ' -f2 | tr -d ',' || echo "false")
            ts=$(grep '"timestamp"' "$f" | cut -d'"' -f4 || echo "???")
        fi
        echo -e "  ${GREEN}${title}${RESET} [$ts] ${validated:+/}"
    done <<< "$results"
}
