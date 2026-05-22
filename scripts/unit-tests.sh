#!/usr/bin/env bash
# scripts/unit-tests.sh — Unit tests para módulos DEVORQ v3
#
# Testa:
#   - Gates (lib/gates.sh)
#   - Lessons (lib/lessons.sh)
#   - Context (lib/context.sh)
#   - Workflow (lib/commands/workflow.sh)

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEVORQ_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LIB_DIR="$DEVORQ_ROOT/lib"
readonly TEST_DIR="/tmp/devorq-unit-test"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_TEST_FAILED=2

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================
# Helpers
# ============================================================

unit::info() { echo -e "${CYAN}[TEST]${RESET} $*"; }
unit::pass() { echo -e "${GREEN}[PASS]${RESET} $*"; ((TESTS_PASSED++)) || true; }
unit::fail() { echo -e "${RED}[FAIL]${RESET} $*"; ((TESTS_FAILED++)) || true; }

setup_test_env() {
    rm -rf "$TEST_DIR" && mkdir -p "$TEST_DIR/.devorq/state/lessons/captured"
}

teardown_test_env() {
    rm -rf "$TEST_DIR"
}

assert() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    ((TESTS_RUN++))

    if [ "$expected" = "$actual" ]; then
        unit::pass "$message"
        return 0
    else
        unit::fail "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    ((TESTS_RUN++))

    if echo "$haystack" | grep -q "$needle"; then
        unit::pass "${message:-Contains: $needle}"
        return 0
    else
        unit::fail "${message:-Does not contain: $needle}"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    ((TESTS_RUN++))

    if [ -f "$file" ]; then
        unit::pass "$message"
        return 0
    else
        unit::fail "$message"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"

    ((TESTS_RUN++))

    if [ ! -f "$file" ]; then
        unit::pass "$message"
        return 0
    else
        unit::fail "$message"
        return 1
    fi
}

# ============================================================
# GATE TESTS
# ============================================================

test_gate_1_spec_exists() {
    unit::info "Test: GATE-1 SPEC.md exists"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: SPEC.md não existe
    if gate_1 2>/dev/null; then
        unit::fail "GATE-1 should fail when SPEC.md doesn't exist"
    else
        unit::pass "GATE-1 fails without SPEC.md"
    fi
    ((TESTS_RUN++))

    # Test: SPEC.md existe
    echo "# Test Spec" > "$TEST_DIR/SPEC.md"
    if gate_1 2>/dev/null; then
        unit::pass "GATE-1 passes with SPEC.md"
    else
        unit::fail "GATE-1 should pass when SPEC.md exists"
    fi
    ((TESTS_RUN++))

    # Test: SPEC.md vazio
    echo "" > "$TEST_DIR/SPEC.md"
    if gate_1 2>/dev/null; then
        unit::fail "GATE-1 should fail with empty SPEC.md"
    else
        unit::pass "GATE-1 fails with empty SPEC.md"
    fi
    ((TESTS_RUN++))
}

