#!/usr/bin/env bash
# ============================================================================
# PATCH F-02: Remover sed fallback em lib/context.sh (sed injection)
# ============================================================================
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"
CONTEXT_SH="$REPO_DIR/lib/context.sh"

if [ ! -f "$CONTEXT_SH" ]; then
    echo "[F-02] 🔴 Arquivo nao encontrado: $CONTEXT_SH"
    exit 1
fi

cp "$CONTEXT_SH" "$CONTEXT_SH.bak"

# Aplica patch via Python externo (evita problemas de heredoc com <<)
if python3 "$SCRIPT_DIR/apply_F02_patch.py" "$CONTEXT_SH"; then
    # Verificar
    if grep -q "Fallback grep+sed rudimentar" "$CONTEXT_SH"; then
        echo "[F-02] 🔴 sed fallback AINDA presente apos patch"
        mv "$CONTEXT_SH.bak" "$CONTEXT_SH"
        exit 1
    fi
    if bash "$SCRIPT_DIR/test_F02_sed_injection.sh"; then
        echo ""
        echo "[F-02] ✅ PATCH APLICADO + TESTES PASSARAM"
        exit 0
    else
        echo "[F-02] 🔴 testes falharam — restore"
        mv "$CONTEXT_SH.bak" "$CONTEXT_SH"
        exit 1
    fi
else
    echo "[F-02] 🔴 python patch falhou"
    mv "$CONTEXT_SH.bak" "$CONTEXT_SH"
    exit 1
fi
