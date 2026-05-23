#!/usr/bin/env bash
# lib/stats.sh — DEVORQ Meta-Level Statistics
#
# Métricas de uso do DEVORQ: lições, gates, recorrências.
# Usado para identificar padrões e refinar thresholds.

set -euo pipefail

# ============================================================
# Helpers
# ============================================================

stats::red()   { echo -e "\033[0;31m$*\033[0m"; }
stats::green() { echo -e "\033[0;32m$*\033[0m"; }
stats::yellow(){ echo -e "\033[1;33m$*\033[0m"; }
stats::cyan()  { echo -e "\033[0;36m$*\033[0m"; }
stats::bold()  { echo -e "\033[1m$*\033[0m"; }

# ============================================================
# stats::lessons — Conta e classifica lições
# ============================================================

stats::lessons() {
    local lessons_dir="${PWD}/.devorq/state/lessons"
    local captured="${lessons_dir}/captured"
    local downloaded="${lessons_dir}/downloaded"

    echo ""
    stats::bold "═══ Lições ═══"

    local cap_count=0 downloaded_count=0 validated=0 applied=0 recurrence=0

    # Captured
    if [ -d "$captured" ]; then
        cap_count=$(find "$captured" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
        cap_count=${cap_count:-0}
    fi

    # Downloaded
    if [ -d "$downloaded" ]; then
        downloaded_count=$(find "$downloaded" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
        downloaded_count=${downloaded_count:-0}
    fi

    # Stats via jq se disponível
    if command -v jq &>/dev/null && [ -d "$captured" ]; then
        validated=$(find "$captured" -maxdepth 1 -name "*.json" -type f -exec jq -r '.validated // false' {} \; 2>/dev/null | grep -c "true" || true)
        applied=$(find "$captured" -maxdepth 1 -name "*.json" -type f -exec jq -r '.applied // false' {} \; 2>/dev/null | grep -c "true" || true)
        recurrence=$(find "$captured" -maxdepth 1 -name "*.json" -type f -exec jq -r '.recurrence_count // 0' {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}' || true)
        validated=${validated:-0}; applied=${applied:-0}; recurrence=${recurrence:-0}
    fi

    echo "  Capturadas:   $(stats::cyan $cap_count)"
    echo "  Baixadas:    $(stats::cyan $downloaded_count)"
    echo "  Validadas:   $(stats::green $validated)"
    echo "  Aplicadas:   $(stats::green $applied)"
    echo "  Recorrências: $(stats::yellow $recurrence)"

    # Top tags
    if command -v jq &>/dev/null && [ -d "$captured" ] && [ "$cap_count" -gt 0 ]; then
        echo ""
        stats::bold "  Top Tags:"
        find "$captured" -maxdepth 1 -name "*.json" -type f -exec jq -r '.tags // [] | .[]' {} \; 2>/dev/null | \
            sort | uniq -c | sort -rn | head -5 | while read -r count tag; do
                echo "    $(stats::cyan $count)x $tag"
            done
    fi
}

# ============================================================
# stats::gates — Histórico de gates
# ============================================================

stats::gates() {
    local ctx_file="${PWD}/.devorq/state/context.json"

    echo ""
    stats::bold "═══ Gates ═══"

    if [ ! -f "$ctx_file" ]; then
        echo "  Nenhum context.json encontrado"
        return 0
    fi

    # Gates completados
    if command -v jq &>/dev/null; then
        local completed
        completed=$(jq -r '.gates_completed // [] | length' "$ctx_file" 2>/dev/null || echo 0)
        echo "  Completados: $(stats::green $completed)/7"

        local pending
        pending=$(jq -r '.pending_gates // [] | length' "$ctx_file" 2>/dev/null || echo 0)
        echo "  Pendentes:   $(stats::yellow $pending)"

        # Última sessão
        local last_session
        last_session=$(jq -r '.last_session // "nunca"' "$ctx_file" 2>/dev/null || echo "nunca")
        echo "  Última:      $(stats::cyan $last_session)"
    else
        echo "  (jq não disponível — detalhes limitados)"
    fi
}

# ============================================================
# stats::patterns — Identifica padrões repetitivos
# ============================================================

stats::patterns() {
    local lessons_dir="${PWD}/.devorq/state/lessons/captured"

    echo ""
    stats::bold "═══ Padrões ═══"

    if [ ! -d "$lessons_dir" ]; then
        echo "  Nenhuma lição capturada"
        return 0
    fi

    local lesson_count
    lesson_count=$(find "$lessons_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
    lesson_count=${lesson_count:-0}

    if [ "$lesson_count" -lt 3 ]; then
        echo "  Menos de 3 lições — padrões需要在 mais dados"
        return 0
    fi

    # Problemas recorrentes (mesmo título/problema)
    if command -v jq &>/dev/null; then
        echo "  Problemas recorrentes (recurrence_count > 0):"
        find "$lessons_dir" -maxdepth 1 -name "*.json" -type f -exec jq -r 'if .recurrence_count > 0 then "\(.recurrence_count)x \(.title)" else empty end' {} \; 2>/dev/null | \
            head -5 | while read -r line; do
                echo "    $(stats::yellow $line)"
            done

        if [ $(find "$captured" -maxdepth 1 -name "*.json" -type f -exec jq -r 'if .recurrence_count > 0 then 1 else 0 end' {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}' 2>/dev/null || echo 0) -eq 0 ]; then
            echo "    Nenhum padrão detectado ainda"
        fi
    fi

    # Stack mais comum
    if command -v jq &>/dev/null; then
        echo ""
        echo "  Stacks mais comuns:"
        find "$lessons_dir" -maxdepth 1 -name "*.json" -type f -exec jq -r '.stack // [] | .[]' {} \; 2>/dev/null | \
            sort | uniq -c | sort -rn | head -3 | while read -r count stack; do
                echo "    $(stats::cyan $count)x $stack"
            done
    fi
}

# ============================================================
# stats::context — Tamanho e saúde do contexto
# ============================================================

stats::context() {
    local ctx_file="${PWD}/.devorq/state/context.json"

    echo ""
    stats::bold "═══ Contexto ═══"

    if [ ! -f "$ctx_file" ]; then
        echo "  Nenhum context.json"
        return 0
    fi

    local size
    size=$(wc -c < "$ctx_file" 2>/dev/null || echo 0)
    local tokens=$((size / 4))

    echo "  Tamanho:     $(stats::cyan ${size}B / ~${tokens} tokens)"

    if [ "$size" -gt 240000 ]; then
        echo "  Alerta:      $(stats::red "Contexto grande — use ctx_pack")"
    elif [ "$size" -gt 120000 ]; then
        echo "  Alerta:      $(stats::yellow "Contexto crescendo — monitore")"
    else
        echo "  Status:      $(stats::green "Saudável")"
    fi

    # Campos
    if command -v jq &>/dev/null; then
        local intent
        intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null)
        if [ -n "$intent" ] && [ "$intent" != "null" ]; then
            echo "  Intent:      ${intent:0:60}..."
        else
            echo "  Intent:      $(stats::yellow "não definido")"
        fi
    fi
}

# ============================================================
# stats::update_context — Atualiza context.json com métricas
# ============================================================

stats::update_context() {
    local ctx_file="${PWD}/.devorq/state/context.json"

    if [ ! -f "$ctx_file" ] || ! command -v jq &>/dev/null; then
        return 0
    fi

    local lessons_dir="${PWD}/.devorq/state/lessons/captured"
    local cap_count=0
    if [ -d "$lessons_dir" ]; then
        cap_count=$(find "$lessons_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
        cap_count=${cap_count:-0}
    fi

    local tmp
    tmp=$(mktemp)
    jq --argjson lessons_count "$cap_count" \
       --argjson gates_total 7 \
       --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '. + {
           stats: {
               lessons_count: $lessons_count,
               gates_total: $gates_total,
               last_stats_update: $now
           }
       }' "$ctx_file" > "$tmp" && mv "$tmp" "$ctx_file"
}

# ============================================================
# stats::summary — Resumo completo
# ============================================================

stats::summary() {
    stats::bold "═══════════════════════════════════════"
    stats::bold "  DEVORQ Statistics"
    stats::bold "═══════════════════════════════════════"

    stats::lessons
    stats::gates
    stats::context
    stats::patterns

    echo ""
    stats::bold "═══════════════════════════════════════"

    # Atualiza context.json com métricas
    stats::update_context
}
