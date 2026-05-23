#!/usr/bin/env bash
# lib/gates.sh — DEVORQ 7 Gates
#
# GATE-1 (BLOQUEANTE): Spec Exists       — SPEC.md existe e não está vazio
# GATE-2 (BLOQUEANTE): Tests Pass        — devorq test passa (testa estrutura)
# GATE-3 (BLOQUEANTE): Context Documented— devorq context mostra estado atual
# GATE-4 (BLOQUEANTE): Lessons Reviewed  — devorq lessons search encontrou lições relevantes
# GATE-5 (BLOQUEANTE): Handoff Ready     — devorq compact gera JSON válido
# GATE-6 (Aviso):      Context7 Checked  — Docs consultadas (mesmo que rejeite)
# GATE-7 (Pipeline):   Systematic Debugging — Se erro: devorq debug antes de continuar

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
# GATE-0 — DDD Domain Exploration (OPIONAL, pre-GATE-1)
# ============================================================

gate_0() {
    gate::info 0 "Domain Exploration — checa se intent requer DDD"

    # Detecta keywords DDD no intent (enviado via DEVORQ_INTENT)
    local intent="${DEVORQ_INTENT:-}"
    if [ -z "$intent" ]; then
        # Tenta ler do context.json se existir
        local ctx_file="${PWD}/.devorq/state/context.json"
        if [ -f "$ctx_file" ] && command -v jq &>/dev/null; then
            intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
        fi
    fi

    # Se não tem keywords DDD, skip
    if ! echo "$intent" | grep -qiE "domínio|ddd|modelagem|entidade|contexto|bounded|invariante"; then
        gate::info 0 "DDD não detectado — skip"
        return 0
    fi

    # DDD detectado — valida se SPEC.md tem modelo mental
    local ddd_validate="${DEVORQ_ROOT}/skills/ddd-deep-domain/scripts/ddd-validate-spec.sh"
    if [ ! -f "$ddd_validate" ]; then
        gate::warn 0 "ddd-validate-spec.sh não encontrado — skip"
        return 0
    fi

    if bash "$ddd_validate"; then
        gate::pass 0 "DDD: SPEC.md tem modelo mental válido"
        return 0
    else
        gate::fail 0 "DDD: SPEC.md parece CRUD sem modelo de domínio"
        gate::info 0 "Sugestão: devorq ddd explore  (ou carregue skill ddd-deep-domain)"
        return 1
    fi
}

# ============================================================
# GATE-1 — Spec Exists (BLOQUEANTE)
# ============================================================

gate_1() {
    gate::info 1 "Spec Exists — SPEC.md existe e não está vazio"

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
# GATE-2 — Tests Pass (BLOQUEANTE)
# ============================================================

gate_2() {
    gate::info 2 "Tests Pass — devorq test passa"

    local has_tests=false
    local test_errors=0
    local test_cmd=""

    if [ -d "tests" ] || [ -f "phpunit.xml" ] || [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "bin/devorq" ] || [ -f "Makefile" ]; then
        has_tests=true
    fi

    if [ -f "composer.json" ] && [ -d "tests" ]; then
        if [ -f "vendor/bin/pest" ]; then
            test_cmd="vendor/bin/pest --compact"
            gate::info 2 "Runner detectado: Pest"
        elif [ -f "vendor/bin/phpunit" ]; then
            test_cmd="vendor/bin/phpunit --no-coverage"
            gate::info 2 "Runner detectado: PHPUnit"
        elif [ -f "artisan" ]; then
            test_cmd="php artisan test --compact"
            gate::info 2 "Runner detectado: artisan test"
        fi

        if [ -n "$test_cmd" ] && command -v php &>/dev/null; then
            $test_cmd 2>/dev/null || {
                gate::warn 2 "Testes falharam (exit code: $?)"
                ((test_errors++))
            }
        elif [ -f "composer.json" ] && [ ! -d "vendor" ]; then
            gate::warn 2 "vendor/ não instalado"
            ((test_errors++))
        fi
    fi

    if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ]; then
        if [ -d "tests" ] && command -v pytest &>/dev/null; then
            pytest -q 2>/dev/null || {
                gate::warn 2 "pytest falhou"
                ((test_errors++))
            }
        fi
    fi

    if [ -f "bin/devorq" ] || [ -f "Makefile" ]; then
        if command -v shellcheck &>/dev/null; then
            local sc_errors
            sc_errors=$(shellcheck -S error bin/devorq lib/*.sh scripts/*.sh 2>/dev/null | grep -c "SC[12]" || true)
            if [ "$sc_errors" -gt 0 ]; then
                gate::warn 2 "shellcheck: $sc_errors erro(s) de sintaxe"
                ((test_errors += sc_errors))
            fi
        fi
    fi

    if [ "$has_tests" = "false" ]; then
        gate::warn 2 "Nenhum framework de teste detectado (OK para CLI/bash puro)"
    fi

    if [ $test_errors -eq 0 ]; then
        gate::pass 2 "Tests Pass OK"
        return 0
    else
        gate::fail 2 "$test_errors problema(s) encontrado(s)"
        return 1
    fi
}

# ============================================================
# GATE-3 — Context Documented (BLOQUEANTE)
# ============================================================

gate_3() {
    gate::info 3 "Context Documented — devorq context mostra estado atual"

    source "${DEVORQ_LIB}/context.sh" 2>/dev/null || true

    local ctx_file="${PWD}/.devorq/state/context.json"

    # Se não existe, criar com project/stack básico
    if [ ! -f "$ctx_file" ]; then
        if declare -f ctx_set &>/dev/null; then
            gate::warn 3 "context.json não existe — criando automaticamente"
            ctx_set "project" "${PWD##*/}" >/dev/null 2>&1
            ctx_set "stack" "[]" >/dev/null 2>&1
            ctx_set "intent" "" >/dev/null 2>&1
        else
            gate::fail 3 "lib/context.sh não disponível"
            return 1
        fi
    fi

    # Verificar conteúdo mínimo
    if declare -f ctx_lint &>/dev/null; then
        if ! ctx_lint >/dev/null 2>&1; then
            gate::warn 3 "context.json com problemas (campos ausentes)"
        fi
    fi

    # Mostrar contexto atual
    if [ -f "$ctx_file" ]; then
        gate::pass 3 "Context Documented"
        if command -v jq &>/dev/null; then
            local intent project
            intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
            project=$(jq -r '.project // ""' "$ctx_file" 2>/dev/null || echo "")
            gate::info 3 "project=$project intent=${intent:0:60}..."
        fi
        return 0
    fi

    gate::fail 3 "context.json não pôde ser criado"
    return 1
}

