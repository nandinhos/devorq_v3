#!/usr/bin/env bash
# skills/project-foundation/scripts/foundation-wizard.sh
#
# Assistente interativo para criar os 5 foundation docs
# Uso: foundation-wizard.sh [--doc 5w2h|premissas|riscos|requisitos|restricoes]
#
# Se --doc não for passado, cria todos

set -euo pipefail

MODE="${1:-all}"
FOUNDATION_DIR="${DEVORQ_FOUNDATION_DIR:-.devorq/state}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

# Pergunta interativa
ask() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if [ -n "$default" ]; then
        read -p "$(echo -e "${CYAN}[?]${RESET} ${prompt} [${default}]: ")" result
        result="${result:-$default}"
    else
        read -p "$(echo -e "${CYAN}[?]${RESET} ${prompt}: ")" result
    fi

    echo "$result"
}

# Ask com múltiplas linhas (para arrays)
ask_array() {
    local prompt="$1"
    local var_name="$2"
    local -n arr="$var_name"

    echo ""
    echo -e "${CYAN}--- ${prompt} ---${RESET}"
    echo -e "${YELLOW}(Enter vazio para finalizar lista)${RESET}"
    echo ""

    local item
    while true; do
        read -p "$(echo -e "${CYAN}[+]${RESET} Item: ")" item
        if [ -z "$item" ]; then
            break
        fi
        arr+=("$item")
    done
}

# Inicializar wizard para 5W2H
wizard_5w2h() {
    info "Wizard: 5W2H"
    echo ""

    local project_name
    project_name=$(ask "Nome do projeto" "$(basename "$(pwd)")")

    local what_desc what_ex
    echo ""
    what_desc=$(ask "WHAT — O que este projeto é?")
    echo -e "${CYAN}---${RESET}"
    what_ex=$(ask "Exemplos (separados por vírgula)")

    local why_desc why_value
    echo ""
    why_desc=$(ask "WHY — Por que este projeto existe?")
    why_value=$(ask "Valor de negócio")

    local who_desc who_stake
    echo ""
    who_desc=$(ask "WHO — Para quem é este projeto?")
    echo -e "${CYAN}---${RESET}"
    read -p "$(echo -e "${CYAN}[+]${RESET} Stakeholders (Enter para finalizar): ")" who_stake

    local when_desc when_timeline
    echo ""
    when_desc=$(ask "WHEN — Quando é relevante?")
    when_timeline=$(ask "Timeline (ex: Q2 2026)")

    local where_desc where_context
    echo ""
    where_desc=$(ask "WHERE — Onde se insere?")
    where_context=$(ask "Stack/Contexto técnico")

    local how_desc how_approach
    echo ""
    how_desc=$(ask "HOW — Como será construído?")
    how_approach=$(ask "Abordagem metodológica")

    local how_much_desc how_effort
    echo ""
    how_much_desc=$(ask "HOW MUCH — Quanto custa/esforço?")
    how_effort=$(ask "Estimativa de esforço")

    # Converter vírgulas em array JSON
    local examples_json="[]"
    if [ -n "$what_ex" ]; then
        examples_json=$(echo "$what_ex" | jq -R 'split(",")' 2>/dev/null || echo "[\"$what_ex\"]")
    fi

    local stakeholders_json="[]"
    if [ -n "$who_stake" ]; then
        stakeholders_json=$(echo "$who_stake" | jq -R 'split(",")' 2>/dev/null || echo "[\"$who_stake\"]")
    fi

    # Gerar JSON
    local out="${FOUNDATION_DIR}/5w2h.json"

    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$project_name" \
            --arg ts "$TIMESTAMP" \
            --arg what_desc "$what_desc" \
            --argjson what_ex "$examples_json" \
            --arg why_desc "$why_desc" \
            --arg why_value "$why_value" \
            --arg who_desc "$who_desc" \
            --argjson who_stake "$stakeholders_json" \
            --arg when_desc "$when_desc" \
            --arg when_timeline "$when_timeline" \
            --arg where_desc "$where_desc" \
            --arg where_ctx "$where_context" \
            --arg how_desc "$how_desc" \
            --arg how_approach "$how_approach" \
            --arg how_much_desc "$how_much_desc" \
            --arg how_effort "$how_effort" \
            '{
                project: $project,
                created_at: $ts,
                updated_at: $ts,
                what: { description: $what_desc, examples: $what_ex },
                why: { description: $why_desc, business_value: $why_value },
                who: { description: $who_desc, stakeholders: $who_stake },
                when: { description: $when_desc, timeline: $when_timeline },
                where: { description: $where_desc, context: $where_ctx },
                how: { description: $how_desc, approach: $how_approach },
                how_much: { description: $how_much_desc, estimated_effort: $how_effort }
            }' > "$out"
    else
        # Fallback sem jq
        cat > "$out" <<JSONEOF
{
  "project": "$project_name",
  "created_at": "$TIMESTAMP",
  "updated_at": "$TIMESTAMP",
  "what": {
    "description": "$what_desc",
    "examples": $examples_json
  },
  "why": {
    "description": "$why_desc",
    "business_value": "$why_value"
  },
  "who": {
    "description": "$who_desc",
    "stakeholders": $stakeholders_json
  },
  "when": {
    "description": "$when_desc",
    "timeline": "$when_timeline"
  },
  "where": {
    "description": "$where_desc",
    "context": "$where_context"
  },
  "how": {
    "description": "$how_desc",
    "approach": "$how_approach"
  },
  "how_much": {
    "description": "$how_much_desc",
    "estimated_effort": "$how_effort"
  }
}
JSONEOF
    fi

    success "5w2h.json criado"
}

