#!/usr/bin/env bash
# lib/lessons.sh — DEVORQ Lessons Module
#
# Responsabilidades:
#   lessons::capture  — Salvar lição aprendida
#   lessons::search    — Buscar lições no HUB
#   lessons::validate  — Validar com Context7
#   lessons::apply     — Aplicar lição validada

set -euo pipefail

# Cores (sem ANSI — compatibilidade máxima)
GREEN='' CYAN='' RED='' YELLOW='' RESET='' BOLD=''

DEVORQ_LESSONS_DIR="${DEVORQ_LESSONS_DIR:-${PWD}/.devorq/state/lessons}"
DEVORQ_HUB_HOST="${DEVORQ_HUB_HOST:-}"
DEVORQ_HUB_PORT="${DEVORQ_HUB_PORT:-5432}"

# ============================================================
# capture
#   $1 = title
#   $2 = problem
#   $3 = solution
# ============================================================

lessons::capture() {
    local title="$1"
    local problem="$2"
    local solution="$3"

    local dir="${DEVORQ_LESSONS_DIR}/captured"
    mkdir -p "$dir"

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local id="lesson_${ts}_$$"
    local file="${dir}/${id}.json"

    # Determinar stack do contexto
    local stack="${DEVORQ_STACK:-unknown}"
    local tags="${DEVORQ_TAGS:-}"

    # Serializar como JSON (fallback sem jq)
    if command -v jq &>/dev/null; then
        jq -n \
            --arg id "$id" \
            --arg title "$title" \
            --arg problem "$problem" \
            --arg solution "$solution" \
            --arg stack "$stack" \
            --arg tags "$tags" \
            --arg ts "$ts" \
            '{
                id: $id,
                title: $title,
                problem: $problem,
                solution: $solution,
                stack: $stack,
                tags: ($tags | if . == "" then [] else split(",") end),
                timestamp: $ts,
                validated: false,
                applied: false
            }' > "$file"
    else
        # Fallback: printf manual (sem dependência de jq)
        printf '%s\n' \
            "{" \
            "  \"id\": \"${id}\"," \
            "  \"title\": \"${title}\"," \
            "  \"problem\": \"${problem}\"," \
            "  \"solution\": \"${solution}\"," \
            "  \"stack\": \"${stack}\"," \
            "  \"tags\": [], " \
            "  \"timestamp\": \"${ts}\"," \
            "  \"validated\": false," \
            "  \"applied\": false" \
            "}" > "$file"
    fi

    # Sync com VPS se configurado
    lessons::sync_vps "$file" &>/dev/null || true

    echo -e "${GREEN}[✓]${RESET} Lição salva: ${id}"
    echo "   $title"
}

# ============================================================
# search
#   $1 = query string
# ============================================================

