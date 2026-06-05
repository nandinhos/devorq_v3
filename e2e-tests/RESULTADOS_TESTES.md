# Resultados dos Testes E2E - DEVORQ v3.8.5

> **Data:** 2026-06-04
> **Versão Testada:** DEVORQ v3.8.4 (suite revival — sprint v3.8.5 dogfooding)
> **Ambiente:** WSL Ubuntu 24.04, Node.js v18.19.1, Playwright 1.52, Chromium 1223
> **Origem:** Story 1 do sprint v3.8.5 (revival da suite estagnada desde v3.6.0/2026-05-12)

---

## Resumo Executivo

A suite E2E em `e2e-tests/` (Playwright + bash) **estava estagnada desde 2026-05-12 (v3.6.0) com 35% reportado** e nunca havia sido re-rodada. A Story 1 do sprint v3.8.5 dogfooding reviveu a suite, instalou as dependências e rodou a baseline em 2026-06-04.

**Baseline (estado pré-refactor story-003): 77/77 testes passando (100%) em 20.1s** — bem acima da meta de 80%.

**Estado atual (2026-06-04 22:52, com story-003 refactor em curso): 68/77 (88.3%)** — 9 falhas, todas decorrentes de regressão introduzida pelo refactor de `lib/lessons.sh` (story-003, peer session). **Mantém-se acima da meta de 80%**.

> **Nota sobre regressão:** o refactor de `lib/lessons.sh` em `lib/lessons/{crud,search,sync}.sh` (story-003, em curso na sessão paralela `mvs_58c21b6fd9534f54bb76c5f3d5e03f53`) removeu/acessou incorretamente a função `devorq::sanitize_input`, quebrando 9 testes que dependem de `lessons::capture`. Este arquivo está em `files_prohibited` para story-001, então a regressão é reportada mas não corrigida nesta story. Quando story-003 estabilizar, espera-se retorno a 100%.

Nenhuma correção de código dos testes foi necessária por story-001. A suite já estava alinhada com a v3.8.4; o que faltava era disciplina de re-execução e integração na CI.

---

## Diagnóstico Inicial (estado pré-revival)

| Item | Estado | Categoria |
|------|--------|-----------|
| `e2e-tests/node_modules/` | ausente — `npm install` nunca rodou | infra |
| Playwright Chromium 1217/1223 | já cacheado em `~/.cache/ms-playwright` | ok |
| `playwright.config.ts` | funcional | ok |
| `tsconfig.json` | funcional | ok |
| Versão do Node | 18.19.1 (>= 18 requerido) | ok |
| Suite de testes `*.spec.ts` | 7 arquivos, 77 testes | ok |
| Integração com `scripts/ci-test.sh` | ausente (FASE 5.6 adicionada nesta story) | infra |
| GATE-E2E em `lib/gates.sh` | ausente (adicionado nesta story) | infra |
| Workflow `e2e.yml` em `.github/workflows/` | ausente (criado nesta story) | infra |

A estagnação não era por bugs nos testes nem no framework: era por **falta de
execução contínua** (suite ficou órfã entre v3.6.0 e v3.8.4 = 2 sprints sem
re-rodar).

---

## Correções Aplicadas (categoria infra/ambiente)

Nenhuma correção de lógica de teste foi necessária. Ações executadas, todas na
categoria **infra**:

1. **`npm install`** em `e2e-tests/` — instalou `@playwright/test@1.52`,
   `@types/node@22` e `typescript@5.8`.
2. **`npx playwright install chromium`** — browsers já estavam cacheados
   (Chromium 1217/1223); comando executado só para garantir reprodutibilidade.
3. **`FASE 5.6`** adicionada em `scripts/ci-test.sh` — wrapper que detecta
   `node_modules` ausente, instala deps sob demanda e roda a suite com
   `npx playwright test`. Não bloqueante no dev; reportando.
4. **`GATE-E2E`** adicionado em `lib/gates.sh` — gate informativo (não-bloqueante)
   que delega para a FASE 5.6. Retorna 0 sempre, mas imprime status para o
   `devorq verify`.
5. **Workflow `.github/workflows/e2e.yml`** criado — job Playwright que roda
   em `ubuntu-latest`, instala deps + Chromium e roda a suite. Não bloqueia
   PRs ainda (workflow separado do `ci.yml`); promove a visibilidade sem
   acoplar ao gate atual.

---

## Estatísticas (2026-06-04)

### Baseline (pré-refactor story-003)

