# Auditoria Técnica Profunda — DEVORQ v3.8.5

> **Data:** 2026-06-26 · **Alvo:** `main` @ `36d0d74` (= tag `v3.8.5`) · **Repo:** github.com/nandinhos/devorq_v3
> **Método:** auditoria multi-agente (34 agentes, ~1,74M tokens, 426 tool-calls) com leitura profunda de 10 dimensões, **verificação adversarial** dos achados críticos/altos, verificação dinâmica (execução das suites seguras + shellcheck) e síntese. Achados-âncora reconferidos manualmente no código pelo mantenedor da auditoria.
> **Cobertura:** ~20.900 linhas de Bash (98 `.sh`), 70 docs, suites bats/Playwright, 9 skills.

---

## 1. Diagnóstico Executivo

O DEVORQ v3 é um orquestrador de metodologia **bem andaimado na superfície e frágil no núcleo de execução**. A casca — roteador/dispatcher, hardening de segurança de entrada, captura de lições, documentação — é real e, em vários pontos, de boa qualidade sênior. Mas as **três promessas centrais do produto — automação confiável (AUTO), enforcement por gates e rastreabilidade — são em grande parte teatro**: o código que deveria sustentá-las não roda, não persiste estado, ou aceita qualquer coisa como sucesso.

O padrão se repetiu de forma **independente em 5 das 10 dimensões auditadas** (harness, integração-de-agentes, débitos, lições/sync, observabilidade), o que torna o achado robusto e não-anedótico:

- **"Verde" não significa "verificado".** O modo AUTO pode marcar uma story como *done* (a) **sem implementar nada** quando rodado pela CLI sem um agente-motor (`DEVORQ_DELEGATE_FN` ausente → delegação `SIMULATED` + `check-story` fail-open), (b) **sem commitar** mesmo no caminho com agente (a chamada de `git_commit` está literalmente comentada em `loop-auto.sh:792`) e (c), no pior caminho, **destruindo o `prd.json`** (mv de um `mktemp` vazio). Os pontos (b) e (c) e a ausência de retomada valem **independentemente** de haver agente; só (a) depende da execução sem driver. O seletor de modo ainda aponta para um **fork obsoleto v1.0.0** do loop.
- **Os gates são, na maioria, checagens de presença cosmética.** Rótulos "BLOQUEANTE" que sempre retornam 0; `GATE-5.5` e `GATE-E2E` ficam fora do pipeline do `flow`; `gates_completed` **nunca é persistido em runtime**, então não há retomada (`--resume`) e todo handoff reporta "7/7 pendentes".
- **A camada de observabilidade lê estado-fantasma.** `stats`, `debug` e `compact` leem campos (`gates_completed`, `last_test.json`, `.errors`) que **nenhum código de produção escreve** — só fixtures de teste. Não há trilha de execução persistente nem `run_id` correlacionando `flow → gate → verify → commit → lição`.
- **O sync de lições para o HUB está 100% quebrado** (SQL gerado com aspas duplas = identificadores no PostgreSQL) e **sai com `EXIT_SUCCESS` mesmo sincronizando zero lições** — falha silenciosa total.
- **O CI não protege o que importa:** as suites de **segurança e de sync não rodam em CI**, o ShellCheck roda com `|| true` (decorativo), o **E2E está cronicamente vermelho** (npm ci sem lockfile) e nunca bloqueia, e o passo `bash bin/devorq test` (`ci.yml:30`) é um **self-test oco** — confirmei executando que ele imprime apenas `[OK] Estrutura OK` (checagem de estrutura via `workflow.sh:94`), **não os 68 testes de `unit-tests.sh`**. Ou seja, o suite unitário não roda no caminho documentado.

**Contraponto honesto — o que está genuinamente bom:** o refactor arquitetural router→dispatcher→domínio é real (`bin/devorq` é um roteador puro); o **hardening de segurança de entrada é sólido e foi auditado** (sanitização na captura, whitelist SSH em duas camadas, patch de RCE F-01 fechado, `jq -n --arg` em vez de interpolação); e **6 dos issues conhecidos de abril foram confirmadamente corrigidos** (KI1, KI2, KI4, KI5, RCE). A auditoria gerou **47 achados novos** além dos reviews anteriores, confirmou **24** ainda presentes e fechou **10** (6 corrigidos + 4 parcialmente).

### Veredito por dimensão

| # | Dimensão | Saúde | Nota |
|---|----------|-------|------|
| 1 | Arquitetura geral | 🟡 Adequado | Camadas reais, mas partição comando→módulo vaza por ordem de glob |
| 2 | Engenharia de harness | 🔴 Frágil | AUTO marca *done* sem fazer/commitar; CLASSIC sem retomada |
| 3 | Hooks & Gates | 🔴 Frágil | Maioria cosmética; rótulos BLOQUEANTE superestimados |
| 4 | Segurança operacional | 🟡 Adequado | Entrada bem defendida; sync com injeção root + defaults hardcoded |
| 5 | Qualidade de código | 🔴 Frágil | 0 erros shellcheck, mas ~652 linhas de código morto e shadowing |
| 6 | Testes & validação | 🔴 Frágil | Suites de segurança/sync fora do CI; E2E sempre vermelho |
| 7 | Observabilidade | 🔴 Frágil | Lê estado que o runtime nunca grava; sem trilha persistente |
| 8 | Integração com agentes | 🔴 Frágil | "Agnóstico" mas acoplado ao Hermes; fork obsoleto ativo |
| 9 | Experiência do operador | 🟡 Adequado | Observabilidade e confirmações boas; papercuts de UX/DX corrigíveis |
| 10 | Débitos & panes ocultas | 🔴 Frágil | Wipe de prd.json, portabilidade BSD, estado-fantasma |

**Severidade dos 81 achados:** **1 crítico-de-impacto** (o wipe de `prd.json`, reclassificado de "alto" pela verificação adversarial — ver §5) · **10 altos** · **42 médios** · **28 baixos**. Os 11 achados do topo (1 crítico + 10 altos) passaram por **verificação adversarial independente** (segundo agente reconferindo a evidência); os 70 médios/baixos têm evidência `file:line` de um único leitor.

> ⚠️ **Risco #1 a tratar hoje:** `lib/auto.sh:152-179` (`mark_pass`) pode **zerar o `prd.json`** — perda total da lista de stories e do progresso. Correção de esforço baixo (trocar `[[ -f ]]` por `[[ -s ]]` + `jq empty`). Detalhe em §6 e §9.
>
> ✅ **CORRIGIDO** na branch `fix/auditoria-fase1-estabilizacao` (commit `ae9776e`), com teste de regressão. Ver **Apêndice D** para o status completo da Fase 1.

---

## 2. Situação Git / Ambiente

### 🔴 Achado crítico de risco operacional (headline)

No início da auditoria, **o diretório local `/home/nandodev/projects/devorq_v3` estava completamente vazio**. O orquestrador usado no dia a dia havia desaparecido do disco, e o wrapper instalado `~/.local/bin/devorq` (`exec …/devorq_v3/bin/devorq "$@"`) apontava para um caminho inexistente — ou seja, **o comando `devorq` estava quebrado nesta máquina**. Não havia backup local nem cópia de trabalho alternativa (`projects/devorq-history` ao lado é um app Next.js não relacionado). **A única cópia canônica sobrevivente era o remoto no GitHub.** Isso é um **ponto único de falha**: uma perda de disco/`rm` acidental teria custado todo o trabalho não-publicado.

**Normalização aplicada (não-destrutiva, reversível):** `git clone` do remoto para o diretório vazio. Restaurou o working tree para `v3.8.5` e **consertou o CLI quebrado**. Estratégia de reversão trivial: `rm -rf` do clone (nada a perder, pois o diretório estava vazio).

### Estado pós-normalização

