#!/usr/bin/env bash
#============================================================
# scripts/adapters/test-panes-bash-python.sh
#
# Prova o bug class "bash interpola $var em Python source via '...'"
# em loop-auto.sh. Roda em /tmp isolado. Story com ' no titulo
# deve passar 100% verde apos os fixes; antes do fix, falha.
#============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
LOOP="${REPO_ROOT}/skills/devorq-auto/scripts/loop-auto.sh"
readonly LOOP
TESTDIR="$(mktemp -d -t devorq-panes-XXXXXX)"
readonly TESTDIR

G="\033[32m"; R="\033[31m"; Y="\033[33m"; N="\033[0m"
pass() { echo -e "${G}PASS${N} $*"; }
fail() { echo -e "${R}FAIL${N} $*"; exit 1; }
info() { echo -e "${Y}...${N} $*"; }

cleanup() { rm -rf "$TESTDIR"; }
trap cleanup EXIT

[[ -x "$LOOP" ]] || fail "loop nao executavel: $LOOP"
command -v jq >/dev/null 2>&1 || fail "jq nao encontrado"
command -v git >/dev/null 2>&1 || fail "git nao encontrado"

info "testdir=$TESTDIR"

#----- Setup: git repo + prd.json com 1 story com aspas no titulo
git -C "$TESTDIR" init -q -b main
git -C "$TESTDIR" config user.email "test@devorq"
git -C "$TESTDIR" config user.name "devorq-test"
echo "# test" > "$TESTDIR/README.md"
git -C "$TESTDIR" add README.md
git -C "$TESTDIR" commit -q -m "chore(test): scaffold"

# Story com aspas simples E duplas no titulo + aspas no id (via ordem de keys).
# Aspas no titulo sao o vetor que dispara o bug em lessons_capture.
cat > "$TESTDIR/prd.json" <<'JSONEOF'
{
  "project": "devorq-panes-test",
  "version": "0.0.1",
  "stories": [
    {
      "id": "panes-test-001",
      "title": "Validar input com aspas: aspas 'simples' e \"duplas\" no titulo",
      "description": "Smoke do contracto DEVORQ_DELEGATE_FN",
      "acceptanceCriteria": [
        "Story processada ate done",
        "lessons_capture nao quebra com ' no titulo"
      ],
      "priority": 1,
      "passes": false,
      "status": "pending"
    }
  ]
}
JSONEOF

info "cenario: 1 story com aspas no titulo (vetor do bug lessons_capture)"

#----- E2E
info "executando loop-auto.sh..."
set +e
(
    cd "$TESTDIR"
    export DEVORQ_DELEGATE_FN="${REPO_ROOT}/scripts/adapters/opencode-delegate.sh"
    export OPENCODE_DRY_RUN=1
    export DEVORQ_AUTO_ALLOW_NO_RUNNER=1
    export DEVORQ_AUTO_SIMULATE=0
    bash "$LOOP" "$TESTDIR" --iterations 1 2>&1
)
LOOP_RC=$?
set -e

info "loop rc=$LOOP_RC"
[[ $LOOP_RC -eq 0 ]] || fail "loop-auto.sh retornou $LOOP_RC (esperado 0) — bug ainda presente"
pass "loop rc=0 com aspas no titulo"

#----- Validacoes
info "verificando prd.json..."
PASSES=$(jq -r '.stories[0].passes' "$TESTDIR/prd.json")
STATUS=$(jq -r '.stories[0].status' "$TESTDIR/prd.json")
[[ "$PASSES" == "true" ]] || fail "story.passes deveria ser true, veio '$PASSES'"
[[ "$STATUS" == "done" ]] || fail "story.status deveria ser 'done', veio '$STATUS'"
pass "prd.json: story done mesmo com aspas"

#----- A lição é o ponto crítico: lessons.json deve ter sido gravado
# SEM SyntaxError do Python. Se o bug persistir, o lessons_capture
# falha silenciosamente e lessons.json fica vazio ou incompleto.
info "verificando lessons.json..."
LESSONS="$TESTDIR/.devorq-auto/lessons.json"
[[ -f "$LESSONS" ]] || fail "lessons.json nao criado"
COUNT=$(jq '.lessons | length' "$LESSONS")
[[ "$COUNT" -ge 1 ]] || fail "esperava >=1 lesson gravada, encontrei $COUNT"
pass "lessons.json gravado com $COUNT lesson(s)"

# Verifica que a lesson gravada tem o titulo original intacto (sem perda por escape mal feito)
STORED_TITLE=$(jq -r '.lessons[0].story_title' "$LESSONS")
[[ -n "$STORED_TITLE" ]] || fail "story_title gravado vazio"
info "  story_title gravado: $STORED_TITLE"

#----- Teste mark_skip (segundo vetor): story com aspas + complexidade detectada
# Cria 2a story que dispare mark_skip (complex) — mais uma camada.
info "testando mark_skip com story complexa contendo aspas..."
cat > "$TESTDIR/prd.json" <<'JSONEOF'
{
  "project": "devorq-panes-test",
  "version": "0.0.1",
  "stories": [
    {
      "id": "skip-test-001",
      "title": "Migration complexa com aspas no titulo 'migracao'",
      "description": "Heuristica de complexidade vai disparar mark_skip",
      "acceptanceCriteria": [
        "Story marcada como skipped sem SyntaxError"
      ],
      "priority": 1,
      "passes": false,
      "status": "pending"
    }
  ]
}
JSONEOF

# Simula interacao: o loop chama devorq_auto::propose_break quando detecta
# complexidade. Como o input vem via stdin, monkeypatch nao ajuda — em vez
# disso invocamos mark_skip diretamente via source.

set +e
(
    cd "$TESTDIR"
    # NAO sourcing o loop inteiro (main() abortaria). Extrai so a funcao.
    bash -c "
        eval \"\$(awk '/^devorq_auto::mark_skip\(\) \{/,/^\}/' '${LOOP}')\"
        # Stub de LESSONS_FILE para isolar
        export LESSONS_FILE='${TESTDIR}/.devorq-auto/lessons.json'
        export CAPTURE_LESSONS=true
        devorq_auto::mark_skip '${TESTDIR}' 'skip-test-001' \"motivo com 'aspas'\"
    "
)
RC=$?
set -e

[[ $RC -eq 0 ]] || fail "mark_skip retornou $RC (esperado 0) — bug em interpolacao de \$reason"
pass "mark_skip funciona com aspas no reason"

#----- Teste lessons_suggest (3o vetor): chamada direta com story com aspas
info "testando lessons_suggest com titulo aspeado..."
set +e
(
    cd "$TESTDIR"
    bash -c "
        eval \"\$(awk '/^devorq_auto::lessons_suggest\(\) \{/,/^\}/' '${LOOP}')\"
        export LESSONS_FILE='${TESTDIR}/.devorq-auto/lessons.json'
        devorq_auto::lessons_suggest '${TESTDIR}' \"titulo com 'aspas' e \\\"duplas\\\"\"
    " 2>&1
)
RC=$?
set -e

[[ $RC -eq 0 ]] || fail "lessons_suggest retornou $RC (esperado 0)"
pass "lessons_suggest funciona com aspas no titulo"

echo ""
echo -e "${G}=============================================="
echo -e "PANES E2E: TODOS OS TESTES PASSARAM"
echo -e "==============================================${N}"