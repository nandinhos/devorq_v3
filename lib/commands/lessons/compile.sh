#!/usr/bin/env bash
# lib/commands/lessons/compile.sh — Compilação de lições em Skills

# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046

# ============================================================
# LESSONS::COMPILE
# Compila lições aprovadas em skills
# ============================================================

lessons::compile() {
    local lesson_id="${1:-}"
    local skill_path="${2:-}"
    local dry_run="${3:-false}"
    local base_dir="${DEVORQ_LESSONS_DIR:-${DEVORQ_DIR}/state/lessons}"
    local dir="${base_dir}/captured"
    local count=0

    if [[ ! -d "$dir" ]]; then
        echo "[INFO] Nenhuma lição capturada."
        return 0
    fi

    if [[ -n "$lesson_id" ]]; then
        lessons::_compile_lesson "$lesson_id" "$skill_path" "$dry_run"
        return $?
    fi

    # Compile all approved
    for f in "$dir"/*.json; do
        [[ -f "$f" ]] || continue
        local id
        id=$(basename "$f" .json)
        if lessons::_compile_lesson "$id" "$skill_path" "$dry_run"; then
            ((count++)) || true
        fi
    done

    echo ""
    echo "Skills compiladas: $count"
}

# Internal: compile single lesson
lessons::_compile_lesson() {
    local id="$1"
    local skill_path="$2"
    local dry_run="${3:-false}"
    local base_dir="${DEVORQ_LESSONS_DIR:-${DEVORQ_DIR}/state/lessons}"
    local dir="${base_dir}/captured"
    local file="${dir}/${id}.json"

    [[ ! -f "$file" ]] && echo "[ERROR] Lição não encontrada: $id" && return 1

    # Check approved
    if command -v jq &>/dev/null; then
        local approved
        approved=$(jq -r '.approved // false' "$file")
        [[ "$approved" != "true" ]] && echo "[SKIP] Não aprovada: $id" && return 0
    fi

    local title problem solution tags skill_name
    if command -v jq &>/dev/null; then
        title=$(jq -r '.title' "$file")
        problem=$(jq -r '.problem' "$file")
        solution=$(jq -r '.solution' "$file")
        tags=$(jq -r '.tags // [] | join(", ")' "$file")
        skill_name=$(jq -r '.skill_name // (.skill_path | split("/")[1]) // "learned-lesson"' "$file")
    fi

    [[ -z "$skill_path" ]] && skill_path="skills/${skill_name:-learned-lesson}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[DRY RUN] Skill seria gerada em: $skill_path"
        echo "  Title: $title"
        echo "  Tags: $tags"
        return 0
    fi

    # Create directories
    mkdir -p "${skill_path}/references/approved"
    mkdir -p "${skill_path}/scripts"

    # Copy approved lesson
    cp "$file" "${skill_path}/references/approved/${id}.json"

    # Generate/update SKILL.md
    local skill_md="${skill_path}/SKILL.md"
    local entry="- **${title}**: ${problem} → ${solution} (${tags})"

    if [[ -f "$skill_md" ]]; then
        # Add entry if exists
        if ! grep -qF "$title" "$skill_md" 2>/dev/null; then
            if grep -q "## Approved Lessons" "$skill_md" 2>/dev/null; then
                sed -i "/## Approved Lessons/a\\$entry" "$skill_md"
            else
                echo "" >> "$skill_md"
                echo "## Approved Lessons" >> "$skill_md"
                echo "$entry" >> "$skill_md"
            fi
        fi
    else
        # Create SKILL.md from scratch
        cat > "$skill_md" << 'SKILLEDOF'
# Learned Lessons Skill

This skill captures lessons learned from the project.

## Trigger Words
- learned-lesson
- lesson-learned

## Approved Lessons
SKILLEDOF
        echo "$entry" >> "$skill_md"
        echo "Skill compilada: $skill_path" && return 0
    fi

    echo "Skill compilada: $skill_path"
    return 0
}

export -f lessons::compile 2>/dev/null || true
export -f lessons::_compile_lesson 2>/dev/null || true
