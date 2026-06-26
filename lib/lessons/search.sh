#!/usr/bin/env bash
# shellcheck disable=SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/lessons/search.sh - DEVORQ Lessons SEARCH module
# Funcoes: approve, help (split de lib/lessons.sh em v3.8.5)
# Story 3 - dogfooding. Refatorado de lib/lessons.sh (1045 LOC).

set -euo pipefail

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

    # Verificar se foi validada (modo auto interno ou --force bypassam)
    local force=false
    [[ "${2:-}" == "--force" || "${3:-}" == "--force" ]] && force=true
    if [[ "$auto" != "true" && "$force" != "true" ]] && command -v jq &>/dev/null; then
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
        # Fallback sed para campos approved (portavel — DQ-029)
        devorq::sed_inplace \
            "s/\"validated\": true/\"validated\": true, \"approved\": true, \"approved_at\": \"$ts\", \"approved_by\": \"user\", \"skill_path\": \"$skill_path\"/" \
            "$file"
    fi

    echo -e "${GREEN}[✓]${RESET} Aprovada: $id → $skill_path"
}

# ============================================================
# help — Texto de ajuda dos comandos de lessons
# ============================================================

lessons::help() {
    cat << 'HELPEOF'
DEVORQ Lessons — Comandos de Lições Aprendidas

Uso: devorq lessons <comando> [args...]

Comandos:
  capture "<título>" "<problema>" "<solução>"
                  Capturar uma nova lição aprendida
  
  list [filtro]   Listar lições
    all           Todas (default)
    approved      Apenas aprovadas
    pending       Pendentes
  
  search "<query>"  Buscar lições por texto
  
  validate [--auto]  Validar lições com Context7
  
  approve <id> [skill] [--force]
                  Aprovar lição para compilação
  
  compile [id] [--dry-run]
                  Compilar lições aprovadas em skills
  
  migrate         Migrar lições existentes

Exemplos:
  devorq lessons capture "Título" "Problema" "Solução"
  devorq lessons list approved
  devorq lessons search "bash"
  devorq lessons approve lesson_20260521_123456
  devorq lessons compile --dry-run
HELPEOF
}
