#!/usr/bin/env bash
# lib/context7.sh — DEVORQ Context7 Integration
#
# Consulta documentação oficial via Context7 API.
# Wrapper puro bash que usa Python para requisições HTTP.
#
# Funções:
#   ctx7_check       — Verifica se Context7 está configurado e responde
#   ctx7_search      — Busca documentação por query
#   ctx7_resolve     — Resolve library ID e busca docs
#   ctx7_compare     — Compara múltiplas libs para uma query
#
# Config (via env ou ~/.devorq/config):
#   OPENAI_API_KEY   — API key para Context7 (obrigatório)
#   OPENAI_BASE_URL  — Endpoint da API (default: https://api.context7.io/v1)

set -euo pipefail

CTX7_CONFIG="${DEVORQ_CONFIG:-${HOME}/.devorq/config}"
CTX7_API_KEY="${OPENAI_API_KEY:-}"
CTX7_BASE_URL="${OPENAI_BASE_URL:-https://api.context7.io/v1}"

# Carrega API key do config se existir
_load_config() {
    if [ -f "$CTX7_CONFIG" ]; then
        # shellcheck source=/dev/null
        source <(grep -E "^(OPENAI_API_KEY|CTX7_API_KEY)=" "$CTX7_CONFIG" 2>/dev/null || true)
        CTX7_API_KEY="${CTX7_API_KEY:-${CTX7_API_KEY:-}}"
    fi
}

# ============================================================
# _ctx7_req — Faz request POST genérico ao Context7
# ============================================================

_ctx7_req() {
    local endpoint="${1:-}"
    local payload="${2:-}"
    local api_key="${3:-${CTX7_API_KEY}}"

    if [ -z "$api_key" ]; then
        echo "[ERROR] OPENAI_API_KEY não configurado" >&2
        return 1
    fi

    curl -s --fail-with-body \
        -X POST \
        -H "Authorization: Bearer ${api_key}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${CTX7_BASE_URL}${endpoint}" 2>/dev/null
}

# ============================================================
# ctx7_check — Verifica se Context7 responde
# ============================================================
# Chamado por GATE-6. Retorna 0 se configurado e respondendo.

ctx7_check() {
    _load_config

    if [ -z "${CTX7_API_KEY:-}" ]; then
        echo "[WARN] Context7: OPENAI_API_KEY não configurado"
        echo "[INFO] Configure: export OPENAI_API_KEY=sua_chave_api"
        echo "[INFO] Ou edite ~/.devorq/config"
        return 1
    fi

    # Teste: resolve biblioteca conhecida (express)
    local resp
    resp=$(_ctx7_req "/context7/resolve" \
        '{"library": "express", "query": "express js getting started"}' 2>/dev/null)

    if [ -z "$resp" ]; then
        echo "[WARN] Context7: API não respondeu"
        return 1
    fi

    echo "[OK] Context7: API respondendo"
    return 0
}

# ============================================================
# ctx7_search — Busca documentação por query
# ============================================================
# Uso: ctx7_search "<query>"
# Retorna: resultados formatados em markdown

ctx7_search() {
    local query="${1:-}"
    _load_config

    if [ -z "$query" ]; then
        echo "[ERROR] Uso: ctx7_search \"<query>\""
        return 1
    fi

    if [ -z "${CTX7_API_KEY:-}" ]; then
        echo "[WARN] Context7: OPENAI_API_KEY não configurado"
        return 1
    fi

    echo "[INFO] Context7: buscando '$query'..."

    local resp
    resp=$(_ctx7_req "/context7/resolve" \
        "$(jq -n --arg q "$query" '{"library": "_auto", "query": $q}')" 2>/dev/null)

    if [ -z "$resp" ]; then
        echo "[WARN] Context7: sem resposta para '$query'"
        return 1
    fi

    # Extrai conteúdo relevante do response
    if command -v jq &>/dev/null; then
        echo "$resp" | jq -r '.results // [.documents // .[]] | .[:5] | .[] | "- **\(.title // "Sem título")**\n  \(.content // .snippet // . // "" | .[0:300])..."' 2>/dev/null || echo "$resp"
    else
        echo "$resp"
    fi
}

# ============================================================
# ctx7_resolve — Resolve biblioteca e busca docs
# ============================================================
# Uso: ctx7_resolve <library> "<query>"
# Exemplo: ctx7_resolve "react" "useEffect hook"

ctx7_resolve() {
    local library="${1:-}"
    local query="${2:-}"
    _load_config

    if [ -z "$library" ] || [ -z "$query" ]; then
        echo "[ERROR] Uso: ctx7_resolve <library> \"<query>\""
        return 1
    fi

    if [ -z "${CTX7_API_KEY:-}" ]; then
        echo "[WARN] Context7: OPENAI_API_KEY não configurado"
        return 1
    fi

    echo "[INFO] Context7: resolvendo $library para '$query'..."

    local resp
    resp=$(_ctx7_req "/context7/resolve" \
        "$(jq -n --arg lib "$library" --arg q "$query" '{"library": $lib, "query": $q}')" 2>/dev/null)

    if [ -z "$resp" ]; then
        echo "[WARN] Context7: sem resposta"
        return 1
    fi

    # Formata saída
    if command -v jq &>/dev/null; then
        local content
        content=$(echo "$resp" | jq -r '.content // .documents // .[0].content // .text // .' 2>/dev/null || echo "$resp")
        echo "$content"
    else
        echo "$resp"
    fi
}

# ============================================================
# ctx7_compare — Compara múltiplas libs para uma query
# ============================================================
# Uso: ctx7_compare "<query>" <lib1> <lib2> ...
# Exemplo: ctx7_compare "http server" express fastify koa

ctx7_compare() {
    local query="${1:-}"
    shift
    local libs=("$@")
    _load_config

    if [ -z "$query" ] || [ ${#libs[@]} -eq 0 ]; then
        echo "[ERROR] Uso: ctx7_compare \"<query>\" <lib1> <lib2> ..."
        return 1
    fi

    if [ -z "${CTX7_API_KEY:-}" ]; then
        echo "[WARN] Context7: OPENAI_API_KEY não configurado"
        return 1
    fi

    echo "[INFO] Context7: comparando ${libs[*]} para '$query'"
    echo ""

    for lib in "${libs[@]}"; do
        echo "=== $lib ==="
        ctx7_resolve "$lib" "$query"
        echo ""
    done
}
