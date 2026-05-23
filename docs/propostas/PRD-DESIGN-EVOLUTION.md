# DEVORQ v3 — Proposta de Evolução: BDD + UNIFY

**Documento:** Proposta de Design para Implementação  
**Versão:** 1.0.0  
**Data:** 2026-05-09  
**Autor:** Hermes Agent (para Fernando Dos Santos)  
**Destinatário:** Dev Core do DEVORQ v3  
**Status:** Pronto para Implementação

---

## Resumo Executivo

Proposta de evolução do DEVORQ v3 para incorporar dois conceitos do framework PAUL (Plan-Apply-Unify Loop):

1. **BDD-style Acceptance Criteria** — Formato estruturado `Given/When/Then` para especificações com maior assertividade
2. **UNIFY como fase explícita** — Rito de fechamento documentado ao final de cada ciclo de implementação

**Não é uma reescrita.** É uma extensão opcional que se encaixa no fluxo existente sem quebrar nada. Specs continuarão funcionando como hoje — BDD e UNIFY são adições, não substituições.

**Stack unchanged:** Bash 5+, jq 1.7+, Git, SSH. Zero novas dependências.

---

## 1. Motivação

### O problema atual

Specs do DEVORQ são livres — qualquer formato. Isso é bom para flexibilidade, mas gera inconsistência:

```
## Validação
- Verificar que endpoint responde 200
- Checar resposta no banco
```

Esse tipo de critério é vago. O que significa "verificar"? O que é "resposta correta"? Quem decide?

### O que acontece na prática

1. Dev implementa baseado na interpretação pessoal da spec
2. Reviewer valida contra "o que acha que a spec pedia"
3. Edge cases (senha errada, token expirado, rate limit) são descobertos em produção
4. Sessões longas perdem rastreamento do que saiu diferente do planejado

### O que a proposta resolve

| Problema | Solução |
|----------|---------|
| Critérios vagos | BDD: "Quando X, então Y" — exato e testável |
| Edge cases descobertos tarde | Given: pré-condições documentadas antes de implementar |
| Sem rito de fechamento | UNIFY: momento formal de fechar, documentar desvios, atualizar estado |
| Context rot | UNIFY reduz acumulação de estado implícito entre sessões |

---

## 2. Análise Comparativa

### Fluxo Atual (DEVORQ v3.4.1)

```
PLAN → SPEC.md (livre) → GATE-1 → GATE-2 → GATE-3 → GATE-4 → [WORK] → GATE-5 → SYNC → END
```

### Proposta (DEVORQ v3.5.0)

```
PLAN → SPEC.md (BDD opcional) → GATE-1 → GATE-2 → GATE-3 → GATE-4 → [WORK] → UNIFY → GATE-5 → SYNC → END
```

**Diferença:** UNIFY entre [WORK] e GATE-5 (Handoff Ready). Não muda os gates existentes.

### Comparação com PAUL

| Aspecto | DEVORQ Atual | PAUL | Proposta DEVORQ |
|---------|-------------|------|-----------------|
| Planning | SPEC.md livre | PLAN.md | SPEC.md com BDD opcional |
| Execution | Validação livre | Execute/Qualify loop | Mantém gates 1-7 |
| Closing | GATE-5 (handoff) | UNIFY (reconciliação) | UNIFY + GATE-5 (handoff) |
| Estado | context.json | STATE.md + ROADMAP.md | Mantém context.json + novo UNIFY.md |
| Flexibilidade | Alta | Média | Alta (BDD opcional) |
| Rastreabilidade | Lições aprendidas | Milestones explícitos | UNIFY.md com desvios documentados |

---

## 3. Arquitetura da Proposta

### 3.1 Estrutura de Arquivos — O que muda

```
devorq_v3/
├── bin/devorq                  # +2 comandos: unify, spec-template
├── lib/
│   ├── unify.sh               # NOVO — lógica UNIFY
│   ├── gates.sh               # + gate_unify() como GATE-5.5 (não bloqueante)
│   ├── lessons.sh             # Integração: UNIFY gera lições automaticamente
│   ├── spec.sh                # NOVO — utilitários de spec BDD
│   └── context.sh             # + ctx_unify_import (importa UNIFY.md → context)
├── scripts/
│   └── sync-push.py           # + UNIFY.md no payload
├── .devorq/
│   └── state/
│       ├── context.json        # + campo "unify_done: bool"
│       └── unify/             # NOVO — UNIFY.md por feature/sessão
│           └── 2026-05-09_143022_unify.md
└── docs/
    ├── SPEC.md                 # Atualizado com BDD template
    ├── BDD-TEMPLATE.md        # NOVO — template Given/When/Then
    └── UNIFY-GUIDE.md         # NOVO — como usar UNIFY
```

### 3.2 Estrutura de Diretórios — Contexto

**.devorq/state/unify/ — Exemplo**

```
.devorq/state/unify/
├── 2026-05-09_143022_auth-login_unify.md   # Feature: auth-login
├── 2026-05-09_144500_auth-logout_unify.md  # Feature: auth-logout
└── 2026-05-10_090000_session-review_unify.md  # Fechamento de sessão
```

Formato do arquivo:

