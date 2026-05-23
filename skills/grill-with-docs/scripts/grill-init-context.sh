#!/usr/bin/env bash
# grill-init-context.sh — Fase 2: Gera template inicial de CONTEXT.md
#
# Uso: grill-init-context.sh <project_root> <intent>
#
# Comportamento:
#   - Extrai termos do INTENT, SPEC.md e código existente
#   - Gera template com [PLACEHOLDER] para cada termo não-resolvido
#   - NÃO escreve nada sem confirmação
#   - Output vai para stdout (não sobrepõe arquivos)
#
# Exit codes:
#   0 = Template gerado (vai para stdout)
#   1 = Erro (sem termos кандидатов, etc.)
#   2 = Usage error

set -uo pipefail

PROJECT_ROOT="${1:-}"
INTENT="${2:-}"

# Cores
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================
# Helpers
# ============================================================

usage() {
    echo "Uso: grill-init-context.sh <project_root> <intent>"
    echo ""
    echo "Gera template inicial de CONTEXT.md:"
    echo "  - Extrai termos do INTENT, SPEC.md e código"
    echo "  - Output vai para stdout (não sobrepõe nada)"
    echo "  - Use '>' para salvar: grill-init-context.sh ... > CONTEXT.md"
    exit 2
}

[ -z "$PROJECT_ROOT" ] || [ -z "$INTENT" ] && usage

# ============================================================
# 1. Detectar stack (para extrair termos relevantes)
# ============================================================

detect_stack() {
    local root="$1"
    if [ -f "$root/composer.json" ]; then
        echo "laravel"
    elif [ -f "$root/package.json" ]; then
        if grep -q '"react"' "$root/package.json" 2>/dev/null; then
            echo "react"
        else
            echo "node"
        fi
    elif [ -f "$root/go.mod" ]; then
        echo "go"
    elif [ -f "$root/requirements.txt" ] || [ -f "$root/pyproject.toml" ]; then
        echo "python"
    else
        echo "unknown"
    fi
}

# ============================================================
# 2. Extrair termos do INTENT
# ============================================================

extract_intent_terms() {
    local intent="$1"
    echo "$intent" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -s ' .,?!:;()[]{}' '\n' \
        | grep -vE "^(o|a|os|as|um|uma|é|foi|ser|ter|fazer|de|para|com|em|no|na|que|qual|qualquer|todo|toda|novo|nova|implementar|criar|adicionar|feature|módulo|sistema|projeto|parte|tela|página|botão|campo|input|form|usuario|usuário|usagers|pessoa)$" \
        | grep -vE "^[0-9]+$" \
        | grep -vE "^.{1,2}$" \
        | sort -u
}

# ============================================================
# 3. Extrair termos da SPEC.md
# ============================================================

extract_spec_terms() {
    local spec="$1"
    [ -f "$spec" ] || return

    # Extrai títulos de seções, ACs, nomes de entidades
    grep -E "^#{1,3}" "$spec" 2>/dev/null \
        | sed 's/^#*[[:space:]]*//' \
        | tr '[:upper:]' '[:lower:]' \
        | tr -s ' .,?!:;()[]{}' '\n' \
        | grep -vE "^(o|a|os|as|um|uma|é|foi|ser|ter|fazer|de|para|com|em|no|na|que|qual|qualquer|todo|toda|novo|nova|implementar|criar|adicionar|feature|módulo|sistema|projeto|parte|tela|página|botão|campo|input|form|acceptance|criteria|given|when|then|out of scope|stack|técnica|visão|arquitetura)$" \
        | grep -vE "^[0-9]+$" \
        | grep -vE "^.{1,2}$" \
        | sort -u
}

# ============================================================
# 4. Extrair termos do código (Models/tabelas para Laravel)
# ============================================================

extract_code_terms_laravel() {
    local root="$1"

    # Models do Laravel
    if [ -d "$root/app/Models" ]; then
        find "$root/app/Models" -name "*.php" -type f 2>/dev/null \
            | xargs -I{} basename {} .php 2>/dev/null \
            | sort -u
    fi

    # Tabelas do banco (se migrations existirem)
    if [ -d "$root/database/migrations" ]; then
        find "$root/database/migrations" -name "*.php" -type f 2>/dev/null \
            | xargs -I{} grep -h "Create" {} 2>/dev/null \
            | grep -oE "create_([a-z_]+)_table" \
            | sed 's/create_//; s/_table$//' \
            | sort -u
    fi
}

extract_code_terms_generic() {
    local root="$1"

    # Nomes de arquivos em src/ que parecem entidades
    if [ -d "$root/src" ]; then
        find "$root/src" -type f \( -name "*.php" -o -name "*.ts" -o -name "*.js" -o -name "*.go" \) 2>/dev/null \
            | xargs -I{} basename {} 2>/dev/null \
            | sed 's/\..*//' \
            | grep -vE "^(index|main|app|controller|service|repository|model|entity|repository|router|route|config|utils|helper|middleware)$" \
            | grep -vE "^[0-9]+" \
            | sort -u
    fi
}

# ============================================================
# 5. Unificar e deduplicar termos
# ============================================================

merge_terms() {
    local -a all_terms=()

    # Ler stdin (termos do INTENT)
    while IFS= read -r term; do
        [ -n "$term" ] && all_terms+=("$term")
    done

    # TERMOS do INTENT
    extract_intent_terms "$INTENT"

    # TERMOS da SPEC.md
    local spec="$PROJECT_ROOT/SPEC.md"
    [ -f "$spec" ] && extract_spec_terms "$spec"

    # TERMOS do código
    local stack
    stack=$(detect_stack "$PROJECT_ROOT")

    case "$stack" in
        laravel)
            extract_code_terms_laravel "$PROJECT_ROOT"
            ;;
        *)
            extract_code_terms_generic "$PROJECT_ROOT"
            ;;
    esac
}

