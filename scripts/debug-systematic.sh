#!/usr/bin/env bash
# scripts/debug-systematic.sh — DEVORQ Systematic Debugging Trigger
# Executa debug sistemático quando teste falha (vermelho)
# Baseado no skill: ~/.hermes/skills/software-development/systematic-debugging/SKILL.md

DEBUG_TRIGGER_LOG="${DEVORQ_LOGS_DIR:-${PWD}/.devorq/state/logs}/debug-trigger.log"

devorq::debug::log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$DEBUG_TRIGGER_LOG" 2>/dev/null || true
    echo "$msg"
}

# ============================================================
# main
# ============================================================
main() {
    local failure_context="${1:-}"
    local project_root="${2:-$PWD}"

    mkdir -p "$(dirname "$DEBUG_TRIGGER_LOG")" 2>/dev/null || true

    devorq::debug::log "═══════════════════════════════════════"
    devorq::debug::log "  SYSTEMATIC DEBUGGING TRIGGERED"
    devorq::debug::log "═══════════════════════════════════════"
    devorq::debug::log "Contexto: $failure_context"
    devorq::debug::log "Projeto: $project_root"
    devorq::debug::log ""

    # PHASE 0: Classify failure mode
    devorq::debug::log "═══ PHASE 0: Classify Failure Mode ═══"
    local failure_type
    failure_type="$(classify_failure "$failure_context" "$project_root")"
    devorq::debug::log "Tipo: $failure_type"
    devorq::debug::log ""

    # PHASE 1: Root Cause Investigation
    devorq::debug::log "═══ PHASE 1: Root Cause Investigation ═══"
    investigate_root_cause "$failure_context" "$project_root"
    devorq::debug::log ""

    # PHASE 2: Pattern Analysis
    devorq::debug::log "═══ PHASE 2: Pattern Analysis ═══"
    analyze_pattern "$failure_context" "$project_root"
    devorq::debug::log ""

    # PHASE 3: Context7 Validation
    devorq::debug::log "═══ PHASE 3: Context7 Validation ═══"
    validate_with_context7 "$failure_context" "$project_root"
    devorq::debug::log ""

    # PHASE 4: Implementation
    devorq::debug::log "═══ PHASE 4: Implementation ═══"
    devorq::debug::log "1. Crie teste de regressão (RED)"
    devorq::debug::log "2. Aplique correção (root cause)"
    devorq::debug::log "3. Verifique: todos os testes passam (GREEN)"
    devorq::debug::log "4. Refatore se necessário (REFACTOR)"
    devorq::debug::log ""

    # CAPTURA LIÇÃO
    devorq::debug::log "═══ CAPTURA LIÇÃO ═══"
    devorq::debug::log "Após resolver, execute:"
    devorq::debug::log "  devorq lessons capture"
    devorq::debug::log "  devorq lessons approve --all"
    devorq::debug::log ""

    # ATUALIZAR SPEC
    devorq::debug::log "═══ ATUALIZAR SPEC.md ═══"
    devorq::debug::log "Após resolver, documentar em SPEC.md:"
    devorq::debug::log "  - Root cause identificado"
    devorq::debug::log "  - Decisão técnica tomada"
    devorq::debug::log "  - Marcar como resolved com data"
    devorq::debug::log ""

    # RESUMO
    devorq::debug::log "═══════════════════════════════════════"
    devorq::debug::log "  PRÓXIMOS PASSOS"
    devorq::debug::log "═══════════════════════════════════════"
    devorq::debug::log "1. Investigue o erro (Phase 1-3)"
    devorq::debug::log "2. Aplique correção validada com Context7"
    devorq::debug::log "3. Crie teste de regressão"
    devorq::debug::log "4. Execute: devorq verify --story <id>"
    devorq::debug::log "5. Se passou: devorq commit --story <id>"
    devorq::debug::log ""

    devorq::debug::log "Log salvo em: $DEBUG_TRIGGER_LOG"

    return 0
}

# ============================================================
# classify_failure
# Classifica tipo de falha (CAT A/B/C/D)
# ============================================================
classify_failure() {
    local failure_context="${1:-}"
    local project_root="${2:-$PWD}"

    # CAT A: Cascade failure (E2E) — uma página de erro faz todos falharem
    if [[ "$failure_context" =~ "playwright" ]] && \
       [[ "$failure_context" =~ "intercept" || "$failure_context" =~ "overlay" ]]; then
        echo "CAT A: E2E Cascade Failure"
        return
    fi

    # CAT B: Application bug — teste correto, app com bug real
    if [[ "$failure_context" =~ "playwright" ]] || \
       [[ "$failure_context" =~ "test" && "$failure_context" =~ "fail" ]]; then
        echo "CAT B: Application Bug"
        return
    fi

    # CAT C: Test infrastructure — auth, storage, network
    if [[ "$failure_context" =~ "auth" || "$failure_context" =~ "storage" ]] || \
       [[ "$failure_context" =~ "network" || "$failure_context" =~ "timeout" ]]; then
        echo "CAT D: Infrastructure Issue"
        return
    fi

    # Default
    echo "CAT B: Application Bug (default)"
}