```markdown
# UNIFY — auth-login
**Data:** 2026-05-09T14:30:22Z
**Sessão:** session_20260509_143022
**Feature:** auth-login (AC-1, AC-2, AC-3)

---

## Acceptance Criteria — Resultado Real

| AC | Esperado | Real | Status |
|----|----------|------|--------|
| AC-1 | Status 200 + JWT válido | ✅ Status 200 + JWT com exp 24h | PASS |
| AC-2 | Status 401, sem dados sensíveis | ✅ Status 401 + `{"error": "..."}` | PASS |
| AC-3 | Rate limit após 5 tentativas | ❌ Não implementado (escopo) | DEFERRED |

---

## Lições Aprendidas (auto-geradas)

1. **bcrypt.compare() é síncrono** — precisei usar `crypto.promisify(bcrypt.compare)` dentro de async handler
2. **Token JWT exp está em segundos, não ms** — confundi units no teste

---

## Desvios do Plano Original

- Adicionei middleware de logging (não estava na SPEC) → documentado para próxima revisão
- Tempo real: 45min vs estimado 30min → +50% overhead em validação de edge cases

---

## Pending Items

- [ ] AC-3: Rate limiting (DEFERRED — depende de middleware existente)
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

### 3.3 Fluxo Detalhado — Como UNIFY funciona

```
[SESSÃO INICIADA]
       │
       ▼
  devorq flow "implementar auth-login"
       │
       ▼
  ┌───────────┐
  │  GATE-1   │  SPEC.md existe? (com ou sem BDD)
  └─────┬─────┘
       │
       ▼
  ┌───────────┐
  │  GATE-2   │  devorq test passa?
  └─────┬─────┘
       │
       ▼
  ┌───────────┐
  │  GATE-3   │  contexto válido?
  └─────┬─────┘
       │
       ▼
  ┌───────────┐
  │  GATE-4   │  lições revisadas?
  └─────┬─────┘
       │
       ▼
  ┌───────────┐
  │  GATE-6   │  Context7?
  └─────┬─────┘
       │
       ▼
  ┌─────────────────────┐
  │      WORK            │  ← Implementação
  │                      │
  │  devorq spec validate │  ← Valida BDD se existir
  │  (verifica AC format)│
  │                      │
  │  [implementa AC-1]   │
  │  [implementa AC-2]   │
  │  [implementa AC-3]   │
  └──────────┬──────────┘
             │
             ▼ (ao finalizar feature ou sessão)
  ┌─────────────────────┐
  │       UNIFY          │  ← NOVA FASE
  │                      │
  │  devorq unify        │  ← Gera UNIFY.md
  │  (review de ACs)    │  ← Documenta desvios
  │  (captura lições)   │  ← Auto-capture lessons
  │  (update context)  │  ← context.unify_done = true
  └──────────┬──────────┘
             │
             ▼
  ┌───────────┐
  │  GATE-5   │  devorq compact (handoff)
  └─────┬─────┘
       │
       ▼
  devorq sync push
       │
       ▼
   [FIM DA SESSÃO]
```

### 3.4 Quando UNIFY é acionado

| Gatilho | Comportamento |
|---------|---------------|
| `devorq unify` (manual) | Executa UNIFY imediatamente, gera UNIFY.md |
| `devorq flow` completo | UNIFY executado automaticamente antes de GATE-5 |
| `devorq compact` | Se UNIFY ainda não feito, pergunta se quer fazer agora |
| `devorq lessons capture` | Lições capturadas via UNIFY já vão para o array |

---

## 4. Template de SPEC.md com BDD

### 4.1 Template Completo

```markdown
# [Nome do Projeto/Feature]

**Versão:** X.Y.Z  
**Data:** YYYY-MM-DD  
**Status:** Draft | In Progress | Review | Done

---

## 1. Visão

[Descrição de uma linha do que este projeto resolve]

## 2. Stack

- [ ] Tecnologia 1
- [ ] Tecnologia 2

## 3. Arquitetura

[Diagrama ou descrição da estrutura]

---

## 4. Acceptance Criteria (BDD)

### AC-[N]: [Título da AC]

**Given** [pré-condição / estado inicial do sistema]
**When** [ação realizada pelo usuário ou sistema]
**Then** [resultado esperado, verificável e testável]

**Critérios de sucesso:**
- [ ] Critério 1 (testável)
- [ ] Critério 2 (testável)

**Critérios de falha (edge cases):**
- [ ] Edge case 1
- [ ] Edge case 2

**Notas:**
- [Nota opcional sobre decisão de design]

---

## 5. Out of Scope

- Item 1
- Item 2

---

## 6. Stack Técnica

| Componente | Tecnologia | Justificativa |
|-----------|------------|---------------|
| API | Node.js 20 | [ ] |
| DB | PostgreSQL 16 | [ ] |
| Auth | JWT RS256 | [ ] |

---

## 7. Diagrama de Fluxo

```
[Diagrama em ASCII ou descrição]
```

---

## 8. Interfaces

### 8.1 API Endpoints

| Método | Path | Descrição | Auth |
|--------|------|-----------|------|
| POST | /auth/login | Login | Não |

### 8.2 Request/Response

**POST /auth/login**

Request:
```json
{
  "email": "string",
  "password": "string"
}
```

Response (200):
```json
{
  "token": "jwt-string",
  "expires_in": 86400
}
```

---

## 9. Notas de Implementação

[N decisions, trade-offs, e observações técnicas]

---

## 10. UNIFY (preenchido ao fechar)

[Este bloco é ignorado durante GATE-1 e preenchido pelo `devorq unify`]

```yaml
unify:
  date: YYYY-MM-DDTHH:MM:SSZ
  ac_passed: [lista de AC que passaram]
  ac_failed: [lista de AC que falharam]
  ac_deferred: [lista de AC adiadas]
  lessons: [lições aprendidas durante implementação]
  deviations: [o que saiu diferente do planejado]
  time_spent: [tempo real vs estimado]
```
```

### 4.2 Exemplo Completo: auth-login

```markdown
# auth-login — Autenticação de Usuário

**Versão:** 1.0.0  
**Data:** 2026-05-09  
**Status:** In Progress

---

## 1. Visão

Endpoint de autenticação que valida credenciais e retorna JWT para sessões.

## 2. Stack

- Node.js 20 + Express
- PostgreSQL 16
- bcrypt + jsonwebtoken

## 3. Arquitetura

```
┌──────────┐     POST /auth/login     ┌─────────────┐
│  Client  │ ───────────────────────► │   Express   │
│          │ ◄─────────────────────── │  /auth/*   │
└──────────┘      200 + JWT           └──────┬──────┘
                                            │
                                      ┌─────▼─────┐
                                      │ PostgreSQL│
                                      │  users    │
                                      └───────────┘
```

---

## 4. Acceptance Criteria (BDD)

### AC-1: Login com credenciais válidas

