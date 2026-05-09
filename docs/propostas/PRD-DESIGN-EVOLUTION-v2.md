# DEVORQ v3 — Proposta de Evolução: BDD + UNIFY + GATE-0 + AUTO MODE + CODE REVIEW
## (Versão Unificada v2)

**Documento:** Proposta de Design para Implementação  
**Versão:** 2.0.0  
**Data:** 2026-05-09  
**Autor:** Hermes Agent (para Fernando Dos Santos)  
**Destinatário:** Dev Core do DEVORQ v3  
**Status:** Pronto para Revisão e Implementação  
**Base:** `PRD-DESIGN-EVOLUTION.md` v1.0.0 + Skills Nando (GATE-0, AUTO, REVIEW)

---

## Resumo Executivo

Esta é a **versão unificada** da proposta de evolução do DEVORQ v3, que combina três camadas aditivas:

1. **BDD + UNIFY** (da proposta original `PRD-DESIGN-EVOLUTION.md` v1.0.0)
   - Given/When/Then para acceptance criteria testáveis
   - UNIFY como fase explícita de fechamento

2. **GATE-0 Suite** (das skills Nando — não existe no repo oficial)
   - `scope-guard`: contrato de escopo explícito
   - `ddd-deep-domain`: exploração de domínio pré-spec
   - `env-context`: detecção automática de ambiente

3. **AUTO Mode + Code Review** (das skills Nando — não existe no repo oficial)
   - `devorq-mode`: seletor AUTO vs CLASSIC
   - `devorq-auto`: loop story-by-story via delegate_task
   - `devorq-code-review`: review multi-agente com scoring 0-100

**Filosofia:** Todas as adições são **opcionais e não quebram nada**. O fluxo atual continua funcionando. Novas features são ativadas por trigger ou flag.

**Stack unchanged:** Bash 5+, jq 1.7+, Git, SSH. Zero novas dependências externas.

---

## 1. Análise Comparativa Completa

### 1.1 O que Existe no Repo Oficial vs Suas Skills

