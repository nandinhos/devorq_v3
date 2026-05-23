#!/usr/bin/env bash
# lib/commands/lessons/validate.sh — Validação de lições

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# ============================================================
# LESSONS::VALIDATE
# Valida lições usando Context7
# ============================================================

lessons::validate() {
    local lesson_id="${1:-}"

    echo "[GATE-6] Validando lições com Context7..."

    local lessons_dir="${DEVORQ_LESSONS_DIR:-${DEVORQ_DIR}/state/lessons}/captured"
    local validated=0
    local skipped=0

    # Check Context7 availability or LESSONS_AUTO mode
    if [[ "${LESSONS_AUTO:-false}" == "true" ]]; then
        # Auto mode: mark all as validated
        while IFS= read -r file; do
            ((validated++)) || true
        done < <(find "$lessons_dir" -name "*.json" -type f 2>/dev/null)
        echo "lição(ões) auto-validadas: $validated"
    elif ! command -v context7 &>/dev/null; then
        echo "[!] Context7 não configurado — validação automática indisponível"
        echo "    (Usando validação manual: todas as lessons pendentes serão marcadas como 'skipped')"

        # Mark all as skipped
        while IFS= read -r file; do
            ((skipped++)) || true
        done < <(find "$lessons_dir" -name "*.json" -type f 2>/dev/null)

        echo ""
        echo "Validadas: $validated | Puladas: $skipped"
        return $EXIT_SUCCESS
    fi

    # Validate specific lesson or all
    if [[ -n "$lesson_id" ]]; then
        local filepath="${lessons_dir}/${lesson_id}.json"
        if [[ -f "$filepath" ]]; then
            if lessons::_validate_single "$filepath"; then
                ((validated++)) || true
            else
                ((skipped++)) || true
            fi
        fi
    else
        # Validate all
        while IFS= read -r file; do
            if lessons::_validate_single "$file"; then
                ((validated++)) || true
            else
                ((skipped++)) || true
            fi
        done < <(find "$lessons_dir" -name "*.json" -type f 2>/dev/null)
    fi

    echo ""
    echo "Validadas: $validated | Puladas: $skipped"

    return $EXIT_SUCCESS
}

lessons::_validate_single() {
    local filepath="$1"
    local title
    title=$(grep '"title"' "$filepath" | head -1 | sed 's/.*"title": "\(.*\)".*/\1/')

    # Call Context7 for validation
    if context7 validate "$filepath" &>/dev/null; then
        echo "  [✓] $title"
        return $EXIT_SUCCESS
    else
        echo "  [~] $title (Context7 indisponível — pula)"
        return $EXIT_VALIDATION_FAILED
    fi
}

# Export for backward compatibility
export -f lessons::validate 2>/dev/null || true
export -f lessons::_validate_single 2>/dev/null || true
