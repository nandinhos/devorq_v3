#!/usr/bin/env bash
# lib/commands/lessons/migrate.sh — Migração de lições (schema update)

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# ============================================================
# LESSONS::MIGRATE
# Migra lições para novo schema
# ============================================================

lessons::migrate() {
    local lessons_dir="${DEVORQ_LESSONS_DIR:-${DEVORQ_DIR}/state/lessons}/captured"

    if [[ ! -d "$lessons_dir" ]]; then
        echo "[MIGRATE] Nenhuma lição para migrar"
        return $EXIT_SUCCESS
    fi

    echo "[MIGRATE] Adicionando campos ao schema das lições existentes..."
    local migrated=0

    while IFS= read -r file; do
        # Check if 'approved' field exists
        if ! grep -q '"approved"' "$file"; then
            # Add 'approved' field
            local temp_file
            temp_file=$(mktemp)
            sed 's/"solution": "\(.*\)"/"solution": "\1",\n  "approved": false/' "$file" > "$temp_file"
            mv "$temp_file" "$file"
            echo "  Migrado: $(basename "$file")"
            ((migrated++)) || true
        fi

    done < <(find "$lessons_dir" -name "*.json" -type f 2>/dev/null)

    echo "Lições migradas: $migrated"

    return $EXIT_SUCCESS
}

# Export for backward compatibility
export -f lessons::migrate 2>/dev/null || true
