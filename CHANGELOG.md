# CHANGELOG — DEVORQ v3

All notable changes to DEVORQ v3 are documented here.

## [3.6.3] — 2026-05-18

### Added
- **skills/grill-with-docs** — Skill de sparring terminológico (Matt Pocock) integrada ao DEVORQ v3.6.3
  - GATE-0: Validação de vocabulário contra glossário (CONTEXT.md)
  - GERA template inicial de CONTEXT.md (com placeholders para refinamento orquestrador-guided)
  - BREAK/warn forte (não-bloqueante) com recomendação forte de executar grill antes de prosseguir
  - Scripts: `grill-detect.sh`, `grill-init-context.sh`, `grill-refine.sh`, `grill-suggest-adr.sh`, `grill-create-adr.sh`
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