# ============================================================
# investigate_root_cause
# Phase 1: Investigar causa raiz
# ============================================================
investigate_root_cause() {
    local failure_context="${1:-}"
    local project_root="${2:-$PWD}"

    devorq::debug::log "1. Ler erros do Playwright / logs do browser"

    # Verificar logs recentes
    local log_files
    log_files=$(find "$project_root/storage/logs" -name "*.log" -mtime -1 2>/dev/null | head -5)

    if [[ -n "$log_files" ]]; then
        devorq::debug::log "Logs encontrados em storage/logs/:"
        echo "$log_files" | while read -r f; do
            devorq::debug::log "  - $f"
        done
    fi

    devorq::debug::log "2. Identificar padrão (CAT A/B/C/D)"
    devorq::debug::log "3. Se CAT A: identificar página raiz do problema"
    devorq::debug::log "4. Se CAT B: investigar código da app"
    devorq::debug::log "5. Se CAT C: atualizar seletor do teste"
    devorq::debug::log "6. Se CAT D: verificar Docker/config"

    # Dicas específicas para stacks comuns
    if [[ -f "$project_root/composer.json" ]]; then
        devorq::debug::log ""
        devorq::debug::log "Stack: Laravel detectado"
        devorq::debug::log "Verificar:"
        devorq::debug::log "  - php artisan test (testes unit/feature)"
        devorq::debug::log "  - docker exec <container> php artisan test (via Sail)"
        devorq::debug::log "  - storage/logs/laravel.log (erros PHP)"
    fi

    if [[ -d "$project_root/playwright_tests" ]]; then
        devorq::debug::log ""
        devorq::debug::log "Playwright: verificar"
        devorq::debug::log "  - npx playwright test --project=chromium"
        devorq::debug::log "  - playwright_tests/test-results/ (screenshots)"
    fi
}

# ============================================================
# analyze_pattern
# Phase 2: Encontrar padrões similares
# ============================================================
analyze_pattern() {
    local failure_context="${1:-}"
    local project_root="${2:-$PWD}"

    devorq::debug::log "1. Encontrar exemplos similares no código"
    devorq::debug::log "2. Comparar com systematic-debugging skill"
    devorq::debug::log "3. Identificar diferenças"

    # Patterns comuns para Laravel/Livewire
    if [[ -f "$project_root/composer.json" ]]; then
        devorq::debug::log ""
        devorq::debug::log "Patterns Laravel comuns:"

        if [[ "$failure_context" =~ "livewire" || "$failure_context" =~ "alpine" ]]; then
            devorq::debug::log "  - Alpine duplicado: verificar x-data + CDN"
            devorq::debug::log "  - Livewire stale view: php artisan view:clear"
            devorq::debug::log "  - Component missing: verificar namespace em app/Http/Livewire/"
        fi

        if [[ "$failure_context" =~ "model" || "$failure_context" =~ "attribute" ]]; then
            devorq::debug::log "  - MissingAttributeException: verificar accessors no model"
            devorq::debug::log "  - Fillable: verificar se campo está em $fillable"
            devorq::debug::log "  - Cast: verificar tipo do cast (enum, datetime)"
        fi

        if [[ "$failure_context" =~ "database" || "$failure_context" =~ "migrate" ]]; then
            devorq::debug::log "  - Migration pendente: php artisan migrate --force"
            devorq::debug::log "  - Factory: verificar campos no make() vs create()"
        fi
    fi

    devorq::debug::log ""
    devorq::debug::log "Consulte systematic-debugging skill para processo completo:"
    devorq::debug::log "  ~/.hermes/skills/software-development/systematic-debugging/SKILL.md"
}

# ============================================================
# validate_with_context7
# Phase 3: Validar contra documentação oficial
# ============================================================
validate_with_context7() {
    local failure_context="${1:-}"
    local project_root="${2:-$PWD}"

    devorq::debug::log "Após identificar root cause, consultar docs oficiais via Context7:"

    if [[ "$failure_context" =~ "laravel" || "$failure_context" =~ "livewire" ]]; then
        devorq::debug::log ""
        devorq::debug::log "Exemplo de query Context7:"
        devorq::debug::log "  mcp_context7_resolve_library_id(libraryName=\"laravel\")"
        devorq::debug::log "  mcp_context7_query_docs(libraryId, query=\"[problema específico]\")"
        devorq::debug::log ""
        devorq::debug::log "Bibliotecas disponíveis no Context7:"
        devorq::debug::log "  - /laravel/framework (Laravel core)"
        devorq::debug::log "  - /laravel/breeze (Breeze)"
        devorq::debug::log "  - /livewire/livewire (Livewire)"
        devorq::debug::log "  - /tailwindcss/tailwindcss (Tailwind)"
    fi

    devorq::debug::log ""
    devorq::debug::log "REGRA: NUNCA aplique correção sem validar contra docs oficiais."
    devorq::debug::log "Hipótese sem validação = speculação."
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi