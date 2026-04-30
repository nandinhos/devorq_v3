#!/usr/bin/env bash
# scripts/ci-test.sh — DEVORQ v3 CI Test Suite
# Run locally or in GitHub Actions
# Exit codes: 0 = all pass, 1 = any failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVORQ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)); ((TESTS_RUN++)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)); ((TESTS_RUN++)); }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

cleanup() {
    # Restaura estado original
    if [ -d "$DEVORQ_ROOT/.devorq.bak" ]; then
        rm -rf "$DEVORQ_ROOT/.devorq"
        mv "$DEVORQ_ROOT/.devorq.bak" "$DEVORQ_ROOT/.devorq"
    fi
    # Remove skill de teste se existir
    rm -rf "$DEVORQ_ROOT/skills/learned-lesson"
    rm -rf "$DEVORQ_ROOT/skills/.index.md"
    # Limpa lessons de teste
    rm -f "$DEVORQ_ROOT/.devorq/state/lessons/captured/"*.json 2>/dev/null || true
}

# Setup
trap cleanup EXIT
mkdir -p "$DEVORQ_ROOT/.devorq/state/lessons/captured"

# Backup estado atual
rm -rf "$DEVORQ_ROOT/.devorq.bak" 2>/dev/null || true
[ -d "$DEVORQ_ROOT/.devorq" ] && mv "$DEVORQ_ROOT/.devorq" "$DEVORQ_ROOT/.devorq.bak"
mkdir -p "$DEVORQ_ROOT/.devorq/state/lessons/captured"

export DEVORQ_DIR="$DEVORQ_ROOT"
export DEVORQ_ROOT="$DEVORQ_ROOT"
export DEVORQ_LESSONS_DIR="$DEVORQ_ROOT/.devorq/state/lessons"
export DEVORQ_LIB="$DEVORQ_ROOT/lib"
export PATH="$DEVORQ_ROOT/bin:$PATH"
export LESSONS_AUTO=true

cd "$DEVORQ_ROOT"

echo ""
echo "========================================"
echo " DEVORQ v3 — CI Test Suite"
echo "========================================"
echo ""

# ============================================================
# FASE 1: Sintaxe
# ============================================================
info "═══ FASE 1: Sintaxe ═══"

check_syntax() {
    local file="$1"
    if bash -n "$file" 2>/dev/null; then
        pass "syntax: $file"
        return 0
    else
        fail "syntax: $file"
        return 1
    fi
}

