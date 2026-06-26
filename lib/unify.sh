#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/unify.sh — DEVORQ UNIFY Module
#
# Responsabilidades:
#   unify::run        — Executa fase UNIFY completa
#   unify::parse_ac   — Extrai ACs do SPEC.md
#   unify::check_ac   — Verifica status de cada AC
#   unify::generate   — Gera arquivo UNIFY.md
#   unify::capture    — Auto-captura lições dos desvios encontrados
#   unify::update_ctx — Atualiza context.json

set -euo pipefail

# ============================================================
# Helpers
# ============================================================

unify::info()  { echo "[INFO] UNIFY: $*"; }
unify::warn()  { echo "[WARN] UNIFY: $*" >&2; }
unify::error() { echo "[ERROR] UNIFY: $*" >&2; }
unify::pass()  { echo "[PASS] UNIFY: $*"; }

# Paths
DEVORQ_UNIFY_DIR="${PWD}/.devorq/state/unify"
DEVORQ_STATE_DIR="${PWD}/.devorq/state"

# ============================================================
# unify::run
#   $1 = feature name (opcional)
#   $2 = --auto (opcional)
# ============================================================

unify::run() {
    local feature="${1:-}"
    local auto="${2:-}"

    # 1. Detectar feature se não informada
    if [ -z "$feature" ]; then
        feature=$(unify::infer_feature)
    fi

    # 2. Verificar que SPEC.md existe
    if [ ! -f "SPEC.md" ]; then
        unify::error "SPEC.md não encontrado"
        return 2
    fi

    # 3. Criar diretório de unify se não existir
    mkdir -p "$DEVORQ_UNIFY_DIR"

    # 4. Parsear ACs do SPEC.md
    local ac_list
    ac_list=$(unify::parse_ac "SPEC.md")
    if [ -z "$ac_list" ]; then
        unify::warn "Nenhum Acceptance Criteria (BDD) encontrado em SPEC.md"
        unify::info "UNIFY é mais efetivo com BDD-style ACs"
        unify::info "Para criar ACs: devorq spec template [feature]"
        # Não é erro — spec sem BDD é válida
    fi

    # 5. Verificar status de cada AC
    local ac_results=""
    if [ -n "$ac_list" ]; then
        ac_results=$(unify::check_acs "$ac_list")
    fi

    # 6. Gerar UNIFY.md
    local ts
    ts=$(date +%Y-%m-%d_%H%M%S)
    local unify_file="${DEVORQ_UNIFY_DIR}/${ts}_${feature}_unify.md"
    unify::generate "$unify_file" "$feature" "$ts" "$ac_list" "$ac_results"

    # 7. Auto-capturar lições se habilitado
    if [ "$auto" = "--auto" ] || [ "$auto" = "--lessons" ]; then
        unify::capture_lessons "$ac_results"
    fi

    # 8. Atualizar context.json
    unify::update_context "$unify_file" "$ac_results"

    echo ""
    unify::pass "UNIFY gerado: $unify_file"

    # 9. Resumo
    if [ -n "$ac_results" ]; then
        local passed failed deferred
        passed=$(echo "$ac_results" | grep -c "PASS" 2>/dev/null || echo "0")
        failed=$(echo "$ac_results" | grep -c "FAIL" 2>/dev/null || echo "0")
        deferred=$(echo "$ac_results" | grep -c "DEFERRED" 2>/dev/null || echo "0")
        echo "AC: $passed passed, $failed failed, $deferred deferred"
    fi

    return 0
}

# ============================================================
# unify::infer_feature
#   Infere nome da feature do context.json ou git branch
# ============================================================

unify::infer_feature() {
    local ctx_file="${DEVORQ_STATE_DIR}/context.json"
    local intent=""

    if [ -f "$ctx_file" ] && command -v jq &>/dev/null; then
        intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
    fi

    # Limpa intent para nome de arquivo
    local feature
    feature=$(echo "$intent" | sed 's/[^a-zA-Z0-9_-]/_/g' | tr '[:upper:]' '[:lower:]' | cut -c1-50)
    if [ -z "$feature" ]; then
        feature="unknown-feature"
    fi
    echo "$feature"
}

