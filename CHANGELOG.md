# CHANGELOG — DEVORQ v3

All notable changes to DEVORQ v3 are documented here.

## [3.8.1] — 2026-05-23

### Added
- **`devorq rules export`** — alvos `project`, `cursor`, `claude`, `agents` (adaptadores gerados de `rules/`)
- **`AGENTS.md`** — instruções agnósticas estáveis na raiz do repo
- **`docs/ARQUITETURA-AGNOSTICA-LLM.md`** — uso com Telegram, Claude, Cursor sem acoplamento
- **`scripts/rebuild-history-by-version.sh`** — histórico linear por release (divulgação)
- **CI** — smoke tests export + `scope lite`; `validate-rules.sh` falha em coautoria

### Changed
- **Agnosticismo LLM** — `.cursor/` removido do repo; gitignored; gerar via `devorq rules export cursor`
- **Hook commit-msg** — rejeita `Co-Authored-By` (além do formato escopo(fase))
- **`rules/README.md`** — secção arquitetura agnóstica
- **Histórico Git** — reorganizado por versão (1 commit/release); re-clone recomendado

### Fixed
- **[3.8.0]** menção incorreta de `.cursor/rules/` como feature commitada — corrigido para export-only

## [3.8.0] — 2026-05-23

### Added
- **`rules/agent-discipline.md`** — 4 princípios Karpathy adaptados ao DEVORQ (PT)
- **Bootstrap** — `agent-discipline` incluída em `devorq rules bootstrap` (junto commit-convention)
- **`success_criteria`** — campo no template `context.json` do `devorq init`
- **`devorq scope lite "<intent>"`** — contrato mínimo FAZER/NÃO FAZER/VERIFICAR
- **`docs/EXEMPLOS-DISCIPLINA-AGENTE.md`** — 4 exemplos bash/DEVORQ
- **`docs/ANALISE-KARPATHY-DEVORQ.md`** — análise sistemática Karpathy × DEVORQ

### Changed
- **`ctx_lint`** — avisa se `intent` preenchido sem `success_criteria`
- **Docs de release** — INSTALL, TROUBLESHOOTING, EXTRAS, COMPORTAMENTO_ESPERADO → v3.8.0

### Note (v3.8.1)
- `.cursor/rules/devorq-discipline.mdc` foi removido em v3.8.1 — use `devorq rules export cursor`

## [3.7.2] — 2026-05-23

### Fixed
- **`devorq build`** — carrega `test.sh` e `workflow.sh` antes de `cmd_test`/`cmd_gate` (fix de `dev`)
- **`lessons validate --auto`** — flag `--auto` ativa `LESSONS_AUTO` (auto-validação sem Context7)
- **`lessons approve`** — modo auto interno e `--force` bypassam exigência de validação Context7
- **`scripts/security-tests.sh`** — cria `/tmp/.devorq/state` antes do teste de path traversal
- **E2E Playwright** — `devorq init` idempotente (captura stderr); fluxo compile com `validate --auto`
- **README.md / SPEC.md** — versão alinhada com `VERSION` (estavam em 3.7.0 após release 3.7.1)

### Added
- **`e2e-tests/package.json`** — dependências Playwright versionadas no repo
- **`.gitignore`** — permite `e2e-tests/package.json` (ignora apenas root `package.json`)

### Changed
- **`docs/DEVORQ-DEFICITS-FIX-PLAN.md`** — status RESOLVIDO v3.7.1 (merge de `dev`)

## [3.7.1] — 2026-05-23

### Added
- **orch-002** — Restaura dispatch de `commit`, `verify` e `rules` no CLI v3.7 modular
- **`lib/commands/commit.sh`** e **`lib/commands/rules.sh`** — wrappers de dispatch
- **`devorq rules bootstrap`** — aplica commit-convention + manual-commit + commit-msg hook
- **`devorq rules install-hook`** / **`uninstall-hook`** — git commit-msg hook (substitui pre-commit incorreto)
- **`commit_mode: manual`** em context.json template do `devorq init`
- Smoke tests em `verify-dispatch.sh` para commit, verify, rules

