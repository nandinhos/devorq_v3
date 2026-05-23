#!/usr/bin/env bash
# scripts/test-commands.sh — Testes para módulos CLI e commands

set +e  # Don't exit on errors in test conditions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "${GREEN}✓${NC} $*"; ((TESTS_PASSED++)) || true; }
fail() { echo -e "${RED}✗${NC} $*"; ((TESTS_FAILED++)) || true; }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

# ============================================================
# SETUP
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/devorq-test-commands"
DEVORQ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$DEVORQ_ROOT/lib"

setup() {
    info "Setup: criando ambiente de teste..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
    export DEVORQ_ROOT DEVORQ_DIR TEST_DIR LIB_DIR
}

teardown() {
    info "Teardown: limpando..."
    rm -rf "$TEST_DIR"
}

# ============================================================
# TEST: CLI INIT
# ============================================================

test_cli_init() {
    info "Test: CLI init command"
    cd "$TEST_DIR"
    source "$LIB_DIR/commands/cli/init.sh" 2>/dev/null || true
    
    # Test: init creates directory structure
    rm -rf "$TEST_DIR/.devorq"
    mkdir -p "$TEST_DIR"
    output=$(devorq::cmd_init "$TEST_DIR" 2>&1)
    
    if [ -d "$TEST_DIR/.devorq/state/lessons" ]; then
        pass "init creates .devorq structure"
    else
        fail "init should create .devorq structure"
    fi
    ((TESTS_RUN++)) || true
    
    # Test: init creates context.json
    if [ -f "$TEST_DIR/.devorq/state/context.json" ]; then
        pass "init creates context.json"
    else
        fail "init should create context.json"
    fi
    ((TESTS_RUN++)) || true
    
    # Test: init handles nonexistent directory
    output=$(devorq::cmd_init "/nonexistent/path" 2>&1)
    if echo "$output" | grep -qi "não existe\|não encontrado\|does not exist\|not found"; then
        pass "init handles nonexistent path"
    else
        fail "init should handle nonexistent path"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# TEST: CLI VERSION
# ============================================================

test_cli_version() {
    info "Test: CLI version command"
    cd "$TEST_DIR"
    export DEVORQ_ROOT="$DEVORQ_ROOT"
    source "$LIB_DIR/commands/cli/version.sh" 2>/dev/null || true
    
    output=$(devorq::cmd_version 2>/dev/null)
    if echo "$output" | grep -q "DEVORQ"; then
        pass "version outputs DEVORQ"
    else
        fail "version should output DEVORQ"
    fi
    ((TESTS_RUN++)) || true
    
    if echo "$output" | grep -q "v[0-9]"; then
        pass "version outputs version number"
    else
        fail "version should output version number"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# TEST: CLI STATS
# ============================================================

test_cli_stats() {
    info "Test: CLI stats command"
    cd "$TEST_DIR"
    export DEVORQ_ROOT="$PWD"
    export DEVORQ_DIR="$TEST_DIR/.devorq"
    source "$LIB_DIR/commands/cli/stats.sh" 2>/dev/null || true
    
    if devorq::cmd_stats 2>/dev/null; then
        pass "stats runs without error"
    else
        fail "stats should run without error"
    fi
    ((TESTS_RUN++)) || true
    
    output=$(devorq::cmd_stats 2>/dev/null)
    if echo "$output" | grep -q "Project:"; then
        pass "stats shows project name"
    else
        fail "stats should show project name"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# TEST: LESSONS APPROVE
# ============================================================

test_lessons_approve() {
    info "Test: lessons::approve"
    cd "$TEST_DIR"
    export DEVORQ_DIR="$TEST_DIR/.devorq"
    export DEVORQ_LESSONS_DIR="$TEST_DIR/.devorq/state/lessons"
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
    source "$LIB_DIR/commands/lessons/index.sh"
    
    # Setup: criar lição
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
    echo '{"id":"lesson_approve","title":"Approve Test","problem":"Test problem","solution":"Test solution","approved":false}' > "$TEST_DIR/.devorq/state/lessons/captured/lesson_approve.json"
{
  "id": "lesson_approve",
  "title": "Approve Test",
  "problem": "Test problem",
  "solution": "Test solution",
  "approved": false
}
EOF
    
    # Test: approve adds approved field
    output=$(lessons::approve "lesson_approve" "" "true" 2>&1)
    if echo "$output" | grep -qi "aprovada\|approved"; then
        pass "lessons::approve outputs success"
    else
        fail "lessons::approve should output success"
    fi
    ((TESTS_RUN++)) || true
    
    # Test: approve handles nonexistent lesson
    output=$(lessons::approve "nonexistent" 2>&1)
    if echo "$output" | grep -qi "não encontrada\|não encontrado\|not found"; then
        pass "approve handles nonexistent"
    else
        fail "approve should handle nonexistent"
    fi
    ((TESTS_RUN++)) || true
    
    # Test: approve --help shows usage
    output=$(lessons::approve --help 2>&1)
    if echo "$output" | grep -q "USAGE"; then
        pass "approve --help shows usage"
    else
        fail "approve --help should show usage"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# TEST: LESSONS COMPILE
# ============================================================

test_lessons_compile() {
    info "Test: lessons::compile"
    cd "$TEST_DIR"
    export DEVORQ_DIR="$TEST_DIR/.devorq"
    export DEVORQ_LESSONS_DIR="$TEST_DIR/.devorq/state/lessons"
    source "$LIB_DIR/commands/lessons/index.sh"
    
    # Setup: criar lição aprovada
    mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
    echo '{"id":"lesson_compile","title":"Compile Test","problem":"Test problem","solution":"Test solution","approved":true,"skill_name":"test-skill"}' > "$TEST_DIR/.devorq/state/lessons/captured/lesson_compile.json"
    
    # Test: compile --dry-run works
    output=$(lessons::compile "" "" "true" 2>&1)
    if echo "$output" | grep -qi "dry run\|dry"; then
        pass "compile --dry-run works"
    else
        fail "compile --dry-run should work"
    fi
    ((TESTS_RUN++)) || true
    
    # Test: compile runs without error
    if lessons::compile 2>/dev/null; then
        pass "compile runs without error"
    else
        fail "compile should run without error"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# TEST: LESSONS LIST
# ============================================================

test_lessons_list() {
    info "Test: lessons::list"
    cd "$TEST_DIR"
    export DEVORQ_DIR="$TEST_DIR/.devorq"
    export DEVORQ_LESSONS_DIR="$TEST_DIR/.devorq/state/lessons"
    source "$LIB_DIR/commands/lessons/index.sh"
    
    # Test: list shows help with --help
    output=$(lessons::list --help 2>&1)
    if echo "$output" | grep -qi "USAGE\|FILTERS\|devorq lessons"; then
        pass "list --help shows usage"
    else
        fail "list --help should show usage"
    fi
    ((TESTS_RUN++)) || true
    
    # Test: list runs without error
    if lessons::list 2>/dev/null; then
        pass "list runs without error"
    else
        fail "list should run without error"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# TEST: DDD VALIDATE
# ============================================================

test_ddd_validate() {
    info "Test: ddd validate"
    cd "$TEST_DIR"
    export DEVORQ_ROOT="$PWD"
    source "$LIB_DIR/commands/ddd.sh" 2>/dev/null || true
    
    # Setup: criar SPEC.md
    echo '# Test Project

## Domain Model
Entities: User, Order
Bounded Contexts: CRM, Billing' > "$TEST_DIR/SPEC.md"
    
    # Test: ddd validate with valid spec
    output=$(devorq::cmd_ddd_validate 2>/dev/null)
    if echo "$output" | grep -qi "Score\|PASS\|GATE\|válido"; then
        pass "ddd validate outputs result"
    else
        fail "ddd validate should output result"
    fi
    ((TESTS_RUN++)) || true
    
    # Test: ddd validate with missing spec
    rm "$TEST_DIR/SPEC.md"
    output=$(devorq::cmd_ddd_validate 2>&1)
    if echo "$output" | grep -qi "não encontrado\|not found\|não encontrado"; then
        pass "ddd validate handles missing spec"
    else
        fail "ddd validate should handle missing spec"
    fi
    ((TESTS_RUN++)) || true
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo ""
    echo "========================================"
    echo " Commands Module Tests"
    echo "========================================"
    echo ""
    
    setup
    trap teardown EXIT
    
    test_cli_init
    test_cli_version
    test_cli_stats
    test_lessons_approve
    test_lessons_compile
    test_lessons_list
    test_ddd_validate
    
    echo ""
    echo "========================================"
    echo " Commands Tests Summary"
    echo "========================================"
    echo " Tests run:    $TESTS_RUN"
    echo " Passed:       $TESTS_PASSED"
    echo " Failed:       $TESTS_FAILED"
    echo "========================================"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        return 0
    else
        echo -e "${RED}SOME TESTS FAILED${NC}"
        return 1
    fi
}

main "$@"
