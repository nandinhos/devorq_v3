#!/usr/bin/env bash
# ============================================================================
# TEST F-06: grep regex injection em lib/lessons.sh
# ============================================================================
# Hipotese: grep -l -i "$query" interpreta $query como regex
# Patch: usar grep -F (literal) ao inves de regex
# ============================================================================

# NAO usa set -u — funcoes de lessons.sh usam variaveis como CYAN que dao unbound
set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"
LESSONS_SH="$REPO_DIR/lib/lessons.sh"

# Setup
TESTDIR="/tmp/f06_test_$$"
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR/lessons/captured"

trap "rm -rf '$TESTDIR'" EXIT

# Criar lessons de exemplo
cat > "$TESTDIR/lessons/captured/01.json" <<'EOF'
{"title": "Docker nao inicia", "problem": "container fails to start", "validated": true, "timestamp": "2026-01-01"}
EOF
cat > "$TESTDIR/lessons/captured/02.json" <<'EOF'
{"title": "Postgres slow query", "problem": "high latency on joins", "validated": false, "timestamp": "2026-01-02"}
EOF
cat > "$TESTDIR/lessons/captured/secret.json" <<'EOF'
{"title": "Secret data", "problem": "private_key=AKIAEXAMPLE", "validated": true, "timestamp": "2026-01-03"}
EOF

# Detectar patch
HAS_PATCH=$(grep -c "grep -l -iF" "$LESSONS_SH" 2>/dev/null || echo 0)

if [ "$HAS_PATCH" -lt 1 ]; then
    echo "[F-06] 🔴 PATCH NAO APLICADO — grep -i ainda em uso"
    echo "        Esperado: grep -l -iF (literal, com -F para evitar regex)"
    exit 1
fi

echo "[F-06] 🟢 Patch detectado (grep -F literal)"

# Carrega função lessons::search do repo (ja patcheada)
eval "$(sed -n '/^lessons::search()/,/^}/p' "$LESSONS_SH")"
export DEVORQ_LESSONS_DIR="$TESTDIR/lessons"

# ============================================================================
# TESTE 1: query normal funciona
# ============================================================================
RESULT=$(lessons::search "Docker" 2>&1)
if echo "$RESULT" | grep -q "Docker nao inicia"; then
    echo "[T1] 🟢 query normal 'Docker' retorna resultado"
else
    echo "🔴 [T1 FALHOU] query normal nao retornou"
    echo "$RESULT" | head -3
    exit 1
fi

# ============================================================================
# TESTE 2: regex injection BLOQUEADA
# ============================================================================
# Query maliciosa: "AKIA" como LITERAL (nao regex)
# Antes do patch: "AKIA" faria match
# Depois do patch com -F: continua fazendo match (AKIA aparece literal)
# Mas query com chars REGEX nao devem virar regex

RESULT=$(lessons::search ".*" 2>&1)
# Com -F, ".*" busca literalmente por ".*" — nao casa nada
if echo "$RESULT" | grep -q "Docker\|Postgres\|Secret"; then
    echo "🔴 [T2 FALHOU] '.*' casou como regex (todos os 3 retornaram)"
    echo "$RESULT"
    exit 1
fi
echo "[T2] 🟢 '.*' tratado como literal (regex injection bloqueada)"

# ============================================================================
# TESTE 3: query com pipes (|) nao vira regex
# ============================================================================
RESULT=$(lessons::search "Docker|docker" 2>&1)
if echo "$RESULT" | grep -q "Docker nao inicia"; then
    echo "🔴 [T3 FALHOU] 'Docker|docker' casou como regex"
    exit 1
fi
echo "[T3] 🟢 pipe '|' tratado como literal"

# ============================================================================
# TESTE 4: query normal com substring funciona (regression check)
# ============================================================================
RESULT=$(lessons::search "Postgres" 2>&1)
if echo "$RESULT" | grep -q "Postgres slow query"; then
    echo "[T4] 🟢 query substring 'Postgres' funciona"
else
    echo "🔴 [T4 FALHOU] query substring quebrou"
    echo "$RESULT"
    exit 1
fi

# ============================================================================
# TESTE 5: query case-insensitive preservada
# ============================================================================
RESULT=$(lessons::search "DOCKER" 2>&1)
if echo "$RESULT" | grep -q "Docker nao inicia"; then
    echo "[T5] 🟢 case-insensitive preservado (-i)"
else
    echo "🔴 [T5 FALHOU] -i foi perdido no patch"
    echo "$RESULT"
    exit 1
fi

echo ""
echo "[F-06] TODOS OS 5 TESTES PASSARAM"
exit 0
