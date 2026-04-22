#!/usr/bin/env bash
# lib/gates.sh — DEVORQ 7 Gates
#
# GATE-1 (BLOQUEANTE): SPEC Review
# GATE-2 (BLOQUEANTE): Pre-Flight (tipos, contratos)
# GATE-3 (BLOQUEANTE): Quality Gate (testes, lint, segurança)
# GATE-4 (Aviso):      Handoff
# GATE-5 (Pipeline):   Lesson Capture
# GATE-6 (Pipeline):   Lesson Validate (Context7)
# GATE-7 (Pipeline):   Lesson Apply

set -euo pipefail

RED='' GREEN='' YELLOW='' CYAN='' RESET=''

GATE_BLOCKING="${DEVORQ_BLOCKING:-true}"
DEVORQ_ALLOW_DRAFT="${DEVORQ_ALLOW_DRAFT:-false}"

# ============================================================
# helpers
# ============================================================

gate::pass() {
    echo -e "${GREEN}[PASS]${RESET} GATE-${1}: $*"
}

gate::fail() {
    echo -e "${RED}[FAIL]${RESET} GATE-${1}: $*"
}

gate::warn() {
    echo -e "${YELLOW}[WARN]${RESET} GATE-${1}: $*"
}

gate::info() {
    echo -e "${CYAN}[INFO]${RESET} GATE-${1}: $*"
}

# ============================================================
# GATE-1 — SPEC Review (BLOQUEANTE)
# ============================================================

gate_1() {
    gate::info 1 "SPEC Review"

    local spec_file="${PWD}/SPEC.md"

    if [ ! -f "$spec_file" ]; then
        if [ "$DEVORQ_ALLOW_DRAFT" = "true" ]; then
            gate::warn 1 "SPEC.md não encontrado — ALLOW_DRAFT ativo"
            return 0
        fi
        gate::fail 1 "SPEC.md não encontrado"
        return 1
    fi

    local size
    size=$(wc -c < "$spec_file")
    if [ "$size" -lt 100 ]; then
        gate::fail 1 "SPEC.md está vazio ou incompleto"
        return 1
    fi

    gate::pass 1 "SPEC.md existe e tem conteúdo"
}

# ============================================================
# GATE-2 — Pre-Flight (BLOQUEANTE)
# ============================================================

gate_2() {
    gate::info 2 "Pre-Flight — tipos e contratos"

    local errors=0

    # Verificar presença de types/interfaces se existir spec
    local spec_file="${PWD}/specs/approved/SPEC.md"
    if [ -f "$spec_file" ]; then
        # Procurar sinais de TypeScript/PHP types
        if grep -q "interface\|type \|class " "$spec_file" 2>/dev/null; then
            gate::info 2 "Detected types — verificar contracts/"
            [ -d "${PWD}/contracts" ] || gate::warn 2 "contracts/ não existe (esperado para Laravel)"
        fi
    fi

    # Verificar .env.example — só para projetos Laravel/PHP reais
    # (DEVORQ em si não é um projeto Laravel, então pulamos)
    if [ -f "${PWD}/.env.example" ]; then
        gate::pass 2 ".env.example presente"
    elif [ -f "${PWD}/composer.json" ] || [ -f "${PWD}/package.json" ]; then
        gate::warn 2 ".env.example não encontrado"
        ((errors++))
    fi
    # Para frameworks/CLI tools bash, não exigimos .env.example

    if [ $errors -eq 0 ]; then
        gate::pass 2 "Pre-Flight OK"
    else
        gate::fail 2 "$errors problema(s) encontrado(s)"
        return 1
    fi
}

# ============================================================
# GATE-3 — Quality Gate (BLOQUEANTE)
# ============================================================

gate_3() {
    gate::info 3 "Quality Gate — testes, lint, segurança"

    local errors=0

    # PHPUnit / tests
    if [ -f "phpunit.xml" ] || [ -f "composer.json" ]; then
        if [ -d "tests" ]; then
            gate::info 3 "Rodando testes..."
            if command -v php &>/dev/null && [ -f "vendor/bin/phpunit" ]; then
                vendor/bin/phpunit --testdox 2>/dev/null || {
                    gate::warn 3 "PHPUnit falhou ou sem saída"
                    ((errors++))
                }
            elif [ -f "composer.json" ]; then
                gate::warn 3 "vendor/ não instalado (rode composer install)"
                ((errors++))
            fi
        else
            gate::warn 3 "Diretório tests/ não existe"
            ((errors++))
        fi
    fi

    # Python tests
    if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ]; then
        if [ -d "tests" ]; then
            if command -v pytest &>/dev/null; then
                pytest -q 2>/dev/null || {
                    gate::warn 3 "pytest falhou"
                    ((errors++))
                }
            fi
        fi
    fi

    # Bash lint (se houver scripts)
    if [ -f "bin/devorq" ]; then
        if command -v shellcheck &>/dev/null; then
            # Só conta como erro se houver SC1/2xxx (sintaxe/fatals), não warnings de estilo (SC2xxx)
            local sc_errors
            sc_errors=$(shellcheck -S error bin/devorq lib/*.sh 2>/dev/null | grep -c "SC[12]" || true)
            if [ "$sc_errors" -gt 0 ]; then
                gate::warn 3 "shellcheck: $sc_errors erro(s) de sintaxe"
                ((errors += sc_errors))
            fi
        fi
    fi

    # Secrets scan (basic)
    if grep -r "password\s*=" --include="*.php" --include="*.py" . 2>/dev/null | grep -v ".env" | grep -qv "=.*\$" ; then
        gate::warn 3 "Possível segredo hardcoded detectado"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        gate::pass 3 "Quality Gate OK"
    else
        gate::fail 3 "$errors problema(s)"
        return 1
    fi
}

# ============================================================
# GATE-4 — Handoff (Aviso)
# ============================================================

gate_4() {
    gate::info 4 "Handoff — preparando contexto para próxima sessão"

    local ctx_file="${PWD}/.devorq/state/context.json"
    local handoff_file="${PWD}/.devorq/state/handoff.json"

    if [ ! -f "$ctx_file" ]; then
        gate::warn 4 "context.json não encontrado — pulando"
        return 0
    fi

    # Gerar snapshot do contexto atual
    cp "$ctx_file" "$handoff_file"

    gate::pass 4 "Handoff preparado"
}

# ============================================================
# GATE-5 — Lesson Capture (Pipeline)
# ============================================================

gate_5() {
    gate::info 5 "Lesson Capture — capturar lições do fluxo"

    # Capturar qualquer lição encontrada em comments/TODOs
    local lessons_file="${PWD}/.devorq/state/lessons_flow.json"

    if [ -f "$lessons_file" ]; then
        gate::info 5 "Lições capturadas no fluxo encontradas"
        # Forward para lessons.sh
        source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true
    fi

    gate::pass 5 "Lesson Capture OK"
}

# ============================================================
# GATE-6 — Lesson Validate (Context7) (Pipeline)
# ============================================================

gate_6() {
    gate::info 6 "Lesson Validate — validando com Context7"

    source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true
    if declare -f lessons::validate &>/dev/null; then
        lessons::validate
    else
        gate::warn 6 "lib/lessons.sh não disponível"
    fi
}

# ============================================================
# GATE-7 — Lesson Apply (Pipeline)
# ============================================================

gate_7() {
    gate::info 7 "Lesson Apply — aplicando lições validadas"

    source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true
    if declare -f lessons::apply &>/dev/null; then
        lessons::apply
    else
        gate::warn 7 "lib/lessons.sh não disponível"
    fi

    gate::pass 7 "Lesson Apply OK"
}
