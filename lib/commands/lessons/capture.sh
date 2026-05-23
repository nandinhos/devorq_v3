#!/usr/bin/env bash
# lib/commands/lessons/capture.sh — Captura de lições

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# ============================================================
# LESSONS::CAPTURE
# Captura uma nova lição aprendida
# ============================================================

# Dependencies

lessons::capture() {
    local title="${1:-}"
    local problem="${2:-}"
    local solution="${3:-}"

    # Validate required fields
    if [[ -z "$title" ]]; then
        echo "[ERROR] Título é obrigatório" >&2
        return $EXIT_INVALID_ARGS
    fi

    # Generate ID and timestamp
    local id="lesson_$(date +%Y%m%d_%H%M%S)_$$"
    local timestamp
    timestamp=$(date +%Y-%m-%dT%H:%M:%S)

    # Create lesson JSON
    local lesson_json
    lesson_json=$(cat <<JSONEOF
{
  "id": "$id",
  "title": "$title",
  "problem": "$problem",
  "solution": "$solution",
  "timestamp": "$timestamp",
  "approved": false,
  "captured_by": "${DEVORQ_USER:-$(whoami)}",
  "context": {
    "project": "${DEVORQ_PROJECT:-unknown}",
    "stack": "${DEVORQ_STACK:-unknown}"
  }
}
JSONEOF
)

    # Save to file (maintain backward compatibility with captured/)
    local base_dir="${DEVORQ_LESSONS_DIR:-${DEVORQ_DIR}/state/lessons}"
    local lessons_dir="${base_dir}/captured"
    mkdir -p "$lessons_dir"

    local filepath="${lessons_dir}/${id}.json"
    echo "$lesson_json" > "$filepath"

    # Optionally sync to VPS
    lessons::sync_vps "$filepath" &>/dev/null || true

    echo "[✓] Lição salva: $id"
    echo "   $title"

    return $EXIT_SUCCESS
}

# Export for backward compatibility
export -f lessons::capture 2>/dev/null || true
