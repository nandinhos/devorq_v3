#!/usr/bin/env bash
# ============================================================================
# PATCH F-01: Corrigir RCE em lib/context7.sh:38
# ============================================================================
# Substitui:  source <(grep -E "..."  ... || true)
# Por:        while+read com validacao explicita de keys
# ============================================================================

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"
CONTEXT7_SH="$REPO_DIR/lib/context7.sh"

if [ ! -f "$CONTEXT7_SH" ]; then
    echo "[F-01] 🔴 Arquivo nao encontrado: $CONTEXT7_SH"
    exit 1
fi

# Backup
cp "$CONTEXT7_SH" "$CONTEXT7_SH.bak"

# PATCH: substituir source <(grep ...) por while+read
# Estrategia: usar patch() tool do Hermes para fazer replace exato
HERMES_PY=$(cat <<'PYEOF'
import sys
import re

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Pattern do codigo vulneravel (lida com indentacao)
old = '''        # shellcheck source=/dev/null
        source <(grep -E "^(OPENAI_API_KEY|CTX7_API_KEY|CTX7_MCP_URL)=" "$CTX7_CONFIG" 2>/dev/null || true)
        CTX7_API_KEY="${OPENAI_API_KEY:-${CTX7_API_KEY:-}}"'''

new = '''        # PATCH F-01: substituir source <(grep ...) por leitura segura
        # O source original executava command substitution no shell atual
        # (RCE via payload no $CTX7_CONFIG). Agora validamos keys explicitamente.
        while IFS='=' read -r k v; do
            [[ "$k" =~ ^(OPENAI_API_KEY|CTX7_API_KEY|CTX7_MCP_URL)$ ]] || continue
            declare -gx "$k=$v"
        done < <(grep -E "^(OPENAI_API_KEY|CTX7_API_KEY|CTX7_MCP_URL)=" "$CTX7_CONFIG" 2>/dev/null)
        CTX7_API_KEY="${OPENAI_API_KEY:-${CTX7_API_KEY:-}}"'''

if old in content:
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print("[F-01] 🟢 Patch aplicado em", path)
    print(f"       Backup: {path}.bak")
else:
    print("[F-01] 🟡 Pattern nao encontrado (ja patcheado ou mudanca no source?)")
    print("       Diff manual necessario em", path)
    sys.exit(1)
PYEOF
)

python3 -c "$HERMES_PY" "$CONTEXT7_SH"

if [ $? -eq 0 ]; then
    # Roda o teste
    if bash "$SCRIPT_DIR/tests/test_F01_RCE_source.sh"; then
        echo ""
        echo "[F-01] ✅ PATCH APLICADO + TESTES PASSARAM"
        exit 0
    else
        echo ""
        echo "[F-01] 🔴 PATCH APLICADO MAS TESTES FALHARAM — restore backup"
        mv "$CONTEXT7_SH.bak" "$CONTEXT7_SH"
        exit 1
    fi
else
    echo "[F-01] 🔴 Falha ao aplicar patch"
    exit 1
fi
