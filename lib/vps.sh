#!/usr/bin/env bash
# lib/vps.sh — VPS HUB connectivity + sync
#
# SSH multiplexing para conexões rápidas (~0.3s/comando)
# Sincroniza .devorq/state/lessons ↔ PostgreSQL devorq.lessons

set -euo pipefail

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_NOT_FOUND=3
readonly EXIT_SSH_FAILED=4

VPS_HOST="${DEVORQ_VPS_HOST:-187.108.197.199}"
VPS_PORT="${DEVORQ_VPS_PORT:-6985}"
VPS_USER="${DEVORQ_VPS_USER:-root}"

PG_DB="${DEVORQ_PG_DB:-hermes_study}"
PG_USER="${DEVORQ_PG_USER:-hermes_study}"

MUX_SOCK="${DEVORQ_MUX_SOCK:-/tmp/devorq-ssh-mux}"

# ============================================================
# Sanitization helpers
# ============================================================

devorq::sanitize_path() {
    local path="$1"
    local base_dir="${2:-.}"

    # Normaliza e valida que está dentro de base_dir
    local real_path real_base
    real_path=$(realpath -q "$path" 2>/dev/null) || {
        echo "[ERROR] Path invalido: $path" >&2
        return $EXIT_INVALID_ARGS
    }
    real_base=$(realpath -q "$base_dir" 2>/dev/null) || {
        echo "[ERROR] Base dir invalido: $base_dir" >&2
        return $EXIT_INVALID_ARGS
    }

    case "$real_path" in
        "$real_base"*) true ;;
        *) echo "[ERROR] Path traversal detectado: $path" >&2; return $EXIT_INVALID_ARGS ;;
    esac

    echo "$real_path"
}

devorq::validate_ssh_host() {
    local host="$1"
    local port="$2"

    # Validação básica de host
    if [[ ! "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        echo "[ERROR] Host invalido: $host" >&2
        return $EXIT_INVALID_ARGS
    fi

    # Validação de porta
    if [[ ! "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        echo "[ERROR] Porta invalida: $port" >&2
        return $EXIT_INVALID_ARGS
    fi

    return $EXIT_SUCCESS
}

# ============================================================
# check — Testa conexão com VPS HUB
# ============================================================

devorq::vps_check() {
    echo "[VPS] Testando ${VPS_HOST}:${VPS_PORT}..."

    # Validação de inputs
    devorq::validate_ssh_host "$VPS_HOST" "$VPS_PORT" || return $?

    if ! command -v ssh &>/dev/null; then
        echo "[ERROR] ssh não encontrado"
        return $EXIT_NOT_FOUND
    fi

    mkdir -p "$(dirname "$MUX_SOCK")"

    local result
    result=$(ssh \
             -o "ControlMaster=auto" \
             -o "ControlPath=${MUX_SOCK}" \
             -o "ControlPersist=600" \
             -o "StrictHostKeyChecking=yes" \
             -o "UserKnownHostsFile=${HOME}/.ssh/known_hosts" \
             -o "ConnectTimeout=5" \
             -p "$VPS_PORT" \
             "${VPS_USER}@${VPS_HOST}" \
             "echo PING" 2>&1) || {
        echo "[ERROR] SSH falhou: $result"
        return $EXIT_SSH_FAILED
    }

    if echo "$result" | grep -q "PING"; then
        echo "[OK] VPS responde"
    else
        echo "[ERROR] Resposta inesperada: $result"
        return $EXIT_ERROR
    fi
}

# ============================================================
# exec — Executa comando no VPS via SSH mux
# ============================================================

devorq::vps_exec() {
    local cmd="$*"
    [ -z "$cmd" ] && echo "Uso: devorq::vps_exec <comando>" && return $EXIT_INVALID_ARGS

    # Validação
    devorq::validate_ssh_host "$VPS_HOST" "$VPS_PORT" || return $?

    ssh \
        -o "ControlMaster=auto" \
        -o "ControlPath=${MUX_SOCK}" \
        -o "ControlPersist=600" \
        -o "StrictHostKeyChecking=yes" \
        -o "UserKnownHostsFile=${HOME}/.ssh/known_hosts" \
        -o "ConnectTimeout=10" \
        -p "$VPS_PORT" \
        "${VPS_USER}@${VPS_HOST}" \
        "$cmd"
}

# ============================================================
# pg_exec — Executa SQL no PostgreSQL do HUB
# ============================================================

devorq::vps_pg_exec() {
    local sql="$*"
    [ -z "$sql" ] && echo "Uso: devorq::vps_pg_exec <sql>" && return $EXIT_INVALID_ARGS

    # Validação de SQL básico (procurar caracteres perigosos)
    local dangerous_pattern='[;&|`\$\(\)\{\}\[\]< >!\\]'
    if echo "$sql" | grep -qE "$dangerous_pattern"; then
        echo "[ERROR] Caracteres perigosos detectados no SQL" >&2
        return $EXIT_INVALID_ARGS
    fi

    # Usa printf %q para escapar correctamente
    local escaped
    escaped=$(printf '%s' "$sql" | sed "s/'/'\"'\"'/g")

    devorq::vps_exec "docker exec hermesstudy_postgres psql -U ${PG_USER} -d ${PG_DB} -c '${escaped}'"
}

# ============================================================
# lessons_count — Conta lições no HUB
# ============================================================

devorq::vps_lessons_count() {
    devorq::vps_pg_exec "SELECT count(*) FROM devorq.lessons;" 2>/dev/null || echo "0"
}

# Aliases para compatibilidade (deprecated)
vps::check() { devorq::vps_check "$@"; }
vps::exec() { devorq::vps_exec "$@"; }
vps::pg_exec() { devorq::vps_pg_exec "$@"; }
vps::lessons_count() { devorq::vps_lessons_count "$@"; }
