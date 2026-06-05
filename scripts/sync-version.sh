#!/usr/bin/env bash
# scripts/sync-version.sh - DEVORQ v3.8.5+
#
# Detecta e opcionalmente corrige drift de versao entre os pontos
# canonicos de declaracao de versao no projeto.
#
# Pontos verificados:
#   - VERSION (raiz)
#   - bin/devorq (header comment, readonly DEVORQ_VERSION, linha de help)
#   - lib/*.sh (header comment com versao)
#   - CHANGELOG.md (header de versao atual)
#   - README.md (badge "Version" se existir)
#
# Uso:
#   ./scripts/sync-version.sh --check   # CI gate, exit != 0 se drift
#   ./scripts/sync-version.sh --fix     # atualiza todos os pontos
#   ./scripts/sync-version.sh --status  # status detalhado, exit 0 sempre
#
# Adicionado no sprint v3.8.5 (dogfooding)

set -euo pipefail

# ============================================================
# CONFIGURACAO
# ============================================================

PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
VERSION_FILE="${PROJECT_ROOT}/VERSION"
BIN_FILE="${PROJECT_ROOT}/bin/devorq"
LIB_DIR="${PROJECT_ROOT}/lib"
CHANGELOG_FILE="${PROJECT_ROOT}/CHANGELOG.md"
README_FILE="${PROJECT_ROOT}/README.md"
PRD_FILE="${PROJECT_ROOT}/prd.json"

# Cores
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

# ============================================================
# FUNCOES AUXILIARES
# ============================================================

log()  { echo -e "${CYAN}[sync-version]${RESET} $*"; }
ok()   { echo -e "${GREEN}  [OK]${RESET} $*"; }
warn() { echo -e "${YELLOW}  [DRIFT]${RESET} $*"; }
fail() { echo -e "${RED}  [FAIL]${RESET} $*"; }

# Coleta versao canonica do VERSION
get_canonical_version() {
    if [ ! -f "$VERSION_FILE" ]; then
        fail "VERSION nao encontrado em $VERSION_FILE"
        exit 2
    fi
    cat "$VERSION_FILE" | tr -d '[:space:]'
}

# Coleta versao declarada em um arquivo (regex)
# retorna string vazia se nao encontrar
detect_version_in_file() {
    local file="$1"
    local pattern="$2"
    if [ ! -f "$file" ]; then
        echo ""
        return
    fi
    grep -oE "$pattern" "$file" 2>/dev/null | head -1 | sed -E "s/$pattern/\\1/" || echo ""
}

# ============================================================
# CHECK: detecta drift
# ============================================================

declare -a DRIFT_POINTS=()