# Wizard para premissas
wizard_premissas() {
    info "Wizard: Premissas"
    echo ""

    local project_name
    project_name=$(ask "Nome do projeto" "$(basename "$(pwd)")")

    local -a premissas=()
    echo ""
    echo -e "${CYAN}--- Premissas ---${RESET}"
    echo -e "${YELLOW}(Enter vazio para finalizar lista)${RESET}"
    echo ""

    local item owner
    local id=1
    while true; do
        read -p "$(echo -e "${CYAN}[+]${RESET} Premissa: ")" item
        [ -z "$item" ] && break

        read -p "$(echo -e "${CYAN}[+]${RESET}   Owner (opcional): ")" owner

        local pre_json
        if command -v jq &>/dev/null; then
            pre_json=$(jq -n \
                --arg id "PRE-$(printf '%03d' $id)" \
                --arg desc "$item" \
                --arg own "$owner" \
                '{
                    id: $id,
                    description: $desc,
                    owner: $own,
                    validated: false,
                    validated_at: null,
                    notes: ""
                }')
        else
            pre_json="{\"id\":\"PRE-$(printf '%03d' $id)\",\"description\":\"$item\",\"owner\":\"$owner\",\"validated\":false,\"validated_at\":null,\"notes\":\"\"}"
        fi
        premissas+=("$pre_json")
        id=$((id + 1))
    done

    if [ ${#premissas[@]} -eq 0 ]; then
        warn "Nenhuma premissa adicionada"
        return
    fi

    local arr_json
    if command -v jq &>/dev/null; then
        arr_json=$(printf '%s\n' "${premissas[@]}" | jq -s '.')
    else
        arr_json=$(IFS=,; echo "[${premissas[*]}]")
    fi

    local out="${FOUNDATION_DIR}/premissas.json"
    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$project_name" \
            --arg ts "$TIMESTAMP" \
            --argjson arr "$arr_json" \
            '{ project: $project, created_at: $ts, premissas: $arr }' > "$out"
    else
        cat > "$out" <<JSONEOF
{
  "project": "$project_name",
  "created_at": "$TIMESTAMP",
  "premissas": $arr_json
}
JSONEOF
    fi

    success "premissas.json criado com ${#premissas[@]} premissa(s)"
}

# Wizard para riscos
wizard_riscos() {
    info "Wizard: Riscos"
    echo ""

    local project_name
    project_name=$(ask "Nome do projeto" "$(basename "$(pwd)")")

    local -a riscos=()
    local -a severities=("LOW" "MEDIUM" "HIGH" "CRITICAL")
    local -a statuses=("OPEN" "MITIGATED" "ACCEPTED" "CLOSED")

    echo ""
    echo -e "${CYAN}--- Riscos ---${RESET}"
    echo -e "${YELLOW}(Enter vazio para finalizar lista)${RESET}"
    echo ""

    local item severity probability impact mitigation contingency status
    local id=1
    while true; do
        echo -e "${CYAN}[+] Risco #${id}${RESET}"
        read -p "  Descrição: " item
        [ -z "$item" ] && break

        echo "  Severity: $(IFS=,; echo "${severities[*]}")"
        read -p "  Severity [MEDIUM]: " severity
        severity="${severity:-MEDIUM}"

        echo "  Probability: $(IFS=,; echo "${severities[*]}")"
        read -p "  Probability [MEDIUM]: " probability
        probability="${probability:-MEDIUM}"

        echo "  Impact: $(IFS=,; echo "${severities[*]}")"
        read -p "  Impact [MEDIUM]: " impact
        impact="${impact:-MEDIUM}"

        read -p "  Mitigação: " mitigation
        read -p "  Contingency (plano B): " contingency
        echo "  Status: $(IFS=,; echo "${statuses[*]}")"
        read -p "  Status [OPEN]: " status
        status="${status:-OPEN}"

        local risk_json
        if command -v jq &>/dev/null; then
            risk_json=$(jq -n \
                --arg id "RISK-$(printf '%03d' $id)" \
                --arg desc "$item" \
                --arg sev "$severity" \
                --arg prob "$probability" \
                --arg imp "$impact" \
                --arg mit "$mitigation" \
                --arg cont "$contingency" \
                --arg stat "$status" \
                '{
                    id: $id,
                    description: $desc,
                    severity: $sev,
                    probability: $prob,
                    impact: $imp,
                    mitigation: $mit,
                    contingency: $cont,
                    status: $stat
                }')
        else
            risk_json="{\"id\":\"RISK-$(printf '%03d' $id)\",\"description\":\"$item\",\"severity\":\"$severity\",\"probability\":\"$probability\",\"impact\":\"$impact\",\"mitigation\":\"$mitigation\",\"contingency\":\"$contingency\",\"status\":\"$status\"}"
        fi
        riscos+=("$risk_json")
        id=$((id + 1))
    done

    if [ ${#riscos[@]} -eq 0 ]; then
        warn "Nenhum risco adicionado"
        return
    fi

    local arr_json
    if command -v jq &>/dev/null; then
        arr_json=$(printf '%s\n' "${riscos[@]}" | jq -s '.')
    else
        arr_json=$(IFS=,; echo "[${riscos[*]}]")
    fi

    local out="${FOUNDATION_DIR}/riscos.json"
    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$project_name" \
            --arg ts "$TIMESTAMP" \
            --argjson arr "$arr_json" \
            '{ project: $project, created_at: $ts, riscos: $arr }' > "$out"
    else
        cat > "$out" <<JSONEOF
{
  "project": "$project_name",
  "created_at": "$TIMESTAMP",
  "riscos": $arr_json
}
JSONEOF
    fi

    success "riscos.json criado com ${#riscos[@]} risco(s)"
}

# Wizard para requisitos
wizard_requisitos() {
    info "Wizard: Requisitos"
    echo ""

    local project_name
    project_name=$(ask "Nome do projeto" "$(basename "$(pwd)")")

    local -a requisitos=()
    local -a types=("FUNCTIONAL" "NON_FUNCTIONAL" "BUSINESS" "REGULATORY")
    local -a priorities=("MUST" "SHOULD" "COULD" "WONT")
    local -a req_statuses=("DRAFT" "APPROVED" "IMPLEMENTED" "VERIFIED")

    echo ""
    echo -e "${CYAN}--- Requisitos ---${RESET}"
    echo -e "${YELLOW}(Enter vazio para finalizar lista)${RESET}"
    echo ""

    local title desc type priority source status
    local -a criteria=()
    local id=1
    while true; do
        echo -e "${CYAN}[+] Requisito #${id}${RESET}"
        read -p "  Título: " title
        [ -z "$title" ] && break

        read -p "  Descrição: " desc

        echo "  Tipo: $(IFS=,; echo "${types[*]}")"
        read -p "  Tipo [FUNCTIONAL]: " type
        type="${type:-FUNCTIONAL}"

        echo "  Prioridade: $(IFS=,; echo "${priorities[*]}")"
        read -p "  Prioridade [MUST]: " priority
        priority="${priority:-MUST}"

        read -p "  Source: " source

        echo "  Status: $(IFS=,; echo "${req_statuses[*]}")"
        read -p "  Status [DRAFT]: " status
        status="${status:-DRAFT}"

        echo ""
        echo -e "${YELLOW}  Acceptance Criteria (Enter vazio para finalizar)${RESET}"
        criteria=()
        local crit
        while true; do
            read -p "    Critério: " crit
            [ -z "$crit" ] && break
            criteria+=("$crit")
        done

        local criteria_json="[]"
        if [ ${#criteria[@]} -gt 0 ]; then
            if command -v jq &>/dev/null; then
                criteria_json=$(printf '%s\n' "${criteria[@]}" | jq -R . | jq -s .)
            else
                criteria_json=$(IFS=,; echo "[\"${criteria[*]}\"]")
            fi
        fi

        local req_json
        if command -v jq &>/dev/null; then
            req_json=$(jq -n \
                --arg id "REQ-$(printf '%03d' $id)" \
                --arg title "$title" \
                --arg desc "$desc" \
                --arg type "$type" \
                --arg priority "$priority" \
                --arg source "$source" \
                --arg status "$status" \
                --argjson criteria "$criteria_json" \
                '{
                    id: $id,
                    type: $type,
                    title: $title,
                    description: $desc,
                    acceptance_criteria: $criteria,
                    priority: $priority,
                    source: $source,
                    status: $status
                }')
        else
            req_json="{\"id\":\"REQ-$(printf '%03d' $id)\",\"type\":\"$type\",\"title\":\"$title\",\"description\":\"$desc\",\"acceptance_criteria\":$criteria_json,\"priority\":\"$priority\",\"source\":\"$source\",\"status\":\"$status\"}"
        fi
        requisitos+=("$req_json")
        id=$((id + 1))
    done

    if [ ${#requisitos[@]} -eq 0 ]; then
        warn "Nenhum requisito adicionado"
        return
    fi

    local arr_json
    if command -v jq &>/dev/null; then
        arr_json=$(printf '%s\n' "${requisitos[@]}" | jq -s '.')
    else
        arr_json=$(IFS=,; echo "[${requisitos[*]}]")
    fi

    local out="${FOUNDATION_DIR}/requisitos.json"
    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$project_name" \
            --arg ts "$TIMESTAMP" \
            --argjson arr "$arr_json" \
            '{ project: $project, created_at: $ts, version: "1.0.0", requisitos: $arr }' > "$out"
    else
        cat > "$out" <<JSONEOF
{
  "project": "$project_name",
  "created_at": "$TIMESTAMP",
  "version": "1.0.0",
  "requisitos": $arr_json
}
JSONEOF
    fi

    success "requisitos.json criado com ${#requisitos[@]} requisito(s)"
}

# Wizard para restrições
wizard_restricoes() {
    info "Wizard: Restrições"
    echo ""

    local project_name
    project_name=$(ask "Nome do projeto" "$(basename "$(pwd)")")

    local -a restricoes=()
    local -a types=("TECHNICAL" "BUDGET" "TIME" "SCOPE" "QUALITY" "REGULATORY")
    local -a flexibilities=("FIXED" "FLEXIBLE")

    echo ""
    echo -e "${CYAN}--- Restrições ---${RESET}"
    echo -e "${YELLOW}(Enter vazio para finalizar lista)${RESET}"
    echo ""

    local desc type source flexibility
    local id=1
    while true; do
        echo -e "${CYAN}[+] Restrição #${id}${RESET}"
        read -p "  Descrição: " desc
        [ -z "$desc" ] && break

        echo "  Tipo: $(IFS=,; echo "${types[*]}")"
        read -p "  Tipo [TECHNICAL]: " type
        type="${type:-TECHNICAL}"

        read -p "  Source/Origem: " source

        echo "  Flexibilidade: $(IFS=,; echo "${flexibilities[*]}")"
        read -p "  Flexibilidade [FIXED]: " flexibility
        flexibility="${flexibility:-FIXED}"

        local rest_json
        if command -v jq &>/dev/null; then
            rest_json=$(jq -n \
                --arg id "CONST-$(printf '%03d' $id)" \
                --arg type "$type" \
                --arg desc "$desc" \
                --arg source "$source" \
                --arg flex "$flexibility" \
                '{
                    id: $id,
                    type: $type,
                    description: $desc,
                    source: $source,
                    flexibility: $flex,
                    validated: false
                }')
        else
            rest_json="{\"id\":\"CONST-$(printf '%03d' $id)\",\"type\":\"$type\",\"description\":\"$desc\",\"source\":\"$source\",\"flexibility\":\"$flexibility\",\"validated\":false}"
        fi
        restricoes+=("$rest_json")
        id=$((id + 1))
    done

    if [ ${#restricoes[@]} -eq 0 ]; then
        warn "Nenhuma restrição adicionada"
        return
    fi

    local arr_json
    if command -v jq &>/dev/null; then
        arr_json=$(printf '%s\n' "${restricoes[@]}" | jq -s '.')
    else
        arr_json=$(IFS=,; echo "[${restricoes[*]}]")
    fi

    local out="${FOUNDATION_DIR}/restricoes.json"
    if command -v jq &>/dev/null; then
        jq -n \
            --arg project "$project_name" \
            --arg ts "$TIMESTAMP" \
            --argjson arr "$arr_json" \
            '{ project: $project, created_at: $ts, restricoes: $arr }' > "$out"
    else
        cat > "$out" <<JSONEOF
{
  "project": "$project_name",
  "created_at": "$TIMESTAMP",
  "restricoes": $arr_json
}
JSONEOF
    fi

    success "restricoes.json criado com ${#restricoes[@]} restrição(ões)"
}

# Main
main() {
    mkdir -p "${FOUNDATION_DIR}"

    info "DEVORQ Foundation Wizard"
    echo ""

    case "$MODE" in
        5w2h)
            wizard_5w2h
            ;;
        premissas)
            wizard_premissas
            ;;
        riscos)
            wizard_riscos
            ;;
        requisitos)
            wizard_requisitos
            ;;
        restricoes)
            wizard_restricoes
            ;;
        all)
            wizard_5w2h
            echo ""
            wizard_premissas
            echo ""
            wizard_riscos
            echo ""
            wizard_requisitos
            echo ""
            wizard_restricoes
            echo ""
            info "Todos os foundation docs criados!"
            info "Execute: devorq foundation validate"
            ;;
        *)
            error "Modo inválido: $MODE"
            error "Use: 5w2h | premissas | riscos | requisitos | restricoes | all"
            ;;
    esac
}

main "$@"
