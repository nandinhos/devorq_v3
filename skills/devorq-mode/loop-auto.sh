#!/usr/bin/env bash
#===========================================================
# devorq-auto — loop-auto.sh v1.0.0
# Loop principal Ralph-style: delegate -> verify -> commit
#===========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

#-----------------------------------------------------------
# Helpers
#-----------------------------------------------------------
devorq_auto::usage() {
    cat <<EOF
Usage: loop-auto.sh <PROJECT_ROOT> [--iterations N|--all]

Loop Ralph-style: uma story por iteracao.
1. Seleciona story de maior priority com passes=false
2. delegate_task para sub-agente implementar
3. check-story.sh para verificar
4. git commit se passou
5. Atualiza prd.json

Args:
  PROJECT_ROOT    Diretorio do projeto (obrigatorio)
  --iterations N  Numero de iters (default: 1)
  --all           Executar todas as pendentes

Exit codes:
  0   Sucesso
  1   Projeto nao encontrado
  2   Abortado pelo usuario
  3   Verification falhou
  4   Delegate falhou
  5   prd.json nao encontrado
EOF
}

devorq_auto::die() {
    echo "ERROR: $*" >&2
    exit "${1:-1}"
}

devorq_auto::info()    { echo "[$(date +%H:%M)] $*"; }
devorq_auto::success() { echo "✅ $*"; }
devorq_auto::fail()    { echo "❌ $*"; }

#-----------------------------------------------------------
# Detectar projeto
#-----------------------------------------------------------
devorq_auto::detect_project() {
    local dir="${1:-.}"

    if [[ -f "$dir/SPEC.md" ]]; then
        echo "$dir"
        return 0
    elif [[ -f "$dir/.git/config" ]]; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null
        return 0
    fi

    # Procura subindo
    local parent="$dir"
    while [[ "$parent" != "/" && "$parent" != "." ]]; do
        parent=$(dirname "$parent")
        if [[ -f "$parent/SPEC.md" ]] || [[ -f "$parent/.git/config" ]]; then
            echo "$parent"
            return 0
        fi
    done

    return 1
}

#-----------------------------------------------------------
# Verificar prd.json
#-----------------------------------------------------------
devorq_auto::require_prd() {
    local prd="$1/prd.json"
    [[ -f "$prd" ]] || devorq_auto::die 5 "prd.json nao encontrado em $1"
}

#-----------------------------------------------------------
# Selecionar proxima story
#-----------------------------------------------------------
devorq_auto::next_story() {
    local prd="$1/prd.json"
    # Retorna JSON da primeira story (priority mais baixa)
    # com passes=false
    jq -r '.stories | sort_by(.priority) | .[] | select(.passes==false) | @json' "$prd" 2>/dev/null | head -1
}

devorq_auto::pending_count() {
    local prd="$1/prd.json"
    jq '.stories | map(select(.passes==false)) | length' "$prd" 2>/dev/null
}

devorq_auto::total_count() {
    local prd="$1/prd.json"
    jq '.stories | length' "$prd" 2>/dev/null
}

devorq_auto::completed_count() {
    local prd="$1/prd.json"
    jq '.stories | map(select(.passes==true)) | length' "$prd" 2>/dev/null
}

#-----------------------------------------------------------
# Atualizar prd.json — marcar story como passes=true
#-----------------------------------------------------------
devorq_auto::mark_pass() {
    local prd="$1/prd.json"
    local story_id="$2"
    local tmp
    tmp=$(mktemp)

    python3 -c "
import json, sys
with open('$prd') as f:
    data = json.load(f)
for s in data['stories']:
    if s['id'] == '$story_id':
        s['passes'] = True
        break
with open('$tmp', 'w') as f:
    json.dump(data, f, indent=2)
"
    mv "$tmp" "$prd"
}