# ============================================================
# 6. Gerar template
# ============================================================

generate_context_template() {
    local project_name
    project_name=$(basename "$PROJECT_ROOT")

    # Coletar todos os termos кандидатов
    local -a intent_terms=()
    while IFS= read -r term; do
        [ -n "$term" ] && intent_terms+=("$term")
    done < <(extract_intent_terms "$INTENT")

    local -a spec_terms=()
    local spec="$PROJECT_ROOT/SPEC.md"
    [ -f "$spec" ] && while IFS= read -r term; do
        [ -n "$term" ] && spec_terms+=("$term")
    done < <(extract_spec_terms "$spec")

    local -a code_terms=()
    local stack
    stack=$(detect_stack "$PROJECT_ROOT")
    case "$stack" in
        laravel)
            while IFS= read -r term; do
                [ -n "$term" ] && code_terms+=("$term")
            done < <(extract_code_terms_laravel "$PROJECT_ROOT")
            ;;
        *)
            while IFS= read -r term; do
                [ -n "$term" ] && code_terms+=("$term")
            done < <(extract_code_terms_generic "$PROJECT_ROOT")
            ;;
    esac

    # Header
    cat <<EOF
# $project_name — Context

Este documento define o glossário de domínio do projeto.
Cada termo representa um conceito específico do negócio, não uma implementação.

## Language

EOF

    # Termos do INTENT (alta prioridade — são o foco da tarefa atual)
    local -A seen_terms=()
    for term in "${intent_terms[@]}"; do
        [ -z "$term" ] && continue
        # Normalizar para display
        local display
        display=$(echo "$term" | sed 's/\b\(.\)/\U\1/g')
        echo "**$display**:"
        echo "[PLACEHOLDER: defina o que '$term' significa neste contexto]"
        echo "_Avoid_: "
        echo ""
        seen_terms["$term"]=1
    done

    # Termos da SPEC.md (se existir e forem diferentes)
    for term in "${spec_terms[@]}"; do
        [ -z "$term" ] && continue
        [ "${seen_terms[$term]:-}" = "1" ] && continue
        local display
        display=$(echo "$term" | sed 's/\b\(.\)/\U\1/g')
        echo "**$display**:"
        echo "[PLACEHOLDER: defina o que '$term' significa neste contexto]"
        echo "_Avoid_: "
        echo ""
        seen_terms["$term"]=1
    done

    # Termos do código (só se não duplicados)
    for term in "${code_terms[@]}"; do
        [ -z "$term" ] && continue
        [ "${seen_terms[$term]:-}" = "1" ] && continue
        local display
        display=$(echo "$term" | sed 's/\b\(.\)/\U\1/g')
        echo "**$display**:"
        echo "[PLACEHOLDER: defina o que '$term' significa — confirma se é entidade do domínio]"
        echo "_Avoid_: "
        echo ""
    done

    # Relationships
    cat <<EOF
## Relationships

[PLACEHOLDER: defina relationships entre os termos acima. Exemplo:]
- Um **TermoA** pertence a um **TermoB**
- Um **TermoA** produz um ou mais **TermoC**

## Flagged Ambiguities

[PLACEHOLDER: adicione termos que foram usados de forma ambígua. Exemplo:]
- "conta" foi usado para significar tanto **ContaCorrente** quanto **ContaPoupança** — resolvido: são conceitos distintos.

## Example Dialogue

[PLACEHOLDER: escreva uma conversa entre dev e domain expert que demonstra como os termos interagem]

## Notes

- Stack detectada: $stack
- Termos extraídos do intent: ${#intent_terms[@]}
- Termos extraídos da SPEC.md: ${#spec_terms[@]}
- Termos extraídos do código: ${#code_terms[@]}
EOF
}

# ============================================================
# Main
# ============================================================

# Verificar se já existe CONTEXT.md
if [ -f "$PROJECT_ROOT/CONTEXT.md" ]; then
    echo -e "${YELLOW}⚠${RESET} CONTEXT.md já existe em $PROJECT_ROOT"
    echo "  grill-init-context.sh não vai sobreescrever."
    echo ""
    echo "  Se quiser regenerar o template, remova o arquivo primeiro:"
    echo "    rm CONTEXT.md"
    echo ""
    echo "  Ou use grill-refine.sh para refinar o existente."
    exit 1
fi

# Verificar se tem alguma fonte de termos
_spec="$PROJECT_ROOT/SPEC.md"
_has_code=false
[ -d "$PROJECT_ROOT/src" ] || [ -d "$PROJECT_ROOT/app" ] && _has_code=true

if [ ! -f "$_spec" ] && ! $_has_code; then
    echo -e "${RED}✗${RESET} Nenhuma fonte de termos encontrada:"
    echo "  - SPEC.md não existe"
    echo "  - src/ ou app/ não existe"
    echo ""
    echo "  Gere manualmente com base no entendimento do domínio."
    exit 1
fi

# Gerar template
echo -e "${CYAN}Gerando template de CONTEXT.md...${RESET}"
echo ""
generate_context_template
echo ""

# Instruções
echo -e "${GREEN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}✓${RESET} Template gerado (vai para stdout)"
echo ""
echo "  Para salvar:"
echo "    grill-init-context.sh \"$PROJECT_ROOT\" \"$INTENT\" > CONTEXT.md"
echo ""
echo "  Próximo passo:"
echo "    1. Revise o template"
echo "    2. Execute: grill-refine.sh para refinar termos um por um"
echo "    3. Ou edite manualmente se preferir"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${RESET}"

exit 0