| Categoria | Total | Passou | Falhou | % Sucesso |
|-----------|-------|--------|--------|-----------|
| `debug.spec.ts` | 4 | 4 | 0 | 100% |
| `devorq-cli.spec.ts` (9 describes) | 20 | 20 | 0 | 100% |
| `gates.spec.ts` (10 describes) | 15 | 15 | 0 | 100% |
| `lessons.spec.ts` (7 describes) | 13 | 13 | 0 | 100% |
| `modes-classic-auto.spec.ts` (4 describes) | 8 | 8 | 0 | 100% |
| `sandbox.spec.ts` (4 describes) | 10 | 10 | 0 | 100% |
| `security-e2e.spec.ts` (4 describes) | 7 | 7 | 7 | 100% |
| **TOTAL** | **77** | **77** | **0** | **100%** |

**Tempo total:** 20.1s

### Estado atual (com regressão story-003)

| Categoria | Total | Passou | Falhou | % Sucesso |
|-----------|-------|--------|--------|-----------|
| `debug.spec.ts` | 4 | 3 | 1 | 75% |
| `devorq-cli.spec.ts` | 20 | 19 | 1 | 95% |
| `gates.spec.ts` | 15 | 15 | 0 | 100% |
| `lessons.spec.ts` | 13 | 9 | 4 | 69% |
| `modes-classic-auto.spec.ts` | 8 | 8 | 0 | 100% |
| `sandbox.spec.ts` | 10 | 8 | 2 | 80% |
| `security-e2e.spec.ts` | 7 | 6 | 1 | 86% |
| **TOTAL** | **77** | **68** | **9** | **88.3%** |

**Tempo total:** 13.4s
**Acima da meta de 80%** — atende acceptance criteria.

---

## Lista de Falhas (categoria) — estado atual

As 9 falhas são **todas da mesma causa raiz**: regressão introduzida pelo
peer session story-003 (`mvs_58c21b6fd9534f54bb76c5f3d5e03f53`) ao refatorar
`lib/lessons.sh` em `lib/lessons/{crud,search,sync}.sh`. A função
`devorq::sanitize_input` ficou indefinida no agregador, fazendo
`lessons::capture` falhar com:

```
/home/nandodev/projects/devorq_v3/lib/lessons/crud.sh: line 32:
  devorq::sanitize_input: command not found
```

| # | Arquivo | Teste | Categoria |
|---|---------|-------|-----------|
| 1 | `debug.spec.ts:80` | devorq lessons capture deve funcionar | regressão story-003 |
| 2 | `devorq-cli.spec.ts:178` | devorq lessons capture deve capturar lição | regressão story-003 |
| 3 | `lessons.spec.ts:41` | devorq lessons capture deve criar arquivo JSON | regressão story-003 |
| 4 | `lessons.spec.ts:89` | devorq lessons capture deve suportar tags | regressão story-003 |
| 5 | `lessons.spec.ts:256` | devorq lessons compile deve compilar lição | cascata (depende de capture) |
| 6 | `lessons.spec.ts:291` | fluxo completo: capture → validate → approve → compile | cascata |
| 7 | `sandbox.spec.ts:94` | init → lessons → compact → context | cascata |
| 8 | `sandbox.spec.ts:114` | vários projetos não compartilham estado | cascata |
| 9 | `security-e2e.spec.ts:34` | should block dangerous characters in lessons capture | regressão story-003 |

**Categorias:**
- **infra** (path, dep, config) — 0 falhas.
- **ambiente** (Node, Chromium, permissões) — 0 falhas.
- **logica** (bug em teste ou framework) — 9 falhas, **todas** decorrentes da
  regressão story-003 e portanto fora de escopo desta story (lib/lessons* é
  `files_prohibited` para story-001).

---

## Comparação com baseline anterior (v3.6.0, 2026-05-12)

| Categoria | Antes (v3.6.0, 35%) | Agora (v3.8.4, 88.3%-100%) |
|-----------|---------------------|----------------------------|
| Comandos básicos (version, --help) | 4/4 (100%) | 4/4 (100%) |
| Inicialização (init) | 1/2 (50%) | 3/3 (100%) |
| Foundation (foundation) | 1/2 (50%) | 4/4 (100%) |
| GATE-0 (Exploration) | 0/2 (0%) | 2/2 (100%) |
| Lições (capture/search/list/...) | 0/7 (0%) | 9/13 (69% c/ regressão, 13/13 sem) |
| Gates (GATE-1 ... GATE-7) | 0/3 (0%) | 15/15 (100%) |
| Modos CLASSIC/AUTO (não existia em v3.6.0) | n/a | 8/8 (100%) |
| Sandbox isolation (não existia em v3.6.0) | n/a | 8/10 (80%, 2 cascata) |
| Security E2E (não existia em v3.6.0) | n/a | 6/7 (86%, 1 cascata) |

A v3.6.0 cobria ~17 testes (subset pequeno). A v3.8.4 expandiu a suite para
77 testes, cobrindo os mesmos cenários da v3.6.0 **mais**: modos CLASSIC/AUTO,
sandbox isolation, security E2E (input validation, SSH, exit codes, file
permissions), debug workflow.

