#!/usr/bin/env bash
# lib/commands/lessons/list.sh — Listagem de lições

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# ============================================================
# LESSONS::LIST
# Lista todas as lições capturadas
# ============================================================

lessons::list() {
    # Show help if requested
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        cat << 'HELPEOF'
USAGE: devorq lessons list [filter]

FILTERS:
  all        Listar todas as lições (default)
  approved   Listar apenas lições aprovadas
  pending    Listar apenas lições pendentes
  validated  Listar lições validadas
  compiled   Listar lições compiladas

EXAMPLES:
  devorq lessons list
  devorq lessons list approved
HELPEOF
        return 0
    fi

    local filter="${1:-all}"

    local lessons_dir="${DEVORQ_LESSONS_DIR:-${DEVORQ_DIR}/state/lessons}/captured"
    if [[ ! -d "$lessons_dir" ]]; then
        echo "[LESSONS] Nenhuma lição capturada ainda"
        return $EXIT_SUCCESS
    fi

    # Count lessons
    local total approved_count pending_count
    total=$(find "$lessons_dir" -name "*.json" 2>/dev/null | wc -l)
    approved_count=$(find "$lessons_dir" -name "*.json" -exec grep -l '"approved": true' {} \; 2>/dev/null | wc -l)
    pending_count=$((total - approved_count))

    echo "[LESSONS] Total: $total | Filtro: $filter"
    echo ""

    # List by filter
    local status_icon
    local count=0

    while IFS= read -r file; do
        local id
        id=$(basename "$file" .json)

        local title approved
        title=$(grep '"title"' "$file" | head -1 | sed 's/.*"title": "\(.*\)".*/\1/')
        approved=$(grep '"approved": true' "$file" >/dev/null && echo "[✓]" || echo "[ ]")

        # Apply filter
        if [[ "$filter" == "approved" ]] && ! grep -q '"approved": true' "$file"; then
            continue
        fi
        if [[ "$filter" == "pending" ]] && grep -q '"approved": true' "$file"; then
            continue
        fi

        echo "  $approved $id"
        echo "       $title"
        echo ""
        ((count++)) || true

    done < <(find "$lessons_dir" -name "*.json" -type f 2>/dev/null | sort -r)

    echo "Mostrando $count de $total lição(ões)"

    return $EXIT_SUCCESS
}

# Export for backward compatibility
export -f lessons::list 2>/dev/null || true
