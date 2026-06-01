#!/usr/bin/env bash
# ============================================================================
# PATCH F-06: Corrigir grep regex injection em lib/lessons.sh:151
# ============================================================================
# Substitui:  grep -l -i "$query"  (interpreta $query como regex)
# Por:        grep -l -iF -- "$query"  (literal, sem regex)
# ============================================================================

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"
LESSONS_SH="$REPO_DIR/lib/lessons.sh"

if [ ! -f "$LESSONS_SH" ]; then
    echo "[F-06] 🔴 Arquivo nao encontrado: $LESSONS_SH"
    exit 1
fi

cp "$LESSONS_SH" "$LESSONS_SH.bak"

HERMES_PY=$(cat <<'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

old = '    results=$(grep -l -i "$query" "$dir"/*.json 2>/dev/null || true)'
new = '    # PATCH F-06: -F (literal) impede regex injection, -- encerra opcoes\n    results=$(grep -l -iF -- "$query" "$dir"/*.json 2>/dev/null || true)'

if old in content:
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)
    print("[F-06] 🟢 Patch aplicado em", path)
    print(f"       Backup: {path}.bak")
else:
    print("[F-06] 🟡 Pattern nao encontrado")
    sys.exit(1)
PYEOF
)

python3 -c "$HERMES_PY" "$LESSONS_SH"

if [ $? -eq 0 ]; then
    if bash "$SCRIPT_DIR/tests/test_F06_grep_injection.sh"; then
        echo ""
        echo "[F-06] ✅ PATCH APLICADO + TESTES PASSARAM"
        exit 0
    else
        echo ""
        echo "[F-06] 🔴 PATCH APLICADO MAS TESTES FALHARAM — restore"
        mv "$LESSONS_SH.bak" "$LESSONS_SH"
        exit 1
    fi
else
    echo "[F-06] 🔴 Falha ao aplicar patch"
    exit 1
fi
