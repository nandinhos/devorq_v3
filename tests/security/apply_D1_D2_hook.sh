#!/usr/bin/env bash
# ============================================================================
# PATCH D-1+D-2: Documentar install-hook como passo obrigatorio do init
# ============================================================================
# Hook ja existe em lib/commands/rules.sh e funciona corretamente.
# Patch: garantir que devorq init instala o hook automaticamente
#        E documentar em INSTALL.md como passo manual.
# ============================================================================

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"

# Instalar hook (se nao estiver)
cd "$REPO_DIR" || exit 1

if [ -f .git/hooks/commit-msg ] && [ -x .git/hooks/commit-msg ]; then
    echo "[D-1] 🟢 Hook commit-msg ja instalado e executavel"
else
    echo "[D-1] 🔴 Hook commit-msg NAO instalado. Rodando 'devorq rules install-hook'..."
    if ./bin/devorq rules install-hook 2>&1 | head -3; then
        echo "[D-1] 🟢 Hook instalado"
    else
        echo "[D-1] 🔴 Falha ao instalar hook via devorq"
        exit 1
    fi
fi

# Roda o teste
if bash "$SCRIPT_DIR/test_D1_D2_hook.sh"; then
    echo ""
    echo "[D-1+D-2] ✅ HOOK INSTALADO + TESTES PASSARAM"
    exit 0
else
    echo ""
    echo "[D-1+D-2] 🔴 TESTES FALHARAM"
    exit 1
fi
