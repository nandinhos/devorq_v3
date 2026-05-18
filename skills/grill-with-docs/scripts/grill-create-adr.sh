#!/usr/bin/env bash
# grill-create-adr.sh — Fase 4: Cria ADR com numeração automática
#
# Uso: grill-create-adr.sh <project_root> <title> <content> [--status proposed|accepted|deprecated]
#
# Numeração: scan docs/adr/ → highest 000N → next = 000(N+1)
# Formato:   000N-slug.md (slug = title em kebab-case)
#
# Exit codes:
#   0 = ADR criado com sucesso
#   1 = Erro
#   2 = Usage error

set -uo pipefail

PROJECT_ROOT="${1:-}"
TITLE="${2:-}"
CONTENT="${3:-}"
STATUS="${4:-}"

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
    echo "Uso: grill-create-adr.sh <project_root> <title> <content> [--status <status>]"
    echo ""
    echo "Cria ADR com numeração automática:"
    echo "  - Scan docs/adr/ → highest 000N → next = 000(N+1)"
    echo "  - Formato: 000N-slug.md"
    echo ""
    echo "Arguments:"
    echo "  project_root    Diretório raiz do projeto"
    echo "  title           Título da decisão (curto)"
    echo "  content         1-3 parágrafos: contexto, decisão, por quê"
    echo "  --status        Opcional: proposed | accepted | deprecated (default: não inclui)"
    echo ""
    echo "Exit codes:"
    echo "  0 = ADR criado com sucesso"
    echo "  1 = Erro (diretório não pode ser criado, etc.)"
    echo "  2 = Usage error (faltam argumentos)"
    exit 2
}

slugify() {
    # Converte título em slug: kebab-case, lowercase
    echo "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | tr 'áàãâäéèêëíìîïóòõôöúùûüç' 'aaaaaeeeeiiiiooooouuuuc' \
        | tr -s ' .,?!:;()[]{}' '-' \
        | tr -d "'\"„""''" \
        | tr -s '-' \
        | sed 's/^-+//; s/-+$//' \
        | tr -c 'a-z0-9-' '\n' \
        | tr '\n' '-' \
        | sed 's/-$//'
}

find_highest_adr_number() {
    local adr_dir="$1"
    local highest=0

    if [ ! -d "$adr_dir" ]; then
        echo "0"
        return
    fi

    for f in "$adr_dir"/[0-9][0-9][0-9][0-9]-*.md; do
        [ -f "$f" ] || continue
        local num
        num=$(basename "$f" | grep -oE "^[0-9]+" | head -1)
        if [ -n "$num" ] && [ "$num" -gt "$highest" ]; then
            highest="$num"
        fi
    done

    echo "$highest"
}

# ============================================================
# Validate
# ============================================================

[ -z "$PROJECT_ROOT" ] && usage
[ -z "$TITLE" ] && usage
[ -z "$CONTENT" ] && usage

if [ "$STATUS" = "--status" ]; then
    STATUS="$5"
fi

# Validar status se fornecido
if [ -n "$STATUS" ] && [[ ! "$STATUS" =~ ^(proposed|accepted|deprecated)$ ]]; then
    echo -e "${RED}✗${RESET} Status inválido: $STATUS"
    echo "  Use: proposed | accepted | deprecated"
    exit 2
fi

# ============================================================
# Setup
# ============================================================

ADR_DIR="$PROJECT_ROOT/docs/adr"
mkdir -p "$ADR_DIR"

# ============================================================
# Encontrar próximo número
# ============================================================

_highest=$(find_highest_adr_number "$ADR_DIR")
printf -v _next "%04d" $((_highest + 1))

# ============================================================
# Gerar slug
# ============================================================

_slug=$(slugify "$TITLE")

_filename="${_next}-${_slug}.md"

# ============================================================
# Gerar ADR
# ============================================================

{
    echo "# $TITLE"
    echo ""
    echo "$CONTENT"
    echo ""

    if [ -n "$STATUS" ]; then
        echo "**Status:** $STATUS"
        echo ""
    fi
} > "$ADR_DIR/$_filename"

# ============================================================
# Resultado
# ============================================================

echo ""
echo -e "${GREEN}✓${RESET} ADR criado com sucesso"
echo ""
echo "  Arquivo: docs/adr/$_filename"
echo "  Número:  $_next"
echo "  Título:  $TITLE"
[ -n "$STATUS" ] && echo "  Status:  $STATUS"
echo ""

# Mostrar preview
echo -e "${BOLD}Preview:${RESET}"
echo -e "${CYAN}────────────────────────────────────────${RESET}"
cat "$ADR_DIR/$_filename"
echo -e "${CYAN}────────────────────────────────────────${RESET}"
echo ""

exit 0