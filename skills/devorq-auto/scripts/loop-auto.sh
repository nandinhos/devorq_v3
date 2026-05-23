#!/usr/bin/env bash
#===========================================================
# devorq-auto — loop-auto.sh v1.2.0
# Loop principal Ralph-style: delegate -> verify -> commit
# Com:
#   - Fallback automatico execute_code
#   - Lessons aprendidas por projeto
#   - Log estruturado: failures.md + runs/*.log + pending/*.json
#===========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

#-----------------------------------------------------------
# Config
#-----------------------------------------------------------
DEVORQ_AUTO_VERSION="1.2.0"
FORCE_CONTINUE=false
CAPTURE_LESSONS=true
MAX_DELEGATE_RETRIES=1

#-----------------------------------------------------------
# Helpers
#-----------------------------------------------------------
devorq_auto::usage() {
    cat <<EOF
Usage: loop-auto.sh <PROJECT_ROOT> [OPTIONS]

Loop Ralph-style: uma story por iteracao.
1. Seleciona story de maior priority com passes=false
2. delegate_task para sub-agente implementar
3. Fallback automatico para execute_code se delegate falhar
4. check-story.sh para verificar
5. git commit se passou
6. Atualiza prd.json + lessons + failures.md

Args:
  PROJECT_ROOT    Diretorio do projeto (obrigatorio)

Options:
  --iterations N    Numero de iters (default: 1)
  --all             Executar todas as pendentes
  --force-continue  Pula stories com erro e continua (nao pergunta)
  --no-learn        Nao captura licoes aprendidas
  -h, --help        Este help

Output files:
  progress.txt         Log append-only de cada iteracao
  .devorq-auto/
    failures.md       Sumario das falhas (human-readable, latest)
    lessons.json      Falhas estruturadas (máquina)
    runs/YYYY-MM-DD_HH-MM.log   Log completo do batch
    pending/*.json    Context de cada story que falhou
EOF
}

devorq_auto::die() {
    echo "ERROR: $*" >&2
    exit "${1:-1}"
}

devorq_auto::info()    { echo "[$(date +%H:%M)] $*"; }
devorq_auto::success() { echo "✅ $*"; }
devorq_auto::fail()    { echo "❌ $*"; }
devorq_auto::warn()    { echo "⚠️  $*"; }
devorq_auto::learn()  { echo "📚 $*"; }

#-----------------------------------------------------------
# Devorq-auto directory structure
#-----------------------------------------------------------
DEVORQ_AUTO_DIR=""
RUN_LOG_FILE=""

devorq_auto::setup_dirs() {
    local project="$1"
    DEVORQ_AUTO_DIR="$project/.devorq-auto"
    mkdir -p "$DEVORQ_AUTO_DIR/pending" "$DEVORQ_AUTO_DIR/runs"

    # Create run log for this execution
    RUN_LOG_FILE="$DEVORQ_AUTO_DIR/runs/$(date +%Y-%m-%d_%H-%M).log"
}

#-----------------------------------------------------------
# Log to run file
#-----------------------------------------------------------
devorq_auto::log() {
    local msg="[$(date +%H:%M:%S)] $*"
    echo "$msg" >> "$RUN_LOG_FILE"
    echo "$msg"
}

#-----------------------------------------------------------
# Lessons — persistencia de licoes aprendidas por projeto
#-----------------------------------------------------------
LESSONS_FILE=""

devorq_auto::lessons_init() {
    local project="$1"
    LESSONS_FILE="$project/.devorq-auto/lessons.json"

    if [[ ! -f "$LESSONS_FILE" ]]; then
        cat > "$LESSONS_FILE" <<'LESSONSEOF'
{
  "project": "",
  "created": "",
  "lessons": [],
  "stats": { "total": 0, "delegate_failed": 0, "verification_failed": 0, "complex_detected": 0 }
}
LESSONSEOF
        python3 -c "import json; d=json.load(open('$LESSONS_FILE')); d['project']='$(basename "$project")'; d['created']='$(date -Iseconds)'; json.dump(d,open('$LESSONS_FILE','w'),indent=2))"
    fi
}

devorq_auto::lessons_capture() {
    local project="$1"
    local story_id="$2"
    local story_title="$3"
    local failure_type="$4"  # "delegate" | "verification" | "complex" | "success"
    local details="${5:-}"

    [[ "$CAPTURE_LESSONS" != "true" ]] && return 0

    local tmp
    tmp=$(mktemp)

    python3 -c "
import json
from datetime import datetime

with open('$LESSONS_FILE') as f:
    data = json.load(f)

lesson = {
    'story_id': '$story_id',
    'story_title': '$story_title',
    'type': '$failure_type',
    'details': '$details',
    'timestamp': datetime.now().isoformat()
}

data['lessons'].append(lesson)
data['stats']['total'] += 1

if '$failure_type' == 'delegate':
    data['stats']['delegate_failed'] += 1
elif '$failure_type' == 'verification':
    data['stats']['verification_failed'] += 1
elif '$failure_type' == 'complex':
    data['stats']['complex_detected'] += 1

with open('$tmp', 'w') as f:
    json.dump(data, f, indent=2)
"
    mv "$tmp" "$LESSONS_FILE"
}

devorq_auto::lessons_suggest() {
    local project="$1"
    local story_title="$2"

    [[ ! -f "$LESSONS_FILE" ]] && return 0

    python3 -c "
import json
with open('$LESSONS_FILE') as f:
    data = json.load(f)

similar = [l for l in data['lessons'] if l['type'] in ('delegate', 'complex') and l['story_title'].lower() in '$story_title'.lower()]
if similar:
    print()
    print('📚 Licao anterior relevante:')
    for l in similar[-2:]:
        print(f"  -> {l['story_id']}: {l['details']}")
" 2>/dev/null || true
}

#-----------------------------------------------------------
# FAILURES.MD — Gerar sumario human-readable das falhas
#-----------------------------------------------------------
devorq_auto::failures_generate() {
    local project="$1"

    [[ ! -f "$LESSONS_FILE" ]] && return 0

    local failures_md="$DEVORQ_AUTO_DIR/failures.md"
    local total pending done

    total=$(devorq_auto::total_count "$project")
    pending=$(devorq_auto::pending_count "$project")
    done=$(devorq_auto::completed_count "$project")

    python3 << PYEOF
import json
from datetime import datetime

project_name = '$(basename "$project")'

with open('$LESSONS_FILE') as f:
    data = json.load(f)

failed = [l for l in data['lessons'] if l['type'] in ('delegate', 'verification', 'complex')]
failed.reverse()  # Most recent first

type_icon = {
    'delegate': '❌',
    'verification': '❌',
    'complex': '⚠️'
}

type_action = {
    'delegate': 'delegate_task falhou apos retries',
    'verification': 'check-story.sh failed',
    'complex': 'Story complexa detectada'
}

lines = []
lines.append(f'# DEVORQ-AUTO Failures — {project_name}')
lines.append(f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M")}')
lines.append('')
lines.append(f'## {len(failed)} Stories Pendentes de Correção')
lines.append('')

for l in failed:
    icon = type_icon.get(l['type'], '❌')
    action = type_action.get(l['type'], l['type'])
    dt = datetime.fromisoformat(l['timestamp']).strftime('%Y-%m-%d %H:%M')
    lines.append(f'### {icon} {l["story_id"]}: {l["story_title"]}')
    lines.append(f'- **Tipo:** {l["type"]} ({l["details"]})')
    lines.append(f'- **Data:** {dt}')
    lines.append(f'- **Action:** {action}')
    lines.append(f'- **Contexto:** \`.devorq-auto/pending/{l["story_id"]}.json\`')
    lines.append('')

lines.append('---')
lines.append(f'Total: {len(failed)} failures | Stats: delegate={data["stats"]["delegate_failed"]}, verification={data["stats"]["verification_failed"]}, complex={data["stats"]["complex_detected"]}')
lines.append(f'Progresso: {done}/{total} done, {pending} pending')

with open('$failures_md', 'w') as f:
    f.write('
'.join(lines))
PYEOF
}

#-----------------------------------------------------------
# PENDING — Salvar contexto da story que falhou
#-----------------------------------------------------------
devorq_auto::pending_save() {
    local project="$1"
    local story_json="$2"
    local failure_type="$3"
    local details="$4"

    local story_id
    story_id=$(echo "$story_json" | jq -r '.id')

    local pending_file="$DEVORQ_AUTO_DIR/pending/${story_id}.json"

    # Write story_json to temp file first to avoid escaping issues
    local json_tmp
    json_tmp=$(mktemp)
    echo "$story_json" > "$json_tmp"

    python3 << PYEOF
import json
from datetime import datetime

with open('$json_tmp') as f:
    story = json.load(f)

pending = {
    'story_id': story['id'],
    'title': story['title'],
    'description': story['description'],
    'acceptanceCriteria': story.get('acceptanceCriteria', []),
    'priority': story['priority'],
    'failure': {
        'type': '$failure_type',
        'details': '$details',
        'timestamp': datetime.now().isoformat()
    }
}

with open('$pending_file', 'w') as f:
    json.dump(pending, f, indent=2)
PYEOF

    rm -f "$json_tmp"
    echo "Saved: $pending_file"
}

#-----------------------------------------------------------
# Detectar projeto
#-----------------------------------------------------------
devorq_auto::detect_project() {
    local dir="\${1:-.}"

    if [[ -f "$dir/SPEC.md" ]]; then
        echo "$dir"
        return 0
    elif [[ -f "$dir/.git/config" ]]; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null
        return 0
    fi

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
# Atualizar prd.json
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

devorq_auto::mark_skip() {
    local prd="$1/prd.json"
    local story_id="$2"
    local reason="$3"
    local tmp
    tmp=$(mktemp)

    python3 -c "
import json, sys
with open('$prd') as f:
    data = json.load(f)
for s in data['stories']:
    if s['id'] == '$story_id':
        s['passes'] = True
        s['skipped'] = True
        s['skip_reason'] = '$reason'
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
    local status="\${4:-PASSED}"

    {
        echo "# devorq-auto progress — $(basename "$1")"
        echo "# Formato: [HH:MM] ✅|❌|⏭️  Story Title — PASSED|FAILED|SKIPPED"
        echo "[$(date +%H:%M)] \${status} \${story_id}: \${story_title} — \${status}"
    } >> "$progress"
}

#-----------------------------------------------------------
# Criar branch
#-----------------------------------------------------------
devorq_auto::ensure_branch() {
    local project="$1"
    local branch_file="$project/.devorq-auto/.last-branch"

    mkdir -p "$project/.devorq-auto"

    if [[ -f "$branch_file" ]]; then
        local existing_branch
        existing_branch=$(cat "$branch_file")
        if git -C "$project" rev-parse --verify "$existing_branch" >/dev/null 2>&1; then
            git -C "$project" checkout "$existing_branch" 2>/dev/null && return 0
        fi
    fi

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

    if git -C "$project" diff --cached --quiet && git -C "$project" diff --quiet; then
        devorq_auto::info "Nenhum change para commitar"
        return 0
    fi

    git -C "$project" add -A
    git -C "$project" commit -m "feat(\${story_id}): \${story_title}" --no-verify 2>/dev/null || true
}

#-----------------------------------------------------------
# Detectar complexidade de story
#-----------------------------------------------------------
devorq_auto::detect_complexity() {
    local story_title="$1"
    local story_desc="$2"

    local complex_keywords="migration|enum|policy|relation|many-to-many|factory|seeder|job|queue|event|listener|middleware|service provider|config|schema|refactor|multi|distributed|parallel"
    local complex_heuristic

    complex_heuristic=$(echo "$story_title $story_desc" | grep -Ei "$complex_keywords" | head -1 || true)

    if [[ -n "$complex_heuristic" ]]; then
        echo "complex:$complex_heuristic"
        return 0
    fi

    local total_len=$((\${#story_title} + \${#story_desc}))
    if [[ $total_len -gt 500 ]]; then
        echo "complex:long_description"
        return 0
    fi

    return 1
}

#-----------------------------------------------------------
# Propor quebra de story
#-----------------------------------------------------------
devorq_auto::propose_break() {
    local story_json="$1"

    echo ""
    devorq_auto::warn "Story complexa detectada!"
    echo ""
    echo "  ID: $(echo "$story_json" | jq -r '.id')"
    echo "  Title: $(echo "$story_json" | jq -r '.title')"
    echo ""
    echo "  Suggestoes:"
    echo "    1. Continuar mesmo assim (pode falhar)"
    echo "    2. Marcar como SKIPPED (analise manual)"
    echo "    3. Abortar"
    echo ""
    echo -n "  Escolha [1]: "

    local choice="1"
    read -r choice < /dev/stdin

    case "\${choice:-1}" in
        2) echo "SKIPPED" ;;
        3) exit 2 ;;
        *) echo "CONTINUE" ;;
    esac
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
        icon = '✅' if s.get('passes', False) else ('⏭️ ' if s.get('skipped') else '🔴')
        skipped = f' (SKIP: {s["skip_reason"]})' if s.get('skipped') else ''
        print(f'  [{s["priority"]}] "{s["title"]}" [{icon}]')
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
# DELEGATE — wrapper com retry
#-----------------------------------------------------------
devorq_auto::delegate_with_retry() {
    local story_json="$1"
    local project="$2"
    local attempt=0
    local last_error=""

    while [[ $attempt -lt $MAX_DELEGATE_RETRIES ]]; do
        attempt=$((attempt + 1))

        if [[ $attempt -eq 1 ]]; then
            devorq_auto::info "⏳ Delegando para sub-agente (tentativa $attempt)..."
        else
            devorq_auto::warn "Retry $attempt..."
        fi

        if [[ -n "\${DEVORQ_DELEGATE_FN:-}" ]]; then
            local output
            output=$($DEVORQ_DELEGATE_FN "$story_json" "$project" 2>&1) && {
                devorq_auto::success "Delegate completo"
                return 0
            }
            last_error="$output"
        else
            devorq_auto::info "⏳ SIMULATED — Nao ha DEVORQ_DELEGATE_FN (rode via agent)"
            return 0
        fi

        if [[ $attempt -lt $MAX_DELEGATE_RETRIES ]]; then
            devorq_auto::warn "Delegate falhou, tentando novamente em 2s..."
            sleep 2
        fi
    done

    devorq_auto::fail "Delegate falhou apos $MAX_DELEGATE_RETRIES retries: $last_error"
    return 1
}

#-----------------------------------------------------------
# Handle failure — save pending + lessons
#-----------------------------------------------------------
devorq_auto::handle_failure() {
    local project="$1"
    local story_json="$2"
    local story_id="$3"
    local story_title="$4"
    local failure_type="$5"
    local details="$6"

    # Save pending context
    devorq_auto::pending_save "$project" "$story_json" "$failure_type" "$details"

    # Capture lesson
    devorq_auto::lessons_capture "$project" "$story_id" "$story_title" "$failure_type" "$details"

    # Update progress
    devorq_auto::append_progress "$project" "$story_id" "$story_title" "FAILED"
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
            --force-continue) FORCE_CONTINUE=true; shift ;;
            --no-learn) CAPTURE_LESSONS=false; shift ;;
            -h|--help) devorq_auto::usage; exit 0 ;;
            *) project_root="$1"; shift ;;
        esac
    done

    [[ -z "$project_root" ]] && { devorq_auto::usage; exit 1; }

    project_root=$(devorq_auto::detect_project "$project_root")         || devorq_auto::die 1 "Nao encontrei SPEC.md ou .git a partir de: $project_root"

    cd "$project_root"
    devorq_auto::require_prd "$project_root"

    # Setup dirs and init
    devorq_auto::setup_dirs "$project_root"
    devorq_auto::lessons_init "$project_root"

    # Start run log header
    devorq_auto::log "=== DEVORQ-AUTO v$DEVORQ_AUTO_VERSION RUN START ==="
    devorq_auto::log "Project: $project_root"
    devorq_auto::log "Force-continue: $FORCE_CONTINUE | Capture-lessons: $CAPTURE_LESSONS"

    local pending
    pending=$(devorq_auto::pending_count "$project_root")
    [[ $pending -eq 0 ]] && { echo "✅ Todas as stories ja passaram."; exit 0; }

    echo ""
    echo "devorq-auto loop v$DEVORQ_AUTO_VERSION — $pending stories pendentes"
    echo "Force-continue: $FORCE_CONTINUE | Capture-lessons: $CAPTURE_LESSONS"
    echo "Log: $RUN_LOG_FILE"
    echo "=============================================="

    devorq_auto::ensure_branch "$project_root"

    local loop=0
    local total_failures=0
    local failure_list=()

    while [[ $loop -lt $iterations ]]; do
        loop=$((loop + 1))

        local story_json
        story_json=$(devorq_auto::next_story "$project_root")
        [[ -z "$story_json" || "$story_json" == "null" ]] && {
            devorq_auto::log "All stories processed"
            echo "✅ Todas stories processadas."
            break
        }

        local story_id story_title story_desc story_priority
        story_id=$(echo "$story_json" | jq -r '.id')
        story_title=$(echo "$story_json" | jq -r '.title')
        story_desc=$(echo "$story_json" | jq -r '.description')
        story_priority=$(echo "$story_json" | jq -r '.priority')

        devorq_auto::log "--- Story: $story_id ---"
        devorq_auto::info "🚀 Iteration $loop — Story: $story_id"
        devorq_auto::show_story "$story_json"

        # Suggest previous lesson
        devorq_auto::lessons_suggest "$project_root" "$story_title"

        # Detect complexity
        local complexity
        complexity=$(devorq_auto::detect_complexity "$story_title" "$story_desc")
        local complex_result=""

        if [[ -n "$complexity" ]]; then
            devorq_auto::lessons_capture "$project_root" "$story_id" "$story_title" "complex" "$complexity"
            complex_result=$(devorq_auto::propose_break "$story_json")

            if [[ "$complex_result" == "SKIPPED" ]]; then
                devorq_auto::warn "Story marcada como SKIPPED"
                devorq_auto::mark_skip "$project_root" "$story_id" "$complexity"
                devorq_auto::append_progress "$project_root" "$story_id" "$story_title" "SKIPPED"
                devorq_auto::log "SKIPPED: $story_id ($complexity)"
                continue
            elif [[ "$complex_result" == "CONTINUE" ]]; then
                devorq_auto::info "Prosseguindo mesmo assim..."
            fi
        fi

        # DELEGATE with retry
        local delegate_ok=false
        if devorq_auto::delegate_with_retry "$story_json" "$project_root"; then
            delegate_ok=true
        else
            devorq_auto::fail "Delegate falhou apos retries"
            devorq_auto::handle_failure "$project_root" "$story_json" "$story_id" "$story_title" "delegate" "failed_after_${MAX_DELEGATE_RETRIES}_retries"
            total_failures=$((total_failures + 1))
            failure_list+=("$story_id")

            if [[ "$FORCE_CONTINUE" == "true" ]]; then
                devorq_auto::warn "FORCE_CONTINUE=true — pulando story"
                continue
            fi

            echo ""
            echo "  [1] Abortar"
            echo "  [2] Pular story e continuar"
            echo "  [3] Tentar novamente"
            echo -n "  Escolha [1]: "
            local choice
            read -r choice < /dev/stdin

            case "\${choice:-1}" in
                2) devorq_auto::warn "Pulando $story_id"; continue ;;
                3) loop=$((loop - 1)); continue ;;
                *) devorq_auto::die 4 "Abortado pelo usuario" ;;
            esac
        fi

        # Verification gate
        devorq_auto::info "🔍 Verificando..."
        devorq_auto::log "Running verification for: $story_id"
        if "$SKILL_DIR/scripts/check-story.sh" "$project_root"; then
            devorq_auto::success "Verification passed"
            devorq_auto::git_commit "$project_root" "$story_id" "$story_title"
            devorq_auto::success "Commit: feat(\${story_id}): \${story_title}"
            devorq_auto::mark_pass "$project_root" "$story_id"
            devorq_auto::append_progress "$project_root" "$story_id" "$story_title" "PASSED"
            devorq_auto::lessons_capture "$project_root" "$story_id" "$story_title" "success" ""
            devorq_auto::log "PASSED: $story_id"

            local done total
            done=$(devorq_auto::completed_count "$project_root")
            total=$(devorq_auto::total_count "$project_root")
            devorq_auto::info "📊 Progress: $done/$total stories done"
        else
            devorq_auto::fail "Verification failed"
            devorq_auto::handle_failure "$project_root" "$story_json" "$story_id" "$story_title" "verification" "check-story.sh_failed"
            total_failures=$((total_failures + 1))
            failure_list+=("$story_id")

            if [[ "$FORCE_CONTINUE" == "true" ]]; then
                devorq_auto::warn "FORCE_CONTINUE=true — continuando mesmo assim"
                continue
            fi

            echo ""
            echo "  [1] Abortar"
            echo "  [2] Pular story e continuar"
            echo "  [3] Tentar novamente"
            echo -n "  Escolha [1]: "
            local choice
            read -r choice < /dev/stdin

            case "\${choice:-1}" in
                2) devorq_auto::warn "Pulando $story_id"; continue ;;
                3) loop=$((loop - 1)); continue ;;
                *) devorq_auto::die 3 "Verification failed — abortado" ;;
            esac
        fi

        echo ""
    done

    # Generate failures.md
    devorq_auto::failures_generate "$project_root"

    # Summary
    local done total
    done=$(devorq_auto::completed_count "$project_root")
    total=$(devorq_auto::total_count "$project_root")
    pending=$(devorq_auto::pending_count "$project_root")

    echo ""
    echo "═══════════════════════════════════════"
    echo "✅ AUTO MODE COMPLETE (v$DEVORQ_AUTO_VERSION)"
    echo "═══════════════════════════════════════"
    echo "$done stories done, $pending pending, $total_failures failures"
    echo ""
    echo "📊 progress:    $project_root/progress.txt"
    echo "📋 prd.json:    $project_root/prd.json"
    echo "📚 lessons:     $DEVORQ_AUTO_DIR/lessons.json"
    echo "📝 failures:    $DEVORQ_AUTO_DIR/failures.md"
    echo "📁 run log:     $RUN_LOG_FILE"
    echo "📁 pending ctx: $DEVORQ_AUTO_DIR/pending/"
    echo "⚠️  Lembre de: E2E antes do PR"
    echo "══════════════════════════════════════="

    devorq_auto::log "=== RUN END: $done done, $pending pending, $total_failures failures ==="
}

main "$@"
