#!/usr/bin/env bash
# skills/project-foundation/scripts/foundation-migrate.sh
#
# Migra informações de SPEC.md existente para os 5 foundation docs
# Uso: foundation-migrate.sh [--from-spec <spec_file>]
#
# Extrai:
# - Stack do SPEC.md → 5w2h.where.context
# - Descrição do SPEC.md → 5w2h.what.description
# - Features do SPEC.md → requisitos.json
# - Premissas implícitas → premissas.json

set -euo pipefail

SPEC_FILE="${2:-SPEC.md}"
FOUNDATION_DIR="${DEVORQ_FOUNDATION_DIR:-.devorq/state}"
PROJECT_NAME="${DEVORQ_PROJECT_NAME:-$(basename "$(pwd)")}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Cores
RED='' GREEN='' YELLOW='' CYAN='' RESET=''
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
fi

log()   { echo "[DEVORQ] $*"; }
info()  { echo -e "${CYAN}[INFO]${RESET} $*"; }
success(){ echo -e "${GREEN}[OK]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# Extrair título/descrição do SPEC.md
extract_spec_info() {
    if [ ! -f "$SPEC_FILE" ]; then
        error "SPEC.md não encontrado: $SPEC_FILE"
    fi

    # Extrair o primeiro H1 (# Título)
    local title
    title=$(grep -m1 '^# ' "$SPEC_FILE" 2>/dev/null | sed 's/^# //' | tr -d '\n' || echo "")

    # Extrair primeira frase após o título (descrição)
    local desc
    desc=$(awk '/^# /{found=1; next} found && NF{print; exit}' "$SPEC_FILE" 2>/dev/null | head -1 | tr -d '\n' || echo "")

    echo "$title|$desc"
}

# Extrair stack do SPEC.md (procura PHP, Laravel, etc)
extract_stack() {
    local stack_items=()

    if grep -qi 'laravel' "$SPEC_FILE" 2>/dev/null; then
        stack_items+=("Laravel")
    fi
    if grep -qi 'livewire' "$SPEC_FILE" 2>/dev/null; then
        stack_items+=("Livewire")
    fi
    if grep -qi 'tailwind' "$SPEC_FILE" 2>/dev/null; then
        stack_items+=("Tailwind CSS")
    fi
    if grep -qi 'filament' "$SPEC_FILE" 2>/dev/null; then
        stack_items+=("Filament")
    fi
    if grep -qi 'bash' "$SPEC_FILE" 2>/dev/null; then
        stack_items+=("Bash")
    fi
    if grep -qi 'postgresql\|postgres' "$SPEC_FILE" 2>/dev/null; then
        stack_items+=("PostgreSQL")
    fi
    if grep -qi 'docker' "$SPEC_FILE" 2>/dev/null; then
        stack_items+=("Docker")
    fi

    if [ ${#stack_items[@]} -eq 0 ]; then
        echo "Não detectado"
    else
        IFS=,; echo "${stack_config[*]}"
    fi
}

# Gerar 5w2h a partir do SPEC.md
migrate_5w2h() {
    local spec_info
    spec_info=$(extract_spec_info)
    local title="${spec_info%%|*}"
    local desc="${spec_info#*|}"

    local stack
    stack=$(extract_stack)

    local out="${FOUNDATION_DIR}/5w2h.json"

    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$PROJECT_NAME" \
            --arg ts "$TIMESTAMP" \
            --arg title "$title" \
            --arg desc "$desc" \
            --arg stack "$stack" \
            '{
                project: $project,
                created_at: $ts,
                updated_at: $ts,
                what: {
                    description: ($title + ". " + $desc),
                    examples: []
                },
                why: {
                    description: "Extraído do SPEC.md — motivo não especificado",
                    business_value: ""
                },
                who: {
                    description: "Extraído do SPEC.md — público-alvo não especificado",
                    stakeholders: []
                },
                when: {
                    description: "Projeto atual",
                    timeline: ""
                },
                where: {
                    description: $stack,
                    context: $stack
                },
                how: {
                    description: "A ser definido",
                    approach: ""
                },
                how_much: {
                    description: "A ser estimado",
                    estimated_effort: ""
                }
            }' > "$out"
    else
        cat > "$out" <<JSONEOF
{
  "project": "$PROJECT_NAME",
  "created_at": "$TIMESTAMP",
  "updated_at": "$TIMESTAMP",
  "what": {
    "description": "${title}. ${desc}",
    "examples": []
  },
  "why": {
    "description": "Extraído do SPEC.md — motivo não especificado",
    "business_value": ""
  },
  "who": {
    "description": "Extraído do SPEC.md — público-alvo não especificado",
    "stakeholders": []
  },
  "when": {
    "description": "Projeto atual",
    "timeline": ""
  },
  "where": {
    "description": "${stack}",
    "context": "${stack}"
  },
  "how": {
    "description": "A ser definido",
    "approach": ""
  },
  "how_much": {
    "description": "A ser estimado",
    "estimated_effort": ""
  }
}
JSONEOF
    fi

    success "5w2h.json migrado do SPEC.md"
}

# Gerar premissas padrão
migrate_premissas() {
    local out="${FOUNDATION_DIR}/premissas.json"

    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$PROJECT_NAME" \
            --arg ts "$TIMESTAMP" \
            '{
                project: $project,
                created_at: $ts,
                premissas: [
                    {
                        id: "PRE-001",
                        description: "O usuário tem as dependências necesarias instaladas (PHP, Composer, Node, etc)",
                        owner: "",
                        validated: false,
                        validated_at: null,
                        notes: "Verificar no ambiente antes de iniciar"
                    },
                    {
                        id: "PRE-002",
                        description: "O projeto usa Git para controle de versão",
                        owner: "",
                        validated: false,
                        validated_at: null,
                        notes: ""
                    },
                    {
                        id: "PRE-003",
                        description: "As configurações de ambiente (.env) estão disponíveis",
                        owner: "",
                        validated: false,
                        validated_at: null,
                        notes: ""
                    }
                ]
            }' > "$out"
    else
        cat > "$out" <<'JSONEOF'
{
  "project": "MIGRADO",
  "created_at": "TIMESTAMP",
  "premissas": [
    {
      "id": "PRE-001",
      "description": "O usuário tem as dependências necesarias instaladas (PHP, Composer, Node, etc)",
      "owner": "",
      "validated": false,
      "validated_at": null,
      "notes": "Verificar no ambiente antes de iniciar"
    },
    {
      "id": "PRE-002",
      "description": "O projeto usa Git para controle de versão",
      "owner": "",
      "validated": false,
      "validated_at": null,
      "notes": ""
    },
    {
      "id": "PRE-003",
      "description": "As configurações de ambiente (.env) estão disponíveis",
      "owner": "",
      "validated": false,
      "validated_at": null,
      "notes": ""
    }
  ]
}
JSONEOF
    fi

    success "premissas.json criado com premissas padrão"
}

# Gerar riscos vazios
migrate_riscos() {
    local out="${FOUNDATION_DIR}/riscos.json"

    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$PROJECT_NAME" \
            --arg ts "$TIMESTAMP" \
            '{
                project: $project,
                created_at: $ts,
                riscos: [
                    {
                        id: "RISK-001",
                        description: "A ser identificado durante o desenvolvimento",
                        severity: "MEDIUM",
                        probability: "MEDIUM",
                        impact: "MEDIUM",
                        mitigation: "Revisar riscos a cada gate",
                        contingency: "",
                        status: "OPEN"
                    }
                ]
            }' > "$out"
    else
        cat > "$out" <<'JSONEOF'
{
  "project": "MIGRADO",
  "created_at": "TIMESTAMP",
  "riscos": [
    {
      "id": "RISK-001",
      "description": "A ser identificado durante o desenvolvimento",
      "severity": "MEDIUM",
      "probability": "MEDIUM",
      "impact": "MEDIUM",
      "mitigation": "Revisar riscos a cada gate",
      "contingency": "",
      "status": "OPEN"
    }
  ]
}
JSONEOF
    fi

    success "riscos.json criado com template"
}