**Given** o usuário existe no sistema com email "nando@devorq.com" e senha "Senha@123"  
**When** o cliente envia POST /auth/login com `{"email": "nando@devorq.com", "password": "Senha@123"}`  
**Then** o servidor retorna status 200 com `{"token": "<jwt-válido>", "expires_in": 86400}` e o token expira em 24h

**Critérios de sucesso:**
- [ ] Status code é 200
- [ ] Response contém campo `token` (string não-vazia)
- [ ] Response contém campo `expires_in` = 86400
- [ ] Token pode ser decodificado com a secret do servidor
- [ ] Payload do token contém `user_id` e `email`

**Critérios de falha (edge cases):**
- [ ] Usuário não existe → status 401
- [ ] Senha errada → status 401
- [ ] Campos faltando → status 400
- [ ] Email mal-formatado → status 400

---

### AC-2: Login com credenciais inválidas

**Given** o usuário existe com email "nando@devorq.com" e senha "Senha@123"  
**When** o cliente envia POST /auth/login com senha "senhaErrada"  
**Then** o servidor retorna status 401 com `{"error": "Invalid credentials"}` e a resposta NÃO contém dados do usuário

**Critérios de sucesso:**
- [ ] Status code é 401
- [ ] Response contém `error` (string)
- [ ] Response NÃO contém campo `token`
- [ ] Response NÃO expõe hash da senha ou dados sensíveis
- [ ] Tempo de resposta é indistinguível de usuário inexistente (timing attack)

**Critérios de falha (edge cases):**
- [ ] Rate limit: após 5 tentativas falhas em 1 minuto, bloquear por 5 minutos
- [ ] Usuário inexistente retorna mesmo tempo de resposta que senha errada

---

### AC-3: Rate limiting

**Given** o cliente tentou login 5 vezes com credenciais inválidas em menos de 1 minuto  
**When** o cliente envia POST /auth/login com credenciais válidas  
**Then** o servidor retorna status 429 com `{"error": "Too many requests", "retry_after": 300}` e o IP fica bloqueado por 5 minutos

**Critérios de sucesso:**
- [ ] Status code é 429 após 5 tentativas falhas
- [ ] Response contém `retry_after` com segundos para desbloqueio
- [ ] Bloqueio é por IP, não por email

---

## 5. Out of Scope

- Refresh token (feature separada)
- Login social (Google, GitHub)
- 2FA
- Recuperação de senha

---

## 6. Stack Técnica

| Componente | Tecnologia | Justificativa |
|-----------|------------|---------------|
| Runtime | Node.js 20 LTS | LTS, async/await nativo |
| Framework | Express 4 | Middleware disponível |
| DB Driver | pg (node-postgres) | Prepared statements contra SQL injection |
| Hash | bcrypt 5 | Cost factor 12, built-in salt |
| JWT | jsonwebtoken | RS256, expClaim automático |
| Validation | express-validator | Sanitização de input |

---

## 7. Diagrama de Fluxo

```
Client                    Server                      DB
  │                          │                         │
  │──POST /auth/login───────►│                         │
  │                          │──SELECT users WHERE───► │
  │                          │◄──user row──────────────│
  │                          │                         │
  │                          │ [valida senha]          │
  │                          │ [gera JWT]              │
  │◄──200 {token}────────────│                         │
  │                          │                         │
  [fim]                      [fim]                    [fim]
```

---

## 8. Interfaces

### 8.1 API Endpoints

| Método | Path | Descrição | Auth |
|--------|------|-----------|------|
| POST | /auth/login | Login de usuário | Não |

### 8.2 Request/Response

**POST /auth/login**

Request:
```json
{
  "email": "nando@devorq.com",
  "password": "Senha@123"
}
```

Response (200):
```json
{
  "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 86400
}
```

Response (401):
```json
{
  "error": "Invalid credentials"
}
```

Response (429):
```json
{
  "error": "Too many requests",
  "retry_after": 300
}
```

---

## 9. Notas de Implementação

1. **Timing attack mitigation:** Sempre executar bcrypt.compare() mesmo quando usuário não existe — usar hash placeholder
2. **JWT RS256 vs HS256:** Usar RS256 (assimétrico) — private key no servidor, public key pode ser exposta
3. **bcrypt Cost Factor 12:** Default 10 é lento demais para 2026; 12 é bom equilíbrio

---

## 10. UNIFY (preenchido ao fechar)