#-----------------------------------------------------------
# Append progress.txt
#-----------------------------------------------------------
devorq_auto::append_progress() {
    local progress="$1/progress.txt"
    local story_id="$2"
    local story_title="$3"
    local status="${4:-PASSED}"

    {
        echo "# devorq-auto progress — $(basename "$1")"
        echo "# Formato: [HH:MM] ✅|❌ Story Title — PASSED|FAILED"
        echo "[$(date +%H:%M)] ${status} ${story_id}: ${story_title} — ${status}"
    } >> "$progress"
}

#-----------------------------------------------------------
# Criar branch para o work
#-----------------------------------------------------------
devorq_auto::ensure_branch() {
    local project="$1"
    local branch_file="$project/.devorq-auto/.last-branch"
    local existing_branch

    mkdir -p "$project/.devorq-auto"

    if [[ -f "$branch_file" ]]; then
        existing_branch=$(cat "$branch_file")
        if git -C "$project" rev-parse --verify "$existing_branch" >/dev/null 2>&1; then
            git -C "$project" checkout "$existing_branch" 2>/dev/null && return 0
        fi
    fi

    # Criar branch nova
    local new_branch="devorq-auto/$(date +%Y%m%d-%H%M%S)"
    git -C "$project" checkout -b "$new_branch" 2>/dev/null || true
    echo "$new_branch" > "$branch_file"
}

#-----------------------------------------------------------
# Git commit
#-----------------------------------------------------------
devorq_auto::git_commit() {
    local project="$1"
    local story_id="$2"
    local story_title="$3"

    # So comita se tiver changes
    if git -C "$project" diff --cached --quiet && git -C "$project" diff --quiet; then
        devorq_auto::info "Nenhum change para commitar (story pode ter sido NF)"
        return 0
    fi

    git -C "$project" add -A
    git -C "$project" commit -m "feat(${story_id}): ${story_title}" --no-verify 2>/dev/null || true
}

#-----------------------------------------------------------
# Mostrar status
#-----------------------------------------------------------
devorq_auto::show_status() {
    local project="$1"
    devorq_auto::require_prd "$project"

    local total pending completed
    total=$(devorq_auto::total_count "$project")
    pending=$(devorq_auto::pending_count "$project")
    completed=$(devorq_auto::completed_count "$project")

    echo ""
    echo "📋 prd.json — $total stories ($completed done, $pending pending)"
    echo "-----------------------------------------------------------"

    python3 -c "
import json
with open('$project/prd.json') as f:
    for s in sorted(json.load(f)['stories'], key=lambda x: x['priority']):
        icon = '✅' if s['passes'] else '🔴'
        print(f'  [{s[\"priority\"]}] \"{s[\"title\"]}\" [{icon}]')
"
}

#-----------------------------------------------------------
# Mostrar story atual
#-----------------------------------------------------------
devorq_auto::show_story() {
    local story_json="$1"
    local id title desc priority

    id=$(echo "$story_json" | jq -r '.id')
    title=$(echo "$story_json" | jq -r '.title')
    desc=$(echo "$story_json" | jq -r '.description')
    priority=$(echo "$story_json" | jq -r '.priority')

    echo ""
    echo "📖 Story: $id — $title"
    echo "   Priority: $priority"
    echo "   Desc: $desc"
    echo "   Criteria:"
    echo "$story_json" | jq -r '.acceptanceCriteria[] | "     - \(.)"'
}

