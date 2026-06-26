#!/usr/bin/env bash
# shellcheck disable=SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/lessons/sync.sh - DEVORQ Lessons SYNC module
#
# Modulo responsavel por:
#   lessons::sync_vps            - Sincronizar licao com VPS HUB
#   lessons::compile             - Compilar licoes approved -> skills
#   lessons::migrate             - Adicionar campos approved a licoes
#   lessons::_infer_skill        - Inferir skill por tags (helper)
#   lessons::_compile_lesson     - Compilar uma licao (helper)
#   lessons::_update_skill_index - Manter skills/.index.md (helper)
#
# Originalmente em lib/lessons.sh (Story 3 - dogfooding).
# Mantem 100% das assinaturas publicas: nenhuma chamada externa precisa mudar.

set -euo pipefail

# ============================================================

lessons::sync_vps() {
    local file="$1"
    # Infra via config/env, sem default hardcoded (DQ-011). Vazio => pula o sync.
    local vps_host="${DEVORQ_VPS_HOST:-}"
    local vps_port="${DEVORQ_VPS_PORT:-22}"
    local vps_user="${DEVORQ_VPS_USER:-}"
    local mux_sock="${DEVORQ_MUX_SOCK:-/tmp/devorq-ssh-mux}"
    [ -z "$vps_host" ] && return 0

    [ ! -f "$file" ] && echo "[ERROR] Arquivo não encontrado: $file" && return 1

    # Carrega lib/vps.sh se disponível para usar SSH mux
    local mux_lib="${DEVORQ_DIR:-.}"/lib/vps.sh
    if [ -f "$mux_lib" ]; then
        # shellcheck source=/dev/null
        source "$mux_lib"
        local safe_name
        safe_name=$(basename "$file" | tr -cd 'a-zA-Z0-9._-')
        vps::exec "mkdir -p ~/.devorq/lessons && cat > ~/.devorq/lessons/${safe_name}" < "$file"
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
            # Remover linha separadora antes de adicionar (portavel — DQ-029)
            devorq::sed_inplace '/^|---/d' "$index_file"
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