# Gerar requisitos a partir do SPEC.md
migrate_requisitos() {
    local out="${FOUNDATION_DIR}/requisitos.json"

    # Tentar extrair features/requisitos do SPEC.md
    local reqs=()
    local id=1

    # Procurar seções de features
    while IFS= read -r line; do
        local req_title
        req_title=$(echo "$line" | sed 's/^##* //' | tr -d '\n' | cut -c1-80)
        if [ -n "$req_title" ] && [ ${#req_title} -gt 3 ]; then
            if command -v jq &>/dev/null; then
                local req_json
                req_json=$(jq -n --arg id "REQ-$(printf '%03d' $id)" --arg title "$req_title" '{
                    id: $id,
                    type: "FUNCTIONAL",
                    title: $title,
                    description: "Extraído do SPEC.md",
                    acceptance_criteria: [],
                    priority: "SHOULD",
                    source: "SPEC.md migration",
                    status: "DRAFT"
                }')
                reqs+=("$req_json")
            fi
            id=$((id + 1))
        fi
    done < <(grep -E '^##? ' "$SPEC_FILE" 2>/dev/null | head -10)

    if [ ${#reqs[@]} -eq 0 ]; then
        # Fallback: requisito genérico
        if command -v jq &>/dev/null; then
            jq -n \
                --arg project "$PROJECT_NAME" \
                --arg ts "$TIMESTAMP" \
                '{
                    project: $project,
                    created_at: $ts,
                    version: "1.0.0",
                    requisitos: [
                        {
                            id: "REQ-001",
                            type: "FUNCTIONAL",
                            title: "Requisito migrado do SPEC.md",
                            description: "A ser detalhado",
                            acceptance_criteria: [],
                            priority: "MUST",
                            source: "SPEC.md migration",
                            status: "DRAFT"
                        }
                    ]
                }' > "$out"
        else
            cat > "$out" <<'JSONEOF'
{
  "project": "MIGRADO",
  "created_at": "TIMESTAMP",
  "version": "1.0.0",
  "requisitos": [
    {
      "id": "REQ-001",
      "type": "FUNCTIONAL",
      "title": "Requisito migrado do SPEC.md",
      "description": "A ser detalhado",
      "acceptance_criteria": [],
      "priority": "MUST",
      "source": "SPEC.md migration",
      "status": "DRAFT"
    }
  ]
}
JSONEOF
        fi
    else
        if command -v jq &>/dev/null; then
            local arr_json
            arr_json=$(printf '%s\n' "${reqs[@]}" | jq -s '.')
            jq -n \
                --arg project "$PROJECT_NAME" \
                --arg ts "$TIMESTAMP" \
                --argjson arr "$arr_json" \
                '{ project: $project, created_at: $ts, version: "1.0.0", requisitos: $arr }' > "$out"
        fi
    fi

    success "requisitos.json criado (${#reqs[@]} extraído(s) do SPEC.md)"
}

# Gerar restrições vazias
migrate_restricoes() {
    local out="${FOUNDATION_DIR}/restricoes.json"

    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$PROJECT_NAME" \
            --arg ts "$TIMESTAMP" \
            '{
                project: $project,
                created_at: $ts,
                restricoes: [
                    {
                        id: "CONST-001",
                        type: "TECHNICAL",
                        description: "Stack definida no SPEC.md",
                        source: "SPEC.md",
                        flexibility: "FIXED",
                        validated: false
                    }
                ]
            }' > "$out"
    else
        cat > "$out" <<'JSONEOF'
{
  "project": "MIGRADO",
  "created_at": "TIMESTAMP",
  "restricoes": [
    {
      "id": "CONST-001",
      "type": "TECHNICAL",
      "description": "Stack definida no SPEC.md",
      "source": "SPEC.md",
      "flexibility": "FIXED",
      "validated": false
    }
  ]
}
JSONEOF
    fi

    success "restricoes.json criado com template"
}

# Main
main() {
    mkdir -p "${FOUNDATION_DIR}"

    info "DEVORQ Foundation Migration"
    info "De: ${SPEC_FILE}"
    info "Para: ${FOUNDATION_DIR}"
    echo ""

    migrate_5w2h
    migrate_premissas
    migrate_riscos
    migrate_requisitos
    migrate_restricoes

    echo ""
    info "Migração completa!"
    info "Execute: devorq foundation validate"
    info "Depois edite cada doc para completar as informações"
}

main "$@"
