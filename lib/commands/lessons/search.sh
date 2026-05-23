#!/usr/bin/env bash
# lib/commands/lessons/search.sh — Busca de lições

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# ============================================================
# LESSONS::SEARCH
# Busca lições por termo
# ============================================================

lessons::search() {
    local query="${1:-}"

    if [[ -z "$query" ]]; then
        echo "[ERROR] Query de busca é obrigatória" >&2
        return $EXIT_INVALID_ARGS
    fi

    local lessons_dir="${DEVORQ_LESSONS_DIR:-${DEVORQ_DIR}/state/lessons}/captured"
    if [[ ! -d "$lessons_dir" ]]; then
        echo "[LESSONS] Busca: $query"
        echo "Nenhuma lição capturada ainda"
        return $EXIT_SUCCESS
    fi

    echo "[LESSONS] Busca: $query"
    echo ""

    local found=0

    while IFS= read -r file; do
        local id title problem solution
        id=$(basename "$file" .json)
        title=$(grep '"title"' "$file" | head -1 | sed 's/.*"title": "\(.*\)".*/\1/')
        problem=$(grep '"problem"' "$file" | head -1 | sed 's/.*"problem": "\(.*\)".*/\1/')
        solution=$(grep '"solution"' "$file" | head -1 | sed 's/.*"solution": "\(.*\)".*/\1/')

        # Simple grep search
        if grep -iq "$query" "$file"; then
            echo "$title [$(date -r "$file" +%Y%m%d)]"
            echo "  📁 $id"
            echo ""
            ((found++)) || true
        fi

    done < <(find "$lessons_dir" -name "*.json" -type f 2>/dev/null)

    if [[ $found -eq 0 ]]; then
        echo "Nenhuma lição encontrada"
    else
        echo "Encontrada(s): $found lição(ões)"
    fi

    return $EXIT_SUCCESS
}

# Export for backward compatibility
export -f lessons::search 2>/dev/null || true
