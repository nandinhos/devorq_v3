#!/usr/bin/env bash
# ============================================================================
# APPLY ALL PATCHES — orchestrator para os 4 fixes de seguranca
# ============================================================================
# Aplica em ordem: F-01 (RCE) → F-06 (grep inj) → F-02 (sed inj) → D-1+D-2 (hook)
# Cada patch tem teste de regressao. Falha em qualquer = restore.
# ============================================================================

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"

cd "$REPO_DIR" || { echo "Repo nao encontrado: $REPO_DIR"; exit 2; }

echo "=========================================="
echo "DEVORQ Patches — Security Review 2026-06-01"
echo "Repo: $REPO_DIR"
echo "=========================================="

# Pre-flight: checar working tree limpo
if [ -n "$(git status --porcelain 2>/dev/null | grep -v '^.devorq/state/' | head -3)" ]; then
    echo "⚠️  Working tree tem mudancas. Aplicar em sandbox primeiro?"
    echo "    Use REPO_DIR=/tmp/devorq_sandbox/devorq_v3 para sandbox"
    echo "    Ou commite/stash antes."
fi

# Backup inicial
BACKUP_DIR="/tmp/devorq_pre_patch_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "$REPO_DIR/lib/context7.sh" "$BACKUP_DIR/"
cp "$REPO_DIR/lib/context.sh" "$BACKUP_DIR/"
cp "$REPO_DIR/lib/lessons.sh" "$BACKUP_DIR/"
echo "[*] Backup inicial: $BACKUP_DIR"
echo ""

# Aplica cada patch
PASS=0
FAIL=0

for patch in apply_F01_RCE.sh apply_F06_grep.sh apply_F02_sed.sh apply_D1_D2_hook.sh; do
    echo ""
    echo "=========================================="
    echo "Aplicando: $patch"
    echo "=========================================="
    if bash "$SCRIPT_DIR/$patch"; then
        ((PASS++))
    else
        ((FAIL++))
        echo "🔴 $patch FALHOU — restore automatico ja feito"
    fi
done

echo ""
echo "=========================================="
echo "RESUMO"
echo "=========================================="
echo "Patches aplicados: $PASS/4"
echo "Patches com falha: $FAIL/4"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "🔴 FALHA. Backup completo em: $BACKUP_DIR"
    exit 1
fi

# Sucesso: roda suite completa de testes
echo ""
echo "=========================================="
echo "RODANDO SUITE COMPLETA DE REGRESSAO"
echo "=========================================="
if bash "$SCRIPT_DIR/tests/test_lib.sh"; then
    echo ""
    echo "=========================================="
    echo "✅ TODOS OS 4 PATCHES APLICADOS + TESTES PASSARAM"
    echo "=========================================="
    echo ""
    echo "Proximos passos:"
    echo "  1. Revisar diff: cd $REPO_DIR && git diff lib/"
    echo "  2. Commitar:    git add lib/ && git commit -m 'fix(security): corrige 4 vulnerabilidades do code review'"
    echo "  3. Push:        git push origin main"
    echo ""
    echo "Backup mantido em: $BACKUP_DIR (remover apos validar)"
else
    echo ""
    echo "🔴 TESTES DE REGRESSAO FALHARAM"
    echo "Backup em: $BACKUP_DIR"
    exit 1
fi
