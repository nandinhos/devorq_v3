# CHANGELOG — DEVORQ v3

All notable changes to DEVORQ v3 are documented here.

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
