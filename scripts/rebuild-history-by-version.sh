#!/usr/bin/env bash
# scripts/rebuild-history-by-version.sh — Reconstrói histórico linear por release (one-time)
#
# Uso:
#   bash scripts/rebuild-history-by-version.sh [--dry-run]
#
# Pré-requisitos:
#   - v3.8.1 commitado em HEAD (working tree limpo)
#   - Backup: git clone --mirror <repo> backup.git
#
# Resultado:
#   - Branch main com 1 commit por tag semver
#   - Tags v3.4.1 … v3.8.1 apontando para commits novos
#   - Zero Co-Authored-By

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN="${1:-}"

AUTHOR_NAME="${GIT_AUTHOR_NAME:-Fernando dos Santos Souza}"
AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-109618503+nandinhos@users.noreply.github.com}"

# Tags existentes em ordem cronológica (sem v3.8.1 — vem de HEAD)
TAGS=(
    v3.4.1 v3.5.0 v3.6.0 v3.6.2 v3.6.3 v3.6.4 v3.6.5 v3.6.6
    v3.7.0 v3.7.1 v3.7.2 v3.8.0
)

changelog_title() {
    local ver="$1"
    local changelog="${CHANGELOG_CACHE:-$REPO_ROOT/CHANGELOG.md}"
    awk -v v="$ver" '
        $0 ~ "^## \\[" v "\\]" { found=1; next }
        found && /^- / {
            line = $0
            sub(/^- /, "", line)
            gsub(/\*\*/, "", line)
            print line
            exit
        }
        found && /^## \[/ { exit }
    ' "$changelog"
}

# Pré-carregar títulos antes de orphan (CHANGELOG some do working tree)
declare -A RELEASE_TITLES=()
preload_titles() {
    local changelog="$REPO_ROOT/CHANGELOG.md"
    for tag in "${TAGS[@]}"; do
        local ver="${tag#v}"
        RELEASE_TITLES["$ver"]="$(changelog_title "$ver")"
    done
    RELEASE_TITLES["3.8.1"]="$(changelog_title "3.8.1")"
}

commit_release() {
    local version="$1"
    local tree_ref="$2"
    local title
    title="${RELEASE_TITLES[$version]:-}"
    if [[ -z "$title" ]]; then
        title="$(changelog_title "$version")"
    fi
    if [[ -z "$title" ]]; then
        title="release $version"
    fi
    # Truncar título longo
    title="${title:0:72}"

    local msg="release(v${version}): ${title}"

    if [[ "$DRY_RUN" == "--dry-run" ]]; then
        echo "[DRY-RUN] commit: $msg (tree: ${tree_ref:0:8})"
        return 0
    fi

    find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
    git archive "$tree_ref" | tar -x -C "$REPO_ROOT"
    git add -A
    GIT_AUTHOR_NAME="$AUTHOR_NAME" \
    GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL" \
    GIT_COMMITTER_NAME="$AUTHOR_NAME" \
    GIT_COMMITTER_EMAIL="$AUTHOR_EMAIL" \
    git commit -m "$msg"
}

cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "[ERROR] Working tree não está limpo. Commit v3.8.1 antes de rebuild."
    exit 1
fi

V381_REF="$(git rev-parse HEAD)"

preload_titles

echo "═══════════════════════════════════════════"
echo "  Rebuild histórico DEVORQ por versão"
echo "  v3.8.1 tree: ${V381_REF:0:8}"
echo "═══════════════════════════════════════════"

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    for tag in "${TAGS[@]}"; do
        ver="${tag#v}"
        commit_release "$ver" "$tag"
    done
    commit_release "3.8.1" "$V381_REF"
    echo "[DRY-RUN] Concluído — nenhuma alteração feita."
    exit 0
fi

ORIG_BRANCH="$(git branch --show-current)"
BACKUP_BRANCH="backup/pre-rebuild-$(date +%Y%m%d%H%M%S)"
git branch "$BACKUP_BRANCH" HEAD
echo "[INFO] Backup branch: $BACKUP_BRANCH"

git checkout --orphan history/rebuild-v3.8.1
git rm -rf . >/dev/null 2>&1 || true

declare -A NEW_TAG_REFS

for tag in "${TAGS[@]}"; do
    ver="${tag#v}"
    if ! git rev-parse "$tag" >/dev/null 2>&1; then
        echo "[WARN] Tag $tag não encontrada — pulando"
        continue
    fi
    commit_release "$ver" "$tag"
    NEW_TAG_REFS["$tag"]="$(git rev-parse HEAD)"
    echo "[OK] $tag → $(git rev-parse --short HEAD)"
done

commit_release "3.8.1" "$V381_REF"
NEW_TAG_REFS["v3.8.1"]="$(git rev-parse HEAD)"
echo "[OK] v3.8.1 → $(git rev-parse --short HEAD)"

# Verificar zero coautoria (apenas histórico atual, não refs antigas)
coauthor_count=$(git log --grep="Co-authored-by" --format="%H" | wc -l | tr -d ' ')
if [[ "$coauthor_count" -gt 0 ]]; then
    echo "[ERROR] Ainda há $coauthor_count commits com Co-authored-by"
    exit 1
fi

git branch -M main

for tag in "${!NEW_TAG_REFS[@]}"; do
    git tag -f "$tag" "${NEW_TAG_REFS[$tag]}"
done

echo ""
echo "[OK] Histórico reconstruído: $(git rev-list --count HEAD) commits"
echo "[OK] Tags atualizadas: ${!NEW_TAG_REFS[*]}"
echo ""
echo "Próximo passo:"
echo "  git push origin main --force --tags"
echo ""
echo "Backup da branch anterior: $BACKUP_BRANCH"