[Preenchido automaticamente por `devorq unify`]
```

---

## 5. Comandos Novos

### 5.1 `devorq unify`

**Arquivo:** `lib/unify.sh`  
**Descrição:** Executa fase UNIFY — revisa ACs, documenta desvios, captura lições

```bash
devorq unify [feature] [--auto] [--lessons]
```

| Flag | Descrição |
|------|-----------|
| `[feature]` | Nome da feature para associar (default: inferido do intent) |
| `--auto` | Executa sem prompts (para scripts/CI) |
| `--lessons` | Auto-captura lições dos desvios encontrados |

**Comportamento:**

1. Detecta SPEC.md no diretório atual
2. Se SPEC.md tem seção `Acceptance Criteria (BDD)`, processa cada AC:
   - Compara com estado atual do código (via testes ou inspection)
   - Marca como PASS / FAIL / DEFERRED
3. Gera `.devorq/state/unify/YYYY-MM-DD_HHMMSS_[feature]_unify.md`
4. Auto-captura lições para `lessons::capture` se `--lessons`
5. Atualiza `context.json` com `unify_done: true`
6. Se GATE-5 (Handoff) ainda não passou, executa após UNIFY

**Exit codes:**
- `0` = UNIFY completo com todos AC pass
- `1` = AC falharam ou UNIFY incompleto
- `2` = SPEC.md não encontrada ou sem seção BDD

### 5.2 `devorq spec validate`

**Arquivo:** `lib/spec.sh` (novo)  
**Descrição:** Valida que SPEC.md está bem-formatada (com ou sem BDD)

```bash
devorq spec validate [--strict] [--format table|json]
```

| Flag | Descrição |
|------|-----------|
| `--strict` | Erra se BDD não está presente (mesmo sendo opcional) |
| `--format table` | Saída formatada em tabela (default) |
| `--format json` | Saída JSON para integração CI |

**Validações realizadas:**

```
┌─────────────────────────────────────┬──────────────────────────────┐
│ Regra                               │ Severidade                   │
├─────────────────────────────────────┼──────────────────────────────┤
│ Seção "Acceptance Criteria (BDD)"   │ WARN (opcional)              │
│ AC tem Given/When/Then              │ ERROR se --strict            │
│ AC tem critérios de sucesso         │ WARN                         │
│ AC tem edge cases                   │ WARN                         │
│ "Out of Scope" existe               │ WARN                         │
│ "Stack Técnica" existe              │ WARN                         │
│ Diagrama de fluxo presente           │ WARN                         │
│ Seção UNIFY existe mas vazia        │ INFO                         │
│ Nenhum placeholder [TODO] restante   │ ERROR                        │
└─────────────────────────────────────┴──────────────────────────────┘
```

### 5.3 `devorq spec template`

**Descrição:** Gera template de SPEC com BDD

```bash
devorq spec template [feature-name]
```

**Saída:** Cria `SPEC.md` no diretório atual com o template completo (seção 4.1 deste documento).

### 5.4 `devorq spec check-ac`

**Descrição:** Verifica se todos os Acceptance Criteria estão cobertos por testes

```bash
devorq spec check-ac [--spec SPEC.md]
```

Útil para CI/CD: retorna lista de AC sem cobertura de teste.

---

## 6. Detalhamento Técnico das Mudanças

### 6.1 `lib/unify.sh` — Estrutura Completa

```bash
#!/usr/bin/env bash
# lib/unify.sh — DEVORQ UNIFY Module
#
# Responsabilidades:
#   unify::run        — Executa fase UNIFY completa
#   unify::parse_ac   — Extrai ACs do SPEC.md
#   unify::check_ac   — Verifica status de cada AC
#   unify::generate   — Gera arquivo UNIFY.md
#   unify::capture    — Auto-captura lições dos desvios
#   unify::update_ctx — Atualiza context.json

set -euo pipefail

# Cores
GREEN='' CYAN='' RED='' YELLOW='' RESET='' BOLD=''

# Paths
DEVORQ_UNIFY_DIR="${PWD}/.devorq/state/unify"
DEVORQ_STATE_DIR="${PWD}/.devorq/state"

# ============================================================
# unify::run
#   $1 = feature name (opcional)
#   $2 = --auto (opcional)
# ============================================================
unify::run() {
    local feature="${1:-}"
    local auto="${2:-}"

    # 1. Detectar feature se não informada
    if [ -z "$feature" ]; then
        feature=$(unify::infer_feature)
    fi

    # 2. Verificar que SPEC.md existe
    if [ ! -f "SPEC.md" ]; then
        echo "[ERROR] SPEC.md não encontrado" >&2
        return 2
    fi

    # 3. Criar diretório de unify se não existir
    mkdir -p "$DEVORQ_UNIFY_DIR"

    # 4. Parsear ACs do SPEC.md
    local ac_list
    ac_list=$(unify::parse_ac "SPEC.md")
    if [ -z "$ac_list" ]; then
        echo "[WARN] Nenhum Acceptance Criteria (BDD) encontrado em SPEC.md"
        echo "[INFO] UNIFY é mais efetivo com BDD-style ACs"
        echo "[INFO] Para criar ACs: devorq spec template [feature]"
        return 0  # Não é erro — spec sem BDD é válida
    fi

    # 5. Para cada AC, verificar status
    local ac_results=()
    while IFS= read -r ac; do
        local ac_id=$(echo "$ac" | jq -r '.id')
        local ac_title=$(echo "$ac" | jq -r '.title')
        local ac_status

        # Verifica se AC passou (via testes ou inspection)
        ac_status=$(unify::check_ac "$ac")
        ac_results+=("$(jq -n \
            --arg id "$ac_id" \
            --arg title "$ac_title" \
            --arg status "$ac_status" \
            '{id: $id, title: $title, status: $status}')")
    done <<< "$ac_list"

    # 6. Gerar UNIFY.md
    local ts
    ts=$(date +%Y-%m-%d_%H%M%S)
    local unify_file="${DEVORQ_UNIFY_DIR}/${ts}_${feature}_unify.md"
    unify::generate "$unify_file" "$feature" "$ts" "$ac_list" "$ac_results"

    # 7. Auto-capturar lições se habilitado
    if [ "$auto" = "--auto" ] || [ "$auto" = "--lessons" ]; then
        unify::capture_lessons "$ac_results"
    fi

    # 8. Atualizar context.json
    unify::update_context "$unify_file" "$ac_results"

    echo "[OK] UNIFY gerado: $unify_file"

    # 9. Resumo
    local passed=$(echo "$ac_results" | jq '[.status == "PASS"] | length')
    local failed=$(echo "$ac_results" | jq '[.status == "FAIL"] | length')
    local deferred=$(echo "$ac_results" | jq '[.status == "DEFERRED"] | length')
    echo "AC: $passed passed, $failed failed, $deferred deferred"
}

# ============================================================
# unify::parse_ac
#   $1 = path para SPEC.md
#   Retorna JSON array de ACs
# ============================================================
unify::parse_ac() {
    local spec_file="$1"

    # Procura seção "Acceptance Criteria (BDD)"
    # Extrai todos os blocos "### AC-N: ... Given ... When ... Then"
    grep -A 20 "## 4. Acceptance Criteria" "$spec_file" 2>/dev/null | \
    grep -E "^### AC-" | \
    while IFS= read -r line; do
        local ac_id=$(echo "$line" | sed 's/^### //' | cut -d':' -f1)
        local ac_title=$(echo "$line" | sed 's/^### [^:]*: //')
        # Given/When/Then extraction would go here
        # (full implementation in actual file)
    done
}