check_drift() {
    local canonical="$1"
    local drift_count=0

    log "Versao canonica (VERSION): $canonical"
    echo ""

    # 1) bin/devorq - header
    local bin_header
    bin_header=$(detect_version_in_file "$BIN_FILE" 'DEVORQ v([0-9]+\.[0-9]+\.[0-9]+)')
    if [ -n "$bin_header" ] && [ "$bin_header" != "$canonical" ]; then
        warn "bin/devorq header: '$bin_header' != '$canonical'"
        DRIFT_POINTS+=("bin/devorq:header:$bin_header:$canonical")
        ((drift_count++))
    elif [ -n "$bin_header" ]; then
        ok "bin/devorq header: $bin_header"
    else
        warn "bin/devorq header: nao encontrado"
    fi

    # 2) bin/devorq - readonly DEVORQ_VERSION
    local bin_readonly
    bin_readonly=$(detect_version_in_file "$BIN_FILE" 'DEVORQ_VERSION="([0-9]+\.[0-9]+\.[0-9]+)"')
    if [ -n "$bin_readonly" ] && [ "$bin_readonly" != "$canonical" ]; then
        warn "bin/devorq DEVORQ_VERSION: '$bin_readonly' != '$canonical'"
        DRIFT_POINTS+=("bin/devorq:readonly:$bin_readonly:$canonical")
        ((drift_count++))
    elif [ -n "$bin_readonly" ]; then
        ok "bin/devorq DEVORQ_VERSION: $bin_readonly"
    else
        warn "bin/devorq DEVORQ_VERSION: nao encontrado"
    fi

    # 3) bin/devorq - help
    local bin_help
    bin_help=$(detect_version_in_file "$BIN_FILE" 'DEVORQ v([0-9]+\.[0-9]+\.[0-9]+) - Framework')
    if [ -n "$bin_help" ] && [ "$bin_help" != "$canonical" ]; then
        warn "bin/devorq help: '$bin_help' != '$canonical'"
        DRIFT_POINTS+=("bin/devorq:help:$bin_help:$canonical")
        ((drift_count++))
    elif [ -n "$bin_help" ]; then
        ok "bin/devorq help: $bin_help"
    fi
    echo ""

    # 4) lib/*.sh - header (procura "v3.8.4" no comentario de header)
    local lib_drift=0
    for f in "$LIB_DIR"/*.sh "$LIB_DIR"/commands/*.sh; do
        [ -f "$f" ] || continue
        local fname
        fname=$(basename "$f")
        # Pula arquivos que nao tem versao explicita no header
        local fv
        fv=$(grep -oE '# .*v([0-9]+\.[0-9]+\.[0-9]+)' "$f" 2>/dev/null | head -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | tr -d 'v' || echo "")
        # So reporta se encontrou E difere
        if [ -n "$fv" ] && [ "$fv" != "$canonical" ]; then
            warn "lib/$fname header: v$fv != v$canonical"
            DRIFT_POINTS+=("lib/$fname:header:v$fv:v$canonical")
            ((lib_drift++))
        fi
    done
    if [ $lib_drift -eq 0 ]; then
        ok "lib/*.sh headers: consistentes"
    fi
    drift_count=$((drift_count + lib_drift))
    echo ""

    # 5) CHANGELOG.md - header de versao atual
    if [ -f "$CHANGELOG_FILE" ]; then
        local cl_header
        cl_header=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG_FILE" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
        if [ -n "$cl_header" ] && [ "$cl_header" != "$canonical" ]; then
            warn "CHANGELOG.md header: '$cl_header' != '$canonical'"
            DRIFT_POINTS+=("CHANGELOG.md:header:$cl_header:$canonical")
            ((drift_count++))
        elif [ -n "$cl_header" ]; then
            ok "CHANGELOG.md header: $cl_header"
        else
            warn "CHANGELOG.md header: nao encontrado"
        fi
    fi
    echo ""

    # 6) prd.json (raiz) - campo "version"
    if [ -f "$PRD_FILE" ]; then
        local prd_version
        prd_version=$(jq -r '.version // ""' "$PRD_FILE" 2>/dev/null || echo "")
        if [ -n "$prd_version" ] && [ "$prd_version" != "$canonical" ]; then
            warn "prd.json version: '$prd_version' != '$canonical'"
            DRIFT_POINTS+=("prd.json:version:$prd_version:$canonical")
            ((drift_count++))
        elif [ -n "$prd_version" ]; then
            ok "prd.json version: $prd_version"
        else
            warn "prd.json version: nao encontrado"
        fi
    fi
    echo ""

    return $drift_count
}

# ============================================================
# FIX: corrige drift
# ============================================================

fix_drift() {
    local canonical="$1"

    log "Corrigindo para versao $canonical..."
    echo ""

    for point in "${DRIFT_POINTS[@]}"; do
        IFS=':' read -r file field current target <<< "$point"
        log "  $file [$field]: $current -> $target"

        case "$file:$field" in
            bin/devorq:header)
                sed -i.bak -E "s/DEVORQ v[0-9]+\.[0-9]+\.[0-9]+ CLI/DEVORQ v${target} CLI/" "$BIN_FILE"
                rm -f "$BIN_FILE.bak"
                ;;
            bin/devorq:readonly)
                sed -i.bak -E "s/DEVORQ_VERSION=\"[0-9]+\.[0-9]+\.[0-9]+\"/DEVORQ_VERSION=\"${target}\"/" "$BIN_FILE"
                rm -f "$BIN_FILE.bak"
                ;;
            bin/devorq:help)
                sed -i.bak -E "s/DEVORQ v[0-9]+\.[0-9]+\.[0-9]+ - Framework/DEVORQ v${target} - Framework/" "$BIN_FILE"
                rm -f "$BIN_FILE.bak"
                ;;
            lib/*:header)
                local lib_path="$PROJECT_ROOT/$file"
                sed -i.bak -E "s/v[0-9]+\.[0-9]+\.[0-9]+/v${target}/g" "$lib_path"
                rm -f "$lib_path.bak"
                ;;
            CHANGELOG.md:header)
                sed -i.bak -E "0,/^## \[[0-9]+\.[0-9]+\.[0-9]+\]/{s/^## \[[0-9]+\.[0-9]+\.[0-9]+\]/## [${target}]/}" "$CHANGELOG_FILE"
                rm -f "$CHANGELOG_FILE.bak"
                ;;
            prd.json:version)
                local tmp
                tmp=$(jq --arg v "$target" '.version = $v' "$PRD_FILE")
                echo "$tmp" > "$PRD_FILE"
                ;;
        esac
    done

    echo ""
    log "Drift corrigido. Re-rodando check..."
    echo ""
    DRIFT_POINTS=()
    check_drift "$canonical"
    return $?
}

# ============================================================
# MAIN
# ============================================================

main() {
    local mode="${1:-check}"

    if [ ! -d "$PROJECT_ROOT" ]; then
        fail "Diretorio do projeto nao encontrado: $PROJECT_ROOT"
        exit 2
    fi

    cd "$PROJECT_ROOT"

    local canonical
    canonical=$(get_canonical_version)

    case "$mode" in
        --check|check)
            log "Modo: CHECK (CI gate)"
            echo ""
            if check_drift "$canonical"; then
                echo ""
                ok "Nenhum drift detectado. Tudo sincronizado em $canonical."
                exit 0
            else
                echo ""
                fail "Drift detectado em ${#DRIFT_POINTS[@]} ponto(s). Rode: $0 --fix"
                exit 1
            fi
            ;;
        --fix|fix)
            log "Modo: FIX (atualizar para $canonical)"
            echo ""
            check_drift "$canonical" >/dev/null 2>&1 || true
            if [ ${#DRIFT_POINTS[@]} -eq 0 ]; then
                ok "Nenhum drift. Nada a corrigir."
                exit 0
            fi
            fix_drift "$canonical"
            if [ ${#DRIFT_POINTS[@]} -eq 0 ]; then
                ok "Drift corrigido. Tudo sincronizado em $canonical."
                exit 0
            else
                fail "Ainda ha drift apos fix. Verifique manualmente."
                exit 1
            fi
            ;;
        --status|status)
            log "Modo: STATUS (informativo, exit 0 sempre)"
            echo ""
            check_drift "$canonical" >/dev/null 2>&1 || true
            if [ ${#DRIFT_POINTS[@]} -eq 0 ]; then
                ok "Nenhum drift."
                exit 0
            else
                warn "${#DRIFT_POINTS[@]} ponto(s) com drift:"
                for p in "${DRIFT_POINTS[@]}"; do
                    echo "    - $p"
                done
                exit 0
            fi
            ;;
        -h|--help|help)
            cat <<EOF
scripts/sync-version.sh - DEVORQ v3.8.5+

USO:
  $0 --check    Detecta drift (CI gate, exit != 0 se drift)
  $0 --fix      Corrige drift (atualiza para VERSION)
  $0 --status   Status detalhado (exit 0 sempre)

PONTOS VERIFICADOS:
  - VERSION (raiz)
  - bin/devorq (header, readonly DEVORQ_VERSION, help)
  - lib/*.sh (headers com versao)
  - CHANGELOG.md (header de versao atual)
  - prd.json (campo "version")

Origem: sprint v3.8.5 - story-004-sync-version-script
EOF
            exit 0
            ;;
        *)
            fail "Modo desconhecido: $mode"
            echo "Use: $0 --check | --fix | --status | --help"
            exit 2
            ;;
    esac
}

main "$@"
