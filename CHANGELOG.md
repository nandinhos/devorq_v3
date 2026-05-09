# CHANGELOG — DEVORQ v3

All notable changes to DEVORQ v3 are documented here.

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
