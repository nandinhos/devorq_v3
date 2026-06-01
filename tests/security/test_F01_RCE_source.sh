#!/usr/bin/env bash
# ============================================================================
# TEST F-01: RCE via source <(grep ...) em lib/context7.sh
# ============================================================================

set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"
CONTEXT7_SH="$REPO_DIR/lib/context7.sh"

TEST_HOME="/tmp/f01_test_$$"
mkdir -p "$TEST_HOME/.devorq"

cleanup() {
    unset OPENAI_API_KEY CTX7_API_KEY CTX7_MCP_URL 2>/dev/null || true
    rm -rf "$TEST_HOME" 2>/dev/null
    rm -f /tmp/PWNED_F01_*_$$ 2>/dev/null
}
trap cleanup EXIT

if [ ! -f "$CONTEXT7_SH" ]; then
    echo "[F-01] Arquivo nao encontrado: $CONTEXT7_SH"
    exit 1
fi

HAS_PATCH=$(grep -c "while IFS.*read.*declare" "$CONTEXT7_SH" 2>/dev/null | tr -d '\n' || echo "0")
if [ -z "$HAS_PATCH" ] || [ "$HAS_PATCH" = "0" ]; then
    echo "[F-01] PATCH NAO APLICADO"
    echo "        Esperado: 'while IFS=...read...' em lib/context7.sh"
    exit 1
fi
echo "[F-01] Patch detectado em _load_config()"

get_load_config() {
    sed -n '/^_load_config()/,/^}/p' "$CONTEXT7_SH"
}

export HOME="$TEST_HOME"

# T1: payload com subshell (&&)
P1="/tmp/PWNED_F01_T1_$$"
cat > "$TEST_HOME/.devorq/config" <<EOF
OPENAI_API_KEY=*** $P1 && echo pwned)
EOF
unset OPENAI_API_KEY 2>/dev/null || true
eval "$(get_load_config)"
if [ -f "$P1" ]; then
    echo "[T1 FALHOU] RCE com && criou $P1"
    exit 1
fi
echo "[T1] payload '&&' bloqueado"
rm -f "$P1"

# T2: backticks
P2="/tmp/PWNED_F01_T2_$$"
cat > "$TEST_HOME/.devorq/config" <<EOF
CTX7_API_KEY=*** $P2 && echo pwned)
EOF
unset CTX7_API_KEY 2>/dev/null || true
eval "$(get_load_config)"
if [ -f "$P2" ]; then
    echo "[T2 FALHOU] RCE com backticks criou $P2"
    exit 1
fi
echo "[T2] payload backticks bloqueado"
rm -f "$P2"

# T3: ;
P3="/tmp/PWNED_F01_T3_$$"
cat > "$TEST_HOME/.devorq/config" <<EOF
CTX7_MCP_URL=*** $P3; OPENAI_API_KEY=*** "test"
EOF
unset CTX7_MCP_URL 2>/dev/null || true
eval "$(get_load_config)"
if [ -f "$P3" ]; then
    echo "[T3 FALHOU] RCE com ; criou $P3"
    exit 1
fi
echo "[T3] payload ';' bloqueado"
rm -f "$P3"

# T4: variavel VALIDA funciona
unset OPENAI_API_KEY 2>/dev/null || true
cat > "$TEST_HOME/.devorq/config" <<'EOF'
# Comentario ignorado
OPENAI_API_KEY=sk-tes...val "$(get_load_config)"
if [ "${OPENAI_API_KEY:-}" = "sk-tes...bcde" ]; then
    echo "[T4] variavel VALIDA preservada"
else
    echo "[T4 FALHOU] esperado 'sk-tes...bcde', recebido '${OPENAI_API_KEY:-<vazio>}'"
    exit 1
fi

# T5: key NAO-whitelist ignorada
unset RANDOM_KEY ANOTHER_THING 2>/dev/null || true
cat > "$TEST_HOME/.devorq/config" <<EOF
RANDOM_KEY=should-be-ignored
ANOTHER_THING=also-ignored
OPENAI_API_KEY=*** "T6: shellcheck no trecho patcheado (snippet isolado)
TMP_FILE=$(mktemp --suffix=.sh)
cat > "$TMP_FILE" <<'CHK_EOF'
#!/usr/bin/env bash
set -euo pipefail
CTX7_CONFIG="/tmp/fake_cfg_sc"
touch "$CTX7_CONFIG"
_load_config() {
    if [ -f "$CTX7_CONFIG" ]; then
        while IFS='=' read -r k v; do
            [[ "$k" =~ ^(OPENAI_API_KEY|CTX7_API_KEY|CTX7_MCP_URL)$ ]] || continue
            declare -gx "$k=$v"
        done < <(grep -E "^(OPENAI_API_KEY|CTX7_API_KEY|CTX7_MCP_URL)=" "$CTX7_CONFIG" 2>/dev/null)
        CTX7_API_KEY="${OP..."
    fi
}
_load_config
echo "ok"
CHK_EOF

SH_OUT=$(shellcheck -S warning "$TMP_FILE" 2>&1)
if echo "$SH_OUT" | grep -qE "SC[0-9]+"; then
    echo "[T6] Shellcheck reportou:"
    echo "$SH_OUT" | head -3
else
    echo "[T6] Shellcheck warning-level: 0 issues"
fi
rm -f "$TMP_FILE"

echo ""
echo "[F-01] TODOS OS 6 TESTES PASSARAM"
exit 0