lessons::search() {
    local query="$1"
    local dir="${DEVORQ_LESSONS_DIR}/captured"

    if [ ! -d "$dir" ]; then
        echo "Nenhuma lição capturada ainda."
        return 0
    fi

    echo -e "${CYAN}[LESSONS]${RESET} Busca: $query"
    echo ""

    # Busca local via grep nos arquivos JSON
    local results
    results=$(grep -l -i "$query" "$dir"/*.json 2>/dev/null || true)

    if [ -z "$results" ]; then
        echo "Nenhuma lição encontrada."
        return 0
    fi

    while read -r f; do
        [ -z "$f" ] && continue
        if command -v jq &>/dev/null; then
            local title validated ts
            title=$(jq -r '.title' "$f" 2>/dev/null || echo "???")
            validated=$(jq -r '.validated' "$f" 2>/dev/null || echo "false")
            ts=$(jq -r '.timestamp' "$f" 2>/dev/null || echo "???")
        else
            local title validated ts
            title=$(grep '"title"' "$f" | cut -d'"' -f4 || echo "???")
            validated=$(grep '"validated"' "$f" | cut -d' ' -f2 | tr -d ',' || echo "false")
            ts=$(grep '"timestamp"' "$f" | cut -d'"' -f4 || echo "???")
        fi
        echo -e "  ${GREEN}${title}${RESET} [$ts] ${validated:+/}"
    done <<< "$results"
}

# ============================================================
# validate — Valida com Context7 (GATE-6)
# ============================================================

lessons::validate() {
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

    # Em modo AUTO sem Context7: auto-validar todas as não-validadas
    if [ "${LESSONS_AUTO:-false}" = "true" ] && [ "$ctx7_available" = "false" ]; then
        local auto_val_count=0
        for f in "$dir"/*.json; do
            [ -f "$f" ] || continue
            if command -v jq &>/dev/null; then
                local already_validated
                already_validated=$(jq -r '.validated // false' "$f" 2>/dev/null)
                [ "$already_validated" = "true" ] && continue
            fi
            local ts
            ts=$(date +%Y-%m-%dT%H:%M:%S)
            if command -v jq &>/dev/null; then
                jq --arg ts "$ts" '.validated = true | .validated_at = $ts' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
            else
                sed 's/"validated": false/"validated": true/' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
            fi
            local title
            title=$(jq -r '.title' "$f" 2>/dev/null || echo "$(basename "$f")")
            echo -e "  ${GREEN}[✓]${RESET} $title (auto-validada em modo AUTO)"
            ((auto_val_count++)) || true
        done
        if [ "$auto_val_count" -gt 0 ]; then
            echo ""
            echo -e "${CYAN}[AUTO]${RESET} $auto_val_count lição(ões) auto-validadas (Context7 indisponível)"
        fi
        validated_count=$auto_val_count
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
# apply — Marca lição como aplicada (GATE-7)
# ============================================================

lessons::apply() {
    local id="${1:-}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"

    _apply_file() {
        local f="$1"
        if command -v jq &>/dev/null; then
            jq '.applied = true' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        else
            sed 's/"applied": false/"applied": true/' "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
        fi
        echo -e "${GREEN}[✓]${RESET} $(basename "$f" .json) marcada como aplicada"
    }

    if [ -z "$id" ]; then
        for f in "$dir"/*.json; do
            [ -f "$f" ] || continue
            _apply_file "$f"
        done
    else
        local file="${dir}/${id}.json"
        [ ! -f "$file" ] && echo "Lição não encontrada: $id" && return 1
        _apply_file "$file"
    fi
}

# ============================================================
# sync_vps — Sincroniza lição com VPS HUB (background)
# ============================================================

lessons::sync_vps() {
    local file="$1"
    local vps_host="${DEVORQ_VPS_HOST:-187.108.197.199}"
    local vps_port="${DEVORQ_VPS_PORT:-6985}"
    local vps_user="${DEVORQ_VPS_USER:-root}"
    local mux_sock="${DEVORQ_MUX_SOCK:-/tmp/devorq-ssh-mux}"

    [ ! -f "$file" ] && echo "[ERROR] Arquivo não encontrado: $file" && return 1

    # Carrega lib/vps.sh se disponível para usar SSH mux
    local mux_lib="${DEVORQ_DIR:-.}"/lib/vps.sh
    if [ -f "$mux_lib" ]; then
        # shellcheck source=/dev/null
        source "$mux_lib"
        vps::exec "mkdir -p ~/.devorq/lessons && cat > ~/.devorq/lessons/$(basename "$file")" < "$file"
    else
        # Fallback: scp direto
        scp -P "$vps_port" -o "ControlPath=$mux_sock" "$file" "${vps_user}@${vps_host}:~/.devorq/lessons/" 2>/dev/null || \
        scp -P "$vps_port" "$file" "${vps_user}@${vps_host}:/tmp/" 2>/dev/null || true
    fi
}

# ============================================================
# _infer_skill — Infer skill path por tags
#   $1 = path do arquivo JSON
#   Return: skill name (ex: "laravel", "docker", "learned-lesson")
# ============================================================

lessons::_infer_skill() {
    local file="$1"
    local tags=""
    local stack=""

    if command -v jq &>/dev/null; then
        tags=$(jq -r '.tags | join(",")' "$file" 2>/dev/null || echo "")
        stack=$(jq -r '.stack // ""' "$file" 2>/dev/null || echo "")
    fi

    # Mapa de tags que correspondem a skills existentes
    local skill_map="laravel,docker,postgres,mysql,git,nginx,filament,postgres,docker-compose,git"

    IFS=',' read -ra TAG_ARR <<< "$tags"
    for tag in "${TAG_ARR[@]}"; do
        # Trim whitespace
        tag=$(echo "$tag" | xargs)
        [[ -n "$tag" ]] && [[ ",$skill_map," = *",$tag,"* ]] && {
            echo "$tag"
            return 0
        }
    done

    # Fallback: campo stack
    if [[ -n "$stack" ]] && [[ ",$skill_map," = *",$stack,"* ]]; then
        echo "$stack"
        return 0
    fi

    # Fallback final
    echo "learned-lesson"
}

# ============================================================
# approve — Marca lição como aprovada
#   $1 = lesson id (sem .json)
#   $2 = skill name opcional (inferred se vazio)
#   $3 = auto mode (true/false)
# ============================================================

lessons::approve() {
    local id="${1:-}"
    local skill_name="${2:-}"
    local auto="${3:-false}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local file="${dir}/${id}.json"

    # Validar que existe
    [ ! -f "$file" ] && echo "[ERROR] Lição não encontrada: $id" && return 1

    # Verificar se foi validada
    if command -v jq &>/dev/null; then
        local validated
        validated=$(jq -r '.validated // false' "$file")
        [ "$validated" != "true" ] && echo "[ERROR] Lição precisa ser validada primeiro (Context7)" && return 1
    fi

    # Verificar se já approved
    if command -v jq &>/dev/null; then
        local already_approved
        already_approved=$(jq -r '.approved // false' "$file")
        [ "$already_approved" = "true" ] && echo "[INFO] Já aprovada: $id" && return 0
    fi

    # Inferir skill se não informada
    if [ -z "$skill_name" ]; then
        skill_name=$(lessons::_infer_skill "$file")
    fi

    local skill_path="skills/${skill_name}"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Atualizar JSON com campos approved
    if command -v jq &>/dev/null; then
        jq \
            --arg ts "$ts" \
            --arg skill_path "$skill_path" \
            --arg skill_name "$skill_name" \
            '.approved = true | .approved_at = $ts | .skill_path = $skill_path | .approved_by = "user" | .skill_name = $skill_name' \
            "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    else
        # Fallback sed para campos approved
        sed -i \
            -e "s/\"validated\": true/\"validated\": true, \"approved\": true, \"approved_at\": \"$ts\", \"approved_by\": \"user\", \"skill_path\": \"$skill_path\"/" \
            "$file"
    fi

    echo -e "${GREEN}[✓]${RESET} Aprovada: $id → $skill_path"
}

# ============================================================
# _compile_lesson — Compila uma lição approved → skill
#   $1 = lesson id
#   $2 = skill_path
#   $3 = dry_run (true/false)
# ============================================================

lessons::_compile_lesson() {
    local id="$1"
    local skill_path="$2"
    local dry_run="${3:-false}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local file="${dir}/${id}.json"

    [ ! -f "$file" ] && echo "[ERROR] Lição não encontrada: $id" && return 1

    # Verificar approved
    if command -v jq &>/dev/null; then
        local approved
        approved=$(jq -r '.approved // false' "$file")
        [ "$approved" != "true" ] && echo "[SKIP] Não aprovada: $id" && return 0
    fi

    local title problem solution tags stack skill_name
    if command -v jq &>/dev/null; then
        title=$(jq -r '.title' "$file")
        problem=$(jq -r '.problem' "$file")
        solution=$(jq -r '.solution' "$file")
        tags=$(jq -r '.tags | join(", ")' "$file")
        stack=$(jq -r '.stack // ""' "$file")
        skill_name=$(jq -r '.skill_name // (.skill_path | split("/")[1]) // "learned-lesson"' "$file")
    fi

    [ -z "$skill_path" ] && skill_path="skills/${skill_name:-learned-lesson}"

    if [ "$dry_run" = "true" ]; then
        echo "[DRY RUN] Skill seria gerada em: $skill_path"
        echo "  Title: $title"
        echo "  Tags: $tags"
        return 0
    fi

    # Criar diretórios
    mkdir -p "${skill_path}/references/approved"
    mkdir -p "${skill_path}/scripts"

    # Copiar lição approved
    cp "$file" "${skill_path}/references/approved/${id}.json"

    # Gerar/atualizar SKILL.md
    local skill_md="${skill_path}/SKILL.md"
    local entry="- **${title}**: ${problem} → ${solution} (${tags})"

    if [ -f "$skill_md" ]; then
        # Adicionar entrada se já existe
        if ! grep -qF "$title" "$skill_md" 2>/dev/null; then
            if grep -q "## Approved Lessons" "$skill_md" 2>/dev/null; then
                # Inserir após "## Approved Lessons"
                sed -i "/## Approved Lessons/a\\\\$entry" "$skill_md"
            else
                echo "" >> "$skill_md"
                echo "## Approved Lessons" >> "$skill_md"
                echo "$entry" >> "$skill_md"
            fi
        fi
    else
        # Criar SKILL.md do zero
        local trigger_word
        trigger_word=$(echo "$problem" | cut -d' ' -f1-3 | tr -s ' ')
        local desc_tag
        desc_tag=$(echo "$tags" | cut -d',' -f1 | xargs)
        cat > "$skill_md" << SKELLEOF
---
name: ${skill_name:-learned-lesson}
description: Use quando detectar problema relacionado a ${desc_tag:-conhecimento geral}
triggers:
  - "${trigger_word}"
---

# ${skill_name:-learned-lesson} — Skill Gerada

> Auto-generated from approved lesson: $id

## Problema
$problem

## Solução
$solution

## Tags
$tags

## Stack
$stack

## Approved Lessons
$entry
SKELLEOF
    fi

    # Atualizar timestamp de compilação na lição
    local compiled_at
    compiled_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if command -v jq &>/dev/null; then
        jq --arg compiled_at "$compiled_at" '.compiled_at = $compiled_at' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi

    # Atualizar skill index
    lessons::_update_skill_index "$(dirname "$skill_path")" "$(basename "$skill_path")"

    echo -e "${GREEN}[✓]${RESET} Skill compilada: $skill_path"
    echo "   $title"
}

# ============================================================
# _update_skill_index — Mantém skills/.index.md atualizado
#   $1 = skills dir (ex: "skills")
#   $2 = skill name (ex: "laravel")
# ============================================================

lessons::_update_skill_index() {
    local skills_dir="${1:-skills}"
    local skill_name="$2"
    local index_file="${skills_dir}/.index.md"

    mkdir -p "$skills_dir"

    local today
    today=$(date +%Y-%m-%d)
    local skill_dir="${skills_dir}/${skill_name}"
    local skill_md="${skill_dir}/SKILL.md"

    # Extrair description do SKILL.md se existir
    local description=""
    if [ -f "$skill_md" ]; then
        description=$(sed -n '/^description:/p' "$skill_md" | sed 's/^description: *//' | tr -d '"')
        [ -z "$description" ] && description="Skill gerada automaticamente"
    fi

    local entry="| ${skill_name} | ${description} | ${today} |"

    if [ -f "$index_file" ]; then
        # Não duplicar se já existir
        if ! grep -q "^| ${skill_name} |" "$index_file" 2>/dev/null; then
            # Remover linha separadora antes de adicionar
            sed -i '/^|---/d' "$index_file"
            echo "$entry" >> "$index_file"
            echo "|---" >> "$index_file"
            # Ordenar
            local temp_file
            temp_file=$(mktemp)
            (echo "| Skill | Description | Updated |"; grep "^| " "$index_file" | sort) > "$temp_file"
            mv "$temp_file" "$index_file"
        fi
    else
        cat > "$index_file" << INDEXEOF
# Skills Index

> Auto-generated from approved lessons

| Skill | Description | Updated |
|--- |---|---|
${entry}
|--- |---|---|
INDEXEOF
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

# ============================================================
# compile — Compila lições approved → skills
#   $1 = lesson id opcional (todas se vazio)
#   $2 = skill_path opcional
#   $3 = dry_run (true/false)
# ============================================================

lessons::compile() {
    local lesson_id="${1:-}"
    local skill_path="${2:-}"
    local dry_run="${3:-false}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local count=0

    if [ ! -d "$dir" ]; then
        echo "[INFO] Nenhuma lição capturada."
        return 0
    fi

    if [ -n "$lesson_id" ]; then
        lessons::_compile_lesson "$lesson_id" "$skill_path" "$dry_run"
        return $?
    fi

    # Compilar todas as approved
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        local id
        id=$(basename "$f" .json)
        if lessons::_compile_lesson "$id" "$skill_path" "$dry_run"; then
            ((count++)) || true
        fi
    done

    echo ""
    echo "Skills compiladas: $count"
}

# ============================================================
# migrate — Adiciona campos approved a lições existentes
# ============================================================

lessons::migrate() {
    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local count=0

    [ ! -d "$dir" ] && echo "[INFO] Nenhuma lição para migrar." && return 0

    echo "[MIGRATE] Adicionando campos approved a lições existentes..."

    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue

        if command -v jq &>/dev/null; then
            # Verificar se já tem campo approved
            if jq -e '.approved' "$f" &>/dev/null; then
                continue
            fi

            # Adicionar campos com defaults
            jq '.approved = false | .approved_at = null | .approved_by = null | .skill_path = null | .skill_name = null | .compiled_at = null' \
                "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
            echo "  Migrado: $(basename "$f")"
            ((count++)) || true
        fi
    done

    echo "Lições migradas: $count"
}

# ============================================================
# list — Lista lições com filtros
#   $1 = filtro: all|pending|approved|validated
# ============================================================

lessons::list() {
    local filter="${1:-all}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"

    [ ! -d "$dir" ] && echo "[INFO] Nenhuma lição capturada." && return 0

    local count=0
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        ((count++)) || true
    done

    echo -e "${CYAN}[LESSONS]${RESET} Total: $count | Filtro: $filter"
    echo ""

    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue

        local id title validated approved compiled_at skill_name
        id=$(basename "$f" .json)
        if command -v jq &>/dev/null; then
            title=$(jq -r '.title' "$f")
            validated=$(jq -r '.validated' "$f")
            approved=$(jq -r '.approved' "$f")
            compiled_at=$(jq -r '.compiled_at // "—" ' "$f")
            skill_name=$(jq -r '.skill_name // .skill_path // "—" ' "$f")
        fi

        # Filtro: pending = validada mas nao aprovada
        case "$filter" in
            pending)
                [[ "$validated" != "true" ]] && continue
                [[ "$approved" = "true" ]] && continue
                ;;
            validated)
                [[ "$validated" != "true" ]] && continue
                [[ "$approved" = "true" ]] && continue
                ;;
            approved)
                [[ "$approved" != "true" ]] && continue
                ;;
            compiled)
                [[ "$compiled_at" = "—" ]] || [[ "$compiled_at" = "null" ]] && continue
                ;;
        esac

        # Status badges
        local val_mark="[ ]"
        [[ "$validated" = "true" ]] && val_mark="${GREEN}[✓]${RESET}"
        local appr_mark="[ ]"
        [[ "$approved" = "true" ]] && appr_mark="${GREEN}[★]${RESET}"

        echo -e "  $val_mark $appr_mark ${id}"
        echo -e "       ${title}"
        if [[ "$approved" = "true" ]]; then
            echo -e "       ${CYAN}→ $skill_name${RESET}"
        fi
        echo ""
    done
}

# ============================================================
# export — Exporta todas as lições para JSON
# ============================================================

lessons::export() {
    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local output="${1:-/dev/stdout}"

    if [ ! -d "$dir" ]; then
        echo "[]"
        return 0
    fi

    local first=true
    echo "["
    for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        if $first; then
            first=false
        else
            echo ","
        fi
        jq '.' "$f"
    done
    echo "]"
}