test_gate_2_syntax() {
    unit::info "Test: GATE-2 Syntax checks"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: shellcheck syntax
    if command -v shellcheck &>/dev/null; then
        if shellcheck -S error "$LIB_DIR"/*.sh 2>/dev/null | grep -q "SC[12]"; then
            unit::fail "Shellcheck found syntax errors"
        else
            unit::pass "Shellcheck: no syntax errors"
        fi
    else
        unit::pass "Shellcheck not available (skipped)"
    fi
    ((TESTS_RUN++))
}

test_gate_3_context() {
    unit::info "Test: GATE-3 Context documented"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"
    source "$LIB_DIR/context.sh"

    # Test: context.json não existe
    cat > "$TEST_DIR/SPEC.md" << 'EOF'
# Test
EOF

    if gate_3 2>/dev/null; then
        unit::pass "GATE-3 handles missing context.json"
    else
        unit::fail "GATE-3 should handle missing context.json"
    fi
    ((TESTS_RUN++))

    # Test: context.json existe com dados
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test-project",
  "stack": ["bash"],
  "intent": "testing"
}
EOF

    if gate_3 2>/dev/null; then
        unit::pass "GATE-3 passes with valid context.json"
    else
        unit::fail "GATE-3 should pass with valid context.json"
    fi
    ((TESTS_RUN++))
}

test_gate_4_lessons() {
    unit::info "Test: GATE-4 Lessons reviewed"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"

    # Test: Sem lessons
    if gate_4 2>/dev/null; then
        unit::pass "GATE-4 passes with no lessons (warning OK)"
    else
        unit::fail "GATE-4 should pass with no lessons"
    fi
    ((TESTS_RUN++))

    # Test: Com lessons
    echo '{"title":"test"}' > "$TEST_DIR/.devorq/state/lessons/captured/lesson_001.json"
    if gate_4 2>/dev/null; then
        unit::pass "GATE-4 passes with lessons"
    else
        unit::fail "GATE-4 should pass with lessons"
    fi
    ((TESTS_RUN++))
}

test_gate_5_handoff() {
    unit::info "Test: GATE-5 Handoff ready"

    cd "$TEST_DIR"
    source "$LIB_DIR/gates.sh"
    source "$LIB_DIR/compact.sh"

    # Setup context for handoff
    mkdir -p "$TEST_DIR/.devorq/state"
    cat > "$TEST_DIR/.devorq/state/context.json" << 'EOF'
{
  "project": "test",
  "stack": [],
  "intent": "test"
}
EOF

    if gate_5 2>/dev/null; then
        if [ -f "$TEST_DIR/.devorq/state/handoff.json" ]; then
            unit::pass "GATE-5 generates valid handoff.json"
        else
            unit::fail "GATE-5 should generate handoff.json"
        fi
    else
        unit::fail "GATE-5 should pass"
    fi
    ((TESTS_RUN++))
}

# ============================================================
# LESSONS TESTS
# ============================================================

test_lessons_capture() {
    unit::info "Test: lessons::capture"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Test: Capture válido
    if lessons::capture "Test Lesson" "Problem desc" "Solution desc" 2>/dev/null; then
        local files
        files=$(find "$TEST_DIR/.devorq/state/lessons/captured" -name "*.json" 2>/dev/null | wc -l)
        if [ "$files" -gt 0 ]; then
            unit::pass "lessons::capture creates JSON file"
        else
            unit::fail "lessons::capture should create JSON file"
        fi
    else
        unit::fail "lessons::capture should succeed"
    fi
    ((TESTS_RUN++))

    # Test: Capture com title vazio (deve falhar ou lidar gracefully)
    local files_before
    files_before=$(find "$TEST_DIR/.devorq/state/lessons/captured" -name "*.json" 2>/dev/null | wc -l)

    if ! lessons::capture "" "Problem" "Solution" 2>/dev/null; then
        unit::pass "lessons::capture handles empty title"
    else
        # Aceita se passou e não criou arquivo
        local files_after
        files_after=$(find "$TEST_DIR/.devorq/state/lessons/captured" -name "*.json" 2>/dev/null | wc -l)
        if [ "$files_after" -eq "$files_before" ]; then
            unit::pass "lessons::capture does not create file with empty title"
        else
            unit::fail "lessons::capture should not create file with empty title"
        fi
    fi
    ((TESTS_RUN++))
}

test_lessons_schema() {
    unit::info "Test: Lessons JSON schema"

    cd "$TEST_DIR"
    source "$LIB_DIR/lessons.sh"

    # Criar lesson
    lessons::capture "Schema Test" "Problem" "Solution" 2>/dev/null || true

    local lesson_file
    lesson_file=$(find "$TEST_DIR/.devorq/state/lessons/captured" -name "*.json" -type f 2>/dev/null | head -1)

    if [ -n "$lesson_file" ] && [ -f "$lesson_file" ]; then
        # Verificar campos obrigatórios
        if command -v jq &>/dev/null; then
            local has_title has_problem has_solution
            has_title=$(jq -r '.title' "$lesson_file" 2>/dev/null)
            has_problem=$(jq -r '.problem' "$lesson_file" 2>/dev/null)
            has_solution=$(jq -r '.solution' "$lesson_file" 2>/dev/null)

            if [ "$has_title" != "null" ] && [ "$has_problem" != "null" ] && [ "$has_solution" != "null" ]; then
                unit::pass "Lesson has required fields (title, problem, solution)"
            else
                unit::fail "Lesson missing required fields"
            fi
        else
            # Sem jq, verificar se arquivo tem conteúdo
            if grep -q "title" "$lesson_file" && grep -q "problem" "$lesson_file"; then
                unit::pass "Lesson has content"
            else
                unit::fail "Lesson should have content"
            fi
        fi
    else
        unit::fail "No lesson file found"
    fi
    ((TESTS_RUN++))
}

# ============================================================
# WORKFLOW TESTS
# ============================================================

test_workflow_init() {
    unit::info "Test: devorq::cmd_init"

    cd "$TEST_DIR"
    rm -rf "$TEST_DIR/.devorq"

    # Setup DEVORQ_ROOT for init
    export DEVORQ_ROOT
    DEVORQ_ROOT="$DEVORQ_ROOT"
    export DEVORQ_VERSION="3.6.6"

    source "$LIB_DIR/helpers.sh" 2>/dev/null || true
    source "$LIB_DIR/commands/workflow.sh"

    if declare -f devorq::cmd_init &>/dev/null; then
        if devorq::cmd_init 2>/dev/null; then
            assert_file_exists "$TEST_DIR/.devorq" "Creates .devorq directory"
            assert_file_exists "$TEST_DIR/.devorq/state" "Creates .devorq/state directory"
            assert_file_exists "$TEST_DIR/.devorq/state/context.json" "Creates context.json"
        else
            unit::fail "devorq::cmd_init should succeed"
        fi
    else
        unit::skip "devorq::cmd_init not found"
    fi
    ((TESTS_RUN++))
}

# ============================================================
# SUMMARY
# ============================================================

unit::summary() {
    echo ""
    echo "=========================================="
    echo " Unit Tests Summary"
    echo "=========================================="
    echo -e " Tests run:    ${TESTS_RUN}"
    echo -e " Passed:       ${GREEN}${TESTS_PASSED}${RESET}"
    echo -e " Failed:       ${RED}${TESTS_FAILED}${RESET}"
    echo "=========================================="

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}ALL TESTS PASSED${RESET}"
        return $EXIT_SUCCESS
    else
        echo -e "${RED}SOME TESTS FAILED${RESET}"
        return $EXIT_TEST_FAILED
    fi
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo "=========================================="
    echo " DEVORQ v3 — Unit Tests"
    echo "=========================================="
    echo ""

    setup_test_env

    # Executar testes
    test_gate_1_spec_exists
    test_gate_2_syntax
    test_gate_3_context
    test_gate_4_lessons
    test_gate_5_handoff
    test_lessons_capture
    test_lessons_schema
    test_workflow_init

    teardown_test_env

    unit::summary
}

main "$@"