| Camada | Repo Oficial (`nandinhos/devorq_v3`) | Skills Nando (não existem no oficial) |
|--------|-------------------------------------|---------------------------------------|
| **GATE-0 (pré-spec)** | ❌ | ✅ `scope-guard`, `ddd-deep-domain`, `env-context` |
| **GATE-1 a GATE-7** | ✅ Completo | — |
| **UNIFY (pós-work)** | ❌ (na proposta v1.0.0) | ✅ `lib/unify.sh` especificado na v1.0.0 |
| **BDD Given/When/Then** | ❌ (template na v1.0.0) | ✅ Template na v1.0.0 |
| **AUTO Mode** | ❌ | ✅ `devorq-mode` + `devorq-auto` |
| **PRD generation** | ❌ | ✅ `prd-from-spec.sh` |
| **Code Review** | ❌ | ✅ `devorq-code-review` (5 agents //, scoring) |
| **Lessons por projeto** | ❌ | ✅ `.devorq-auto/lessons.json` |
| **Failures tracking** | ❌ | ✅ `failures.md` + `pending/*.json` |
| **Fallback execute_code** | ❌ | ✅ Retry automático |
| **CI/CD** | ❌ | ✅ `.github/workflows/ci.yml` (PR #1 merged) |
| **PostgreSQL HUB** | ⚠️ Spec | ✅ Scripts + lib/vps.sh |
| **spec validate** | ❌ | ✅ `lib/spec.sh` (na v1.0.0) |

---

## 2. Arquitetura da Proposta v2

### 2.1 Estrutura de Arquivos — O que Muda

```
devorq_v3/
├── bin/devorq
│   ├── + devorq unify [feature] [--auto] [--lessons]
│   ├── + devorq spec validate [--strict] [--format table|json]
│   ├── + devorq spec template [feature-name]
│   ├── + devorq spec check-ac
│   ├── + devorq mode [auto|classic]
│   ├── + devorq auto [n|all] [--force-continue]
│   └── + devorq review [--branch HEAD]
│
├── lib/
│   ├── unify.sh                  # NOVO (da v1.0.0)
│   ├── spec.sh                   # NOVO (da v1.0.0)
│   ├── gates.sh
│   │   ├── + gate_0_scope()     # NOVO — scope-guard integration
│   │   ├── + gate_0_ddd()       # NOVO — ddd-deep-domain integration
│   │   ├── + gate_0_env()        # NOVO — env-context integration
│   │   └── + gate_5_5()         # NOVO — UNIFY check (não bloqueante)
│   ├── lessons.sh
│   │   └── + lessons::from_unify()  # NOVO (da v1.0.0)
│   ├── context.sh
│   │   └── + ctx_unify_import()  # NOVO (da v1.0.0)
│   ├── vps.sh                    # existente
│   ├── debug.sh                  # existente
│   ├── compact.sh                 # existente
│   └── context7.sh              # existente
│
├── skills/                       # NOVO — skills como extensões
│   ├── scope-guard/
│   │   ├── SKILL.md
│   │   ├── scripts/scope-validate.sh
│   │   └── references/
│   ├── ddd-deep-domain/
│   │   ├── SKILL.md
│   │   ├── scripts/ddd-validate-spec.sh
│   │   └── references/
│   ├── env-context/
│   │   ├── SKILL.md
│   │   └── scripts/env-detect.sh
│   ├── devorq-mode/
│   │   ├── SKILL.md
│   │   └── scripts/mode-selector.sh
│   ├── devorq-auto/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── prd-from-spec.sh
│   │       ├── check-story.sh
│   │       └── loop-auto.sh
│   └── devorq-code-review/
│       ├── SKILL.md
│       └── scripts/review.sh
│
├── scripts/
│   ├── sync-push.py              # existente + UNIFY.md no payload
│   ├── sync-pull.py               # existente
│   └── ci-test.sh                 # existente (36 testes)
│
├── .devorq/
│   └── state/
│       ├── context.json           # + campos unify_done, ac_passed, etc.
│       ├── unify/                 # NOVO — UNIFY.md por feature
│       │   └── YYYY-MM-DD_HHMMSS_feature_unify.md
│       └── auto/                  # NOVO — estado do AUTO mode
│           ├── lessons.json
│           ├── failures.md
│           └── pending/
│               └── feat-XXX.json
│
└── docs/
    ├── SPEC.md                   # atualizado com BDD template
    ├── BDD-TEMPLATE.md          # NOVO (da v1.0.0)
    ├── UNIFY-GUIDE.md           # NOVO (da v1.0.0)
    └── GATE0-GUIDE.md           # NOVO — guia GATE-0 suite
```

### 2.2 Fluxo Completo v2 — 11 Fases

```
[NOVA TASK / NOVA SESSÃO]
         │
         ▼
   ┌───────────┐
   │  GATE-0   │  ← OPCIONAL (disparado por keywords)
   │  (suite)  │    scope-guard / ddd-deep-domain / env-context
   └─────┬─────┘
         │
         ▼
   ┌───────────┐
   │  GATE-1   │  SPEC.md existe?
   └───┬───┬───┘
       │   │
    PASS  FAIL → cria/atualiza SPEC.md → volta
       │
       ▼
   ┌───────────┐
   │  GATE-2   │  devorq test passa?
   └───┬───┬───┘
       │   │
    PASS  FAIL → corrige estrutura → volta
       │
       ▼
   ┌───────────┐
   │  GATE-3   │  contexto válido?
   └───┬───┬───┘
       │   │
    PASS  FAIL → devorq context set → volta
       │
       ▼
   ┌───────────┐
   │  GATE-4   │  lições revisadas?
   └───┬───┬───┘
       │   │
    PASS  FAIL → devorq lessons search → volta
       │
       ▼
   ┌───────────┐
   │  GATE-6   │  Context7?
   └───┬───┬───┘
       │   │
    WARN/PASS →无所谓 (não bloqueia)
       │
       ▼
   ┌─────────────────────┐
   │   MODE SELECTION     │  ← NOVO (skill devorq-mode)
   │   AUTO vs CLASSIC    │
   └──────────┬──────────┘
              │
     ┌────────┴────────┐
     ▼                 ▼
  AUTO              CLASSIC
     │                 │
     ▼                 ▼
  prd.json      gates 1-7 manuais
  loop-auto
  delegate_task
     │
     ▼
  ┌─────────────────────┐
  │      WORK            │  ← Implementação
  │                      │
  │  devorq spec validate│  ← Valida BDD se existir
  │  devorq auto check   │  ← Verificação por story
  └──────────┬──────────┘
             │
        (se erro)
             ▼
   ┌─────────────────────┐
   │  devorq debug       │  ← GATE-7 (reativo)
   │  (4-phase)          │
   └──────────┬──────────┘
              │
              ▼
   ┌─────────────────────┐
   │       UNIFY          │  ← NOVO (da v1.0.0)
   │                      │
   │  devorq unify        │  ← Review de ACs
   │  (--auto --lessons) │  ← Documenta desvios + captura lições
   └──────────┬──────────┘
              │
              ▼
   ┌───────────┐
   │  GATE-5   │  devorq compact (handoff)
   └─────┬─────┘
         │
         ▼
   ┌───────────┐
   │  GATE-5.5 │  UNIFY check (não bloqueante)
   └─────┬─────┘
         │
         ▼
   ┌─────────────────────┐
   │   CODE REVIEW        │  ← OPCIONAL (skill devorq-code-review)
   │   (5 agents //)      │    Scored 0-100, filtro ≥80
   │   Approval ⛔        │    Você decide antes de publicar
   └──────────┬──────────┘
              │
              ▼
   ┌───────────┐
   │ sync push  │  → HUB (opcional)
   └─────┬─────┘
         │
         ▼
   [FIM DA SESSÃO]
```

---

## 3. GATE-0 — Pré-Implementação (3 Skills)

### 3.1 Visão Geral do GATE-0

GATE-0 é uma **suite de 3 skills opcionais** que executam ANTES de GATE-1. Só são disparados por keywords no intent do usuário.

| Skill | Trigger Keywords | O que faz |
|-------|-----------------|-----------|
| `env-context` | qualquer primeira mensagem | Detecta stack, ambiente, binários, gotchas |
| `scope-guard` | `implementar`, `criar`, `adicionar`, `feature` | Contrato de escopo whitelist |
| `ddd-deep-domain` | `domínio`, `DDD`, `modelagem`, `entidade` | Exploração de domínio pré-spec |

**Referências:**
- `~/.hermes/skills/env-context/SKILL.md`
- `~/.hermes/skills/scope-guard/SKILL.md`
- `~/.hermes/skills/ddd-deep-domain/SKILL.md`

### 3.2 `env-context` — Detecção Automática de Ambiente

**O que faz:** Na primeira mensagem da sessão, detecta automaticamente:
- Stack (Laravel/Node/Python/etc)
- Runtime (Docker/Sail/Local/Host)
- Binários disponíveis
- Ports mapeadas
- Gotchas conhecidas do ambiente

**Output:**
```
=== DEVORQ ENVIRONMENT CONTEXT ===
Project: eventos-control
Stack: PHP 8.4 / Laravel 12 / Sail (Docker)
Runtime: Sail
Commands: vendor/bin/sail artisan
Ports: 80:8080, 3306:3306
GOTCHAS: [
  - WWWUSER=1000 no .env
  - DB:prod=PostgreSQL (não SQLite)
]
===
```

**Implementar em:** `lib/gates.sh` → `gate_0_env()`

**Script:** `skills/env-context/scripts/env-detect.sh`

### 3.3 `scope-guard` — Contrato de Escopo Explícito

**O que faz:** Gera whitelist FAZER/NÃO FAZER/ARQUIVOS/DONE_CRITERIA antes de qualquer código. Bloqueia over-engineering.

**Estrutura do contrato:**
```markdown
# CONTRATO DE ESCOPO — [nome-da-task]

## FAZER (whitelist — só o que está aqui é permitido)
1. Funcionalidade específica 1
2. Funcionalidade específica 2

## NÃO FAZER (blacklist — nunca fazer)
1. NÃO implementar feature X
2. NÃO modificar arquivo Y

## ARQUIVOS (whitelist — só esses podem ser modificados)
- caminho/arquivo1.ext
- caminho/arquivo2.ext

## ARQUIVOS PROIBIDOS
- app/Models/User.php

## DONE_CRITERIA
- [ ] Critério verificável 1
    Context7 valida: "Laravel validation rules"
- [ ] Critério verificável 2

## RISCO_IDENTIFICADO
- [ ] Risco 1
```

**Integração:** Context7 valida DONE_CRITERIA contra docs oficiais

**Implementar em:** `lib/gates.sh` → `gate_0_scope()`

**Scripts:**
- `skills/scope-guard/scripts/scope-validate.sh`
- `skills/scope-guard/references/examples.md`

**Debitos prevenidos:**
- D16: Especificações vagas → over-engineering
- D17: Escopo não declarado → implementação arbitrária

### 3.4 `ddd-deep-domain` — Exploração de Domínio

**O que faz:** Workshop de 6 etapas para descobrir modelo mental ANTES de escrever SPEC.md. Gera `domain-model.json` com:
- Entidades e Value Objects
- Agregados e Aggregate Roots
- Contextos delimitados (Bounded Contexts)
- Invariantes
- Língua ubíqua

**6 Etapas do Workshop:**
1. **Regra** — Sentar com quem conhece a regra, fazer as perguntas certas
2. **Entidades** — Mapear o que tem identidade própria vs Value Objects
3. **Contextos** — Descobrir onde o mesmo termo significa coisas diferentes
4. **Língua** — Codificar a língua do domínio, não o esqueleto
5. **Alertas** — Identificar DDD de teatro (pastas certas sem alma)
6. **Validação** — Garantir que SPEC.md tem alma, não só esqueleto

**Output:** `domain-model.json`
```json
{
  "entities": [...],
  "bounded_contexts": [...],
  "invariants": [...],
  "validated_with": "expert-name",
  "confidence": "high|medium|low"
}
```

**Implementar em:** `lib/gates.sh` → `gate_0_ddd()`

**Scripts:**
- `skills/ddd-deep-domain/scripts/ddd-validate-spec.sh`
- `skills/ddd-deep-domain/references/domain-questions.md`

---

## 4. BDD — Acceptance Criteria Given/When/Then

### 4.1 O que é

Template de SPEC.md com acceptance criteria no formato BDD (Behavior-Driven Development):

```markdown
### AC-1: Login com credenciais válidas

**Given** o usuário existe no sistema com email "nando@devorq.com" e senha "Senha@123"  
**When** o cliente envia POST /auth/login com `{"email": "nando@devorq.com", "password": "***"}`  
**Then** o servidor retorna status 200 com `{"token": "***", "expires_in": 86400}` e o token expira em 24h

**Critérios de sucesso:**
- [ ] Status code é 200
- [ ] Response contém campo `token` (string não-vazia)
- [ ] Response contém campo `expires_in` = 86400

**Critérios de falha (edge cases):**
- [ ] Usuário não existe → status 401
- [ ] Senha errada → status 401
- [ ] Campos faltando → status 400
```

**Referência:** `PRD-DESIGN-EVOLUTION.md` seção 4 (template completo) e 4.2 (exemplo auth-login)

### 4.2 Implementação

**Arquivos:**
- `lib/spec.sh` — validação de SPEC.md (Given/When/Then, [TODO], Out of Scope)
- `docs/BDD-TEMPLATE.md` — template de referência (da v1.0.0)
- `docs/SPEC.md` — atualizado com BDD template (da v1.0.0)

**Comandos:**
```bash
devorq spec validate [--strict]    # Valida formato BDD
devorq spec template [feature-name] # Gera template
devorq spec check-ac               # Lista ACs sem cobertura de teste
```

**Validações do `spec::validate`:**
| Regra | Severidade |
|-------|------------|
| Seção "Acceptance Criteria (BDD)" | WARN (opcional) |
| AC tem Given/When/Then | ERROR se --strict |
| AC tem critérios de sucesso | WARN |
| AC tem edge cases | WARN |
| "Out of Scope" existe | WARN |
| Nenhum placeholder [TODO] restante | ERROR |

---

## 5. UNIFY — Fase de Fechamento

### 5.1 O que é

UNIFY é uma **fase explícita** entre [WORK] e GATE-5 (Handoff). Executada ao finalizar feature ou sessão. Documenta:
- Quais AC passaram/falharam/deferred
- Lições aprendidas automaticamente
- Desvios do plano original
- Pending items

**Referência:** `PRD-DESIGN-EVOLUTION.md` seção 3.3 e 3.4

### 5.2 Fluxo do UNIFY

```
[SESSÃO INICIADA]
       │
       ▼
  devorq flow "implementar auth-login"
       │
       ▼
  [GATES 1-4, 6 normalmente]
       │
       ▼
  ┌─────────────────────┐
  │      WORK            │
  │  [implementa ACs]   │
  └──────────┬──────────┘
             │ (ao finalizar)
             ▼
  ┌─────────────────────┐
  │       UNIFY          │
  │  devorq unify [--auto --lessons]
  │                      │
  │  1. Parse ACs        │
  │  2. Verifica status  │
  │  3. Gera UNIFY.md   │
  │  4. Captura lições  │
  │  5. Atualiza context │
  └──────────┬──────────┘
             │
             ▼
  GATE-5 (Handoff)
```

### 5.3 Estrutura do UNIFY.md

**Local:** `.devorq/state/unify/YYYY-MM-DD_HHMMSS_feature_unify.md`

**Formato:**
```markdown
# UNIFY — auth-login
**Data:** 2026-05-09T14:30:22Z
**Feature:** auth-login (AC-1, AC-2, AC-3)

---

## Acceptance Criteria — Resultado Real

| AC | Esperado | Real | Status |
|----|----------|------|--------|
| AC-1 | Status 200 + JWT válido | ✅ Status 200 + JWT com exp 24h | PASS |
| AC-2 | Status 401, sem dados sensíveis | ✅ Status 401 + `{"error": "..."}` | PASS |
| AC-3 | Rate limit após 5 tentativas | ❌ Não implementado (escopo) | DEFERRED |

---

## Lições Aprendidas

1. **bcrypt.compare() é síncrono** — precisei usar `crypto.promisify(bcrypt.compare)` dentro de async handler
2. **Token JWT exp está em segundos, não ms** — confundi units no teste

---

## Desvios do Plano Original

- Adicionei middleware de logging (não estava na SPEC) → documentado para próxima revisão
- Tempo real: 45min vs estimado 30min → +50% overhead

---

## Pending Items

- [ ] AC-3: Rate Limiting (DEFERRED — depende de middleware existente)
- [ ] Testar refresh token flow (NÃO ERA ESCOPO — adicionado ao backlog)

---

## Estado Final

```json
{
  "unify_done": true,
  "unify_file": ".devorq/state/unify/2026-05-09_143022_auth-login_unify.md",
  "ac_passed": 2,
  "ac_deferred": 1,
  "lessons_auto_captured": 2
}
```
```

### 5.4 Implementação

**Arquivos:**
- `lib/unify.sh` — lógica UNIFY completa (da v1.0.0, seção 6.1)
- `lib/lessons.sh` — + `lessons::from_unify()` (da v1.0.0, seção 6.5)
- `docs/UNIFY-GUIDE.md` — guia de uso (da v1.0.0)

**Comandos:**
```bash
devorq unify [feature]           # Executa UNIFY
devorq unify --auto             # Sem prompts (para scripts/CI)
devorq unify --lessons          # Auto-captura lições
```

**GATE-5.5 (não bloqueante):**
```bash
# Em lib/gates.sh
gate_5_5() {
    gate::info 5.5 "UNIFY — fase de fechamento"
    # Verifica context.json.unify_done
    # Se false: WARN apenas, não bloqueia
    return 0  # Sempre passa — não bloqueante
}
```

---

## 6. AUTO Mode — Execução Autônoma Story-by-Story

### 6.1 O que é

`devorq-mode` + `devorq-auto` é um **loop completo** que:
1. Detecta se usuário quer AUTO ou CLASSIC
2. Gera `prd.json` do SPEC.md automaticamente
3. Executa uma story por vez via `delegate_task`
4. Verifica cada story com `check-story.sh`
5. Commita e atualiza `prd.json`
6. tracking de failures e lessons aprendidas

**Referência:** `~/.hermes/skills/devorq-auto/SKILL.md`

### 6.2 Fluxo do AUTO Mode

```
USER: "vamos implementar feature X"
          │
          ▼
devorq-mode (pergunta AUTO vs CLASSIC)
          │
    ┌─────┴─────┐
    ▼           ▼
AUTO           CLASSIC
    │           │
    ▼           ▼
prd.json?   gates 1-7
  │             │
  ├── NÃO → prd-from-spec.sh
  │              │
  └── SIM → mostra pendentes
            │
            ▼
   ┌─────────────────────┐
   │  LOOP AUTO           │
   │                      │
   │  1. Seleciona story  │
   │  2. delegate_task    │
   │  3. check-story.sh  │
   │  4. git commit       │
   │  5. update prd.json │
   │  6. repeat           │
   └──────────────────────┘
```

### 6.3 Features Exclusivas do devorq-auto

| Feature | Descrição |
|---------|-----------|
| **PRD generation** | `prd-from-spec.sh` quebra SPEC.md em stories atômicas |
| **Fallback execute_code** | Se `delegate_task` falhar 1x, retry. Se falhar 2x, implementação direta |
| **Lessons por projeto** | `.devorq-auto/lessons.json` com stats |
| **failures.md** | Sumário human-readable de failures |
| **pending/*.json** | Contexto da story que falhou (para debug) |
| **Heurísticas de complexidade** | Detecta keywords e sugere quebra de story |
| **Stories "by design"** | Detecta código já correto e marca `passes: true` |
| **View cache invalidation** | No Laravel Sail, limpa compiled views antes de testar |
| **WSL Docker handling** | Não bloqueia progresso se failures forem ambiente-specific |
| **Partial commits detection** | Verifica staged/unstaged changes antes de próximo delegate |

### 6.4 Pilha de Qualidade do AUTO Mode

| Camada | Ferramenta |
|--------|------------|
| Lint | Laravel Pint (auto-fix) |
| Static | PHPStan/Larastan (0 errors) |
| Tests | Pest |
| Docs (API) | knuckleswtf/scribe |

### 6.5 Implementação

**Scripts:**
- `skills/devorq-mode/scripts/mode-selector.sh`
- `skills/devorq-auto/scripts/prd-from-spec.sh`
- `skills/devorq-auto/scripts/check-story.sh`
- `skills/devorq-auto/scripts/loop-auto.sh`

**Comandos:**
```bash
devorq mode          # Seletor interativo
devorq auto [n]     # Executa n stories (default: 1)
devorq auto all      # Executa todas
devorq auto --force-continue  # Pula failures e continua
```

**Exit codes:**
| Code | Meaning |
|------|---------|
| 0 | Todas completadas |
| 1 | Erro detecção (sem SPEC.md) |
| 2 | Abortado pelo usuário |
| 3 | Verification failed |
| 4 | Delegate failed |
| 5 | prd.json não encontrado |

---

## 7. CODE REVIEW — Review Autônomo Multi-Agente

### 7.1 O que é

Sistema de **code review autônomo em 8 fases** com:
- Eligibility check (para cedo se não precisa)
- 5 agentes de review especializados em paralelo
- Confidence scoring 0-100 por issue
- Filtro ≥80 (só issues importantes)
- Approval gate manual (VOCÊ decide antes de publicar)

**Nunca publica no PR automaticamente.** Output vai pro chat, você decide.

**Referência:** `~/.hermes/skills/devorq-code-review/SKILL.md`

### 7.2 Arquitetura de 8 Fases

```
[0] ELIGIBILITY    → Haiku-level: para cedo se não precisa
[1] CONTEXT        → 2 agentes //: CLAUDE.md + diff summary
[2] REVIEW //      → 5 agentes //: 5 dimensões especializadas
[3] SCORING        → N agentes //: 0-100 por issue
[4] FILTER         → Descarta issues < 80
[5] DEBUG          → systematic-debugging SE issues > 0
[6] APPROVAL ⛔    → VOCÊ valida antes de qualquer ação
[7] REPORT         → Output formatado no chat
```

### 7.3 Os 5 Agentes de Review (paralelo)

| Agente | Foco | O que verifica |
|--------|------|----------------|
| 1 | SPEC/CLAUDE.md Compliance | Viola regras do projeto? |
| 2 | Bug Scan | Logic errors, null checks, security, resource leaks |
| 3 | Git History Context | Git blame, decisões passadas |
| 4 | PR History | Padrões de PRs anteriores |
| 5 | Code Comments Compliance | Mudanças contradizem comentários? |

### 7.4 Confidence Scoring

| Score | Significado |
|-------|-------------|
| 0 | False positive óbvio |
| 25 | Talvez real, talvez false positive |
| 50 | Real mas minor |
| 75 | Highly confident, real e importante |
| 100 | Absolutamente certo, sem dúvida |

**Filtro:** Só issues com score ≥ 80 seguem para o report.

### 7.5 Implementação

**Script:** `skills/devorq-code-review/scripts/review.sh`

**Comando:**
```bash
devorq review [--branch HEAD]
```

**Integração com devorq-auto:**
```bash
# No loop-auto.sh, após delegate e antes de commit:
devorq review --branch HEAD
# Se exit 0 + issues < threshold → commit
# Se issues ≥ threshold → approval gate
```

---

## 8. Infraestrutura Extra

### 8.1 CI/CD — GitHub Actions

**.github/workflows/ci.yml** — 36 testes automatizados:
- Syntax validation (shellcheck)
- Estrutura de diretórios
- Lessons capture/search/validate/apply
- CLI commands (bin/devorq)
- Skills carregamento

**Status:** Testado e mergeado em PR #1

### 8.2 DEV-MEMORY HUB — PostgreSQL Remoto

**VPS:** srv163217:6985 (SSH) / :5433 (PostgreSQL)  
**pgvector:** 0.8.2 com ivfflat index

**Tabelas:**
- `devorq.lessons` — id, title, problem, solution, stack[], tags[], embedding, project, source, validated, applied
- `devorq.memories` — id, project, content, tags[], embedding
- `devorq.sessions` — id, project, started_at, ended_at, handoff_id, summary
- `devorq.handoffs` — id, from_agent, to_agent, context, created_at

**Scripts:**
- `scripts/sync-push.py` — local → HUB com UNIFY.md no payload
- `scripts/sync-pull.py` — HUB → local
- `lib/vps.sh` — SSH mux (~0.3s/comando após primeira conexão)

---

## 9. Tabela Comparativa Final

| Feature | Repo v3.4.1 | Proposta v2 | Implementação |
|---------|-------------|-------------|--------------|
| **GATE-0 env-context** | ❌ | ✅ | `skills/env-context/` |
| **GATE-0 scope-guard** | ❌ | ✅ | `skills/scope-guard/` |
| **GATE-0 ddd-deep-domain** | ❌ | ✅ | `skills/ddd-deep-domain/` |
| **GATE-1 a GATE-7** | ✅ | ✅ | `lib/gates.sh` |
| **GATE-5.5 UNIFY** | ❌ | ✅ | `lib/gates.sh` |
| **BDD Given/When/Then** | ❌ | ✅ | `lib/spec.sh` + `docs/BDD-TEMPLATE.md` |
| **UNIFY fase** | ❌ | ✅ | `lib/unify.sh` |
| **devorq-mode** | ❌ | ✅ | `skills/devorq-mode/` |
| **devorq-auto (loop)** | ❌ | ✅ | `skills/devorq-auto/` |
| **prd.json generation** | ❌ | ✅ | `scripts/prd-from-spec.sh` |
| **fallback execute_code** | ❌ | ✅ | `loop-auto.sh` |
| **failures.md + pending/** | ❌ | ✅ | `.devorq-auto/` |
| **devorq-code-review** | ❌ | ✅ | `skills/devorq-code-review/` |
| **confidence scoring 0-100** | ❌ | ✅ | `review.sh` |
| **filter ≥80** | ❌ | ✅ | `review.sh` |
| **approval gate manual** | ❌ | ✅ | FASE 6 |
| **CI/CD 36 testes** | ❌ | ✅ | `.github/workflows/ci.yml` |
| **PostgreSQL HUB** | ⚠️ spec | ✅ | `scripts/` + `lib/vps.sh` |
| **SSH mux** | ⚠️ spec | ✅ | `lib/vps.sh` |

---

## 10. Stories de Implementação (PRD)

### 10.1 Stories para GATE-0 Suite

```json
{
  "id": "gate0-env-001",
  "title": "lib/gate_0_env.sh — Detecção automática de ambiente",
  "description": "Integrar env-context como gate_0_env() em lib/gates.sh. Detecta stack, runtime, binários, gotchas na primeira mensagem.",
  "acceptanceCriteria": [
    "gate_0_env() executa automaticamente na primeira mensagem",
    "Output contém stack, runtime, commands, ports, GOTCHAS",
    "GOTCHAS inclui WWWUSER, DB mismatch, Vite issues"
  ],
  "priority": 10,
  "phase": "gate0"
}
```

```json
{
  "id": "gate0-scope-001",
  "title": "lib/gate_0_scope.sh — Contrato de escopo explícito",
  "description": "Integrar scope-guard como gate_0_scope() em lib/gates.sh. Dispara quando intent contém 'implementar', 'criar', 'adicionar'.",
  "acceptanceCriteria": [
    "gate_0_scope() gera contrato FAZER/NÃO FAZER/ARQUIVOS",
    "Checkpoint contínuo a cada 3-5 arquivos modificados",
    "Bloqueio se escopo violado"
  ],
  "priority": 20,
  "phase": "gate0"
}
```

```json
{
  "id": "gate0-ddd-001",
  "title": "lib/gate_0_ddd.sh — Exploração de domínio pré-spec",
  "description": "Integrar ddd-deep-domain como gate_0_ddd() em lib/gates.sh. Dispara quando intent contém 'domínio', 'DDD', 'modelagem'.",
  "acceptanceCriteria": [
    "gate_0_ddd() gera domain-model.json",
    "Validação: SPEC.md tem alma (não só esqueleto)",
    "6 etapas do workshop documentadas"
  ],
  "priority": 30,
  "phase": "gate0"
}
```

### 10.2 Stories para BDD + UNIFY

```json
{
  "id": "infra-bdd-001",
  "title": "lib/spec.sh — Validação BDD de SPEC.md",
  "description": "Criar lib/spec.sh com spec::validate, spec::template, spec::check_ac.",
  "acceptanceCriteria": [
    "spec::validate retorna 0 para SPEC.md com BDD válido",
    "spec::validate retorna 1 (--strict) quando AC ausente",
    "spec::template gera SPEC.md com template BDD completo"
  ],
  "priority": 40,
  "phase": "infra"
}
```

```json
{
  "id": "infra-unify-001",
  "title": "lib/unify.sh — Fase UNIFY completa",
  "description": "Criar lib/unify.sh com unify::run, unify::parse_ac, unify::check_ac, unify::generate, unify::update_context.",
  "acceptanceCriteria": [
    "unify::run gera arquivo UNIFY.md válido",
    "GATE-5.5 executa após gate_5 e não bloqueia",
    "context.json atualizado com unify_done: true"
  ],
  "priority": 50,
  "phase": "infra"
}
```

### 10.3 Stories para AUTO Mode

```json
{
  "id": "auto-mode-001",
  "title": "devorq-mode — Seletor AUTO vs CLASSIC",
  "description": "Criar devorq-mode skill com mode-selector.sh. Pergunta automaticamente quando intent não especifica modo.",
  "acceptanceCriteria": [
    "Keywords AUTO disparam modo automático",
    "Keywords CLASSIC disparam modo manual",
    "Menu interativo se ambiguidade"
  ],
  "priority": 60,
  "phase": "auto"
}
```

```json
{
  "id": "auto-mode-002",
  "title": "devorq-auto — Loop story-by-story via delegate_task",
  "description": "Criar devorq-auto skill com loop-auto.sh, prd-from-spec.sh, check-story.sh.",
  "acceptanceCriteria": [
    "prd-from-spec.sh gera stories do SPEC.md",
    "loop-auto.sh executa uma story por vez",
    "check-story.sh verifica (Pint + Pest)",
    "git commit após cada story verificada"
  ],
  "priority": 70,
  "phase": "auto"
}
```

### 10.4 Stories para Code Review

```json
{
  "id": "review-001",
  "title": "devorq-code-review — Review autônomo 5 agents",
  "description": "Criar devorq-code-review skill com review.sh. 8 fases, 5 agents paralelo, scoring 0-100, filtro ≥80.",
  "acceptanceCriteria": [
    "5 agents executam em paralelo",
    "Confidence scoring 0-100 por issue",
    "Filter ≥80 descartado",
    "Approval gate manual antes de qualquer ação"
  ],
  "priority": 80,
  "phase": "review"
}
```

### 10.5 Stories para Documentação

```json
{
  "id": "docs-bdd-001",
  "title": "docs/BDD-TEMPLATE.md — Template BDD de referência",
  "description": "Criar docs/BDD-TEMPLATE.md com template Given/When/Then completo.",
  "priority": 90,
  "phase": "docs"
}
```

```json
{
  "id": "docs-unify-001",
  "title": "docs/UNIFY-GUIDE.md — Guia de uso UNIFY",
  "description": "Criar docs/UNIFY-GUIDE.md explicando quando usar UNIFY e como interpretar o arquivo gerado.",
  "priority": 100,
  "phase": "docs"
}
```

```json
{
  "id": "docs-gate0-001",
  "title": "docs/GATE0-GUIDE.md — Guia GATE-0 Suite",
  "description": "Criar docs/GATE0-GUIDE.md explicando env-context, scope-guard, ddd-deep-domain.",
  "priority": 110,
  "phase": "docs"
}
```

---

## 11. Roadmap de Implementação

### Fase 1: GATE-0 Suite (4h)

| Task | Tempo | Responsável |
|------|-------|-------------|
| Integrar `gate_0_env()` em `lib/gates.sh` | 30min | Dev |
| Integrar `gate_0_scope()` em `lib/gates.sh` | 1h | Dev |
| Integrar `gate_0_ddd()` em `lib/gates.sh` | 1h | Dev |
| Criar `docs/GATE0-GUIDE.md` | 30min | Dev |
| Testar GATE-0 suite | 1h | Dev |
| **Total** | **4h** | |

### Fase 2: BDD + UNIFY (5h)

| Task | Tempo |
|------|-------|
| Criar `lib/spec.sh` | 1h |
| Criar `lib/unify.sh` (estrutura) | 1h |
| Integrar `gate_5_5()` em `lib/gates.sh` | 30min |
| Adicionar comandos em `bin/devorq` | 30min |
| Criar `docs/BDD-TEMPLATE.md` | 45min |
| Criar `docs/UNIFY-GUIDE.md` | 45min |
| Integrar `lessons::from_unify()` | 30min |
| **Total** | **5h** |

### Fase 3: AUTO Mode (4h)

| Task | Tempo |
|------|-------|
| Integrar `devorq-mode` | 1h |
| Integrar `devorq-auto` (prd-from-spec, loop-auto, check-story) | 2h |
| Adicionar comando `devorq auto` | 30min |
| Testar loop completo | 30min |
| **Total** | **4h** |

### Fase 4: Code Review (3h)

| Task | Tempo |
|------|-------|
| Integrar `devorq-code-review` | 2h |
| Adicionar comando `devorq review` | 30min |
| Testar 8 fases | 30min |
| **Total** | **3h** |

### Fase 5: Validação e Docs (2h)

| Task | Tempo |
|------|-------|
| Atualizar `README.md` com novas features | 30min |
| Atualizar `SPEC.md` com arquitetura v2 | 30min |
| Executar testes de regressão | 1h |
| **Total** | **2h** |

**Total estimado:** 18h

---

## 12. Regras de Ouro

### O que NUNCA Mudar
1. **GATE-1 a GATE-7** são bloqueantes e imutáveis
2. **Zero novas dependências** — Bash + jq apenas
3. **Backward compatible** — tudo que existe hoje continua funcionando
4. **UNIFY nunca bloqueia** — só WARN ou INFO
5. **Approval gate manual** — code review nunca publica automaticamente

### O que é OPCIONAL
1. **GATE-0 suite** — dispara por keywords, não forçado
2. **BDD Given/When/Then** — SPEC.md livre continua válida
3. **AUTO Mode** — CLASSIC continua disponível
4. **Code Review** — pode ser pulado se elegibilidade falhar

### O que PODE Mudar
1. Formato interno de UNIFY.md (campos obrigatórios mantidos)
2. Lógica de scoring do code review (threshold 80 é default, configurável)
3. Heurísticas de complexidade do AUTO mode
4. Threshold de tokens para alertas de contexto

---

## 13. Riscos e Mitigações

| Risco | Prob | Impacto | Mitigação |
|-------|------|---------|-----------|
| GATE-0 vira bureaucracy | Média | Alto | É opcional via keywords; não forçado |
| BDD vira burocracia | Média | Alto | BDD é opcional; SPEC livre continua válida |
| UNIFY vira burocracia | Média | Alto | UNIFY nunca bloqueia;文化建设 via coaching |
| AUTO mode faz coisas erradas | Média | Médio | Stories pequenas (max 10min); verify antes de commit |
| Code review gera muito ruído | Média | Baixo | Filtro ≥80 descartado; aprovação manual |
| Lições triviais flooding | Baixa | Baixo | `validated: false` default; review humano |

---

## 14. Decisões de Design Documentadas

| Decisão | Justificativa |
|---------|---------------|
| GATE-0 é pré-gate opcional | Nem todo projeto precisa de scope/domain exploration |
| UNIFY fica entre WORK e GATE-5 | GATE-5 (handoff) precisa de estado fechado |
| UNIFY.md vai para `.devorq/state/unify/` | Versionado localmente; não polui repo |
| GATE-5.5 é não-bloqueante | Filosofia DEVORQ: discipline sem bureaucracy |
| AUTO mode usa delegate_task nativo | Não depende de ferramenta externa; modelo-agnóstico |
| Code review scoring usa threshold 80 | 80+ = highly confident; menos = ruído |
| Skills ficam em `skills/` | Separação clara entre core e extensões |

---

## 15. Referências

### Propostas Originais
- **PRD-DESIGN-EVOLUTION.md v1.0.0:** `docs/propostas/PRD-DESIGN-EVOLUTION.md`
- **Skills Nando:** `~/.hermes/skills/{devorq,devorq-auto,devorq-mode,devorq-code-review,scope-guard,ddd-deep-domain,env-context}/`

### Links Externos
- **DEVORQ v3 Repo:** https://github.com/nandinhos/devorq_v3
- **PAUL Framework:** https://github.com/charlykast/paul-framework
- **Conventional Commits:** https://www.conventionalcommits.org/
- **BDD (Given-When-Then):** https://cucumber.io/docs/gherkin/

---

## 16. Apendice: Skills — Arquivos de Referência

### GATE-0 Suite

| Skill | SKILL.md | Scripts | References |
|-------|----------|---------|------------|
| env-context | `~/.hermes/skills/env-context/SKILL.md` | `scripts/env-detect.sh` | `references/laravel-filament.md` |
| scope-guard | `~/.hermes/skills/scope-guard/SKILL.md` | `scripts/scope-validate.sh` | `references/laravel-filament-scope.md`, `examples.md` |
| ddd-deep-domain | `~/.hermes/skills/ddd-deep-domain/SKILL.md` | `scripts/ddd-validate-spec.sh` | `references/domain-questions.md` |

### AUTO Mode

| Skill | SKILL.md | Scripts |
|-------|----------|---------|
| devorq-mode | `~/.hermes/skills/devorq-mode/SKILL.md` | `scripts/mode-selector.sh` |
| devorq-auto | `~/.hermes/skills/devorq-auto/SKILL.md` | `scripts/prd-from-spec.sh`, `scripts/check-story.sh`, `scripts/loop-auto.sh` |

### Code Review

| Skill | SKILL.md | Scripts |
|-------|----------|---------|
| devorq-code-review | `~/.hermes/skills/devorq-code-review/SKILL.md` | `scripts/review.sh` |

---

**Documento gerado em:** 2026-05-09 02:00 BRT  
**Versão:** 2.0.0  
**Base:** `PRD-DESIGN-EVOLUTION.md` v1.0.0 + Skills Nando  
**Status:** Pronto para Implementação
