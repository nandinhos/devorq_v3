#!/usr/bin/env bash
# lib/spec.sh — DEVORQ SPEC Validation with BDD
#
# Responsabilidades:
#   spec::validate  — Valida SPEC.md (opcional com BDD)
#   spec::template  — Gera template de SPEC com BDD
#   spec::check_ac  — Verifica cobertura de ACs

set -euo pipefail

# ============================================================
# Helpers
# ============================================================

spec::info()  { echo "[INFO] SPEC: $*"; }
spec::warn()  { echo "[WARN] SPEC: $*" >&2; }
spec::error() { echo "[ERROR] SPEC: $*" >&2; }
spec::pass()  { echo "[PASS] SPEC: $*"; }

# ============================================================
# spec::validate
#   $1 = --strict (opcional)
#   $2 = --format table|json (opcional)
# ============================================================

spec::validate() {
    local strict=""
    local format="table"
    local exit_code=0
    local spec_file="${PWD}/SPEC.md"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --strict) strict="true"; shift ;;
            --format)
                format="${2:-table}"
                shift 2
                ;;
            *) shift ;;
        esac
    done

    if [ ! -f "$spec_file" ]; then
        spec::error "SPEC.md não encontrado"
        return 1
    fi

    local -a issues=()
    local -a passes=()

    # CHECK 1: Seção Acceptance Criteria (BDD)
    if grep -q "## 4. Acceptance Criteria" "$spec_file"; then
        if grep -qE "Given|When|Then" "$spec_file"; then
            passes+=("BDD-style ACs encontrados")
            spec::info "BDD-style ACs encontrados"
        else
            if [ -n "$strict" ]; then
                spec::error "Seção AC existe mas não usa Given/When/Then"
                issues+=("AC sem formato BDD (ERROR)")
                exit_code=1
            else
                spec::warn "Seção AC existe mas não usa Given/When/Then"
                issues+=("AC sem formato BDD (WARN)")
            fi
        fi
    else
        if [ -n "$strict" ]; then
            spec::error "Seção Acceptance Criteria não encontrada"
            issues+=("AC ausente (ERROR)")
            exit_code=1
        else
            spec::warn "Seção Acceptance Criteria não encontrada"
            issues+=("AC ausente (WARN)")
        fi
    fi

    # CHECK 2: Out of Scope
    if grep -qE '## [45].*Out of Scope' "$spec_file"; then
        passes+=("Out of Scope presente")
    else
        spec::warn "Seção Out of Scope não encontrada"
        issues+=("Out of Scope ausente (WARN)")
    fi

    # CHECK 3: Stack Técnica ou Stack
    if grep -qE '## [56].*Stack|## [56].*Tecnolog' "$spec_file"; then
        passes+=("Stack Técnica presente")
    else
        spec::warn "Seção Stack Técnica não encontrada"
        issues+=("Stack Técnica ausente (WARN)")
    fi

    # CHECK 4: Placeholder [TODO]
    if grep -q '\[TODO\]' "$spec_file"; then
        spec::error "SPEC.md contém placeholders [TODO]"
        issues+=("[TODO] presente (ERROR)")
        exit_code=1
    fi

    # CHECK 5: Diagrama de fluxo
    if grep -qE '```|ASCII|diagrama|fluxo' "$spec_file"; then
        passes+=("Diagrama de fluxo presente")
    else
        spec::warn "Diagrama de fluxo não encontrado"
        issues+=("Diagrama ausente (WARN)")
    fi

    # CHECK 6: ACs com DEFERRED
    local defer_count
    defer_count=$(grep -cE "DEFERRED|NOT IMPLEMENTED|NÃO IMPLEMENTADO" "$spec_file" 2>/dev/null | head -1 || echo "0")
    defer_count="${defer_count//[^0-9]/}"
    [ -z "$defer_count" ] && defer_count=0
    if [ "$defer_count" -gt 0 ]; then
        spec::warn "SPEC.md contém $defer_count item(s) adiado(s)"
        issues+=("AC(s) adiada(s): $defer_count (WARN)")
    fi

    # Output
    if [ "$format" = "json" ]; then
        spec::format_json
    else
        spec::format_table
    fi

    return $exit_code
}

