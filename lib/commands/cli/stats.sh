#!/usr/bin/env bash
# lib/commands/cli/stats.sh — Comando devorq stats

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

devorq::cmd_stats() {
    local project="${1:-${DEVORQ_PROJECT:-${PWD}}}"
    
    echo "=== DEVORQ Statistics ==="
    echo ""
    echo "Project: $project"
    echo ""
    
    # Count lessons
    local lessons_dir="${DEVORQ_DIR}/state/lessons"
    if [[ -d "$lessons_dir" ]]; then
        local total captured approved
        total=$(find "$lessons_dir" -name "*.json" 2>/dev/null | wc -l)
        captured=$(find "$lessons_dir/captured" -name "*.json" 2>/dev/null | wc -l)
        approved=$(find "$lessons_dir/captured" -name "*.json" -exec grep -l '"approved": true' {} \; 2>/dev/null | wc -l)
        echo "Lessons: $total total | $captured captured | $approved approved"
    else
        echo "Lessons: 0 (nenhuma captura)"
    fi
    
    # Count skills
    local skills_dir="${DEVORQ_ROOT}/skills"
    if [[ -d "$skills_dir" ]]; then
        local skills
        skills=$(find "$skills_dir" -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l)
        echo "Skills: $skills"
    fi
    
    echo ""
}

export -f devorq::cmd_stats 2>/dev/null || true