# ============================================================
# GATE-4 — Lessons Reviewed (BLOQUEANTE)
# ============================================================

gate_4() {
    gate::info 4 "Lessons Reviewed — devorq lessons search encontrou lições relevantes"

    source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true

    local lessons_dir="${PWD}/.devorq/state/lessons/captured"
    local found=0

    if [ -d "$lessons_dir" ]; then
        found=$(find "$lessons_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
        found=${found:-0}
    fi

    if [ "$found" -gt 0 ]; then
        gate::pass 4 "Lessons Reviewed — $found lição(ões) capturada(s)"
        return 0
    fi

    # Sem lessons é OK — só um aviso (projetos novos)
    gate::warn 4 "Nenhuma lesson capturada ainda (OK para projetos novos)"
    return 0
}

# ============================================================
# GATE-5 — Handoff Ready (BLOQUEANTE)
# ============================================================

gate_5() {
    gate::info 5 "Handoff Ready — devorq compact gera JSON válido"

    source "${DEVORQ_LIB}/compact.sh" 2>/dev/null || true

    if ! declare -f compact::generate &>/dev/null; then
        gate::fail 5 "lib/compact.sh não disponível"
        return 1
    fi

    local handoff_file="${PWD}/.devorq/state/handoff.json"
    local tmp
    tmp=$(mktemp)

    # Gerar handoff e validar JSON
    if compact::generate "$tmp" >/dev/null 2>&1; then
        if command -v jq &>/dev/null; then
            if jq empty "$tmp" 2>/dev/null; then
                # JSON válido — mover para localização real
                mkdir -p "$(dirname "$handoff_file")"
                mv "$tmp" "$handoff_file"
                gate::pass 5 "Handoff Ready — JSON válido gerado"
                return 0
            else
                gate::fail 5 "JSON gerado é inválido"
                rm -f "$tmp"
                return 1
            fi
        else
            # Sem jq, confiar na saída
            mv "$tmp" "$handoff_file"
            gate::pass 5 "Handoff Ready (jq não disponível, validação manual)"
            return 0
        fi
    fi

    gate::fail 5 "devorq compact falhou"
    rm -f "$tmp"
    return 1
}

# ============================================================
# GATE-6 — Context7 Checked (Aviso)
# ============================================================

gate_6() {
    gate::info 6 "Context7 Checked — Docs consultadas (mesmo que rejeite)"

    if [ -f "${DEVORQ_LIB}/context7.sh" ]; then
        source "${DEVORQ_LIB}/context7.sh" 2>/dev/null || true
        if declare -f ctx7_check &>/dev/null; then
            # Captura output e exit code — set -e não pode interferir
            local ctx7_output rv
            set +e
            ctx7_output=$(ctx7_check 2>&1)
            rv=$?
            set -e
            # Imprime output da ctx7_check
            [ -n "$ctx7_output" ] && echo "$ctx7_output"
            if [ $rv -eq 0 ]; then
                gate::pass 6 "Context7 Checked"
            else
                gate::warn 6 "Context7 não configurado (sem API key ou API offline)"
            fi
            return 0
        fi
    fi

    gate::warn 6 "Context7 não configurado (lib não encontrada)"
    return 0
}

# ============================================================
# GATE-7 — Systematic Debugging (Pipeline)
# ============================================================

gate_7() {
    gate::info 7 "Systematic Debugging — workflow de debug sistemático"

    # Carregar lib de debug se existir (Fase 5)
    if [ -f "${DEVORQ_LIB}/debug.sh" ]; then
        source "${DEVORQ_LIB}/debug.sh" 2>/dev/null || true
        if declare -f debug::check &>/dev/null; then
            debug::check
            return $?
        fi
    fi

    gate::pass 7 "Systematic Debugging OK (lib/debug.sh não presente — Fase 5)"
    return 0
}
