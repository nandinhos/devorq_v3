#!/usr/bin/env bash
# scripts/verify-dispatch.sh — Garante que bin/devorq só referencia módulos existentes
#
# Uso: bash scripts/verify-dispatch.sh

set -euo pipefail

DEVORQ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${DEVORQ_ROOT}/bin/devorq"
FAIL=0

# Apos o refactor router->dispatcher, bin/devorq sourcea lib/dispatchers/*.sh
# (nao mais lib/commands/* direto). Verifica os modulos de comando referenciados
# pelos DISPATCHERS — antes este check grepava bin/devorq e virava no-op. DQ-030
check_source() {
    local disp_dir="${DEVORQ_ROOT}/lib/dispatchers"
    if [[ ! -d "$disp_dir" ]] || ! compgen -G "$disp_dir/*.sh" >/dev/null; then
        echo "[FAIL] dispatchers ausentes em lib/dispatchers/"
        FAIL=$((FAIL + 1))
        return
    fi
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        local full="${DEVORQ_ROOT}/lib/commands/${path}"
        if [[ ! -f "$full" ]]; then
            echo "[FAIL] source ausente: commands/$path (referenciado por dispatcher)"
            FAIL=$((FAIL + 1))
        else
            echo "[OK]   commands/$path"
        fi
    done < <(grep -ohE 'source "\$\{DEVORQ_LIB\}/commands/[^"]+\.sh"' "$disp_dir"/*.sh \
                | sed 's|source "${DEVORQ_LIB}/commands/||;s|"||' | sort -u)
}

echo "=== verify-dispatch: módulos referenciados pelos dispatchers ==="
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