# ============================================================
# unify::check_ac
#   $1 = AC JSON object
#   Retorna: PASS | FAIL | DEFERRED | UNKNOWN
#
# Lógica de detecção (a ser implementada pelo dev):
#   1. Se existe teste com nome da AC → executa
#   2. Se AC contém keyword "TODO" → DEFERRED
#   3. Se código referencia AC (grep) → UNKNOWN (precisa review)
#   4. Caso contrário → FAIL
# ============================================================
unify::check_ac() {
    local ac_json="$1"
    local ac_id=$(echo "$ac_json" | jq -r '.id')

    # PLACEHOLDER — implementação real fica a cargo do dev
    # Este é o algoritmo sugerido:

    # 1. Tentar encontrar teste correspondente
    if grep -r "AC-$ac_id" tests/ 2>/dev/null | grep -q "test\|it\|describe"; then
        # Executar teste
        local test_result
        test_result=$(npm test -- --grep "AC-$ac_id" 2>/dev/null && echo "PASS" || echo "FAIL")
        echo "$test_result"
        return
    fi

    # 2. AC contém TODO
    if grep -A 5 "AC-$ac_id" SPEC.md | grep -qi "TODO\|DEFERRED\|NOT IMPLEMENTED"; then
        echo "DEFERRED"
        return
    fi

    # 3. Default: precisa review manual
    echo "UNKNOWN"
}

# ============================================================
# unify::generate
#   $1 = output file
#   $2 = feature name
#   $3 = timestamp
#   $4 = ac_list (JSON)
#   $5 = ac_results (JSON)
# ============================================================
unify::generate() {
    local output="$1"
    local feature="$2"
    local ts="$3"
    local ac_list="$4"
    local ac_results="$5"

    cat > "$output" << EOF
# UNIFY — $feature
**Data:** $(date -Iseconds)
**Feature:** $feature

---

## Acceptance Criteria — Resultado Real

$(unify::format_ac_table "$ac_list" "$ac_results")

---

## Lições Aprendidas

[Preencha manualmente ou use --lessons para auto-capture]

---

## Desvios do Plano Original

[O que saiu diferente do planejado na SPEC.md]

---

## Pending Items

- [ ] [item pendente]

---

## Estado Final

\`\`\`json
{
  "unify_done": true,
  "unify_file": "$output",
  "timestamp": "$ts"
}
\`\`\`
EOF
}

# ============================================================
# unify::update_context
#   Atualiza context.json com unify_done
# ============================================================
unify::update_context() {
    local unify_file="$1"
    local ac_results="$2"

    local ctx_file="${DEVORQ_STATE_DIR}/context.json"

    if [ -f "$ctx_file" ]; then
        # Usa jq se disponível, fallback sed
        if command -v jq &>/dev/null; then
            local passed=$(echo "$ac_results" | jq '[.status == "PASS"] | length')
            local failed=$(echo "$ac_results" | jq '[.status == "FAIL"] | length')
            local deferred=$(echo "$ac_results" | jq '[.status == "DEFERRED"] | length')

            jq --arg uf "$unify_file" \
               --argjson passed "$passed" \
               --argjson failed "$failed" \
               --argjson deferred "$deferred" \
               '. + {
                   unify_done: true,
                   unify_file: $uf,
                   ac_passed: $passed,
                   ac_failed: $failed,
                   ac_deferred: $deferred
               }' "$ctx_file" > "${ctx_file}.tmp" && \
               mv "${ctx_file}.tmp" "$ctx_file"
        fi
    fi
}

# ============================================================
# unify::infer_feature
#   Infere nome da feature do context.json ou git branch
# ============================================================
unify::infer_feature() {
    local ctx_file="${DEVORQ_STATE_DIR}/context.json"
    local intent=""

    if [ -f "$ctx_file" ] && command -v jq &>/dev/null; then
        intent=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null || echo "")
    fi

    # Limpa intent para nome de arquivo (remove espaços, caracteres especiais)
    echo "$intent" | sed 's/[^a-zA-Z0-9_-]/_/g' | tr '[:upper:]' '[:lower:]' | cut -c1-50
}
```

### 6.2 `lib/spec.sh` — Estrutura Completa

```bash
#!/usr/bin/env bash
# lib/spec.sh — DEVORQ SPEC Validation Module
#
# Responsabilidades:
#   spec::validate  — Valida SPEC.md (opcional com BDD)
#   spec::template   — Gera template de SPEC com BDD
#   spec::check_ac   — Verifica cobertura de ACs

set -euo pipefail

# ============================================================
# spec::validate
#   $1 = --strict (opcional)
#   $2 = --format table|json (opcional)
# ============================================================
spec::validate() {
    local strict=""
    local format="table"
    local exit_code=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --strict) strict="true"; shift ;;
            --format) format="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local spec_file="${PWD}/SPEC.md"

    if [ ! -f "$spec_file" ]; then
        echo "[ERROR] SPEC.md não encontrado"
        return 1
    fi

    # Validações
    local issues=()

    # CHECK 1: Seção Acceptance Criteria (BDD)
    if grep -q "## 4. Acceptance Criteria" "$spec_file"; then
        if grep -q "Given\|When\|Then" "$spec_file"; then
            spec::info "BDD-style ACs encontrados"
        else
            spec::warn "Seção AC existe mas não usa Given/When/Then"
            issues+=("AC sem formato BDD (WARN)")
        fi
    else
        if [ -n "$strict" ]; then
            spec::error "Seção Acceptance Criteria não encontrada"
            issues+=("AC ausente (ERROR)")
            exit_code=1
        else
            spec::warn "Seção Acceptance Criteria não encontrada"
            issues+=("AC ausente (WARN)")
        fi
    fi

    # CHECK 2: Out of Scope
    if ! grep -q "## [45].*Out of Scope" "$spec_file"; then
        spec::warn "Seção Out of Scope não encontrada"
        issues+=("Out of Scope ausente (WARN)")
    fi

    # CHECK 3: Stack Técnica ou Stack
    if ! grep -qE "## [56].*Stack|## [56].*Tecnolog" "$spec_file"; then
        spec::warn "Seção Stack Técnica não encontrada"
        issues+=("Stack Técnica ausente (WARN)")
    fi

    # CHECK 4: Placeholder [TODO]
    if grep -q "\[TODO\]" "$spec_file"; then
        spec::error "SPEC.md contém placeholders [TODO]"
        issues+=("[TODO] presente (ERROR)")
        exit_code=1
    fi

    # CHECK 5: Diagrama de fluxo
    if ! grep -qE "```|ASCII|diagrama|fluxo" "$spec_file"; then
        spec::warn "Diagrama de fluxo não encontrado"
        issues+=("Diagrama ausente (WARN)")
    fi

    # Output
    if [ "$format" = "json" ]; then
        spec::format_json "$issues"
    else
        spec::format_table "$issues"
    fi

    return $exit_code
}