# ============================================================
# unify::parse_ac
#   $1 = path para SPEC.md
#   Retorna JSON array de ACs
# ============================================================

unify::parse_ac() {
    local spec_file="$1"

    if [ ! -f "$spec_file" ]; then
        return 1
    fi

    # Extrair ACs do SPEC.md
    # Formato esperado: ### AC-N: Título
    local ac_json="["
    local first=true

    while IFS= read -r line; do
        local ac_id
        local ac_title
        ac_id=$(echo "$line" | sed 's/^### //' | cut -d':' -f1 | tr -d ' ')
        ac_title=$(echo "$line" | sed 's/^### [^:]*: //')

        if [ -n "$ac_id" ]; then
            if [ "$first" = "true" ]; then
                first=false
            else
                ac_json="$ac_json,"
            fi
            ac_json="$ac_json{\"id\":\"$ac_id\",\"title\":\"$ac_title\"}"
        fi
    done < <(grep -E "^### AC-" "$spec_file" 2>/dev/null || true)

    ac_json="$ac_json]"

    # Se não encontrou ACs, retorna vazio
    if [ "$ac_json" = "[]" ]; then
        return 0
    fi

    echo "$ac_json"
}

# ============================================================
# unify::check_acs
#   $1 = JSON array de ACs
#   Retorna lista de resultados (um por linha: ID STATUS TITLE)
# ============================================================

unify::check_acs() {
    local ac_list="$1"

    if [ -z "$ac_list" ] || [ "$ac_list" = "[]" ]; then
        return 0
    fi

    # Parse e verifica cada AC
    echo "$ac_list" | jq -r '.[] | "\(.id) \(unify::check_single_ac .id .title)"' 2>/dev/null || {
        # Fallback: apenas mostra as ACs sem verificar
        echo "$ac_list" | jq -r '.[] | "\(.id) UNKNOWN \(.title)"' 2>/dev/null || true
    }
}

# ============================================================
# unify::check_single_ac
#   $1 = AC id
#   $2 = AC title
#   Retorna: PASS | FAIL | DEFERRED | UNKNOWN
# ============================================================

unify::check_single_ac() {
    local ac_id="$1"
    local ac_title="$2"

    # PLACEHOLDER — implementação real fica a cargo do dev
    # Este é o algoritmo sugerido:

    # 1. AC contém DEFERRED/TODO
    if grep -A 5 "### $ac_id" SPEC.md 2>/dev/null | grep -qi "DEFERRED\|NOT IMPLEMENTED\|NÃO IMPLEMENTADO"; then
        echo "DEFERRED"
        return
    fi

    # 2. Se existe teste com nome da AC
    if [ -d "tests" ] && grep -rq "$ac_id" tests/ 2>/dev/null; then
        # Executar teste seria o ideal, por agora marcamos como UNKNOWN
        echo "UNKNOWN (teste existe)"
        return
    fi

    # 3. Default: precisa review manual
    echo "UNKNOWN"
}

# ============================================================
# unify::generate
#   $1 = output file
#   $2 = feature name
#   $3 = timestamp
#   $4 = ac_list (JSON)
#   $5 = ac_results (texto)
# ============================================================