check_syntax "$DEVORQ_ROOT/bin/devorq" || true
for f in "$DEVORQ_LIB"/*.sh; do
    check_syntax "$f" || true
done

echo ""

# ============================================================
# FASE 2: Estrutura
# ============================================================
info "═══ FASE 2: Estrutura ═══"

[ -f "$DEVORQ_LIB/lessons.sh" ] && pass "lib/lessons.sh existe" || fail "lib/lessons.sh existe"
[ -f "$DEVORQ_LIB/gates.sh" ] && pass "lib/gates.sh existe" || fail "lib/gates.sh existe"
[ -f "$DEVORQ_LIB/context7.sh" ] && pass "lib/context7.sh existe" || fail "lib/context7.sh existe"
[ -f "$DEVORQ_LIB/compact.sh" ] && pass "lib/compact.sh existe" || fail "lib/compact.sh existe"
[ -f "$DEVORQ_ROOT/bin/devorq" ] && pass "bin/devorq existe" || fail "bin/devorq existe"

# Skills
[ -d "$DEVORQ_ROOT/skills/scope-guard" ] && pass "skills/scope-guard existe" || fail "skills/scope-guard existe"
[ -d "$DEVORQ_ROOT/skills/env-context" ] && pass "skills/env-context existe" || fail "skills/env-context existe"
[ -d "$DEVORQ_ROOT/skills/ddd-deep-domain" ] && pass "skills/ddd-deep-domain existe" || fail "skills/ddd-deep-domain existe"
[ -d "$DEVORQ_ROOT/skills/devorq-auto" ] && pass "skills/devorq-auto existe" || fail "skills/devorq-auto existe"
[ -d "$DEVORQ_ROOT/skills/devorq-mode" ] && pass "skills/devorq-mode existe" || fail "skills/devorq-mode existe"
[ -d "$DEVORQ_ROOT/skills/devorq-code-review" ] && pass "skills/devorq-code-review existe" || fail "skills/devorq-code-review existe"

echo ""

# ============================================================
# FASE 3: Lessons Loop (capture → validate → approve → compile)
# ============================================================
info "═══ FASE 3: Lessons Loop ═══"

# Carrega lessons.sh
source "$DEVORQ_LIB/lessons.sh"

# 3a: capture
LESSON_ID=""
capture_result=$(lessons::capture "CI Test: file permission" "Permission denied ao criar arquivo" "Usar chmod corretamente" 2>&1) || true
if echo "$capture_result" | grep -q "Lição salva"; then
    pass "lessons::capture"
    LESSON_ID=$(ls "$DEVORQ_LESSONS_DIR/captured/"*.json 2>/dev/null | head -1 | sed 's/.*\///; s/\.json$//')
else
    fail "lessons::capture — output: $capture_result"
fi

# 3b: migrate
migrate_result=$(lessons::migrate 2>&1) || true
if echo "$migrate_result" | grep -q "Lições migradas"; then
    pass "lessons::migrate"
else
    warn "lessons::migrate — output: $migrate_result"
fi

# 3c: validate (auto-mode — auto-valida sem Context7)
validate_result=$(LESSONS_AUTO=true lessons::validate 2>&1) || true
if echo "$validate_result" | grep -q "lição(ões) auto-validadas\|Validadas: [1-9]"; then
    pass "lessons::validate (auto-trigger)"
else
    fail "lessons::validate — output: $validate_result"
fi

# 3d: approve
if [ -n "$LESSON_ID" ]; then
    approve_result=$(lessons::approve "$LESSON_ID" "" "true" 2>&1) || true
    if echo "$approve_result" | grep -qi "aprovada\|já aprovada\|already"; then
        pass "lessons::approve"
    else
        fail "lessons::approve — output: $approve_result"
    fi
fi

# 3e: compile
compile_result=$(lessons::compile "" "" "false" 2>&1) || true
if echo "$compile_result" | grep -q "Skill compilada"; then
    pass "lessons::compile"
else
    fail "lessons::compile — output: $compile_result"
fi

# 3f: skill gerada
if [ -f "$DEVORQ_ROOT/skills/learned-lesson/SKILL.md" ]; then
    pass "skill SKILL.md gerada"
else
    fail "skill SKILL.md gerada"
fi

# 3g: compile dry-run
compile_dry=$(lessons::compile "" "" "true" 2>&1) || true
if echo "$compile_dry" | grep -q "DRY RUN"; then
    pass "lessons::compile --dry-run"
else
    fail "lessons::compile --dry-run — output: $compile_dry"
fi

echo ""

# ============================================================
# FASE 4: CLI commands
# ============================================================
info "═══ FASE 4: CLI Commands ═══"

# devorq test
cli_test=$(bin/devorq test 2>&1) || true
if echo "$cli_test" | grep -q "OK\|Estrutura OK"; then
    pass "devorq test"
else
    fail "devorq test — output: $cli_test"
fi

# devorq lessons list
cli_list=$(bin/devorq lessons list 2>&1) || true
if echo "$cli_list" | grep -q "LESSONS\|Total"; then
    pass "devorq lessons list"
else
    fail "devorq lessons list — output: $cli_list"
fi

# devorq lessons list approved
cli_list_appr=$(bin/devorq lessons list approved 2>&1) || true
if echo "$cli_list_appr" | grep -q "LESSONS\|★"; then
    pass "devorq lessons list approved"
else
    fail "devorq lessons list approved — output: $cli_list_appr"
fi

# devorq lessons approve --help
cli_approve_help=$(bin/devorq lessons approve --help 2>&1) || true
if echo "$cli_approve_help" | grep -q "Uso:"; then
    pass "devorq lessons approve --help"
else
    fail "devorq lessons approve --help — output: $cli_approve_help"
fi

# devorq lessons compile --help
cli_compile_help=$(bin/devorq lessons compile --help 2>&1) || true
if echo "$cli_compile_help" | grep -q "Uso:"; then
    pass "devorq lessons compile --help"
else
    fail "devorq lessons compile --help — output: $cli_compile_help"
fi

# devorq ddd validate
cli_ddd=$(bin/devorq ddd validate 2>&1) || true
if echo "$cli_ddd" | grep -q "GATE-0\|Score\|PASS\|FAIL"; then
    pass "devorq ddd validate"
else
    fail "devorq ddd validate — output: $cli_ddd"
fi

echo ""

# ============================================================
# FASE 5: Skills scripts
# ============================================================
info "═══ FASE 5: Skills Scripts ═══"

# env-detect.sh
env_detect=$("$DEVORQ_ROOT/skills/env-context/scripts/env-detect.sh" 2>&1) || true
if echo "$env_detect" | grep -q "DEVORQ ENVIRONMENT CONTEXT\|Stack:\|Runtime:"; then
    pass "env-detect.sh"
else
    fail "env-detect.sh — output: $env_detect"
fi

# ddd-validate-spec.sh
ddd_val=$("$DEVORQ_ROOT/skills/ddd-deep-domain/scripts/ddd-validate-spec.sh" "$DEVORQ_ROOT/SPEC.md" 2>&1) || true
if echo "$ddd_val" | grep -q "GATE-0\|Score\|PASS\|FAIL"; then
    pass "ddd-validate-spec.sh"
else
    fail "ddd-validate-spec.sh — output: $ddd_val"
fi

echo ""

# ============================================================
# RESUMO
# ============================================================
echo "========================================"
echo " CI Results: $TESTS_PASSED/$TESTS_RUN passed"
if [ "$TESTS_FAILED" -gt 0 ]; then
    echo -e "${RED}FAILED${NC}: $TESTS_FAILED test(s)"
    echo ""
    exit 1
else
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    echo ""
    exit 0
fi
