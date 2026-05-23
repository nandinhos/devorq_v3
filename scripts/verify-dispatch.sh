#!/usr/bin/env bash
# scripts/verify-dispatch.sh — Garante que bin/devorq só referencia módulos existentes
#
# Uso: bash scripts/verify-dispatch.sh

set -euo pipefail

DEVORQ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${DEVORQ_ROOT}/bin/devorq"
FAIL=0

check_source() {
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local full="${DEVORQ_ROOT}/lib/commands/${path}"
        if [[ ! -f "$full" ]]; then
            echo "[FAIL] source ausente: $path"
            FAIL=$((FAIL + 1))
        else
            echo "[OK]   $path"
        fi
    done < <(grep -oE 'source "\$\{DEVORQ_LIB\}/commands/[^"]+\.sh"' "$BIN" | sed 's|source "${DEVORQ_LIB}/commands/||;s|"||')
}

echo "=== verify-dispatch: módulos referenciados em bin/devorq ==="
check_source

echo ""
echo "=== smoke: comandos críticos ==="
export DEVORQ_ROOT DEVORQ_DIR="$DEVORQ_ROOT"

smoke() {
    local label="$1"
    shift
    if "$@"; then
        echo "[OK]   $label"
    else
        echo "[FAIL] $label"
        FAIL=$((FAIL + 1))
    fi
}

smoke "version" bash "$BIN" version
smoke "info" bash "$BIN" info
smoke "mode classic" bash "$BIN" mode classic
smoke "auto --help" bash "$BIN" auto --help
smoke "commit --help" bash "$BIN" commit --help
smoke "verify --help" bash "$BIN" verify --help
smoke "rules list" bash "$BIN" rules list

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "verify-dispatch: $FAIL falha(s)"
    exit 1
fi

echo ""
echo "verify-dispatch: OK"
