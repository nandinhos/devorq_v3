#!/usr/bin/env bash
# lib/vps.sh — VPS HUB connectivity check
#
# Usa SSH multiplexing (ControlMaster) para conexões rápidas
# Pré-requisito: SSH config configurado para srv163217

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

VPS_HOST="${DEVORQ_VPS_HOST:-187.108.197.199}"
VPS_PORT="${DEVORQ_VPS_PORT:-6985}"
VPS_USER="${DEVORQ_VPS_USER:-root}"

# ============================================================
# check — Testa conexão com VPS HUB
# ============================================================

vps::check() {
    echo -e "${CYAN}[VPS]${RESET} Testando conexão com ${VPS_HOST}:${VPS_PORT}..."

    # Teste SSH simples
    if ! command -v ssh &>/dev/null; then
        echo -e "${RED}[✗]${RESET} ssh não encontrado"
        return 1
    fi

    # SSH multiplexing check
    local mux_sock="${HOME}/.ssh/sockets/vps-hub"
    mkdir -p "$(dirname "$mux_sock")"

    echo -e "${CYAN}[VPS]${RESET} ControlMaster: ${mux_sock}"

    # Tentar conexão via mux já existente
    local result
    result=$(ssh -o "ControlMaster=auto" \
             -o "ControlPath=${mux_sock}" \
             -o "ControlPersist=600" \
             -o "StrictHostKeyChecking=accept-new" \
             -o "ConnectTimeout=5" \
             -p "$VPS_PORT" \
             "${VPS_USER}@${VPS_HOST}" \
             "echo PING && date" 2>&1) || {
        echo -e "${RED}[✗]${RESET} SSH falhou: $result"
        return 1
    }

    if echo "$result" | grep -q "PING"; then
        echo -e "${GREEN}[✓]${RESET} VPS responde: $(echo "$result" | grep PING)"
    else
        echo -e "${RED}[✗]${RESET} Resposta inesperada: $result"
        return 1
    fi

    # Testar PostgreSQL se psql disponível
    if command -v psql &>/dev/null; then
        echo -e "${CYAN}[VPS]${RESET} Testando PostgreSQL..."
        vps::pg_check || echo -e "${YELLOW}[!]${RESET} PostgreSQL não acessível via psql"
    fi
}

# ============================================================
# pg_check — Testa PostgreSQL do HUB
# ============================================================

vps::pg_check() {
    local db="${DEVORQ_PG_DB:-hermes_study}"
    local user="${DEVORQ_PG_USER:-hermes_study}"
    local port="${DEVORQ_PG_PORT:-5433}"
    local host="${VPS_HOST}"

    # SSH tunnel → psql
    psql -h "$host" -p "$port" -U "$user" -d "$db" -c "SELECT 1;" &>/dev/null || {
        echo -e "${YELLOW}[!]${RESET} psql falhou (tunnel ou credenciais)"
        return 1
    }

    echo -e "${GREEN}[✓]${RESET} PostgreSQL OK"
}

# ============================================================
# exec — Executa comando no VPS via SSH mux
# ============================================================

vps::exec() {
    local cmd="$*"
    [ -z "$cmd" ] && echo "Uso: vps::exec <comando>" && return 1

    local mux_sock="${HOME}/.ssh/sockets/vps-hub"

    ssh -o "ControlMaster=auto" \
        -o "ControlPath=${mux_sock}" \
        -o "ControlPersist=600" \
        -o "StrictHostKeyChecking=accept-new" \
        -o "ConnectTimeout=5" \
        -p "$VPS_PORT" \
        "${VPS_USER}@${VPS_HOST}" \
        "$cmd"
}

# ============================================================
# sync_up — Sobe arquivo para VPS
# ============================================================

vps::sync_up() {
    local local_file="$1"
    local remote_path="${2:-/tmp}"

    local mux_sock="${HOME}/.ssh/sockets/vps-hub"

    rsync -e "ssh -o ControlMaster=auto -o ControlPath=${mux_sock} -o StrictHostKeyChecking=accept-new -p ${VPS_PORT}" \
        -avz "$local_file" \
        "${VPS_USER}@${VPS_HOST}:${remote_path}/" 2>/dev/null || {
        # Fallback: ssh cat
        ssh -o "ControlMaster=auto" \
            -o "ControlPath=${mux_sock}" \
            -o "StrictHostKeyChecking=accept-new" \
            -p "$VPS_PORT" \
            "${VPS_USER}@${VPS_HOST}" \
            "cat > ${remote_path}/$(basename "$local_file")" < "$local_file"
    }
}

# ============================================================
# sync_down — Baixa arquivo do VPS
# ============================================================

vps::sync_down() {
    local remote_path="$1"
    local local_dir="${2:-.}"

    local mux_sock="${HOME}/.ssh/sockets/vps-hub"

    rsync -e "ssh -o ControlMaster=auto -o ControlPath=${mux_sock} -o StrictHostKeyChecking=accept-new -p ${VPS_PORT}" \
        -avz "${VPS_USER}@${VPS_HOST}:${remote_path}" \
        "$local_dir/" 2>/dev/null || {
        ssh -o "ControlMaster=auto" \
            -o "ControlPath=${mux_sock}" \
            -o "StrictHostKeyChecking=accept-new" \
            -p "$VPS_PORT" \
            "${VPS_USER}@${VPS_HOST}" \
            "cat $remote_path" > "${local_dir}/$(basename "$remote_path")"
    }
}
