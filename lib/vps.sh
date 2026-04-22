#!/usr/bin/env bash
# lib/vps.sh — VPS HUB connectivity + sync
#
# SSH multiplexing para conexões rápidas (~0.3s/comando)
# Sincroniza .devorq/state/lessons ↔ PostgreSQL devorq.lessons

set -euo pipefail

VPS_HOST="${DEVORQ_VPS_HOST:-187.108.197.199}"
VPS_PORT="${DEVORQ_VPS_PORT:-6985}"
VPS_USER="${DEVORQ_VPS_USER:-root}"

PG_DB="${DEVORQ_PG_DB:-hermes_study}"
PG_USER="${DEVORQ_PG_USER:-hermes_study}"
PG_PORT="${DEVORQ_PG_PORT:-5433}"

MUX_SOCK="${DEVORQ_MUX_SOCK:-/tmp/devorq-ssh-mux}"

# ============================================================
# check — Testa conexão com VPS HUB
# ============================================================

vps::check() {
    echo "[VPS] Testando ${VPS_HOST}:${VPS_PORT}..."

    if ! command -v ssh &>/dev/null; then
        echo "[ERROR] ssh não encontrado"
        return 1
    fi

    mkdir -p "$(dirname "$MUX_SOCK")"

    local result
    result=$(ssh -o "ControlMaster=auto" \
             -o "ControlPath=${MUX_SOCK}" \
             -o "ControlPersist=600" \
             -o "StrictHostKeyChecking=accept-new" \
             -o "ConnectTimeout=5" \
             -p "$VPS_PORT" \
             "${VPS_USER}@${VPS_HOST}" \
             "echo PING" 2>&1) || {
        echo "[ERROR] SSH falhou: $result"
        return 1
    }

    if echo "$result" | grep -q "PING"; then
        echo "[OK] VPS responde"
    else
        echo "[ERROR] Resposta inesperada: $result"
        return 1
    fi
}

# ============================================================
# exec — Executa comando no VPS via SSH mux
# ============================================================

vps::exec() {
    local cmd="$*"
    [ -z "$cmd" ] && echo "Uso: vps::exec <comando>" && return 1

    ssh -o "ControlMaster=auto" \
        -o "ControlPath=${MUX_SOCK}" \
        -o "ControlPersist=600" \
        -o "StrictHostKeyChecking=accept-new" \
        -o "ConnectTimeout=10" \
        -p "$VPS_PORT" \
        "${VPS_USER}@${VPS_HOST}" \
        "$cmd"
}

# ============================================================
# pg_exec — Executa SQL no PostgreSQL do HUB
# ============================================================

vps::pg_exec() {
    local sql="$*"
    [ -z "$sql" ] && echo "Uso: vps::pg_exec <sql>" && return 1

    # Usa printf %q para escapar correctamente
    local escaped
    escaped=$(printf '%s' "$sql" | sed "s/'/'\"'\"'/g")

    vps::exec "docker exec hermesstudy_postgres psql -U ${PG_USER} -d ${PG_DB} -c '${escaped}'"
}

# ============================================================
# lessons_count — Conta lições no HUB
# ============================================================

vps::lessons_count() {
    vps::pg_exec "SELECT count(*) FROM devorq.lessons;" 2>/dev/null || echo "0"
}