---

## Detalhamento dos Testes

### `debug.spec.ts` (4 testes)
- verificar se devorq existe e é executável
- devorq version deve funcionar
- devorq init deve criar estrutura
- devorq lessons capture deve funcionar ← **regressão story-003**

### `devorq-cli.spec.ts` (20 testes)
- Comandos Básicos: version, --help, -h, sem args
- Inicialização: init, init detecta já existente, test
- Gates: gate 0, gate 1, flow
- Lições: capture ← **regressão**, search, list
- Contexto: context, compact
- Foundation: foundation, foundation status
- Debug: debug
- Stats: stats
- VPS: vps check

### `gates.spec.ts` (15 testes) — 100%
- GATE-0 DDD + env-context (2)
- GATE-0.5 Foundation (1)
- GATE-1 spec exists: sem/com/vazio (3)
- GATE-2 tests pass (1)
- GATE-3 context: criar/validar (2)
- GATE-4 lessons: sem/com (2)
- GATE-5 handoff (1)
- GATE-6 context7 (1)
- GATE-7 systematic debug (1)
- Fluxo completo de gates (1)

### `lessons.spec.ts` (13 testes) — 69%
- Captura: criar arquivo ← **regressão**, JSON válido, tags ← **regressão** (3)
- Busca: encontrar, nenhuma, múltiplas (3)
- Validação: com/sem Context7 (2)
- Aprovação: list, list com filtro (2)
- Migração: migrate (1)
- Compilação: compile ← **cascata** (1)
- Fluxo completo: capture→validate→approve→compile ← **cascata** (1)

### `modes-classic-auto.spec.ts` (8 testes) — 100%
- Seletor mode: classic, auto, mode-selector.sh (3)
- Fluxo CLASSIC: flow 0→7 (1)
- prd.json / loop-auto: prd done, DIR+number, número como path (3)
- prd-only: predicado de pendência (1)

### `sandbox.spec.ts` (10 testes) — 80%
- Isolamento: /tmp, múltiplos, destruir/recriar (3)
- Fluxo completo: init→lessons→compact→context ← **cascata**, não compartilha estado ← **cascata** (2)
- Gates em isolamento: GATE-1 fail, GATE-1 pass, todos gates (3)
- Cleanup: remover sandbox, sem resíduo (2)

### `security-e2e.spec.ts` (7 testes) — 86%
- Input validation: dangerous chars ← **regressão**, path traversal (2)
- SSH validation: VPS settings, StrictHostKeyChecking (2)
- Exit codes: consistentes, missing args (2)
- File permissions: secure (1)

---

## Como Reproduzir (local)

```bash
cd /home/nandodev/projects/devorq_v3/e2e-tests
npm install                         # se primeira vez
npx playwright install chromium     # se primeira vez
npx playwright test                 # roda 77 testes (~15-20s)
npx playwright test --reporter=line # output compacto
npx playwright test --ui            # modo interativo (debug)
```

Ou via CI wrapper:
```bash
bash scripts/ci-test.sh             # roda FASE 1-5.6 (inclui E2E)
```

Para modo strict (bloqueante em CI):
```bash
DEVORQ_E2E_STRICT=1 bash scripts/ci-test.sh
```

---

## Comando para CI / `devorq verify`

A partir desta story, `devorq verify` reporta o status de E2E via `GATE-E2E`
(novo gate em `lib/gates.sh`).

```bash
DEVORQ_ROOT="$PWD" bash lib/gates.sh
# ou
devorq verify
```

**Critério de bloqueio atual:** GATE-E2E é **informativo (não-bloqueante)** —
retorna 0 mesmo se a suite E2E falhar parcialmente. A promoção para bloqueante
fica para um próximo sprint, após observarmos a estabilidade ao longo de 2-3
releases.

---

## Próximos Passos (fora do escopo desta story)

1. **Promover GATE-E2E a bloqueante** após 2-3 sprints de estabilidade (meta
   v3.8.7+).
2. **Adicionar cobertura para novos comandos** que entrarem em v3.8.5+
   (dispatchers do refactor de `bin/devorq`).
3. **Rodar E2E em paralelo com unit tests** no CI (separar jobs para feedback
   mais rápido).
4. **Adicionar visual regression** se algum dia DEVORQ ganhar UI web (hoje
   é puro CLI/bash, então desnecessário).
5. **Tracking da regressão story-003** — quando o peer estabilizar, re-rodar
   a suite e atualizar este documento.

---

**Origem:** Story 1 do sprint v3.8.5 dogfooding
**Mantido por:** Nando (nandinhos) + DEVORQ agents
**Workflow DEVORQ:** GATE-0 → GATE-0.5 → GATE-1 (revival) → GATE-E2E (novo)