### Fixed
- **`lib/commit.sh`** — lógica invertida que abortava commit quando havia mudanças
- **`loop-auto.sh`** — remove sugestão `feat(story_id):`; delega para `devorq commit --story`
- **`git commit-msg` hook** — validação no hook correto (antes era pre-commit, sem acesso à mensagem)
- **`devorq init`** — executa bootstrap de regras mesmo se `.devorq/` já existir

### Changed
- **`devorq_auto::git_commit`** — usa formato `escopo(impl): título (story_id)` quando auto-commit habilitado

## [3.7.0] — 2026-05-22

### Added
- **shellcheck zero warnings** — FASE 1 do refactoring
  - Adicionadas diretivas shellcheck em todos os arquivos
  - 110 issues → 0 issues
- **lib/commands/lessons/** — Modularização FASE 2
  - `lib/commands/lessons/capture.sh` — lessons::capture
  - `lib/commands/lessons/list.sh` — lessons::list
  - `lib/commands/lessons/search.sh` — lessons::search
  - `lib/commands/lessons/approve.sh` — lessons::approve
  - `lib/commands/lessons/validate.sh` — lessons::validate
  - `lib/commands/lessons/compile.sh` — lessons::compile
  - `lib/commands/lessons/migrate.sh` — lessons::migrate
  - `lib/commands/lessons/index.sh` — carregador de módulos
- **bin/commands/** — Estrutura modular para bin/
- **lib/commands/cli/** — Módulos CLI (init, version, stats)
- **lib/commands/ddd.sh** — Comando DDD validate
- **lib/commands/test.sh** — Wrapper para testes
- **scripts/test-commands.sh** — Suite de testes para comandos CLI

### Changed
- **lib/lessons.sh** — Refatorado como thin wrapper
  - 996 LOC → 205 LOC (↓79%)
  - Delega para módulos em lib/commands/lessons/
- **bin/devorq** — Refatorado como dispatcher
  - 1504 LOC → 174 LOC (↓88%)
  - Carrega módulos sob demanda
- **lessons::validate** — Adicionado suporte a LESSONS_AUTO
- **lessons::approve** — Adicionado help inline
- **lessons::list** — Adicionado help inline

### Fixed
- **bin/devorq dispatch v3.7** — Restaura roteamento para `lib/commands/*` após modularização
  - `init`/`gate`/`flow` → `workflow.sh`; `compact` → `context.sh`; `env`/`spec` → `exploration.sh`
  - Wrappers: `auto.sh`, `mode.sh`, `review.sh`, `info.sh`
- **lib/helpers.sh** — Funções de log (`devorq::info|warn|error|success|fail`) usadas em todo o CLI
- **lesson::capture path bug** — Corrigido duplo /captured/captured
- **test environment** — DEVORQ_DIR/DEVORQ_LESSONS_DIR configurados
- **lessons::search** — Mensagem correta quando não há resultados
- **lessons::apply** — Implementação completa com jq
- **scripts/pipeline-tests.sh** — Comentário que quebrava ShellCheck (SC1072/SC1073)
- **scripts/unit-tests.sh** — Teste de schema de lessons usa arquivo mais recente (evita flake)

### Added (pós-modularização)
- **scripts/verify-dispatch.sh** — Gate CI: valida que `bin/devorq` só referencia módulos existentes
- **docs/FLOW-ORCHESTRATOR-ATTEST.md** — Fluxo de atestação CLASSIC + AUTO (story `orch-001`)
- **prd.json** — Story `orch-001` (orquestrador DEVORQ)

### Security
- **ShellCheck compliance** — 0 warnings em todos os scripts

### Tests
- **Suite 100% verde** (2026-05-22)
  - 68 unit tests | 43 CI tests | 11 e2e bash | 8 Playwright modes-classic-auto
  - `verify-dispatch.sh` integrado ao CI
  - shellcheck: 0 errors (`bin/devorq`, `lib/*.sh`, `scripts/*.sh`)

---

## [3.6.6] — 2026-05-21

### Added
- **lib/rules.sh** — Sistema de regras enforced
  - `devorq::rules::init()` carrega regras global + local (hierarquia)
  - `devorq::cmd_rules()` com ações: list, check, apply, help
  - `devorq::rules::enforce_commit()` valida mensagens de commit
  - `devorq::rules::install_pre_commit_hook()` instala hook em .git/hooks/
  - `devorq::rules::check_commit_convention()` valida últimos 10 commits
  - `devorq::rules::check_brainstorm()` e `devorq::rules::check_grill()`
- **lib/commands/brainstorm.sh** — Comando `devorq brainstorm`
  - Sessão interativa com 5 gates: SCOPE_DEFINED, ENTITIES_IDENTIFIED, RISKS_RAISED, STACK_DECIDED, SESSION_COMPLETE
  - Captura entidades, riscos e decisões de stack
  - Salva sessão em .devorq/state/sessions/brainstorm_*.json
- **lib/commands/grill.sh** — Comando `devorq grill`
  - Sessão de sparring estruturado (demolição estruturada)
  - Gates: PREMISSA_QUESTIONADA, DESIGN_FLAW_FOUND, TRADE-OFF_ACCEPTED, GRILL_COMPLETE
  - Auto-capture de lição quando falha de design detectada
  - Três strikes = trigger para criar regra permanente
  - Salva sessão em .devorq/state/sessions/grill_*.json
- **`devorq rules`** — Sistema de regras (list, check, apply, help)
- **`devorq brainstorm <topic>`** — Brainstorm com gates de captura
- **`devorq grill <topic>`** — Sparring estruturado

### Changed
- **bin/devorq** — Adicionados comandos `rules`, `brainstorm`, `grill` ao dispatch
- **bin/devorq** — Carrega `lib/rules.sh` no bootstrap com `devorq::rules::init()`
- **bin/devorq** — `devorq init` agora copia regras globais para .devorq/rules/
- **bin/devorq** — Cria .devorq/state/sessions/ na inicialização
- **README.md** — Versão atualizada para 3.6.6

### Fixed
- **Regras não eram aplicadas** — Sistema de regras agora carrega e aplica automaticamente
- **Hierarquia global > local** — .devorq/rules/ sobrescreve global quando existe
- **Bug fix: devorq init** — `devorq::rules::init()` não cria mais `.devorq/` prematuramente
- **Bug fix: compact::generate** — `compact::generate()` agora redireciona JSON para arquivo `$output` (antes ignorava e输出va para stdout)
- **Bug fix: GATE-5** — `handoff.json` agora é gerado corretamente

---

## [3.6.7] — 2026-05-21

### Fixed
- **Bug fix: sandbox.spec.ts** — Arquivo de testes E2E para sandbox isolado criado
- **Bug fix: E2E tests** — Correções de case sensitivity e expectativas de output
- **Bug fix: lessons compile** — Adicionado `validate --auto` antes de `approve` (aprovação requer validação prévia)
- **Bug fix: SC2168 shellcheck** — Removidos 9x `local` fora de função em `scripts/validate-rules.sh` (linhas 121, 139, 174, 218, 223, 228, 272, 291, 311)
- **Bug fix: SC2144 shellcheck** — Corrigido glob com `-f` em `scripts/e2e-test.sh:393` (substituído por `find | grep -q`)

### Documentation
- **docs/DEVORQ-COMMIT-VISUAL-SPEC.md** — Atualizado status para `IMPLEMENTADO v3.6.5` com histórico completo de todas as 12 features implementadas desde v3.6.5 (visual.sh, commit.sh, debug-systematic.sh, rules, brainstorm, grill, shellcheck 0 errors)

---

## [3.6.5] — 2026-05-21

### Added
- **lib/visual.sh** — Verificação visual com Playwright + manual
  - `devorq::verify::run()` executa gates + verificação visual
  - `devorq::verify::playwright()` executa suite E2E
  - `devorq::verify::manual()` pede confirmação manual
  - `devorq::verify::trigger_debug()` trigger systematic-debugging quando falha
- **lib/commit.sh** — Commit interativo com convenção
  - `devorq::cmd_commit()` com formato `escopo(fase): descrição (detalhamento)`
  - Suporte a `--story`, `--scope`, `--phase`, `--message`, `--push`, `--dry-run`
- **scripts/debug-systematic.sh** — Trigger automático de debug sistemático
  - Phase 0: Classify failure mode (CAT A/B/C/D)
  - Phase 1: Root cause investigation
  - Phase 2: Pattern analysis
  - Phase 3: Context7 validation
  - Phase 4: Implementation
- **rules/visual-verification.md** — Documentação do gate de verificação visual
- **`devorq verify`** — Novo comando (Playwright ou manual)
- **`devorq commit`** — Novo comando (interativo com convenção)

### Changed
- **lib/auto.sh** — Removido commit automático após cada story
  - `devorq::auto::git_commit()` removido das linhas 319 e 400
  - Substituído por `devorq::verify::run()` + hint de commit manual
  - `devorq auto --continue` agora pede confirmação antes de commitar
- **rules/commit-convention.md** — Formato atualizado
  - Anterior: `type(scope): descrição`
  - Novo: `escopo(fase): descrição (detalhamento)`
  - 21 escopos válidos, 8 fases válidas
  - Sem emojis, sem co-autoria, pt-BR
- **bin/devorq** — Adicionados comandos `verify` e `commit`
- **bin/devorq** — Carrega `lib/visual.sh` e `lib/commit.sh` no bootstrap

### Fixed
- **Commit automático removido** — Developer agora commita manualmente após verificação visual
- **systematic-debugging trigger** — Quando teste falha (vermelho), debug entra em ação automaticamente

### Removed
- **`devorq::auto::git_commit()`** — Não existe mais (era automático)
- **Commits durante implementação** — Não há mais múltiplos commits durante a tarefa

---

## [3.6.4] — 2026-05-20

### Added
- **rules/** — Nova estrutura de regras globais versionadas em `DEVORQ_ROOT/rules/`
  - `rules/README.md` — Índice central com hierarquia e como sobrescrever
  - `rules/commit-convention.md` — Convenções de commit migradas do Hermes
  - `rules/brainstorm.md` — Regras de captura durante sessões brainstorm
  - `rules/grill.md` — Regras de sparring para sessões grill
- **skills/README.md** — Índice central de skills com hierarquia local > global

### Changed
- **INSTALL.md** — Corrigido path de instalação de `~/devorq/` para `~/projects/devorq_v3/`
  - Evita conflito com instalações antigas
  - Adicionado alerta sobre instalações concorrentes no troubleshooting
  - Adicionada seção "Detectando instalações concorrentes"
- **bin/devorq header** — Comentário atualizado: não usar `~/devorq/`, usar `~/projects/devorq_v3/`
- **skills/** — Adicionadas `learned-lesson` (migrada de ~/.devorq_v3), `grill-with-docs`, `security-hardening`
- **devorq skills list** — Agora lista skills do framework corretamente (antes hardcoded parcial)

### Fixed
- **devorq version** — Detecção automática de instalações concorrentes
  - Alerta no output quando `~/devorq/` ou `~/.devorq_v3/` existem com versão diferente
  - Sugere comando de remoção das instalações obsoletas

## [3.6.3] — 2026-05-18

### Added
- **devorq info** — Environment info + PAO status (Token Economy)
- **Laravel PAO** — Recomendação documentação (desacoplado, não dependência)
- **skills/grill-with-docs** — Skill de sparring terminológico (Matt Pocock) integrada ao GATE-0
  - Referências: `CONTEXT-FORMAT.md`, `ADR-FORMAT.md` (Matt Pocock)
  - Integração: `lib/gates.sh` modificado (GATE-0, pós DDD)
  - ADR numbering: scan `docs/adr/` → highest 000N → next = 000(N+1)
  - Skip: bugfix, hotfix, debug, init, lessons, compact, sync, version, stats, test
  - AUTO mode: grill entre sprints (pré prd-from-spec.sh)

## [3.6.2] — 2026-05-18

### Added
- **docs/AUTO-MODE.md** — Documentação oficial do AUTO mode

### Changed
- **AUTO mode unificado** — `loop-auto.sh` agora sourceia `lib/auto.sh`
  - Funções compartilhadas: `next_story`, `pending_count`, `mark_pass`, etc.
  - Elimina duplicação de código
- **v1.2.1** — `loop-auto.sh` atualizado com versão

### Fixed
- **fix(bin)** — `--help` no comando `devorq auto` agora funciona corretamente
- **fix(execution.sh)** — Remoção do arquivo legado que sobrescrevia `cmd_auto`

---

## [3.6.0] — 2026-05-14

### Added
- **sec-001** — Correção de credenciais expostas em variáveis de ambiente
- **AUTO mode lessons** — Integração de lições aprendidas no loop automático
  - `.devorq-auto/lessons.json` — Aprendizados estruturados
  - `.devorq-auto/failures.md` — Sumário de falhas
  - `.devorq-auto/runs/*.log` — Logs de execução

### Security
- Correção de vulnerabilidades em `scripts/sync-push.py` e `scripts/sync-pull.py`
- Validação de inputs e sanitização em `lib/commands/*.sh`

---

## [3.5.0] — 2026-05-09

### Added
- **BDD Validation** — `lib/spec.sh` com validação Given/When/Then
  - `devorq spec validate` — valida SPEC.md com ACs BDD
  - `devorq spec template [feature]` — gera template com BDD
  - `devorq spec check-ac` — verifica cobertura de testes
- **UNIFY Phase** — `lib/unify.sh` com fase explícita de fechamento
  - `devorq unify [feature]` — executa UNIFY completo
  - Gera `.devorq/state/unify/*_unify.md` com resultado dos ACs
  - Atualiza `context.json` com campo `unify_done`
- **GATE-5.5 (UNIFY Check)** — verificação não-bloqueante entre GATE-5 e GATE-6
  - Mostra WARN se UNIFY ainda não executado
  - Passa se UNIFY já realizado
- **GATE-0 Suite** — env-context integrado ao GATE-0
  - `devorq gate 0` executa env-detect.sh automaticamente
  - Detecta stack, runtime, commands, ports, GOTCHAS
- **AUTO Mode** — `devorq auto [n|all]` para loop story-by-story
  - Story por story com delegate_task
  - Bug handling: systematic-debugging → Context7 → correção → commit
- **CLASSIC Mode** — `devorq mode classic` para execução tradicional
  - Nunca faz auto-commit sem validação manual do usuário
- **Code Review** — `devorq review [--branch HEAD]`
  - Review multi-agente com scoring 0-100
  - Filtra recomendações com confidence ≥80
- **E2E Test Suite** — `scripts/e2e-test.sh`
  - Sandbox isolado em /tmp/devorq-e2e-sandbox/
  - 11 testes cobrindo CLASSIC e AUTO modes

### Changed
- `lib/gates.sh` — GATE-0 agora integra env-context
- `lib/lessons.sh` — adicionada função `lessons::from_unify()`
- `bin/devorq` — adicionados comandos: env, spec, unify, mode, auto, review
- `bin/devorq` — GATE-5.5 como caso especial no handler de gates

### Documentation
- README.md, INSTALL.md, TROUBLESHOOTING.md, EXTRAS.md, SPEC.md atualizados para v3.5.0

---

## [3.4.1] — 2026-04-25

### Fixed
- Removido texto em árabe do README
- Version bump correto nos arquivos de documentação

---

## [3.4.0] — 2026-04-20

### Added
- GATE-0 Domain Exploration (DDD keywords detection)
- Context7 integration para validação de lições

---

## [3.3.0] — 2026-04-15

### Added
- Sistema de lições aprendidas com captura e busca
- Handoff generation com compact.sh