| Item | Estado |
|------|--------|
| `main` local ↔ `origin/main` | **0 / 0 — sincronizado**, working tree limpo, em `36d0d74` = `v3.8.5` |
| Branches remotas | `main`; `copilot/fix-playwright-e2e-job` (PR #6, +2 commits); `fix/code-review-2026-06-02` (mergeada) |
| PRs abertos | **#6** (draft) — conserta E2E Playwright, **sem merge** há semanas |
| Branch `fix/code-review-2026-06-02` | Totalmente mergeada (0 à frente / 26 atrás) → **stale, candidata a `git push origin --delete`** |
| Tags | até `v3.8.5`; **`v3.8.4` não existe** (salto `v3.8.3` → `v3.8.5`) embora docs a referenciem |
| **CI atual** | **E2E VERMELHO no `main`** (run do push v3.8.5 falhou em 12s); job CI verde |

### Inconsistências de versão / documentação (doc drift, com evidência)

- `.devorq/version` = **`3.8.4`** enquanto `VERSION`, `bin/devorq` (`DEVORQ_VERSION`) e a tag = `3.8.5` (drift de estado runtime).
- `CHANGELOG.md:5` com **placeholder literal não resolvido**: `## [VERSION] — 2026-06-04`. `scripts/sync-version.sh` não o enxerga.
- `SPEC.md:54,266` citam o módulo **`lib/commands/execution.sh` que não existe** (foi removido no refactor).
- **Contradição de cobertura E2E no mesmo release:** `SPEC.md:360,514` afirmam "77/77 = 100% determinístico"; `CHANGELOG.md:105` diz "68/77 = 88.3%".
- Números de LOC do refactor de lições divergem entre docs (`1045→96` vs `1045→91` vs `995→91`; real = 96).
- `SPEC.md` contradiz a si mesmo nas metas de qualidade (`~40%` vs `82%`; `38/38` vs `46/46` testes).
- Artefatos de runtime **versionados**: `.devorq/auto/.last-branch` (branch AUTO stale de 25/04) e `state/lessons/captured/*.json` commitados no repo.

---

## 3. Mapa Arquitetural

```
bin/devorq (180 LOC)            ← roteador puro: case → devorq::cmd_*  (sem regra de domínio)
  ├─ source lib/{helpers,visual,gates,context,lessons}.sh   (libs core, ordem com intenção de dependência)
  └─ source lib/dispatchers/*.sh  (glob alfabético: delivery, discovery, init, state, workflow)
        └─ cada dispatcher sourceia seus lib/commands/*.sh  e expõe help_<area>()

lib/ (9.660 LOC)
  ├─ commands/      domínio: workflow, exploration, brainstorm, grill, auto, lessons, foundation, ddd, ...
  ├─ dispatchers/   roteamento por área (delivery, discovery, init, state, workflow)
  ├─ lessons/       crud · search · validate · sync   (split modular do antigo lessons.sh monolítico)
  ├─ gates.sh (534) GATE 0,0.5,1-7,5.5,e2e   · rules.sh (731) hierarquia global→local + git hooks
  ├─ context7.sh    integração de validação de docs (CLI > MCP > API > none)
  ├─ context.sh · stats.sh · debug.sh · compact.sh   camada de estado/observabilidade
  └─ vps.sh · commit.sh · unify.sh · spec.sh · visual.sh

skills/   ddd-deep-domain · devorq-auto · devorq-code-review · devorq-mode · env-context ·
          grill-with-docs · project-foundation · scope-guard · security-hardening
scripts/ (5.586 LOC)  suites de teste (unit/security/pipeline/ci/e2e) + sync-{push,pull}.py + sync-version
.devorq/ .devorq-auto/   estado runtime (context, foundation JSONs, lessons capturadas, .last-branch)
```

### Análise crítica

**O que é genuíno:** a separação **entry (router) → dispatch → domínio** foi de fato implementada (commit `ab556c4`). `bin/devorq:122-177` é um `case` que apenas delega; o bootstrap valida diretórios e aborta com erro claro; a ordem de carregamento das libs core é documentada.

**Onde a arquitetura vaza:** os **limites de dispatcher não particionam o conjunto de comandos**. Módulos como `commands/workflow.sh` e `commands/exploration.sh` são sourceados por **múltiplos** dispatchers, e como o `source` é feito por **glob alfabético** (`bin/devorq:45`), **a última definição vence**. No único ponto em que essa sobreposição encontra duas definições conflitantes — `devorq::cmd_test` (`lib/commands/test.sh:6` roda `unit-tests.sh` vs `lib/commands/workflow.sh:94` faz só `bash -n`) — **`devorq test` executa a checagem de sintaxe, não a suíte de testes**, contrariando o mapeamento documentado. *Reconferido manualmente: confirmado.*

**Débito estrutural de duplicação:** existem **três árvores de módulos órfãs** (`bin/commands/`, `lib/commands/cli/`, `lib/commands/lessons/` — ~652 linhas) que **nunca são carregadas em runtime mas são testadas** por `scripts/test-commands.sh`. Isso é uma armadilha de manutenção: quem abre `lib/commands/lessons/validate.sh` (nome óbvio) corrige código morto, enquanto o validador vivo é `lib/lessons/validate.sh`. E o guard que deveria detectar isso (`verify-dispatch.sh:22`) virou no-op após o refactor.

**Acoplamento por ordem de carregamento** (em vez de imports explícitos) é a fragilidade arquitetural raiz: qualquer renomeação/reordenação de dispatcher pode trocar silenciosamente a função efetiva.

---

## 4. Lista de Pontos Fortes (preservar)

**Arquitetura**
- `bin/devorq` é roteador puro real, sem lógica de domínio no entry point (`bin/devorq:122-177`).
- Padrão de dispatcher consistente, com cabeçalho documentando comando→módulo (`lib/dispatchers/delivery.sh:7-18`).
- Bootstrap determinístico e fail-fast (`bin/devorq:44-54`).

**Segurança (a dimensão mais madura)**
- Patch **F-01 fechou o RCE** via `config-source`: `lib/context7.sh:37-45` lê `key=value` com whitelist de chaves e `declare -gx`, sem `source <(grep)` — **KI1 corrigido**.
- **Sanitização na captura** remove `$ \` ( ) ;` dos campos de lição via `python3` passando input como `argv` (sem `eval`) — `lib/lessons/crud.sh:21-38`.
- **Whitelist SSH em 2 camadas** (blocklist de metacaracteres + validação por subcomando), auditada contra bypass `ls | sh` (`lib/vps.sh:125-184`).
- `StrictHostKeyChecking=yes` + `UserKnownHostsFile` fixo em todas as conexões; path traversal guardado com `realpath` + prefixo; redação de credenciais em log.
- Chamadas Context7 montam JSON com `jq -n --arg` (`lib/context7.sh:264,304`) — sem injeção de shell via conteúdo de lição.

**Engenharia / qualidade**
- `GATE-5` gera handoff de forma **atômica e segura**: `mktemp` + `jq empty` (valida) + `mv` no mesmo FS + `trap` de limpeza (`lib/gates.sh:356-368`). **Padrão correto, a ser generalizado.**
- **Escrita atômica `> tmp && mv`** consistente em todo `lib/lessons/*`, `context.sh`, `stats.sh`, `unify.sh`.
- Dependências externas **sempre guardadas** com `command -v` antes do uso (jq em dezenas de pontos, python3, ssh).
- Namespacing `devorq::` em 226/276 funções; **0 erros de shellcheck** em 69 arquivos.
- Git `commit-msg` hook bem feito: bloqueia `Co-Authored-By`, valida formato, instalação idempotente (`lib/rules.sh:662-715`).

**Skills / agentes**
- `devorq-code-review` tem política explícita **human-in-the-loop**: nunca publica no PR sem aprovação (gate FASE 6).
- Telemetria de **falha** do loop AUTO é boa: `failures.md` legível, `lessons.json` estruturado, `pending/*.json` com contexto (`loop-auto.sh:86-301`).
- Sessões de **grill** têm `session_id` timestampado e anexam premises/design-flaws/tradeoffs — **a única rastreabilidade de decisões real do sistema** (`lib/commands/grill.sh:113-378`).

---

## 5. Lista de Débitos Técnicos (por severidade)

> **Profundidade de verificação:** o tier CRÍTICO+ALTO (11 achados) passou por **verificação adversarial independente** — um segundo agente reconferiu cada evidência e ajustou/rebaixou a severidade; os 3 achados-âncora ainda foram reconferidos manualmente. Os tiers MÉDIO/BAIXO têm evidência `file:line` de **um único leitor** (não passaram por segundo par de olhos). `known_status`: 🆕 novo · ✅ confirmado presente · 🟠 parcialmente corrigido.

### 🔴 CRÍTICO (impacto) — perda de dados

| Evidência | Achado | Status |
|-----------|--------|--------|
| `lib/auto.sh:152-179` | **`mark_pass` sobrescreve `prd.json` com `mktemp` vazio** → perda total da PRD. `tmp=$(mktemp)` (0 byte); ramo python3 suprime erros (`2>/dev/null`); fallback sem python3 faz `sed -i` direto no `$prd`; guarda `[[ -f "$tmp" ]]` é sempre verdadeira e `mv "$tmp" "$prd"` (l.177) zera o arquivo deterministicamente. *Reconferido manualmente.* | 🆕 |

> A verificação adversarial rebaixou para "alto" por ser tooling interno; classifico como **crítico de impacto** porque é **perda de dados silenciosa** da fonte de verdade do AUTO. Correção de esforço **baixo**.

### 🔴 ALTO (10)

| Dim | Evidência | Achado | Status |
|-----|-----------|--------|--------|
| harness | `loop-auto.sh:603-613` + `check-story.sh:178-196` | **Delegate `SIMULATED` + check-story fail-open** marcam story *done* sem implementar nada (sem `DEVORQ_DELEGATE_FN`, `return 0`; sem runner detectado, `exit 0`). *Reconferido.* | 🆕 |
| harness | `lib/commands/workflow.sh:145-151`; grep `gates_completed` | **CLASSIC sem persistência de `gates_completed`** → sem retomada; todo `flow` recomeça do GATE-0; handoff sempre "7/7 pendentes". | 🆕 |
| integr. | `skills/devorq-mode/loop-auto.sh` (v1.0.0, 353 LOC) | **Fork obsoleto do loop AUTO é o que o seletor de modo aponta** (`devorq-mode/SKILL.md:48`); diverge massivamente do canônico v1.2.1 (858 LOC). | ✅ |
| integr. | `devorq-mode/loop-auto.sh:299-319` | **Delegação no-op + verificação sem detecção de diff** → no fork antigo, marca *done* **e comita** sem código. | ✅ |
| lessons | `scripts/sync-push.py:240,253-281` | **`sync-push.py` gera SQL inválido** (literais com aspas duplas = identificadores no PG) → **push 100% não-funcional**. *Reconferido.* | ✅ |
| lessons | `lib/lessons/validate.sh:36-62,109-160` | **Validação Context7 aceita qualquer resposta** não-vazia; em AUTO **auto-valida + auto-aprova + auto-compila** lições em skills sem revisão. | ✅ |
| testes | `.github/workflows/*`; grep `security-tests\|test_sync` | **Suites de segurança e de sync não rodam em nenhum CI**; só `ci-test.sh` (smoke) + `devorq test` + `ddd validate`. | 🆕 |
| obs. | `lib/stats.sh:89-99`, `debug.sh:55-79`, `compact.sh:26` | **Observabilidade lê estado que o runtime nunca grava**; writes só em fixtures. GATE-7 é no-op de falso "OK". | 🆕 |
| obs. | `lib/helpers.sh:83-87` | **Sem trilha de execução persistente**; `info/log/warn/error` são só `echo`; nenhum arquivo `.log`; sem `run_id` correlacionando runs. | 🆕 |
| arq. | `lib/commands/{test,workflow}.sh` + `bin/devorq:45` | **Sobreposição de dispatcher → shadowing de `devorq::cmd_test`** (e `cmd_version`, `cmd_stats`): vencedor depende da ordem de glob. **Confirmado executando `bash bin/devorq test` → imprime só `[OK] Estrutura OK`, não os 68 testes de `unit-tests.sh`.** *Reconferido.* | ✅ |

### 🟡 MÉDIO (42 — destaques)

| Dim | Evidência | Achado | Status |
|-----|-----------|--------|--------|
| debitos | `lib/auto.sh:218` vs `loop-auto.sh:444` vs `devorq-mode:153` | **AUTO triplicado com diretórios de estado divergentes** (`.devorq/auto/` vs `.devorq-auto/`) → estado não compartilhado entre modos (rebaixado de alto na verificação). | ✅ |
| harness | `loop-auto.sh:792-793` | AUTO canônico marca *done* **sem commitar** (`git_commit` comentado); todas as stories acumulam mudanças não-commitadas numa branch. *Reconferido.* | 🆕 |
| harness | `loop-auto.sh` `propose_break` | `propose_break` **bloqueia em stdin mesmo com `--force-continue`** → "autônomo" trava sem TTY. | 🆕 |
| gates | `lib/gates.sh:8` vs `:310` | **GATE-4 rotulado BLOQUEANTE mas sempre passa** e não verifica relevância. | 🆕 |
| gates | `lib/commands/workflow.sh:145` | **GATE-5.5 (UNIFY) e GATE-E2E nunca executados** no pipeline do `flow`. | 🆕 |
| gates | `lib/commands/utils.sh:102` | **self-build pula GATE-0/0.5 e reporta "7/7 verdes"** rodando 5. | 🆕 |
| gates | `lib/gates.sh:204-205` (`set -e`) | **GATE-2 aborta o processo** em vez de reportar teste vermelho em `devorq gate 2`. | 🆕 |
| gates | `lib/gates.sh:530` vs dispatch | **`devorq gate e2e`/`gate 8` retornam "Gate inválido"** (inalcançáveis pelo despacho). | ✅ |
| seg. | `sync-push.py:160-163,265-279` | **Injeção de comando remoto (root)** nos scripts python de sync por ausência de escape shell. | 🆕 |
| seg. | `lib/vps.sh:17-19` (+ replicado) | **IP de produção + porta + container + `VPS_USER=root` hardcoded** e versionados. | ✅ |
| qual. | `lib/commands/cli/`, `lib/commands/lessons/` | **~652 linhas de código morto duplicado** que só os testes carregam. | ✅ |
| qual. | `bin/devorq:18` | **`shellcheck disable` em bloco** (~25 códigos) mascara 44 warnings reais. | ✅ |
| testes | `.github/workflows/ci.yml:50` | **ShellCheck no CI roda com `\|\| true`** — lint decorativo que nunca falha o build. | 🆕 |
| testes | `e2e.yml:31` + `.gitignore:8` | **E2E sempre vermelho:** `npm ci` exige `package-lock.json` que o `.gitignore` ignora. | ✅ |
| obs. | `lib/stats.sh:137` | `stats::patterns` referencia variável **`$captured` indefinida** (aborta sob `set -u`). | 🆕 |
| obs. | `lib/visual.sh:109` | Detecção do método de verificação **bugada**: glob dentro de `[[ -f "...playwright.config.*" ]]` não expande. | 🆕 |
| integr. | `AGENTS.md:3` vs `loop-auto.sh` | **"Agnóstico a qualquer LLM" contradiz acoplamento ao Hermes** (`delegate_task`/`execute_code`/`skill_view` nunca definidos no repo). | 🆕 |
| integr. | `lib/compact.sh:13-72` | **Handoff não registra decisões por agente** — zero rastreabilidade entre agentes. | 🆕 |
| lessons | `sync-push.py:283-316` | **`sync-push` sai `EXIT_SUCCESS` mesmo sincronizando 0 lições / todas falhando.** | ✅ |
| lessons | `lib/lessons/crud.sh:59-61` | **ID de lição colide** por segundo+PID (`lesson_${%S}_$$`) → overwrite silencioso em captura em lote. | 🆕 |
| lessons | `sync-pull.py:111-138` | **`sync-pull` corrompe conteúdo multilinha**, descarta tags e grava em diretório órfão. | 🆕 |
| debitos | `CHANGELOG.md:5` | **Placeholder `[VERSION]` não substituído** e invisível ao `sync-version`. | 🆕 |
| debitos | `bin/devorq:24` | **Instalação por symlink quebra `DEVORQ_ROOT`** (sem `readlink -f`/`realpath`) — contradiz `INSTALL.md`. | 🆕 |
| debitos | `sed -i`/`date -r`/`realpath`/`declare -A` | **Construtos GNU-only quebram em BSD/macOS** sem guard de SO (13 ocorrências). | 🆕 |

*(Lista completa dos 42 médios + 28 baixos disponível no anexo de dados `audit_result.json`; os IDs `DQ-xxx` no §10 rastreiam cada um.)*

### Issues conhecidos (KI) — status verificado contra v3.8.5

| KI | Descrição original | Status atual (evidência) |
|----|--------------------|--------------------------|
| KI1 | Command injection no validador Context7 | ✅ **Corrigido** (`lib/context7.sh:37-45`, patch F-01; `jq -n --arg`) |
| KI2 | Hooks criavam `.devorq/.devorq/` aninhado | ✅ **Resolvido** (sem hooks pre/post_tool no repo) |
| KI3 | Sync push não-funcional (4 defeitos) | ✅→❌ **Reincidente em nova forma**: refatorado p/ python, mas SQL com aspas duplas = push ainda 100% quebrado |
| KI4 | BATS com path do autor hardcoded | ✅ **Não reproduz** (não há `.bats`; sem paths `/home/` em tests) |
| KI5 | Plugin setup sobrescreve config | ✅ **Ausente** (sem `setup.sh`/`plugins` no repo) |
| KI6 | Context7 aceita qualquer resposta | ❌ **Confirmado presente** (`lib/lessons/validate.sh:109-114`) |
| KI7 | AUTO duplicado | 🟠 **Pior que o reportado**: são **3** implementações divergentes |
| KI8 | Function shadowing | 🟠 lib↔bin corrigido, mas **novo shadowing** surgiu no refactor de dispatchers (`cmd_test`, `lessons::help`) |
| KI9 | E2E vermelho | ❌ **Confirmado** (npm ci sem lock) |
| KI10 | `--version` não reconhecido | ❌ **Confirmado** (`bin/devorq:164-173`) |

---

## 6. Lista de Panes Ocultas

Problemas que ainda **não explodiram em produção** mas vão, mapeados por gatilho:

1. **Wipe do `prd.json`** (`lib/auto.sh:157-177`) — dispara quando python3 falta **ou** quando o `prd.json` está malformado / `story_id` tem aspas. Em ambiente sem python3, é **determinístico**. Gatilho silencioso, perda total.
2. **Story "concluída" sem trabalho nem commit** — qualquer `devorq auto` rodado **fora de um agente Hermes** (CLI direta) marca stories como `passes=true`/`done` sem implementar e (no fork antigo) comita vazio. Gatilho: rodar AUTO num projeto sem runner de teste.
3. **Retomada inexistente** — interromper um `devorq flow` no GATE-5 perde todo o progresso; o handoff entregue ao próximo agente diz "0/7". Gatilho: qualquer sessão longa interrompida.
4. **`stats::patterns` aborta sob `set -u`** (`lib/stats.sh:137`, `$captured` indefinida) — gatilho: rodar `devorq stats` no caminho de "padrões".
5. **Colisão de ID de lição** (`crud.sh:59-61`) — captura em lote (via `unify`/AUTO) no mesmo segundo+PID sobrescreve silenciosamente. Gatilho: pico de captura.
6. **JSON de lição inválido sem `jq`** (`crud.sh:90-101`) — fallback monta JSON cru sem escape; um título com `"` quebra **todas** as leituras subsequentes. Gatilho: ambiente sem jq + caractere especial.
7. **Corrupção de estado por concorrência** — sem lock e com nome de tmp determinístico (`${f}.tmp`); dois processos AUTO/captura simultâneos corrompem o JSON. Gatilho: paralelismo.
8. **Portabilidade BSD/macOS** — `sed -i` sem sufixo consome o próximo arg; `date -r`/`realpath`/`readlink -f` ausentes; `declare -A` exige Bash 4+. Gatilho: rodar fora de Linux/WSL.
9. **Instalação por symlink quebrada** — `DEVORQ_ROOT` não resolve symlink; o método documentado em `INSTALL.md` falha. Gatilho: `ln -s` em diretório diferente.
10. **Config MCP grava `${OPENAI_API_KEY}` literal** (`lib/context7.sh:489-500`, heredoc com aspas simples) — gatilho: `_install_mcp` → integração nunca autentica.

---

## 7. Matriz de Hooks e Gates (alvo ideal)

**Estado atual:** o pipeline existe (gates 0–7 + 0.5/5.5/e2e), mas o **enforcement é em grande parte ilusório**: a maioria valida apenas presença/tamanho de arquivo; `GATE-4 "BLOQUEANTE"` sempre retorna 0; `GATE-6` valida com qualquer resposta não-vazia; **nenhum gate valida o diff/output da implementação**; o único hook real é o `commit-msg`. `gates_completed` nunca persiste → sem retomada; GATE-7/stats leem estado-fantasma.

| # | Hook / Gate | Momento | Tipo | Status | Prioridade | Risco mitigado |
|---|-------------|---------|------|--------|-----------|----------------|
| 1 | Guard de partição dispatcher→módulo (função única) | pre-flow (load-time) | automático | ausente | **P1** | Shadowing não-determinístico (`cmd_test` roda syntax-check) |
| 2 | GATE-0/0.5 Project Foundation | pre-flow / gate 0-0.5 | crítico | parcial | **P0** | Implementação sem escopo/contexto; self-build pula |
| 3 | Scope Guard (whitelist FAZER/NÃO FAZER) | pre-implementação | crítico | parcial | **P1** | Over-engineering / scope creep |
| 4 | GATE-1 SPEC presente e coerente | gate 1 | automático | parcial | **P1** | Spec vazia/placeholder aprovada |
| 5 | GATE-2 Testes comportamentais (fail graceful) | gate 2 | crítico | parcial | **P0** | GATE-2 aborta sob `set -e` em vez de reportar |
| 6 | GATE-3 Context/Handoff lint | gate 3 | automático | parcial | **P2** | Contexto malformado propagado ao próximo agente |
| 7 | GATE-4 Relevância de lições | gate 4 | automático | parcial | **P2** | Falso enforcement (BLOQUEANTE que sempre passa) |
| 8 | **Gate pós-implementação (diff + lint + aceite)** | pós-implementação | crítico | **ausente** | **P0** | Nenhum gate valida o efeito da implementação |
| 9 | **GATE-5 Handoff com persistência de `gates_completed`** | gate 5 | crítico | **ausente** | **P0** | Sem `--resume`; handoff sempre "7/7 pendentes" |
| 10 | GATE-5.5 UNIFY (fechamento) | gate 5.5 | automático | parcial | **P2** | Gate órfão: nunca roda em `flow` |
| 11 | GATE-6 Context7 validação semântica | gate 6 / validação de lições | crítico | parcial | **P1** | Envelope de erro JSON-RPC aceito como "OK"; lição alucinada selada |
| 12 | GATE-7 Observabilidade real (debug check) | gate 7 | automático | parcial | **P1** | No-op: lê estado-fantasma, falso "OK" |
| 13 | GATE-E2E acionável e gating no CI | pós-impl. / gate 8 | automático | parcial | **P2** | E2E inalcançável pela CLI; workflow 100% vermelho |
| 14 | Hook pre-commit (convenção + secret scan + staged-only) | pre-commit | automático | parcial | **P1** | `git add -A` versiona `.env`/segredos |
| 15 | Hook pre-push (ShellCheck gating + suites de segurança) | pre-push / CI | automático | **ausente** | **P1** | Lint decorativo (`\|\| true`); suites órfãs |
| 16 | **Gate pre-sync (SQL parametrizado + host whitelist + não-root)** | pre-sync | crítico | **ausente** | **P0** | Injeção de comando root no VPS; SQL quebrado |
| 17 | Gate de exit-code do sync | pre-sync (pós-push) | automático | **ausente** | **P1** | `sync-push` sai sucesso sincronizando nada |
| 18 | **Checkpoint AUTO por story (commit + diff-detection + fail-closed)** | loop AUTO (por story) | crítico | **ausente** | **P0** | `SIMULATED` + fail-open marcam *done* sem código |
| 19 | **Guarda de estado AUTO (escrita atômica + lock + path único)** | loop AUTO (por story) | crítico | **ausente** | **P0** | `mark_pass` zera `prd.json`; branch divergente entre modos |
| 20 | Trilha de execução / handoff entre agentes (`run_id`, decisão por agente) | toda a execução | automático | **ausente** | **P1** | Zero rastreabilidade de qual agente decidiu o quê |

> **Legenda de tipo:** *automático* = passa/falha sem humano · *manual* = requer aprovação do operador · *crítico* = bloqueia e exige decisão consciente (manual em modo CLASSIC, fail-closed em AUTO).

---

## 8. Plano de Evolução

### Fase 1 — Estabilização
**Objetivo:** eliminar as panes que fazem o orquestrador **mentir sobre o que executou** e estabelecer fonte única de verdade por função/módulo.
- DQ-001 Partição única comando→módulo (resolve shadowing `cmd_test`/`cmd_version`/`cmd_stats`) + roteamento de `--version`.
- DQ-002 Remover as 3 árvores órfãs testadas mas nunca carregadas.
- DQ-003 Consolidar AUTO numa única fonte canônica (eliminar 2 forks + estado de branch fragmentado).
- DQ-004 Corrigir `mark_pass` que zera o `prd.json` **(crítico)**.
- DQ-005 Fail-closed em delegate `SIMULATED` + exigir diff em `check-story`.
- DQ-006 Restaurar commit/checkpoint por story alinhado à SKILL.md.
- DQ-007 Persistir `gates_completed` + `--resume` no CLASSIC.
- DQ-008 Corrigir geração de SQL e exit codes do sync.
- DQ-009 Resolver symlink em `DEVORQ_ROOT`.

**Critério de saída:** nenhuma função `devorq::cmd_*`/`lessons::help` definida em >1 arquivo carregado (guard automatizado); `devorq test` roda `unit-tests.sh` e `devorq --version` responde; uma única implementação de AUTO; **impossível marcar story *done* sem diff git e commit**; `prd.json` nunca zerado; `flow` retomável; sync persiste ao menos 1 lição ponta-a-ponta com exit code fiel.

### Fase 2 — Segurança operacional
**Objetivo:** fechar a superfície de execução remota como root e os gates que carimbam conhecimento não-verificado.
- DQ-010 Eliminar injeção de comando (root no VPS) via `shlex.quote`/parametrização.
- DQ-011 Remover IP/usuário root hardcoded; exigir host explícito + usuário não-root.
- DQ-012 Validação Context7 real no GATE-6 (parsear `.result`/ausência de `.error`).
- DQ-013 Em AUTO sem Context7, marcar lições `skipped/unverified` e **nunca auto-compilar**.
- DQ-014 Commit seguro (diff/status + aviso de arquivos sensíveis) em vez de `git add -A`.
- DQ-015 Hardening SSH mux + pin da instalação npm do ctx7.
- DQ-016 Unificar e fortalecer `sanitize_input`.

**Critério de saída:** nenhum comando shell remoto por interpolação não-escapada (teste de regressão com payload malicioso); nenhum IP/root default versionado; GATE-6 falha de fato com endpoint quebrado (curl mockado); sanitização idêntica com/sem python3/jq.

### Fase 3 — Observabilidade
**Objetivo:** fazer a camada de relatório refletir a execução real.
- DQ-017 Instrumentar o runtime para gravar o que a observabilidade lê (`gates_completed`, `last_test.json`, `.errors`, `stuck_gates`).
- DQ-018 Log estruturado append-only (JSONL) por execução, com `run_id` propagado em `context.json` e lições.
- DQ-019 Corrigir `$captured` indefinida em `stats::patterns`.
- DQ-020 Corrigir detecção do método de verificação e logar resultado por story.
- DQ-021 Limpar glifos CJK corrompidos + lint anti-CJK no CI.

**Critério de saída:** `devorq stats` mostra gates reais; GATE-7 detecta falha de teste/gate travado; existe trilha por run com `run_id` ligando `flow→gate→verify→commit→lição`; zero CJK espúrio.

### Fase 4 — Integração avançada com agentes
**Objetivo:** resolver "agnóstico vs acoplado ao Hermes" promovendo `DEVORQ_DELEGATE_FN` a contrato oficial de adapter.
- DQ-022 Separar camada de regras (agnóstica) da camada de execução (Hermes); documentar `DEVORQ_DELEGATE_FN` no AGENTS.md + adaptadores de referência (Claude Code Task, Codex).
- DQ-023 Registrar decisões por agente no handoff (append-only: agente, fase, decisão, evidência, timestamp).
- DQ-024 Teto de concorrência (pool de 3) no code-review + limpar CJK dos prompts.
- DQ-025 Corrigir template MCP que grava `${OPENAI_API_KEY}` literal.

**Critério de saída:** AGENTS.md documenta o contrato e ≥1 adaptador não-Hermes funciona end-to-end; agente sem `delegate_task` recebe erro claro (não degradação silenciosa); handoff carrega trilha de decisões por agente.

### Fase 5 — Maturidade de harness pleno+
**Objetivo:** transformar gates cosméticos e CI decorativo em **enforcement real** — verde = verificado.
- DQ-026 Tornar o E2E do CI funcional e **gating** (commitar lock ou trocar `npm ci`) + wirar suites órfãs de segurança/sync.
- DQ-027 ShellCheck **gating** real (remover `|| true` e o disable em bloco).
- DQ-028 Unificar a sequência de gates em fonte única + reclassificar labels honestamente (incluir 5.5/e2e; corrigir despacho; guardar GATE-2 contra `set -e`).
- DQ-029 Padronizar portabilidade BSD/macOS (ou declarar suporte só-Linux).
- DQ-030 Robustez residual + limpeza de código morto (ID de lição único, JSON sem jq, locking, `verify-dispatch.sh`, `--strict`, CHANGELOG `[VERSION]`, heredoc órfão, scripts órfãos).

**Critério de saída:** workflow E2E verde e bloqueante; suites de segurança/sync no CI propagando exit code; ShellCheck bloqueia merge; fonte única de gates consumida por `flow` e self-build com labels fiéis; construtos GNU-only encapsulados.

---

## 9. Recomendações Práticas

> Cada recomendação rastreia a um ou mais achados confirmados. Campos: **problema · impacto · solução · prioridade · esforço · arquivos · critério de aceite**.

### R1 — Corrigir o wipe de `prd.json` `[crítico/baixo]`
- **Problema:** `mark_pass` move um `mktemp` vazio sobre `prd.json` em condições de erro/sem-python3.
- **Impacto:** perda total silenciosa da lista de stories e do progresso do AUTO.
- **Solução:** trocar a guarda por `[[ -s "$tmp" ]]` + `jq empty "$tmp"` antes do `mv`; no fallback sem python3, escrever em `$tmp` (nunca editar `$prd` in-place).
- **Arquivos:** `lib/auto.sh`.
- **Aceite:** removendo python3 do PATH (ou injetando `prd.json` malformado), `mark_pass` mantém o conteúdo de stories e `jq empty prd.json` retorna 0.

### R2 — Fail-closed no AUTO: nunca marcar *done* sem implementação/commit `[alto/médio]`
- **Problema:** delegate `SIMULATED` retorna 0 e `check-story` faz `exit 0` sem runner; `git_commit` está comentado.
- **Impacto:** `devorq auto all` pode marcar todas as stories `done` sem uma linha de código nem commit — falso positivo em escala.
- **Solução:** no ramo `SIMULATED`, retornar não-zero e abortar; `check-story.sh` deve exigir ≥1 verificação válida; exigir diff git antes de `mark_pass`; restaurar commit/checkpoint por story.
- **Arquivos:** `skills/devorq-auto/scripts/loop-auto.sh`, `check-story.sh`, `skills/devorq-mode/loop-auto.sh`.
- **Aceite:** `devorq auto` sem `DEVORQ_DELEGATE_FN` em projeto sem runner **não** marca `passes=true` e sai com código ≠ 0; após PASS real, `git log` mostra 1 commit por story.

### R3 — Consolidar AUTO em uma única fonte canônica `[alto/alto]`
- **Problema:** 3 implementações (`lib/auto.sh`, `devorq-auto`, `devorq-mode` v1.0.0) com namespaces e diretórios de estado divergentes; o seletor aponta para o fork obsoleto.
- **Impacto:** correções não propagam; modos leem/gravam arquivos de estado diferentes.
- **Solução:** eleger `skills/devorq-auto/scripts/loop-auto.sh` como única fonte; remover `devorq-mode/loop-auto.sh` e cópias byte-a-byte; reapontar `devorq-mode/SKILL.md`.
- **Arquivos:** `lib/auto.sh`, `skills/devorq-auto/scripts/loop-auto.sh`, `skills/devorq-mode/{loop-auto.sh,SKILL.md}`, `lib/commands/auto.sh`.
- **Aceite:** `grep loop-auto.sh` referencia um único caminho; ambos os modos usam o mesmo `.last-branch`.

### R4 — Partição única comando→módulo `[alto/médio]`
- **Problema:** módulos sourceados por vários dispatchers; identidade de função depende da ordem de glob; `devorq test` roda só `bash -n`.
- **Impacto:** comando crítico executa a implementação errada → falsa cobertura de testes.
- **Solução:** cada `lib/commands/*` sourceado por exatamente um dispatcher; renomear funções duplicadas (`cmd_test` de `workflow.sh` → `cmd_structure_check`); rotear `--version`/`-V`.
- **Arquivos:** `bin/devorq`, `lib/commands/{test,workflow,utils}.sh`, `lib/dispatchers/{init,workflow}.sh`.
- **Aceite:** `devorq test` imprime "ALL TESTS PASSED" de `unit-tests.sh`; teste novo falha se alguma `devorq::cmd_*` for definida em >1 arquivo carregado.

### R5 — Persistir `gates_completed` + `--resume` no CLASSIC `[alto/médio]`
- **Problema:** nenhum gate grava `gates_completed`; só fixtures escrevem.
- **Impacto:** todo `flow` recomeça do GATE-0; handoff sempre "7/7 pendentes".
- **Solução:** após cada gate passar, `ctx_set` (append em `gates_completed`); `cmd_flow` pula gates já completos com `--resume`.
- **Arquivos:** `lib/gates.sh`, `lib/commands/workflow.sh`, `lib/context.sh`, `lib/compact.sh`.
- **Aceite:** rodar `flow` até GATE-3 → `context.json` tem `gates_completed != []`; `devorq flow --resume` continua do GATE-4.

### R6 — Instrumentar observabilidade real + trilha JSONL `[alto/médio]`
- **Problema:** `stats`/`debug`/`compact` leem campos que o runtime nunca grava; `info/log` são só `echo`.
- **Impacto:** `devorq stats` sempre "0/7" e "Última: nunca"; GATE-7 é no-op; sem auditoria posterior.
- **Solução:** persistir `last_test.json`/`.errors`/`stuck_gates`; log append-only `.devorq/state/logs/run-<ts>-<pid>.jsonl` com `run_id` propagado.
- **Arquivos:** `lib/{gates,context,compact,stats,debug,helpers}.sh`, `bin/devorq`.
- **Aceite:** após um flow, existe `run-*.jsonl` parseável por `jq` com ≥1 linha por gate (run_id, status, timestamp); `devorq stats` mostra gates reais.

### R7 — Corrigir o sync (SQL parametrizado + exit codes) `[alto/médio]`
- **Problema:** SQL montado por interpolação com aspas duplas (= identificador no PG); `sys.exit(EXIT_SUCCESS)` mesmo com 0 lições.
- **Impacto:** nenhuma lição chega ao HUB e o usuário não percebe (exit 0); round-trip não preserva dados.
- **Solução:** `psycopg2` com parâmetros (`cursor.execute(sql, params)`) ou `psql -v`; acumular falhas e sair ≠ 0; formato sem ambiguidade no pull.
- **Arquivos:** `scripts/sync-push.py`, `scripts/sync-pull.py`, `scripts/test_sync.py`.
- **Aceite:** novo teste assere literais com aspas simples; push contra Postgres real persiste e pull reidrata a mesma lição; exit code reflete falhas.

### R8 — Validação Context7 semântica real `[alto/médio]`
- **Problema:** GATE-6 aceita qualquer corpo não-vazio; AUTO auto-aprova/compila sem critério.
- **Impacto:** lições alucinadas ganham selo "validated" e viram skills compiladas.
- **Solução:** exigir `.result` + ausência de `.error` (MCP) / estrutura esperada (API), casando o termo da query; em AUTO sem Context7, marcar `skipped` e nunca compilar.
- **Arquivos:** `lib/context7.sh`, `lib/lessons/validate.sh`, `lib/gates.sh`, `scripts/unit-tests.sh`.
- **Aceite:** stub de curl com `{"error":{...}}` → `ctx7_check` ≠ 0 e lição não marcada `validated`.

### R9 — Wirar suites de segurança/sync no CI + E2E gating `[alto/médio]`
- **Problema:** `security-tests.sh`/`test_sync.py` fora do CI; ShellCheck com `|| true`; E2E sempre vermelho e nunca required.
- **Impacto:** regressões de segurança passam despercebidas; o esforço de teste não rende proteção contínua.
- **Solução:** commitar `e2e-tests/package-lock.json` (remover do `.gitignore`) ou trocar por `npm install`; adicionar passos de `security-tests.sh`/`test_sync.py`/`pipeline-tests.sh` ao job; ShellCheck gating com baseline.
- **Arquivos:** `.github/workflows/{ci,e2e}.yml`, `.gitignore`, `scripts/pipeline-tests.sh`, `tests/security/test_lib.sh`.
- **Aceite:** E2E roda `npm ci` com sucesso em push limpo; job `test` falha se `test_sync.py`/`security-tests.sh` falham.

### R10 — Remover defaults root/IP hardcoded + fechar injeção de sync `[alto/médio]`
- **Problema:** IP de produção + `VPS_USER=root` versionados; injeção de comando remoto nos scripts python.
- **Impacto:** execução como root no VPS de produção; topologia da infra vazada no repo.
- **Solução:** exigir `DEVORQ_VPS_HOST` explícito (config fora do repo) + usuário não-root com sudo restrito; parametrizar todos os comandos remotos.
- **Arquivos:** `lib/vps.sh`, `scripts/sync-push.py`, `scripts/sync-pull.py`, `lib/lessons/sync.sh`.
- **Aceite:** `grep '187.108.197.199'` e `grep 'VPS_USER=root'` vazios; payload `$(touch pwned)` em campo de lição não executa.

### R11 — Remover árvores de módulos órfãs `[alto/médio]`
- **Problema:** `lib/commands/cli/`, `lib/commands/lessons/`, `bin/commands/` (~652 LOC) testadas mas nunca carregadas.
- **Impacto:** cobertura ilusória; risco de corrigir o arquivo morto e não o vivo.
- **Solução:** remover as árvores e os testes que as cobrem; reapontar `test-commands.sh` ao caminho real.
- **Arquivos:** `bin/commands/index.sh`, `lib/commands/cli`, `lib/commands/lessons`, `scripts/test-commands.sh`.
- **Aceite:** `grep 'commands/cli\|commands/lessons/index'` em `lib/`+`bin/` vazio; testes sourceiam só o caminho de produção.

### R12 — Contrato de adapter `DEVORQ_DELEGATE_FN` `[médio/médio]`
- **Problema:** "agnóstico a qualquer LLM" mas execução depende de `delegate_task`/`execute_code` nunca definidos.
- **Impacto:** em Claude Code/Codex/Antigravity, AUTO e code-review degradam silenciosamente.
- **Solução:** separar camada de regras (agnóstica) da execução (Hermes); documentar `DEVORQ_DELEGATE_FN` no AGENTS.md + adaptador de referência.
- **Arquivos:** `AGENTS.md`, `docs/ARQUITETURA-AGNOSTICA-LLM.md`, `skills/devorq-auto/SKILL.md`, `skills/devorq-code-review/SKILL.md`.
- **Aceite:** ≥1 adaptador não-Hermes funcional; agente sem `delegate_task` recebe erro claro.

### R13 — Reclassificar gates honestamente + fonte única `[médio/médio]`
- **Problema:** rótulos BLOQUEANTE que sempre passam; GATE-5.5/E2E fora do `flow`; self-build mente "7/7".
- **Solução:** array único de gates exportado em `gates.sh`, consumido por `cmd_flow` e self-build; mensagem reflete gates executados; guardar GATE-2 contra `set -e`.
- **Arquivos:** `lib/gates.sh`, `lib/commands/{workflow,utils}.sh`.
- **Aceite:** `flow` e self-build consomem a mesma fonte; `devorq gate e2e` funciona; GATE-2 reporta FAIL sem derrubar a CLI.

### R14 — Padronizar portabilidade BSD/macOS `[médio/médio]`
- **Problema:** `sed -i` sem sufixo, `readlink -f`, `date -r`, `declare -A`, `realpath` GNU-only; symlink quebra `DEVORQ_ROOT`.
- **Solução:** resolver symlink em `bin/devorq` antes do `dirname`; wrapper portável de `sed -in-place`; OU declarar suporte só-Linux em INSTALL.md.
- **Arquivos:** `bin/devorq`, `lib/{auto,unify,helpers}.sh`, `lib/lessons/{sync,search}.sh`, `INSTALL.md`.
- **Aceite:** instalar via `ln -s` e rodar `devorq version` funciona; `grep 'sed -i '` sem sufixo vazio (ou encapsulado).

### R15 — Integridade de lições sob concorrência `[médio/baixo]`
- **Problema:** ID `lesson_${%S}_$$` colide; fallback sem jq gera JSON inválido; sem lock + tmp determinístico.
- **Solução:** ID com `date +%N`/`$RANDOM` + checagem de colisão; escapar no fallback (ou exigir jq); `flock` nas escritas de estado/lições.
- **Arquivos:** `lib/lessons/{crud,validate,search,sync}.sh`.
- **Aceite:** 3 capturas no mesmo segundo (mesmo processo) → 3 arquivos distintos; lição com `"` no título não corrompe leituras.

### R16 — Commit seguro + secret scan `[baixo/baixo]`
- **Problema:** `git add -A` cego pode versionar `.env`/segredos.
- **Solução:** mostrar diff/status, stage seletivo, aviso de arquivos sensíveis.
- **Arquivos:** `lib/commit.sh`.
- **Aceite:** commit com `.env` no working tree gera aviso e não o adiciona por padrão.

### R17 — Higiene de docs/versão `[baixo/baixo]`
- **Problema:** `[VERSION]` literal no CHANGELOG; `.devorq/version` em 3.8.4; SPEC cita módulo inexistente; métricas contraditórias.
- **Solução:** `sync-version` cobre o cabeçalho do CHANGELOG; sincronizar `.devorq/version`; corrigir referências mortas e números no SPEC/README.
- **Arquivos:** `scripts/sync-version.sh`, `CHANGELOG.md`, `SPEC.md`, `README.md`, `.devorq/version`.
- **Aceite:** `grep '\[VERSION\]' CHANGELOG.md` vazio; SPEC não cita `execution.sh`; um único número de cobertura por release.

---

## 10. Backlog Técnico

> 30 tarefas implementáveis, com `id · prioridade/esforço`. Ordenadas para execução incremental por fase. Rastreiam aos achados via §5/§9.

| ID | Prio/Esf | Tarefa | Fase |
|----|----------|--------|------|
| DQ-001 | crítico/médio | Partição única comando→módulo + roteamento `--version` | 1 |
| DQ-002 | alto/médio | Remover árvores de módulos órfãs nunca carregadas | 1 |
| DQ-003 | alto/alto | Consolidar AUTO em fonte única canônica | 1 |
| DQ-004 | **crítico/baixo** | **Corrigir `mark_pass` que zera o `prd.json`** | 1 |
| DQ-005 | alto/médio | Fail-closed em delegate SIMULATED + diff em check-story | 1 |
| DQ-006 | alto/médio | Restaurar commit/checkpoint por story | 1 |
| DQ-007 | alto/médio | Persistir `gates_completed` + `--resume` no CLASSIC | 1 |
| DQ-008 | alto/médio | Corrigir SQL e exit codes do sync push/pull | 1 |
| DQ-009 | médio/baixo | Resolver symlink na resolução de `DEVORQ_ROOT` | 1 |
| DQ-010 | alto/médio | Remover injeção de comando shell nos scripts de sync | 2 |
| DQ-011 | alto/baixo | Remover defaults root/IP hardcoded; decidir `vps_pg_exec` | 2 |
| DQ-012 | alto/médio | Validação Context7 real no GATE-6 | 2 |
| DQ-013 | alto/baixo | AUTO sem Context7 marca skipped e nunca auto-compila | 2 |
| DQ-014 | baixo/baixo | Commit seguro em vez de `git add -A` cego | 2 |
| DQ-015 | baixo/baixo | Hardening SSH mux + instalação npm do ctx7 | 2 |
| DQ-016 | baixo/baixo | Unificar e fortalecer `sanitize_input` | 2 |
| DQ-017 | alto/médio | Instrumentar estado de runtime lido pela observabilidade | 3 |
| DQ-018 | alto/médio | Log estruturado JSONL com `run_id` correlacionável | 3 |
| DQ-019 | médio/baixo | Corrigir `$captured` indefinida em `stats::patterns` | 3 |
| DQ-020 | médio/baixo | Corrigir detecção do método de verificação + logar | 3 |
| DQ-021 | baixo/baixo | Limpar glifos CJK + lint anti-CJK | 3 |
| DQ-022 | alto/médio | Contrato `DEVORQ_DELEGATE_FN` + separação de camadas | 4 |
| DQ-023 | médio/médio | Handoff com trilha de decisões por agente | 4 |
| DQ-024 | baixo/baixo | Teto de concorrência no code-review + prompts limpos | 4 |
| DQ-025 | baixo/baixo | Corrigir MCP config gravando env literal | 4 |
| DQ-026 | alto/baixo | E2E do CI funcional, gating + wirar suites órfãs | 5 |
| DQ-027 | médio/médio | ShellCheck gating real | 5 |
| DQ-028 | médio/médio | Unificar sequência de gates + corrigir despacho/labels | 5 |
| DQ-029 | médio/médio | Padronizar portabilidade BSD/macOS | 5 |
| DQ-030 | baixo/médio | Robustez residual de lições/estado + limpeza de código morto | 5 |

---

## Apêndice A — Avaliação dos modos de operação

### Modo AUTO (autônomo)
**Veredito: não confiável para operação desatendida no estado atual.** Apesar da boa telemetria de falha (`failures.md`, `lessons.json`, `pending/*.json`), as garantias centrais estão quebradas: pode marcar *done* sem implementar (delegate `SIMULATED` + `check-story` fail-open), sem commitar (`git_commit` comentado), com possível **wipe do `prd.json`**; o seletor de modo aponta para um fork v1.0.0 obsoleto; `propose_break` trava em stdin mesmo com `--force-continue`; e não há trilha de execução para auditar o que foi decidido. **Risco de execução destrutiva: médio-alto** (wipe de prd.json; commits vazios). **Recuperação de processo interrompido: inexistente** (sem persistência de progresso). Priorizar DQ-003/004/005/006 antes de confiar o AUTO a qualquer pipeline batch.

### Modo CLASSIC / Controlado (gates 1–7)
**Veredito: mais seguro, mas com enforcement ilusório e sem retomada.** O fluxo guiado dá ao operador pontos de parada, mas os gates são majoritariamente checagens de presença; rótulos "BLOQUEANTE" enganam quem audita; `GATE-5.5`/`E2E` ficam fora do pipeline; e a ausência de `gates_completed` persistido significa **zero retomada** e handoff sempre "0/7". O operador **não tem visibilidade real** de quais validações de fato passaram (a observabilidade lê estado-fantasma). Priorizar DQ-007/017/028 para que o CLASSIC ofereça o controle que promete.

---

## Apêndice B — Verificação dinâmica (suites executadas)

| Suite | Resultado | Nota |
|-------|-----------|------|
| `scripts/unit-tests.sh` | ✅ 68/68 | gates, lessons, VPS sanitize |
| `scripts/security-tests.sh` | ✅ 26/0 | path traversal, SSH, SQLi, sanitize (contagem hardcoded 27≠26) |
| `scripts/validate-rules.sh` | ✅ 34/0 (+1 warn) | `e2e-test.sh` não-executável |
| `scripts/test-commands.sh` | ✅ 16/16 | **defeito:** heredoc órfão em `:149-156` (passa mesmo assim) |
| `scripts/ci-test.sh` | ✅ 46/46 | **dispara Playwright E2E** (71/77, não-bloqueante) |
| `scripts/pipeline-tests.sh` | 🟡 partial | **trava/excede 180s** na fase CI Tests |
| `bats tests/` e `bats tests/security/` | ⚪ `1..0` | **não há arquivo `.bats`** — a "suíte bats" do inventário não existe; `tests/security/` são scripts `.sh` que `bats` nunca roda |
| `shellcheck bin/ lib/ scripts/` | 0 erros / 43 warnings reais | SC2178 (`brainstorm.sh:276,283`) = possível bug de tipo; SC2164 `cd` sem `\|\| exit` |

**Portabilidade:** `jq`/`python3`/`ssh`/`node` bem guardados com `command -v`; mas `declare -A`, `sed -i` sem sufixo e `readlink -f` (13 ocorrências) **quebram em macOS/BSD sem nenhum guard de SO**.

---

## Apêndice C — Experiência do operador (papercuts de UX/DX)

A camada de UX é **adequada** — melhor que o núcleo de execução. **Preservar:** confirmação `[Y/n]` antes de commit (`lib/commit.sh:262-268`); observabilidade append-only legível (`progress.txt`, `.devorq-auto/failures.md` com tipo de erro/ação recomendada); gates com cores ANSI claras `[PASS]/[FAIL] GATE-N` (`lib/gates.sh:32-46`); documentação que diferencia AUTO×CLASSIC (`README.md:99-125`).

Papercuts a corrigir (todos esforço baixo/médio, alvo v3.8.6):

| Sev | Evidência | Papercut | DQ |
|-----|-----------|----------|-----|
| baixo | `bin/devorq:110` vs `:122-177` | **`devorq help <comando>` é documentado mas não implementado** — só `devorq <cmd> --help` funciona; a mensagem de ajuda mente. | DQ-001 |
| médio | `lib/visual.sh:48` | **Mensagens de erro não-acionáveis** — "devorq build falhou — gates não passaram" sem indicar **qual** gate falhou; força o operador a rodar gate a gate. | DQ-020 |
| médio | `lib/auto.sh:270` vs `loop-auto.sh` | **Sem banner de modo** — o operador não sabe se está em "guided" ou "Ralph"; falta um cabeçalho inicial claro do modo/sub-agente em execução. | DQ-018 |
| médio | `.devorq-auto/` | **Sem `current_story.json` em tempo real** — em sessão longa/remota não dá para saber qual story está em andamento sem varrer `progress.txt`. | DQ-018 |
| baixo | `loop-auto.sh:75-78`, `progress.txt` | **Emojis viram mojibake** em terminais/CI sem UTF-8; falta `DEVORQ_UNICODE` com fallback ASCII. | DQ-021 |
| baixo | `lib/helpers.sh:4-13` vs `README.md` | **Exit codes não documentados** no README (definidos só em `helpers.sh`) — atrapalha scripts de pipeline. | DQ-017 |

> Nota de reconciliação: a dimensão de UX é "adequada" isoladamente, mas o **controle real** que ela oferece é minado pela observabilidade de estado-fantasma (§5/§6) — o operador vê confirmações e cores, mas **não vê quais validações de fato passaram**. A maturidade de UX só se realiza após a Fase 3.

---

## Apêndice D — Status de implementação · Fase 1 (2026-06-26)

Correções aplicadas na branch **`fix/auditoria-fase1-estabilizacao`** (não publicada), cada uma com TDD e verificação contra as suites do projeto. **Gate de regressão final:** `unit-tests.sh` 73/73, `security-tests.sh` 26/0, `validate-rules.sh` ✓, `shellcheck` 0 erros nos 6 arquivos alterados, smoke do CLI ✓.

| Item | Commit | Estado | Verificação |
|------|--------|--------|-------------|
| **DQ-004** — wipe de `prd.json` em `mark_pass` (CRÍTICO) | `ae9776e` | ✅ Feito | Hardening em **ambos** os `mark_pass` (`lib/auto.sh` + `loop-auto.sh`): valores via ambiente (sem interpolação/injeção), guarda `[[ -s ]]` + `jq empty` antes do `mv`, fallback sem python3 não edita o prd in-place. `test_auto_mark_pass` (RED→GREEN). |
| **DQ-001** — shadowing de `cmd_test` + `--version` (CRÍTICO) | `92c8561` | ✅ Feito | `cmd_test` de `workflow.sh` renomeado p/ `cmd_structure_check`; `devorq test` agora roda os unit-tests (confirmado). `--version`/`-v`/`-V` roteados. `test_no_cmd_shadowing` (guard estático). |
| **DQ-009** — symlink quebra `DEVORQ_ROOT` | `92c8561` | ✅ Feito | Loop de resolução de symlink portável (GNU/BSD); instalação via `ln -s` verificada. |
| **DQ-005** — AUTO marca *done* sem implementar (ALTO) | `49a43e8` | ✅ Feito | `delegate` SIMULATED agora é fail-closed (escape `DEVORQ_AUTO_SIMULATE=1`); `check-story.sh` fail-closed sem runner (escape `DEVORQ_AUTO_ALLOW_NO_RUNNER=1`). `test_check_story_fail_closed`. |
| DQ-002 — remover árvores órfãs | — | ⏸️ Adiado | Requer repontar `scripts/test-commands.sh` (fora do CI) ao código vivo; deferido para esforço focado e evitar rabbit-hole. |
| DQ-006 — commit/checkpoint por story | — | ⏸️ Adiado | Mitigado em parte por DQ-005 (sem falso PASS). O acoplamento done↔commit pede a consolidação do AUTO (DQ-003), de maior superfície. |
| DQ-003 / DQ-007 / DQ-008 | — | ⬜ Pendente | Refactors maiores (consolidar AUTO; persistir `gates_completed`; reescrever SQL do sync — este precisa de Postgres para verificação end-to-end). |

> Observação de convenção: os commits seguem o padrão real do repositório `tipo(escopo):` (sem espaço), consistente com 100% do histórico e com o hook `commit-msg` do projeto.

---

*Relatório gerado por auditoria multi-agente com verificação adversarial. Dados estruturados completos (81 achados, evidências `file:line`, veredictos) preservados em anexo. Dúvidas ou priorização: rastrear cada item pelos IDs `DQ-xxx` (§10) e `R-xx` (§9).*