unify::generate() {
    local output="$1"
    local feature="$2"
    local ts="$3"
    local ac_list="$4"
    local ac_results="$5"

    # Header
    cat > "$output" << EOF
# UNIFY — $feature
**Data:** $(date -Iseconds)
**Feature:** $feature

---

## Acceptance Criteria — Resultado Real

EOF

    # Tabela de ACs
    if [ -n "$ac_results" ]; then
        echo "| AC | Esperado | Real | Status |" >> "$output"
        echo "|----|----------|------|--------|" >> "$output"

        while IFS= read -r line; do
            local ac_id status title
            ac_id=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | awk '{print $2}')
            title=$(echo "$line" | cut -d' ' -f3-)

            local emoji
            case "$status" in
                PASS) emoji="✅" ;;
                FAIL) emoji="❌" ;;
                DEFERRED) emoji="⏳" ;;
                *) emoji="⚠️" ;;
            esac

            echo "| $ac_id | $title | $title | $emoji $status |" >> "$output"
        done <<< "$ac_results"
    else
        echo "_Nenhuma AC encontrada ou processada_" >> "$output"
    fi

    # Footer
    cat >> "$output" << 'EOF'

---

## Lições Aprendidas

[Preencha manualmente ou use --lessons para auto-capture]

---

## Desvios do Plano Original

[O que saiu diferente do planejado na SPEC.md]

---

## Pending Items

- [ ] [item pendente]

---

## Estado Final

```json
{
  "unify_done": true,
  "unify_file": "FILL_ME",
  "timestamp": "FILL_ME"
}
```
EOF

    # Substitui placeholders (sed in-place portavel — DQ-029)
    devorq::sed_inplace "s|FILL_ME|$output|" "$output"
    devorq::sed_inplace "s|FILL_ME|$ts|" "$output"
}

# ============================================================
# unify::update_context
#   Atualiza context.json com unify_done
# ============================================================

unify::update_context() {
    local unify_file="$1"
    local ac_results="$2"

    local ctx_file="${DEVORQ_STATE_DIR}/context.json"

    if [ ! -f "$ctx_file" ]; then
        # Criar context.json básico se não existir
        mkdir -p "$(dirname "$ctx_file")"
        echo "{}" > "$ctx_file"
    fi

    if command -v jq &>/dev/null; then
        local passed=0
        local failed=0
        local deferred=0

        local passed failed deferred
        if [ -n "$ac_results" ]; then
            # grep -c pode ter saída com newlines extras
            passed=$(echo "$ac_results" | grep -c "PASS" | tr -d '[:space:]' || echo "0")
            failed=$(echo "$ac_results" | grep -c "FAIL" | tr -d '[:space:]' || echo "0")
            deferred=$(echo "$ac_results" | grep -c "DEFERRED" | tr -d '[:space:]' || echo "0")
        else
            passed=0; failed=0; deferred=0
        fi

        local tmp
        tmp=$(mktemp)
        local uf_clean
        uf_clean=$(echo "$unify_file" | tr -d '[:space:]')
        jq --arg uf "$uf_clean" \
           --argjson passed "${passed:-0}" \
           --argjson failed "${failed:-0}" \
           --argjson deferred "${deferred:-0}" \
           '. + {
               unify_done: true,
               unify_file: $uf,
               ac_passed: $passed,
               ac_failed: $failed,
               ac_deferred: $deferred
           }' "$ctx_file" > "$tmp" && mv "$tmp" "$ctx_file"
    fi
}

# ============================================================
# unify::capture_lessons
#   Auto-captura lições dos desvios encontrados
# ============================================================

unify::capture_lessons() {
    local ac_results="$1"

    if [ -z "$ac_results" ]; then
        return 0
    fi

    # Capturar lições para ACs que falharam ou foram deferidas
    source "${DEVORQ_LIB}/lessons.sh" 2>/dev/null || true

    while IFS= read -r line; do
        local ac_id status title
        ac_id=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        title=$(echo "$line" | cut -d' ' -f3-)

        if [ "$status" = "FAIL" ] || [ "$status" = "DEFERRED" ]; then
            if declare -f lessons::capture &>/dev/null; then
                local lesson_title="AC-$ac_id: $title"
                local lesson_problem="AC-$ac_id com status $status"
                local lesson_solution="Verificar SPEC.md e implementar AC-$ac_id"
                lessons::capture "$lesson_title" "$lesson_problem" "$lesson_solution" 2>/dev/null || true
            fi
        fi
    done <<< "$ac_results"
}