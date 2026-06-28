#!/usr/bin/env bash
#============================================================
# scripts/adapters/test-opencode-delegate.sh
#
# Teste end-to-end do adapter opencode-delegate.sh:
#   1. Cria projeto-teste isolado em /tmp
#   2. Configura prd.json com 1 story pendente
#   3. Roda loop-auto.sh com o adapter em DRY-RUN
#   4. Verifica: prd.json updated, journal criado, rc=0
#============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
ADAPTER="${REPO_ROOT}/scripts/adapters/opencode-delegate.sh"
readonly ADAPTER
LOOP="${REPO_ROOT}/skills/devorq-auto/scripts/loop-auto.sh"
readonly LOOP
TESTDIR="$(mktemp -d -t devorq-dq022-XXXXXX)"
readonly TESTDIR

#----- Cores
G="\033[32m"; R="\033[31m"; Y="\033[33m"; N="\033[0m"
pass() { echo -e "${G}PASS${N} $*"; }
fail() { echo -e "${R}FAIL${N} $*"; exit 1; }
info() { echo -e "${Y}...${N} $*"; }

cleanup() { rm -rf "$TESTDIR"; }
trap cleanup EXIT

[[ -x "$ADAPTER" ]] || fail "adapter nao executavel: $ADAPTER"
[[ -x "$LOOP" ]] || fail "loop nao executavel: $LOOP"

command -v jq >/dev/null 2>&1 || fail "jq nao encontrado"
command -v git >/dev/null 2>&1 || fail "git nao encontrado"

info "testdir=$TESTDIR"

#----- Setup: git repo + prd.json com 1 story pendente
git -C "$TESTDIR" init -q -b main
git -C "$TESTDIR" config user.email "test@devorq"
git -C "$TESTDIR" config user.name "devorq-test"
echo "# test" > "$TESTDIR/README.md"
git -C "$TESTDIR" add README.md
git -C "$TESTDIR" commit -q -m "chore(test): scaffold"

cat > "$TESTDIR/prd.json" <<'JSONEOF'
{
  "project": "devorq-dq022-test",
  "version": "0.0.1",
  "stories": [
    {
      "id": "dq022-test-001",
      "title": "Criar arquivo hello.txt com conteudo world",
      "description": "Smoke test do adapter opencode-delegate",
      "acceptanceCriteria": [
        "Arquivo hello.txt existe no projeto",
        "Conteudo do arquivo e exatamente 'world'",
        "Sem modificacao de prd.json ou progress.txt"
      ],
      "priority": 1,
      "passes": false,
      "status": "pending"
    }
  ]
}
JSONEOF

info "cenario: 1 story pendente (priority 1)"

#----- E2E: roda o loop com adapter em DRY-RUN
info "executando loop-auto.sh com adapter em OPENCODE_DRY_RUN=1..."

set +e
(
    cd "$TESTDIR"
    export DEVORQ_DELEGATE_FN="$ADAPTER"
    export OPENCODE_DRY_RUN=1
    export DEVORQ_AUTO_ALLOW_NO_RUNNER=1
    export DEVORQ_AUTO_SIMULATE=0
    bash "$LOOP" "$TESTDIR" --iterations 1 2>&1
)
LOOP_RC=$?
set -e

info "loop rc=$LOOP_RC"
[[ $LOOP_RC -eq 0 ]] || fail "loop-auto.sh retornou $LOOP_RC (esperado 0)"

#----- Verificacoes
info "verificando prd.json..."
PASSES=$(jq -r '.stories[0].passes' "$TESTDIR/prd.json")
STATUS=$(jq -r '.stories[0].status' "$TESTDIR/prd.json")
[[ "$PASSES" == "true" ]] || fail "story.passes deveria ser true, veio '$PASSES'"
[[ "$STATUS" == "done" ]] || fail "story.status deveria ser 'done', veio '$STATUS'"
pass "prd.json: story marcada como done/passes=true"

info "verificando journal do adapter..."
JOURNAL_DIR="$TESTDIR/.devorq-auto/runs"
[[ -d "$JOURNAL_DIR" ]] || fail "journal dir nao criado: $JOURNAL_DIR"
JOURNALS=$(find "$JOURNAL_DIR" -name 'adapter-*.log' | wc -l)
[[ "$JOURNALS" -ge 1 ]] || fail "esperava >=1 journal do adapter, encontrei $JOURNALS"
pass "journal criado: $JOURNALS arquivo(s)"

LATEST=$(find "$JOURNAL_DIR" -name 'adapter-*.log' | sort | tail -1)
grep -q "dry_run OK" "$LATEST" || fail "journal nao registra 'dry_run OK' — conteudo:"
cat "$LATEST"
pass "journal registra dry_run OK"

info "verificando progress.txt..."
PROGRESS="$TESTDIR/progress.txt"
[[ -f "$PROGRESS" ]] || fail "progress.txt nao criado"
grep -q "dq022-test-001" "$PROGRESS" || fail "progress.txt nao menciona story id"
pass "progress.txt registra story"

info "verificando que nao houve poluição fora do escopo..."
[[ ! -f "$TESTDIR/hello.txt" ]] || fail "adapter em DRY-RUN NAO deveria criar arquivos — contrato limpo"
pass "DRY-RUN nao criou/modificou arquivos (contrato limpo)"

#----- Teste extra: adapter com story_json malformado (sem .title)
info "testando adapter isolado com story malformado..."
set +e
bash "$ADAPTER" '{"id":"bad"}' "$TESTDIR" 2>/dev/null
RC=$?
set -e
[[ $RC -eq 5 ]] || fail "esperava rc=5 (story sem .title), veio rc=$RC"
pass "adapter rejeita story malformado (rc=5)"

#----- Teste extra: adapter com project_root inexistente
info "testando adapter isolado com project_root inexistente..."
set +e
bash "$ADAPTER" '{"id":"x","title":"x"}' "/nonexistent-path" 2>/dev/null
RC=$?
set -e
[[ $RC -eq 3 ]] || fail "esperava rc=3 (project_root invalido), veio rc=$RC"
pass "adapter rejeita project_root invalido (rc=3)"

echo ""
echo -e "${G}=============================================="
echo -e "DQ-022 e2e: TODOS OS TESTES PASSARAM"
echo -e "==============================================${N}"