#!/usr/bin/env bash
# ============================================================================
# TEST F-02: sed injection em lib/context.sh:229
# ============================================================================
# Hipotese: ctx_set fallback (sem jq) usa sed que permite corrupcao de JSON
# Patch: exigir jq como dependencia OU sanitizar input antes do sed
# ============================================================================

# NAO usa set -u — funcoes de context.sh podem usar vars unbound
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"
CONTEXT_SH="$REPO_DIR/lib/context.sh"

# Setup
TESTDIR="/tmp/f02_test_$$"
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR/.devorq/state"
cd "$TESTDIR" || exit 1

# Criar context.json
echo '{"project":"teste","intent":"original"}' > .devorq/state/context.json

trap "rm -rf '$TESTDIR'" EXIT

# Detectar patch (hard require jq OU mensagem de erro)
HAS_PATCH=$(grep -cE "ctx_set requer|jq.*requer|sed fallback removido" "$CONTEXT_SH" 2>/dev/null || echo "0")

# Patch pode ser:
# (A) Hard require: return 1 se jq nao existe
# (B) Sanitizar input antes do sed
HAS_SANITIZE=$(grep -cE 'tr -d.*\\$\\|sed.*s/[^/]*/[^/]*/' "$CONTEXT_SH" 2>/dev/null || echo 0)

if [ "$HAS_PATCH" -lt 1 ] && [ "$HAS_SANITIZE" -lt 1 ]; then
    echo "[F-02] 🔴 PATCH NAO APLICADO"
    echo "        Patch esperado: exigir jq OU sanitizar input"
    echo "        (ver docs/PATCHES.md para a abordagem escolhida)"
    exit 1
fi

if [ "$HAS_PATCH" -ge 1 ]; then
    echo "[F-02] 🟢 Patch detectado: hard require jq"
elif [ "$HAS_SANITIZE" -ge 1 ]; then
    echo "[F-02] 🟢 Patch detectado: sanitize input antes do sed"
fi

# Carrega funcao ctx_set do repo
ctx_file="$TESTDIR/.devorq/state/context.json"

# Source a funcao (linhas ~201-238 do repo)
eval "$(sed -n '/^ctx_set()/,/^}/p' "$CONTEXT_SH")"

# ============================================================================
# TESTE 1: ctx_set normal funciona
# ============================================================================
ctx_set "project" "meu-projeto" 2>&1 | head -2
if jq -e '.project == "meu-projeto"' "$ctx_file" >/dev/null 2>&1; then
    echo "[T1] 🟢 ctx_set normal funciona"
else
    echo "🔴 [T1 FALHOU] ctx_set normal quebrou"
    cat "$ctx_file"
    exit 1
fi

# Reset
echo '{"project":"teste"}' > "$ctx_file"

# ============================================================================
# TESTE 2: payload com aspas nao corrompe JSON
# ============================================================================
ctx_set "intent" 'valor com "aspas" maliciosas' 2>&1 | head -2
if jq -e '.intent' "$ctx_file" >/dev/null 2>&1; then
    echo "[T2] 🟢 payload com aspas nao corrompeu JSON"
    if jq -r '.intent' "$ctx_file" | grep -q "aspas"; then
        echo "    e o valor foi preservado"
    fi
else
    echo "🔴 [T2 FALHOU] JSON foi corrompido com aspas"
    cat "$ctx_file"
    exit 1
fi

# Reset
echo '{"project":"teste"}' > "$ctx_file"

# ============================================================================
# TESTE 3: payload com newline nao quebra estrutura
# ============================================================================
ctx_set "intent" "$(printf 'L1\nL2')" 2>&1 | head -2
if jq -e . "$ctx_file" >/dev/null 2>&1; then
    echo "[T3] 🟢 payload com newline nao quebra JSON"
else
    echo "🔴 [T3 FALHOU] JSON quebrou com newline"
    cat "$ctx_file"
    exit 1
fi

# ============================================================================
# TESTE 4: payload com backslash (tentativa de regex injection)
# ============================================================================
ctx_set "intent" 'valor com \1 backref' 2>&1 | head -2
if jq -e . "$ctx_file" >/dev/null 2>&1; then
    echo "[T4] 🟢 payload com backslash nao quebra JSON"
else
    echo "🔴 [T4 FALHOU] JSON quebrou com backslash"
    cat "$ctx_file"
    exit 1
fi

# ============================================================================
# TESTE 5: payload com forward slash (tentativa de fechar sed pattern)
# ============================================================================
ctx_set "intent" 'valor/com/slash' 2>&1 | head -2
if jq -e . "$ctx_file" >/dev/null 2>&1; then
    echo "[T5] 🟢 payload com / nao quebra sed"
else
    echo "🔴 [T5 FALHOU] sed quebrou com /"
    cat "$ctx_file"
    exit 1
fi

echo ""
echo "[F-02] TODOS OS 5 TESTES PASSARAM"
exit 0
