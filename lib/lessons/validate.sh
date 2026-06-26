#!/usr/bin/env bash
# shellcheck disable=SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/lessons/validate.sh - DEVORQ Lessons VALIDATE module
# Funcoes: validate, _fuzzy_check, _suggest_tags
# Story 3 - dogfooding. Split de lib/lessons/search.sh para atingir <400 LOC.
# validate sozinho tinha 177 LOC; com helpers total ~260 LOC (cabe em <400).

set -euo pipefail

# ============================================================
# validate — Valida com Context7 (GATE-6)
# ============================================================

lessons::validate() {
    if [[ "${1:-}" == "--auto" ]]; then
        LESSONS_AUTO=true
    fi

    local dir="${DEVORQ_LESSONS_DIR}/captured"

    if [ ! -d "$dir" ]; then
        echo "Nada para validar."
        return 0
    fi

    local ctx7_available=false
    if [ -z "${OPENAI_API_KEY:-}" ] && [ ! -f "${DEVORQ_CONFIG:-${HOME}/.devorq/config}" ]; then
        echo -e "${YELLOW}[!]${RESET} Context7 não configurado — validacao automatica indisponivel"
        echo "  (Usando validacao manual: todas as lessons pendentes serao marcadas como 'skipped')"
        # NAO return aqui — fuzzy check e auto-trigger ainda devem rodar
    else
        ctx7_available=true
    fi

    # Em modo AUTO SEM Context7: NAO auto-validar (nao ha criterio de verificacao).
    # Marca como skipped/nao-verificada — mantem validated=false para NAO disparar
    # o auto-approve/auto-compile abaixo (validated_count permanece 0). DQ-013.
    if [ "${LESSONS_AUTO:-false}" = "true" ] && [ "$ctx7_available" = "false" ]; then
        local auto_skip_count=0
        for f in "$dir"/*.json; do
            [ -f "$f" ] || continue
            command -v jq &>/dev/null || continue
            local already_validated already_skipped
            already_validated=$(jq -r '.validated // false' "$f" 2>/dev/null)
            [ "$already_validated" = "true" ] && continue
            already_skipped=$(jq -r '.validation_status // ""' "$f" 2>/dev/null)
            [ "$already_skipped" = "skipped_no_context7" ] && continue
            local ts; ts=$(date +%Y-%m-%dT%H:%M:%S)
            jq --arg ts "$ts" '.validation_status = "skipped_no_context7" | .validation_checked_at = $ts' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
            local title; title=$(jq -r '.title' "$f" 2>/dev/null || echo "$(basename "$f")")
            echo -e "  ${CYAN}[~]${RESET} $title (skipped — Context7 indisponível, requer validação manual)"
            ((auto_skip_count++)) || true
        done
        if [ "$auto_skip_count" -gt 0 ]; then
            echo ""
            echo -e "${CYAN}[AUTO]${RESET} $auto_skip_count lição(ões) NÃO-verificadas (Context7 indisponível) — não serão auto-aprovadas nem compiladas"
        fi
    fi

    # Carregar lib/context7.sh para usar ctx7_resolve
    local ctx7_lib="${DEVORQ_DIR:-.}"/lib/context7.sh
    if [ -f "$ctx7_lib" ]; then
        # shellcheck source=/dev/null
        source "$ctx7_lib"
    fi

    echo -e "${CYAN}[GATE-6]${RESET} Validando lições com Context7..."

    # Encontrar lições não-validadas
    # NOTA: validated_count pode vir pré-setado do bloco auto-validate acima
    [ -z "${validated_count:-}" ] && validated_count=0
    local skipped_count=0
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue

        # Pula se já validada
        if command -v jq &>/dev/null; then
            local already_validated
            already_validated=$(jq -r '.validated // false' "$f" 2>/dev/null)
            [ "$already_validated" = "true" ] && continue
        fi

        local id title problem
        id=$(basename "$f" .json)
        if command -v jq &>/dev/null; then
            title=$(jq -r '.title' "$f" 2>/dev/null)
            problem=$(jq -r '.problem' "$f" 2>/dev/null)
        else
            title=$(grep '"title"' "$f" | cut -d'"' -f4 || echo "???")
            problem=$(grep '"problem"' "$f" | cut -d'"' -f4 || echo "")
        fi

        # Valida com Context7 — tenta resolver pelo stack/title
        local stack
        if command -v jq &>/dev/null; then
            stack=$(jq -r '.stack // "bash"' "$f" 2>/dev/null)
        else
            stack=$(grep '"stack"' "$f" | cut -d'"' -f4 || echo "bash")
        fi

        local validated=false
        if declare -f ctx7_resolve &>/dev/null; then
            # Tenta validar via Context7 com stack + problem como query
            local ctx_result
            if ctx_result=$(ctx7_resolve "$stack" "$problem" 2>&1); then
                if [ -n "$ctx_result" ] && ! echo "$ctx_result" | grep -qi "error\|warn\|sem resposta"; then
                    validated=true
                fi
            fi
        fi

        if [ "$validated" = "true" ]; then
            echo -e "  ${GREEN}[✓]${RESET} $title (Context7 OK)"
            local ts
            ts=$(date +%Y-%m-%dT%H:%M:%S)
            if command -v jq &>/dev/null; then
                jq --arg ts "$ts" '.validated = true | .validated_at = $ts' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
            else
                sed 's/"validated": false/"validated": true/' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
            fi
            ((validated_count++)) || true
        else
            echo -e "  ${YELLOW}[~]${RESET} $title (Context7 indisponível — pula)"
            ((skipped_count++)) || true
        fi
    done

    echo ""
    echo "Validadas: $validated_count | Puladas: $skipped_count"

    # Fuzzy check sempre executa (ajuda o usuário a decidir approve)
    lessons::_fuzzy_check "$dir"

    # Auto-trigger: sugerir approve + compile se tiver lições validadas
    if [ "$validated_count" -gt 0 ]; then
        local auto_mode="${LESSONS_AUTO:-false}"
        if [ "$auto_mode" = "true" ]; then
            echo ""
            echo "[DEVORQ] Auto-trigger: approve + compile (LESSONS_AUTO=true)"
            # Approve todas as validated (não-approved)
            local approve_count=0
            for f in "$dir"/*.json; do
                [ -f "$f" ] || continue
                if command -v jq &>/dev/null; then
                    local validated approved
                    validated=$(jq -r '.validated // false' "$f")
                    approved=$(jq -r '.approved // false' "$f")
                    [ "$validated" != "true" ] && continue
                    [ "$approved" = "true" ] && continue
                    local id; id=$(basename "$f" .json)
                    lessons::approve "$id" "" "true" &>/dev/null && ((approve_count++)) || true
                fi
            done
            echo "Aprovadas: $approve_count"
            # Compile todas as approved
            lessons::compile "" "" "false"
        else
            echo ""
            read -p "[$validated_count] lição(ões) validada(s). Aprovar para skill? [Y/n]: " confirm
            confirm="${confirm:-Y}"
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "[DEVORQ] Aprovando lições..."
                local approve_count=0
                for f in "$dir"/*.json; do
                    [ -f "$f" ] || continue
                    if command -v jq &>/dev/null; then
                        local validated approved
                        validated=$(jq -r '.validated // false' "$f")
                        approved=$(jq -r '.approved // false' "$f")
                        [ "$validated" != "true" ] && continue
                        [ "$approved" = "true" ] && continue
                        local id; id=$(basename "$f" .json)
                        lessons::approve "$id" "" "true" &>/dev/null && ((approve_count++)) || true
                    fi
                done
                echo "Aprovadas: $approve_count"
                echo ""
                read -p "Compilar skills? [Y/n]: " compile_confirm
                compile_confirm="${compile_confirm:-Y}"
                if [[ "$compile_confirm" =~ ^[Yy]$ ]]; then
                    lessons::compile
                fi
            fi
        fi
    fi
}

# ============================================================
# _fuzzy_check — Detecta lições com problemas similares
#   $1 = lessons dir
# ============================================================

lessons::_fuzzy_check() {
    local dir="$1"
    local threshold="${FUZZY_THRESHOLD:-3}"

    # Pegar últimas N lições validadas
    local recent=()
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        if command -v jq &>/dev/null; then
            local validated approved
            validated=$(jq -r '.validated // false' "$f" 2>/dev/null)
            approved=$(jq -r '.approved // false' "$f" 2>/dev/null)
            [ "$validated" = "true" ] && [ "$approved" != "true" ] || continue
        else
            continue
        fi
        recent+=("$f")
    done

    # Comparar pares
    local found_similar=false
    for i in "${!recent[@]}"; do
        for j in "${recent[@]}"; do
            [ "$i" -ge "${#recent[@]}" ] && break
            [ "${recent[$i]}" = "$j" ] && continue

            local problem_i problem_j
            if command -v jq &>/dev/null; then
                problem_i=$(jq -r '.problem' "${recent[$i]}" 2>/dev/null)
                problem_j=$(jq -r '.problem' "$j" 2>/dev/null)
            fi

            # Extrair palavras-chave (3+ letras) + filtrar vazio
            # grep pode nào encontrar matches (exit 1) → usar || true com set -e
            local words_i words_j
            words_i=$(echo "$problem_i" | tr ' ' '\n' | grep -E '^.{3,}$' | grep -v '^$' | sort -u || true)
            words_j=$(echo "$problem_j" | tr ' ' '\n' | grep -E '^.{3,}$' | grep -v '^$' | sort -u || true)

            # Skip se qualquer um for vazio (evita false-positive com linha vazia)
            [ -z "$words_i" ] && continue
            [ -z "$words_j" ] && continue

            # Contar overlap
            local overlap
            overlap=$(comm -12 <(echo "$words_i") <(echo "$words_j") | grep -v '^$' | wc -l)

            if [ "$overlap" -ge "$threshold" ]; then
                if [ "$found_similar" = "false" ]; then
                    echo ""
                    echo -e "${YELLOW}[!]${RESET} Possível duplicata detectada (fuzzy match):"
                    found_similar=true
                fi
                local id_i id_j
                id_i=$(basename "${recent[$i]}" .json)
                id_j=$(basename "$j" .json)
                echo -e "  ${id_i} ↔ ${id_j} ($overlap palavras em comum)"
            fi
        done
    done
}

# ============================================================
# _suggest_tags — Sugere tags via Context7 (se disponível)
#   $1 = path do arquivo JSON
# ============================================================

lessons::_suggest_tags() {
    local file="$1"

    if ! declare -f ctx7_resolve &>/dev/null; then
        return 1
    fi

    local problem title
    if command -v jq &>/dev/null; then
        problem=$(jq -r '.problem' "$file" 2>/dev/null)
        title=$(jq -r '.title' "$file" 2>/dev/null)
    fi

    # Query pro Context7
    local suggestion
    suggestion=$(ctx7_resolve "general" "Sugira tags para: $title — $problem" 2>/dev/null | head -1)

    if [ -n "$suggestion" ] && ! echo "$suggestion" | grep -qi "error\|nenhum\|null"; then
        echo "$suggestion"
        return 0
    fi
    return 1
}