spec::format_table() {
    echo ""
    echo "SPEC.md Validation Summary"
    echo "========================="

    if [ ${#issues[@]} -eq 0 ] && [ ${#passes[@]} -eq 0 ]; then
        echo "⚠️  Nenhuma validação encontrada (SPEC.md vazia ou mal formatada)"
        return 1
    fi

    if [ ${#passes[@]} -gt 0 ]; then
        echo ""
        echo "✅ Passed:"
        local p
        for p in "${passes[@]}"; do
            echo "   - $p"
        done
    fi

    if [ ${#issues[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Issues:"
        local i
        for i in "${issues[@]}"; do
            echo "   - $i"
        done
    fi

    echo ""
    if [ ${#issues[@]} -eq 0 ]; then
        echo "✅ SPEC.md está bem formatada"
    else
        echo "⚠️  SPEC.md tem ${#issues[@]} issue(s)"
    fi
}

spec::format_json() {
    echo "{\"passes\": ${#passes[@]}, \"issues\": ${#issues[@]}}"
}

# ============================================================
# spec::template
#   Gera template SPEC.md com BDD
# ============================================================

spec::template() {
    local feature="${1:-new-feature}"
    local output="${2:-SPEC.md}"

    cat > "$output" << 'EOF'
# $feature

**Versão:** 0.1.0
**Data:** $(date +%Y-%m-%d)
**Status:** Draft

---

## 1. Visão

[Descrição de uma linha do que este projeto resolve]

## 2. Stack

- [ ] Tecnologia 1
- [ ] Tecnologia 2

## 3. Arquitetura

[Diagrama ou descrição da estrutura]

---

## 4. Acceptance Criteria (BDD)

### AC-1: [Título da AC]

**Given** [pré-condição / estado inicial do sistema]
**When** [ação realizada pelo usuário ou sistema]
**Then** [resultado esperado, verificável e testável]

**Critérios de sucesso:**
- [ ] Critério 1 (testável)
- [ ] Critério 2 (testável)

**Critérios de falha (edge cases):**
- [ ] Edge case 1
- [ ] Edge case 2

---

### AC-2: [Título da AC]

**Given** [pré-condição]
**When** [ação]
**Then** [resultado]

**Critérios de sucesso:**
- [ ] Critério 1

---

## 5. Out of Scope

- Item 1
- Item 2

---

## 6. Stack Técnica

| Componente | Tecnologia | Justificativa |
|-----------|------------|---------------|
| Runtime | [ ] | [ ] |
| Framework | [ ] | [ ] |
| DB | [ ] | [ ] |

---

## 7. Diagrama de Fluxo

```
[Diagrama em ASCII]
```

---

## 8. Interfaces

### 8.1 API Endpoints

| Método | Path | Descrição | Auth |
|--------|------|-----------|------|
| GET | /resource | Listar | Sim |

### 8.2 Request/Response

[Definir request/response]

---

## 9. Notas de Implementação

1. [Decisão de design 1]
2. [Trade-off 1]

---

## 10. UNIFY (preenchido ao fechar)

[Preenchido automaticamente por `devorq unify`]

```yaml
unify:
  date: YYYY-MM-DDTHH:MM:SSZ
  ac_passed: []
  ac_failed: []
  ac_deferred: []
  lessons: []
  deviations: []
  time_spent: []
```
EOF

    echo "[OK] Template gerado: $output"
}

# ============================================================
# spec::check_ac
#   Lista ACs sem cobertura de teste
# ============================================================

spec::check_ac() {
    local spec_file="${PWD}/SPEC.md"

    if [ ! -f "$spec_file" ]; then
        spec::error "SPEC.md não encontrado"
        return 1
    fi

    echo ""
    echo "SPEC.md — Acceptance Criteria Check"
    echo "===================================="

    # Extrair ACs
    local -a ac_ids=()
    local -a ac_titles=()

    while IFS= read -r line; do
        local ac_id
        local ac_title
        ac_id=$(echo "$line" | sed 's/^### //' | cut -d':' -f1)
        ac_title=$(echo "$line" | sed 's/^### [^:]*: //')
        ac_ids+=("$ac_id")
        ac_titles+=("$ac_title")
    done < <(grep -E "^### AC-" "$spec_file" 2>/dev/null || true)

    if [ ${#ac_ids[@]} -eq 0 ]; then
        echo "Nenhuma AC encontrada (ou SPEC.md não usa formato BDD)"
        return 0
    fi

    echo "Total de ACs: ${#ac_ids[@]}"
    echo ""

    local idx
    for idx in "${!ac_ids[@]}"; do
        local ac_id="${ac_ids[$idx]}"
        local ac_title="${ac_titles[$idx]}"

        # Verificar se existe teste cobrindo esta AC
        local test_found=false
        if [ -d "tests" ] && grep -rq "AC-${ac_id#AC-}" tests/ 2>/dev/null; then
            test_found=true
        fi

        if [ "$test_found" = "true" ]; then
            echo "  ✅ $ac_id: $ac_title (testado)"
        else
            echo "  ⚠️  $ac_id: $ac_title (SEM TESTE)"
        fi
    done

    echo ""
    echo "Use 'devorq spec check-ac' para verificar cobertura de testes"
}