#-----------------------------------------------------------
# Main loop
#-----------------------------------------------------------
main() {
    local project_root=""
    local iterations=1
    local all=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --iterations) iterations="$2"; shift 2 ;;
            --all) all=true; iterations=999; shift ;;
            -h|--help) devorq_auto::usage; exit 0 ;;
            *) project_root="$1"; shift ;;
        esac
    done

    [[ -z "$project_root" ]] && { devorq_auto::usage; exit 1; }

    # Detectar projeto
    project_root=$(devorq_auto::detect_project "$project_root") \
        || devorq_auto::die 1 "Nao encontrei SPEC.md ou .git a partir de: $project_root"

    cd "$project_root"
    devorq_auto::require_prd "$project_root"

    local pending
    pending=$(devorq_auto::pending_count "$project_root")
    [[ $pending -eq 0 ]] && { echo "✅ Todas as stories ja passaram."; exit 0; }

    echo ""
    echo "devorq-auto loop — $pending stories pendentes"
    echo "=============================================="

    # Garantir branch
    devorq_auto::ensure_branch "$project_root"

    local loop=0
    while [[ $loop -lt $iterations ]]; do
        loop=$((loop + 1))

        local story_json
        story_json=$(devorq_auto::next_story "$project_root")
        [[ -z "$story_json" || "$story_json" == "null" ]] && {
            echo "✅ Todas stories processadas."
            break
        }

        local story_id story_title story_desc story_priority
        story_id=$(echo "$story_json" | jq -r '.id')
        story_title=$(echo "$story_json" | jq -r '.title')
        story_desc=$(echo "$story_json" | jq -r '.description')
        story_priority=$(echo "$story_json" | jq -r '.priority')

        devorq_auto::info "🚀 Iteration $loop — Story: $story_id"
        devorq_auto::show_story "$story_json"

        # ================================================
        # DELEGATE — aqui o hook pro delegate_task
        # O script detecta se ha um delegate_task disponivel
        # Na pratica, o agent que carregou esta skill
        # fara o delegate real. Este script e o esqueleto.
        # ================================================

        local delegate_output=""
        if [[ -n "${DEVORQ_DELEGATE_FN:-}" ]]; then
            # Funcao de delegate registrada via env
            devorq_auto::info "⏳ Delegando para sub-agente..."
            delegate_output=$($DEVORQ_DELEGATE_FN "$story_json" "$project_root" 2>&1) || {
                devorq_auto::fail "Delegate failed: $delegate_output"
                devorq_auto::append_progress "$project_root" "$story_id" "$story_title" "FAILED"
                devorq_auto::die 4 "Delegate falhou para $story_id"
            }
            devorq_auto::success "Delegate completo"
        else
            devorq_auto::info "⏳ SIMULATED — Nao ha DEVORQ_DELEGATE_FN (rode via agent)"
            # Modo simulado: apenas marca como done para testing
            devorq_auto::info "Para testar local: DEVORQ_DELEGATE_FN=my_delegate_fn ./loop-auto.sh ."
        fi

        # Verification gate
        devorq_auto::info "🔍 Verificando..."
        if "$SKILL_DIR/scripts/check-story.sh" "$project_root"; then
            devorq_auto::success "Verification passed"
            devorq_auto::git_commit "$project_root" "$story_id" "$story_title"
            devorq_auto::success "Commit: feat(${story_id}): ${story_title}"
            devorq_auto::mark_pass "$project_root" "$story_id"
            devorq_auto::append_progress "$project_root" "$story_id" "$story_title" "PASSED"

            local done total
            done=$(devorq_auto::completed_count "$project_root")
            total=$(devorq_auto::total_count "$project_root")
            devorq_auto::info "📊 Progress: $done/$total stories done"
        else
            devorq_auto::fail "Verification failed — abortar? (Ctrl+C para abortar, Enter para continuar mesmo assim)"
            devorq_auto::append_progress "$project_root" "$story_id" "$story_title" "FAILED"
            read -r _ < /dev/stdin
        fi

        echo ""
    done

    # Summary
    local done total
    done=$(devorq_auto::completed_count "$project_root")
    total=$(devorq_auto::total_count "$project_root")
    pending=$(devorq_auto::pending_count "$project_root")

    echo ""
    echo "═══════════════════════════════════════"
    echo "✅ AUTO MODE COMPLETE"
    echo "═══════════════════════════════════════"
    echo "$done stories implemented, $pending pending"
    echo "📊 progress: $project_root/progress.txt"
    echo "📋 status:   $project_root/prd.json"
    echo "⚠️  Lembre de: E2E antes do PR"
    echo "═══════════════════════════════════════"
}

main "$@"
