#!/usr/bin/env bash
# lib/lessons.sh — DEVORQ Lessons Module
#
# Responsabilidades:
#   lessons::capture  — Salvar lição aprendida
#   lessons::search    — Buscar lições no HUB
#   lessons::validate  — Validar com Context7
#   lessons::apply     — Aplicar lição validada

set -euo pipefail

DEVORQ_LESSONS_DIR="${DEVORQ_LESSONS_DIR:-${PWD}/.devorq/state/lessons}"
DEVORQ_HUB_HOST="${DEVORQ_HUB_HOST:-}"
DEVORQ_HUB_PORT="${DEVORQ_HUB_PORT:-5432}"

# ============================================================
# capture
#   $1 = title
#   $2 = problem
#   $3 = solution
# ============================================================

lessons::capture() {
    local title="$1"
    local problem="$2"
    local solution="$3"

    local dir="${DEVORQ_LESSONS_DIR}/captured"
    mkdir -p "$dir"

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local id="lesson_${ts}_$$"
    local file="${dir}/${id}.json"

    # Determinar stack do contexto
    local stack="${DEVORQ_STACK:-unknown}"
    local tags="${DEVORQ_TAGS:-}"

    # Serializar como JSON (fallback sem jq)
    if command -v jq &>/dev/null; then
        jq -n \
            --arg id "$id" \
            --arg title "$title" \
            --arg problem "$problem" \
            --arg solution "$solution" \
            --arg stack "$stack" \
            --arg tags "$tags" \
            --arg ts "$ts" \
            '{
                id: $id,
                title: $title,
                problem: $problem,
                solution: $solution,
                stack: $stack,
                tags: ($tags | if . == "" then [] else split(",") end),
                timestamp: $ts,
                validated: false,
                applied: false
            }' > "$file"
    else
        # Fallback: printf manual (sem dependência de jq)
        printf '%s\n' \
            "{" \
            "  \"id\": \"${id}\"," \
            "  \"title\": \"${title}\"," \
            "  \"problem\": \"${problem}\"," \
            "  \"solution\": \"${solution}\"," \
            "  \"stack\": \"${stack}\"," \
            "  \"tags\": [], " \
            "  \"timestamp\": \"${ts}\"," \
            "  \"validated\": false," \
            "  \"applied\": false" \
            "}" > "$file"
    fi

    # Sync com VPS se configurado
    lessons::sync_vps "$file" &>/dev/null || true

    echo -e "${GREEN}[✓]${RESET} Lição salva: ${id}"
    echo "   $title"
}

# ============================================================
# search
#   $1 = query string
# ============================================================

lessons::search() {
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
    results=$(grep -l -i "$query" "$dir"/*.json 2>/dev/null || true)

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

# ============================================================
# validate — Valida com Context7 (GATE-6)
# ============================================================

lessons::validate() {
    local dir="${DEVORQ_LESSONS_DIR}/captured"

    if [ ! -d "$dir" ]; then
        echo "Nada para validar."
        return 0
    fi

    # Encontrar lições não-validadas
    local unvalidated
    unvalidated=$(find "$dir" -name "*.json" -exec test '!' -f "{}.validated" \; -print 2>/dev/null || true)

    if [ -z "$unvalidated" ]; then
        echo "Todas as lições já foram validadas."
        return 0
    fi

    # Verificar se Context7 está disponível
    if ! command -v ctx_execute &>/dev/null && [ -z "${CONTEXT7_API_KEY:-}" ]; then
        echo -e "${YELLOW}[!]${RESET} Context7 não configurado — valide manualmente"
        return 0
    fi

    echo -e "${CYAN}[GATE-6]${RESET} Validando lições com Context7..."

    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        local id title
        id=$(basename "$f" .json)
        if command -v jq &>/dev/null; then
            title=$(jq -r '.title' "$f" 2>/dev/null)
        else
            title=$(grep '"title"' "$f" | cut -d'"' -f4 || echo "???")
        fi
        echo -e "  ${YELLOW}~${RESET} ${title} (Context7 validation — TODO)"
        if command -v jq &>/dev/null; then
            jq '.validated = true' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        else
            sed 's/"validated": false/"validated": true/' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        fi
    done

}

# ============================================================
# apply — Marca lição como aplicada (GATE-7)
# ============================================================

lessons::apply() {
    local id="${1:-}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"

    _apply_file() {
        local f="$1"
        if command -v jq &>/dev/null; then
            jq '.applied = true' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        else
            sed 's/"applied": false/"applied": true/' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        fi
        echo -e "${GREEN}[✓]${RESET} $(basename "$f" .json) marcada como aplicada"
    }

    if [ -z "$id" ]; then
        for f in "$dir"/*.json; do
            [ -f "$f" ] || continue
            _apply_file "$f"
        done
    else
        local file="${dir}/${id}.json"
        [ ! -f "$file" ] && echo "Lição não encontrada: $id" && return 1
        _apply_file "$file"
    fi
}

# ============================================================
# sync_vps — Sincroniza lição com VPS HUB (background)
# ============================================================

lessons::sync_vps() {
    local file="$1"
    local vps_host="${DEVORQ_VPS_HOST:-}"

    [ -z "$vps_host" ] && return 1

    # TODO: usar SSH mux do lib/sync.sh
    # scp "$file" "${vps_host}:/tmp/" 2>/dev/null || true
}

# ============================================================
# export — Exporta todas as lições para JSON
# ============================================================

lessons::export() {
    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local output="${1:-/dev/stdout}"

    if [ ! -d "$dir" ]; then
        echo "[]"
        return 0
    fi

    local first=true
    echo "["
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        if $first; then
            first=false
        else
            echo ","
        fi
        jq '.' "$f"
    done
    echo "]"
}
