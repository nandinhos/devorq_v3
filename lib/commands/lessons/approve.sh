#!/usr/bin/env bash
# lib/commands/lessons/approve.sh — Aprovação de lições

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# ============================================================
# LESSONS::APPROVE
# Aprova uma lição para compilação
# ============================================================

lessons::approve() {
    # Show help if requested
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        cat << 'HELPEOF'
USAGE: devorq lessons approve <lesson_id> [skill_path] [--force]

OPTIONS:
  lesson_id   ID da lição a aprovar
  skill_path  Caminho opcional para skill (default: learned-lesson)
  --force     Forçar reaprovação mesmo se já aprovada

EXAMPLES:
  devorq lessons approve lesson_20260521_123456
  devorq lessons approve lesson_20260521_123456 --force
HELPEOF
        return 0
    fi

    local lesson_id="${1:-}"
    local skill_path="${2:-}"
    local force="${3:-false}"

    local lessons_dir="${DEVORQ_LESSONS_DIR:-${DEVORQ_DIR}/state/lessons}/captured"
    local filepath="${lessons_dir}/${lesson_id}.json"

    # Validate lesson exists
    if [[ ! -f "$filepath" ]]; then
        echo "[ERROR] Lição não encontrada: $lesson_id" >&2
        return $EXIT_NOT_FOUND
    fi

    # Get current approval status
    local current_approved
    current_approved=$(grep '"approved": true' "$filepath" >/dev/null && echo "true" || echo "false")

    if [[ "$current_approved" == "true" ]] && [[ "$force" != "true" ]]; then
        echo "[INFO] Lição já está aprovada: $lesson_id"
        return $EXIT_SUCCESS
    fi

    # Update approval status
    local temp_file
    temp_file=$(mktemp)
    sed 's/"approved": false/"approved": true/' "$filepath" > "$temp_file"
    mv "$temp_file" "$filepath"

    echo "[✓] Lição aprovada: $lesson_id"

    return $EXIT_SUCCESS
}

# Export for backward compatibility
export -f lessons::approve 2>/dev/null || true
