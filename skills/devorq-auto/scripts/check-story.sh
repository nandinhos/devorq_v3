#!/usr/bin/env bash
#===========================================================
# devorq-auto — check-story.sh v1.0.0
# Verification gate apos implementacao de cada story.
# Roda: lint (Pint) + tests + verification-before-completion
#===========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

#-----------------------------------------------------------
# Helpers
#-----------------------------------------------------------
devorq_auto::usage() {
    cat <<EOF
Usage: check-story.sh <PROJECT_ROOT> [--skip-lint] [--skip-tests]

Verification gate apos implementacao de story.
Roda Pint (PHP) se encontrar composer.json ou phpinsights.php
Roda PHPUnit se encontrar phpunit.xml ou .phpunit.xml
Roda pytest se encontrar pytest.ini ou pyproject.toml

Args:
  PROJECT_ROOT   Diretorio do projeto (obrigatorio)
  --skip-lint   Pular linter
  --skip-tests  Pular tests

Exit codes:
  0  Verificacao passou completa
  1  Verificacao falhou (ler output para detalhes)
EOF
}

devorq_auto::die() {
    echo "ERROR: $*" >&2
    exit 1
}

devorq_auto::info() {
    echo "[check] $*"
}

#-----------------------------------------------------------
# Detectar stack e rodar checks apropriados
#-----------------------------------------------------------
devorq_auto::check_php() {
    # PHP: Pint + PHPUnit
    local php_dir="$1"
    local failed=0

    # Pint
    if [[ -f "$php_dir/composer.json" ]] || [[ -f "$php_dir/phpinsights.php" ]]; then
        if command -v ./vendor/bin/pint >/dev/null 2>&1; then
            devorq_auto::info "Running Pint..."
            if ./vendor/bin/pint --test 2>&1; then
                devorq_auto::info "✅ Pint OK"
            else
                devorq_auto::info "❌ Pint FAILED — applying fix..."
                ./vendor/bin/pint 2>&1 || { devorq_auto::die "Pint fix failed"; }
                failed=1
            fi
        elif command -v php >/dev/null 2>&1; then
            devorq_auto::info "(Pint skipped — vendor not installed)"
        fi
    fi

    # PHPUnit
    if [[ -f "$php_dir/phpunit.xml" ]] || [[ -f "$php_dir/.phpunit.xml" ]]; then
        if command -v ./vendor/bin/phpunit >/dev/null 2>&1; then
            devorq_auto::info "Running PHPUnit..."
            if ./vendor/bin/phpunit --colors=never 2>&1; then
                devorq_auto::info "✅ PHPUnit OK"
            else
                devorq_auto::info "❌ PHPUnit FAILED"
                failed=1
            fi
        else
            devorq_auto::info "(PHPUnit skipped — vendor not installed)"
        fi
    fi

    return $failed
}

devorq_auto::check_python() {
    # Python: pytest
    local py_dir="$1"
    local failed=0

    if [[ -f "$py_dir/pytest.ini" ]] || [[ -f "$py_dir/pyproject.toml" ]] || [[ -f "$py_dir/setup.py" ]]; then
        if command -v pytest >/dev/null 2>&1; then
            devorq_auto::info "Running pytest..."
            if pytest -x --tb=short 2>&1; then
                devorq_auto::info "✅ pytest OK"
            else
                devorq_auto::info "❌ pytest FAILED"
                failed=1
            fi
        elif command -v python3 >/dev/null 2>&1; then
            devorq_auto::info "Running python3 -m pytest..."
            if python3 -m pytest -x --tb=short 2>&1; then
                devorq_auto::info "✅ pytest OK"
            else
                devorq_auto::info "❌ pytest FAILED"
                failed=1
            fi
        fi
    fi

    return $failed
}

devorq_auto::check_node() {
    # Node: npm test
    local node_dir="$1"
    local failed=0

    if [[ -f "$node_dir/package.json" ]]; then
        if command -v npm >/dev/null 2>&1; then
            devorq_auto::info "Running npm test..."
            if npm test 2>&1; then
                devorq_auto::info "✅ npm test OK"
            else
                devorq_auto::info "❌ npm test FAILED"
                failed=1
            fi
        fi
    fi

    return $failed
}

devorq_auto::check_generic() {
    # Bash: shellcheck + basic checks
    local bash_dir="$1"
    local failed=0

    if [[ -f "$bash_dir/.devorq/state/context.json" ]]; then
        if command -v shellcheck >/dev/null 2>&1; then
            devorq_auto::info "Running shellcheck on *.sh..."
            # shellcheck não bloqueia — só avisa
            shellcheck "$bash_dir"/*.sh 2>/dev/null || true
        fi
    fi

    return 0
}

#-----------------------------------------------------------
# Main
#-----------------------------------------------------------
main() {
    local project_root=""
    local skip_lint=false
    local skip_tests=false

    [[ $# -lt 1 ]] && { devorq_auto::usage; exit 1; }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-lint) skip_lint=true; shift ;;
            --skip-tests) skip_tests=true; shift ;;
            -h|--help) devorq_auto::usage; exit 0 ;;
            *) project_root="$1"; shift ;;
        esac
    done

    [[ -z "$project_root" ]] && devorq_auto::die "PROJECT_ROOT obrigatorio"
    [[ ! -d "$project_root" ]] && devorq_auto::die "Diretorio nao existe: $project_root"

    echo ""
    echo "[devorq-auto] Verification Gate"
    echo "================================"

    local overall=0

    # Detectar stack e rodar checks
    if [[ -f "$project_root/composer.json" ]] || [[ -f "$project_root/phpinsights.php" ]]; then
        devorq_auto::check_php "$project_root" || overall=1
    fi

    if [[ -f "$project_root/pytest.ini" ]] || [[ -f "$project_root/pyproject.toml" ]]; then
        devorq_auto::check_python "$project_root" || overall=1
    fi

    if [[ -f "$project_root/package.json" ]]; then
        devorq_auto::check_node "$project_root" || overall=1
    fi

    devorq_auto::check_generic "$project_root"

    echo "================================"
    if [[ $overall -eq 0 ]]; then
        echo "[devorq-auto] ✅ All checks passed"
        exit 0
    else
        echo "[devorq-auto] ❌ Some checks failed"
        exit 1
    fi
}

main "$@"
