#!/usr/bin/env bash
# lib/compact.sh — DEVORQ Context Compaction
#
# Gera contexto compactado para handoff entre sessões/LLMs

set -euo pipefail

# ============================================================
# generate — Gera JSON de contexto para handoff
# ============================================================

compact::generate() {
    local ctx_file="${PWD}/.devorq/state/context.json"
    local output="${1:-/dev/stdout}"

    local project="${PWD##*/}"
    local stack=""
    local intent=""
    local gates_completed=""

    if [ -f "$ctx_file" ]; then
        if command -v jq &>/dev/null; then
            stack=$(jq -r '.stack // [] | if type == "array" then join(",") else . end' "$ctx_file" 2>/dev/null || echo "")
            intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
            gates_completed=$(jq -r '.gates_completed // [] | if type == "array" then join(",") else . end' "$ctx_file" 2>/dev/null || echo "")
        else
            stack=$(grep '"stack"' "$ctx_file" | head -1 | cut -d':' -f2 | tr -d '[]," ' || echo "")
            intent=$(grep '"intent"' "$ctx_file" | cut -d'"' -f4 || echo "")
            gates_completed=$(grep '"gates_completed"' "$ctx_file" | cut -d'[' -f2 | cut -d']' -f1 | tr -d ' ",' || echo "")
        fi
    fi

    local pending=""
    for g in 1 2 3 4 5 6 7; do
        if ! echo "$gates_completed" | grep -q "\b$g\b"; then
            pending="${pending}GATE-${g} "
        fi
    done

    local untracked
    untracked=$(git status --porcelain 2>/dev/null | grep "^??" | cut -c4- | head -5 || true)

    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$project" \
            --arg stack "$stack" \
            --arg intent "$intent" \
            --arg gates_completed "$gates_completed" \
            --arg pending "$(echo $pending)" \
            --arg untracked "$untracked" \
            --arg ts "$ts" \
            '{
                handoff: {
                    project: $project,
                    stack: $stack,
                    intent: $intent,
                    gates_completed: ($gates_completed | if . == "" then [] else split(",") end),
                    pending_gates: ($pending | split(" ") | map(select(. != ""))),
                    untracked_files: ($untracked | if . == "" then [] else split("\n") end),
                    timestamp: $ts
                }
            }'
    else
        # Fallback JSON manual (sem jq)
        printf '{"handoff":{"project":"%s","stack":"%s","intent":"%s","gates_completed":[],"pending_gates":[],"untracked_files":[],"timestamp":"%s"}}\n' \
            "$project" "$stack" "$intent" "$ts"
    fi
}

# ============================================================
# load — Carrega contexto de handoff anterior
# ============================================================

compact::load() {
    local handoff_file="${PWD}/.devorq/state/handoff.json"

    if [ ! -f "$handoff_file" ]; then
        echo "Nenhum handoff anterior encontrado."
        return 1
    fi

    cat "$handoff_file"
}

# ============================================================
# diff — Compara dois handoffs
# ============================================================

compact::diff() {
    local before="${1:-}"
    local after="${2:-}"

    if [ -z "$before" ] || [ -z "$after" ]; then
        echo "Uso: compact::diff <before.json> <after.json>"
        return 1
    fi

    echo "=== HANDOFF DIFF ==="
    echo "Intent antes: $(jq -r '.handoff.intent' "$before" 2>/dev/null || echo '???')"
    echo "Intent depois: $(jq -r '.handoff.intent' "$after" 2>/dev/null || echo '???')"
    echo ""
    echo "Gates antes: $(jq -r '.handoff.gates_completed | join(",")' "$before" 2>/dev/null || echo '???')"
    echo "Gates depois: $(jq -r '.handoff.gates_completed | join(",")' "$after" 2>/dev/null || echo '???')"
}