# ============================================================
# spec::template
#   Gera template SPEC.md com BDD
# ============================================================
spec::template() {
    local feature="${1:-new-feature}"

    cat > "SPEC.md" << EOF
# $feature

**Versão:** 0.1.0
**Data:** $(date +%Y-%m-%d)
**Status:** Draft

---

## 1. Visão

[Descrição de uma linha do que este projeto resolve]

## 2. Stack

- [ ] Tecnologia 1
- [ ] Tecnologia 2

## 3. Arquitetura

[Diagrama ou descrição da estrutura]

---

## 4. Acceptance Criteria (BDD)

### AC-1: [Título da AC]

**Given** [pré-condição / estado inicial do sistema]  
**When** [ação realizada pelo usuário ou sistema]  
**Then** [resultado esperado, verificável e testável]

**Critérios de sucesso:**
- [ ] Critério 1 (testável)
- [ ] Critério 2 (testável)

**Critérios de falha (edge cases):**
- [ ] Edge case 1
- [ ] Edge case 2

---

## 5. Out of Scope

- Item 1
- Item 2

---

## 6. Stack Técnica

| Componente | Tecnologia | Justificativa |
|-----------|------------|---------------|
| Runtime | [ ] | [ ] |
| Framework | [ ] | [ ] |
| DB | [ ] | [ ] |

---

## 7. Diagrama de Fluxo

\`\`\`
[Diagrama em ASCII]
\`\`\`

---

## 8. Interfaces

### 8.1 API Endpoints

| Método | Path | Descrição | Auth |
|--------|------|-----------|------|
| GET | /resource | Listar | Sim |

### 8.2 Request/Response

[Definir request/response]

---

## 9. Notas de Implementação

1. [Decisão de design 1]
2. [Trade-off 1]

---

## 10. UNIFY (preenchido ao fechar)

[Preenchido automaticamente por \`devorq unify\`]
EOF

    echo "[OK] Template gerado: SPEC.md"
}

# Helpers
spec::info()  { echo "[INFO] $*"; }
spec::warn()  { echo "[WARN] $*" >&2; }
spec::error() { echo "[ERROR] $*" >&2; }
spec::format_table() {
    local issues="$1"
    echo ""
    echo "SPEC.md Validation Summary"
    echo "========================="
    if [ ${#issues[@]} -eq 0 ]; then
        echo "✅ SPEC.md está bem formatada"
    else
        printf '%s\n' "${issues[@]}"
    fi
}
spec::format_json() {
    local issues="$1"
    # JSON output — implementation
    echo "{}"
}
```

### 6.3 `bin/devorq` — Mudanças no entry point

**Mudanças no `devorq::help()` — adicionar:**

```
  unify [feature]           Executar fase UNIFY
  spec validate [--strict]  Validar SPEC.md
  spec template [name]     Gerar template SPEC.md com BDD
  spec check-ac            Verificar cobertura de ACs
```

**Novas funções no `bin/devorq`:**

```bash
devorq::cmd_unify() {
    source "${DEVORQ_LIB}/unify.sh"
    local feature="${1:-}"
    local auto="${2:-}"
    unify::run "$feature" "$auto"
}

devorq::cmd_spec() {
    source "${DEVORQ_LIB}/spec.sh"
    local subcommand="${1:-}"
    case "$subcommand" in
        validate) shift; spec::validate "$@";;
        template) shift; spec::template "$@";;
        check-ac) spec::check_ac;;
        *) echo "Uso: devorq spec validate|template|check-ac";;
    esac
}
```

### 6.4 `lib/gates.sh` — GATE-5.5 (não bloqueante)

Adicionar após gate_5() em `lib/gates.sh`:

```bash
# ============================================================
# GATE-5.5 — UNIFY Check (NÃO BLOQUEANTE)
# Executado automaticamente após gate_5
# ============================================================

gate_5_5() {
    gate::info 5.5 "UNIFY — fase de fechamento"

    local ctx_file="${PWD}/.devorq/state/context.json"

    if [ ! -f "$ctx_file" ]; then
        gate::warn 5.5 "context.json não existe — pulando UNIFY check"
        return 0
    fi

    if command -v jq &>/dev/null; then
        local unify_done
        unify_done=$(jq -r '.unify_done // false' "$ctx_file")

        if [ "$unify_done" != "true" ]; then
            gate::warn 5.5 "UNIFY ainda não executado nesta sessão"
            gate::info 5.5 "Execute: devorq unify [feature]"
            gate::info 5.5 "Ou inclua --unify no devorq flow para executar automaticamente"
            # NÃO BLOQUEIA — apenas aviso
        else
            gate::pass 5.5 "UNIFY executado: $(jq -r '.unify_file // "unknown"' "$ctx_file")"
        fi
    fi

    return 0  # Sempre passa — não bloqueante
}
```

**Chamar `gate_5_5` após `gate_5` em `gates::check` e `devorq::gate`:**

```bash
# No fluxo principal (gates::check)
gate_1 || return 1
gate_2 || return 1
gate_3 || return 1
gate_4 || return 1
gate_5 || return 1
gate_5_5  # ← ADICIONAR (não bloqueante)
gate_6    # Não bloqueia — WARN OK
gate_7    # Reativo — só entra se erro
```

### 6.5 `lib/lessons.sh` — Integração UNIFY

**Adicionar função `lessons::from_unify`:**

```bash
# ============================================================
# lessons::from_unify
#   Extrai lições do UNIFY.md e captura automaticamente
#   $1 = caminho para UNIFY.md
# ============================================================
lessons::from_unify() {
    local unify_file="$1"

    if [ ! -f "$unify_file" ]; then
        return 1
    fi

    # Extrair lições da seção "Lições Aprendidas"
    local lessons_section
    lessons_section=$(sed -n '/## Lições Aprendidas/,/## /p' "$unify_file" 2>/dev/null || echo "")

    if [ -z "$lessons_section" ]; then
        return 0  # Sem lições — não é erro
    fi

    # Parsear cada linha que começa com número ou bullet
    echo "$lessons_section" | grep -E "^[0-9]+[\.)]|^\*" | \
    while IFS= read -r line; do
        local title
        local problem
        local solution

        # Parse: "1. bcrypt.compare() é síncrono — precisei usar..."
        title=$(echo "$line" | sed 's/^[0-9]*[\.)] *//' | cut -d'-' -f1 | tr -d '[:space:]')
        problem=$(echo "$line" | sed 's/^[0-9]*[\.)] *//')
        solution="Verificar documentação da biblioteca para确认 se método é síncrono ou async"

        if [ -n "$problem" ]; then
            echo "[LESSON] Capturando: $title"
            lessons::capture "$title" "$problem" "$solution" 2>/dev/null || true
        fi
    done
}
```

---

## 7. PRD Atualizado — Stories v4

O `prd.json` atual tem 8 stories. Adicionar 3 novas para BDD + UNIFY:

```json
{
  "stories": [
    {
      "id": "infra-bdd-001",
      "title": "lib/spec.sh — validação BDD de SPEC.md",
      "description": "Criar lib/spec.sh com spec::validate, spec::template, spec::check_ac. Validar Given/When/Then, detectar [TODO], sugerir Out of Scope.",
      "acceptanceCriteria": [
        "spec::validate retorna 0 para SPEC.md com BDD válido",
        "spec::validate retorna 1 (--strict) quando AC ausente",
        "spec::template gera SPEC.md com template BDD completo",
        "spec::check-ac lista ACs sem cobertura de teste"
      ],
      "priority": 10,
      "passes": false,
      "phase": "infra"
    },
    {
      "id": "infra-unify-001",
      "title": "lib/unify.sh — fase UNIFY completa",
      "description": "Criar lib/unify.sh com unify::run, unify::parse_ac, unify::check_ac, unify::generate, unify::update_context. Gera .devorq/state/unify/YYYY-MM-DD_feature_unify.md.",
      "acceptanceCriteria": [
        "unify::run gera arquivo UNIFY.md válido",
        "GATE-5.5 executa após gate_5 e não bloqueia",
        "context.json atualizado com unify_done: true",
        "Lições auto-capturadas com --lessons flag"
      ],
      "priority": 20,
      "passes": false,
      "phase": "infra"
    },
    {
      "id": "infra-unify-002",
      "title": "devorq unify — comando CLI",
      "description": "Adicionar comando 'devorq unify [feature] [--auto] [--lessons]' ao bin/devorq. Integrar no fluxo devorq flow se --unify passado.",
      "acceptanceCriteria": [
        "devorq unify sem feature infere do context.json",
        "devorq unify --auto não faz perguntas",
        "devorq flow com --unify executa UNIFY antes de GATE-5"
      ],
      "priority": 30,
      "passes": false,
      "phase": "infra"
    },
    {
      "id": "docs-bdd-001",
      "title": "BDD-TEMPLATE.md — template de referência",
      "description": "Criar docs/BDD-TEMPLATE.md com template Given/When/Then completo e exemplos para API, CLI e UI.",
      "acceptanceCriteria": [
        "docs/BDD-TEMPLATE.md existe com template completo",
        "Exemplo de AC-1 (caso de sucesso) com Given/When/Then completo",
        "Exemplo de AC-2 (edge case) com Given/When/Then completo"
      ],
      "priority": 40,
      "passes": false,
      "phase": "docs"
    },
    {
      "id": "docs-unify-001",
      "title": "UNIFY-GUIDE.md — guia de uso",
      "description": "Criar docs/UNIFY-GUIDE.md explicando quando usar UNIFY, como interpretar o arquivo gerado, e como integrar no workflow.",
      "acceptanceCriteria": [
        "docs/UNIFY-GUIDE.md existe com fluxo completo",
        "Guia inclui exemplo de UNIFY.md preenchido",
        "Guia explica interação com lessons::capture"
      ],
      "priority": 50,
      "passes": false,
      "phase": "docs"
    }
  ]
}
```

---

## 8. Critérios de Implementação

### Regras de Ouro

1. **UNIFY nunca bloqueia** — é sempre WARN ou INFO, nunca FAIL
2. **BDD é opcional** — SPEC.md sem Given/When/Then continua válida
3. **Zero novas dependências** — Bash + jq apenas
4. **Backward compatible** — tudo que existe hoje continua funcionando
5. **Arquivos UNIFY em .devorq/state/unify/** — versionados localmente, não vão para o repo principal (adicionar ao .gitignore)
6. **Lições auto-capturadas são sugestões** — vêm marcadas `validated: false` para review

### O que NÃO mudar

- Os 7 gates existentes (GATE-1 a GATE-7)
- Estrutura de `lib/lessons.sh` atual
- Formato de `context.json` (apenas adicionar campos novos)
- Interface do `devorq flow` existente (UNIFY é opt-in via `--unify` ou `devorq unify`)
- Comando `devorq compact` — UNIFY roda antes, não substitui

### O que PODE mudar (se necessário)

- Formato interno de UNIFY.md (desde que campos obrigatórios mantidos)
- Lógica de `unify::check_ac` (placeholder,有待 implementação real)
- Threshold de tokens para alertas de contexto (>60k, >120k) — não relacionado a UNIFY

---

## 9. Roadmap de Implementação

### Fase 1: Infraestrutura (3-4h)

| Task | Tempo | Responsável |
|------|-------|-------------|
| Criar `lib/spec.sh` | 1h | Dev |
| Criar `lib/unify.sh` (estrutura) | 1h | Dev |
| Integrar `gate_5_5` em `lib/gates.sh` | 30min | Dev |
| Adicionar comandos em `bin/devorq` | 30min | Dev |
| **Total Fase 1** | **3h** | |

### Fase 2: Documentação (1-2h)

| Task | Tempo |
|------|-------|
| Criar `docs/BDD-TEMPLATE.md` | 45min |
| Criar `docs/UNIFY-GUIDE.md` | 45min |
| Atualizar `docs/SPEC.md` (seção BDD) | 30min |
| **Total Fase 2** | **2h** |

### Fase 3: Testes e Validação (2h)

| Task | Tempo |
|------|-------|
| Criar SPEC.md de teste com BDD | 15min |
| Executar `devorq spec validate --strict` | 15min |
| Executar `devorq spec template auth-login` | 15min |
| Executar `devorq unify auth-login` (sem AC reais) | 15min |
| Verificar GATE-5.5 no fluxo | 15min |
| Executar `devorq flow --unify "implementar X"` | 1h |
| **Total Fase 3** | **2h** |

### Fase 4: Integração com Lessons (1h)

| Task | Tempo |
|------|-------|
| Integrar `lessons::from_unify` | 30min |
| Testar auto-capture com `--lessons` | 30min |
| **Total Fase 4** | **1h** |

---

## 10. Testes de Regressão

Após implementar, executar e verificar:

```bash
# 1. Fluxo atual continua funcionando
devorq flow "implementar feature simples"

# 2. GATE-5.5 não bloqueia fluxo atual
devorq gate 5   # deve passar
devorq gate 5.5 # deve passar com WARN se UNIFY não feito

# 3. UNIFY gera arquivo válido
devorq unify test-feature --auto
cat .devorq/state/unify/*_test-feature_unify.md

# 4. context.json atualizado
jq '.unify_done, .unify_file' .devorq/state/context.json

# 5. Lições capturadas
devorq lessons list | grep -i "unify\|bdd"

# 6. spec validate funciona
devorq spec validate
devorq spec validate --strict  # deve falhar se sem BDD

# 7. spec template gera arquivo
devorq spec template minha-feature
cat SPEC.md | grep -A 5 "Acceptance Criteria"

# 8. Sync push inclui UNIFY
devorq sync push
# verificar no VPS se UNIFY.md chegou
```

---

## 11. Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|--------------|---------|-----------|
| UNIFY vira bureaucracy | Média | Alto | BDD é opcional; UNIFY nunca bloqueia |
| Dev ignora UNIFY | Alta | Baixo | GATE-5.5 só warn;文化建设 via coaching |
| ACs defasados vs código | Alta | Médio | UNIFY.md fica em .devorq/ (local); revisão no review |
| Gera muita "lição" trivial | Média | Baixo | `validated: false` default; lições passam por review antes de serem skills |
| Aumento de overhead por sessão | Baixa | Médio | UNIFY executado 1x por feature, não por arquivo alterado |

---

## 12. Decisões de Design Documentadas

| Decisão | Justificativa |
|---------|---------------|
| UNIFY é fase entre WORK e GATE-5 | GATE-5 (handoff) precisa de estado fechado; UNIFY fecha antes |
| UNIFY.md vai para `.devorq/state/unify/` | Versionado localmente; não polui repo principal |
| GATE-5.5 é não-bloqueante | Filosofia DEVORQ: discipline sem bureaucracy; gates bloqueantes são só os 7 originais |
| BDD opcional | Não forçar em todos os projetos; overhead só compensa em features complexas |
| Lessons via UNIFY auto-capturadas com `validated: false` | Confiança zero em auto-capture; review humano mantém qualidade |

---

## 13. Referências

- **PAUL Framework:** https://github.com/charlykast/paul-framework
- **DEVORQ v3 Repo:** https://github.com/nandinhos/devorq_v3
- **Conventional Commits:** https://www.conventionalcommits.org/
- **BDD (Given-When-Then):** https://cucumber.io/docs/gherkin/

---

## 14. Apendice: Exemplo de UNIFY.md Completo

```markdown
# UNIFY — api-rate-limiting
**Data:** 2026-05-09T16:45:00Z
**Sessão:** session_20260509_160000
**Feature:** api-rate-limiting (AC-1, AC-2, AC-3)

---

## Acceptance Criteria — Resultado Real

| AC | Esperado | Real | Status |
|----|----------|------|--------|
| AC-1 | Status 429 após 5 req/min | ✅ 429 após 5 req/min | PASS |
| AC-2 | Response tem retry_after | ✅ retry_after: 300 | PASS |
| AC-3 | Bloqueio por IP | ⚠️ Bloqueio por IP + email | PARTIAL |

---

## Lições Aprendidas

1. **express-rate-limit não bloqueia por IP + email juntos** — precisei de middleware customizado combinando `req.ip` + `req.body.email`
2. **Redis é necessário para rate limit distribuído** — memória em-mem não funciona com múltiplas instâncias

---

## Desvios do Plano Original

- Adicionei persistência Redis (não estava na SPEC) porque rate limit in-memory não funciona em produção com 2+ réplicas
- Tempo real: 3h vs estimado 1h30 → +100% overhead

---

## Pending Items

- [ ] AC-3: Melhorar para bloquear por IP E email (não OR, mas AND)
- [ ] Implementar whitelist de IPs (adicionar ao backlog)
- [ ] Testar com múltiplas instâncias (precisa Redis em staging)

---

## Estado Final

```json
{
  "unify_done": true,
  "unify_file": ".devorq/state/unify/2026-05-09_164500_api-rate-limiting_unify.md",
  "ac_passed": 2,
  "ac_partial": 1,
  "ac_failed": 0,
  "ac_deferred": 0,
  "lessons_auto_captured": 2,
  "time_spent": "3h (estimado: 1h30)",
  "deviations": [
    "Adicionei Redis para persistência (não estava no stack original)",
    "Middleware customizado para IP + email combined block"
  ]
}
```
