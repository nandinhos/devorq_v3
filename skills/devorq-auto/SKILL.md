---
name: devorq-auto
description: DEVORQ-AUTO v1.0.0 — Modo autonomo story-by-story do DEVORQ v3. Implementacao automatica via delegate_task seguindo o padrao Ralph (loop com contexto limpo por iteracao). Gera prd.json do SPEC.md, executa uma story por vez, verifica, commita. NAO depende do Ralph instalado — usa delegate_task nativo.
version: 1.0.0
author: Fernando Dos Santos (Nando)
license: MIT
metadata:
  hermes:
    tags: [devorq, autonomous, auto-mode, ralph-pattern, story-driven]
    related_skills: [devorq, systematic-debugging, verification-before-completion]
    stack: [bash, jq, python3, delegate_task]
---

# DEVORQ-AUTO v1.0.0

## Visao Geral

Modo autonomo do DEVORQ v3. Segue o **padrao Ralph**: tarefa grande -> stories pequenas -> loop com contexto limpo -> uma story por iteracao -> delegate -> verify -> commit.

Cada iteracao spawne um sub-agente com **contexto limpo** (so a story atual), evitando context window overflow em features complexas.

## Quando Usar

- Feature grande demais para uma unica iteracao
- Multiplas tasks independentes que podem ser paralelizadas
- Quando o usuario pedir explicitamente "modo auto" ou "executar automaticamente"
- Corrida de code review com multiplos items a corrigir

**Trigger:** `devorq auto`, `modo auto`, `executar automaticamente`, `ralph mode`

## Arquitetura

```
+------------------------------------------------------------+
|                      DEVORQ v3                             |
|                                                              |
|    +------------+       +----------------------------+     |
|    | prd.json   |------>|    loop-auto.sh             |     |
|    | (stories)   |       |  1. Seleciona story        |     |
|    +------------+       |  2. delegate_task()          |     |
|                         |  3. check-story.sh           |     |
|    +------------+       |  4. git commit                |     |
|    |progress.txt|<------|  5. atualiza passes=true    |     |
|    |(append-only) |      |  6. repeat                  |     |
|    +------------+       +----------------------------+     |
|                                                              |
|    Skills: systematic-debugging (se falha)                   |
|             verification-before-completion (gate)            |
+------------------------------------------------------------+
```

## Fluxo Completo

```
USER: "modo auto"
       |
[1] DETECT project root (SPEC.md ou .git)
[2] CHECK prd.json existente?
    +-- NAO -> prd-from-spec.sh gera stories do SPEC.md
    +-- SIM -> mostra pendentes, pergunta se usa ou regera
[3] CONFIRMACAO:
    "⚡ Modo AUTO: story por story via delegate_task
     Quantas iterations? (1 / 3 / 5 / todas)"
[4] LOOP (n vezes):
    a. Seleciona story priority mais alta com passes=false
    b. delegate_task(goal=story, context=acceptanceCriteria+repo)
    c. check-story.sh (Pint + tests)
    d. PASSOU -> git commit + jq passes=true + append progress.txt
    e. FALHOU -> para e pergunta se quer continuar
[5] SUMMARY -> repo pronto pra PR
```

## Step-by-Step

### STEP 1: Detectar Projeto

Procura `SPEC.md` ou `.git` no diretorio atual. Se nao encontrar, aborta.

```bash
if [ -f "SPEC.md" ]; then
  PROJECT_ROOT=$(pwd)
elif git rev-parse --git-dir > /dev/null 2>&1; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
else
  echo "ERROR: SPEC.md ou .git nao encontrado"
  exit 1
fi
```

### STEP 2: Gerar ou Usar prd.json

**Se prd.json nao existe:**
```bash
devorq-auto/scripts/prd-from-spec.sh "$PROJECT_ROOT"
```
-> Leia `SPEC.md`, quebra em stories atomicas, salva `prd.json`

**Se prd.json existe:**
-> Mostra quantas stories pendentes, pergunta se quer usar ou regerar

### STEP 3: Confirmacao com Usuario

```
📋 prd.json — 8 stories, 3 pendentes
  [1] "Adicionar validacao de CPF no model User"     [🔴 pending]
  [2] "Criar migration para coluna cpf"              [🔴 pending]
  [3] "Adicionar endpoint GET /users/{id}/cpf"       [🔴 pending]

⚡ Modo AUTO: delegate_task por story -> verify -> commit
Quantas iterations? (1 / 3 / 5 / todas)
```

### STEP 4: Loop de Execucao

Para cada iteracao:

```bash
# 4a. Seleciona proxima story
STORY=$(jq -r '.stories | sort_by(.priority) | .[] | select(.passes==false) | @json' prd.json | head -1)

# 4b. Delegate
delegate_task(
  goal=STORY.description,
  context="acceptanceCriteria: STORY.acceptanceCriteria
repo: $PROJECT_ROOT
commit msg: feat(STORY.id): STORY.title"
)

# 4c. Verificar (gate)
devorq-auto/scripts/check-story.sh "$PROJECT_ROOT"
if [ $? -ne 0 ]; then
  echo "❌ Verification failed — abortar?"
  exit 3
fi

# 4d. Commit
git -C "$PROJECT_ROOT" add -A
git -C "$PROJECT_ROOT" commit -m "feat(${STORY_ID}): ${STORY_TITLE}"

# 4e. Atualizar prd.json
jq "(.stories[] | select(.id==\"$STORY_ID\")) |= .passes=true" prd.json > prd.json.tmp
mv prd.json.tmp prd.json

# 4f. Append progress
echo "[$(date +%H:%M)] ✅ ${STORY_TITLE} — PASSED" >> progress.txt
```

### STEP 5: Completion

```
═══════════════════════════════════════
✅ AUTO MODE COMPLETE
═══════════════════════════════════════
3 stories implemented
3 verified
0 failures

📝 Commits:
  feat(model): adicionar validacao CPF em User
  feat(migration): adicionar coluna cpf users
  feat(api): GET /users/{id}/cpf endpoint

📊 progress: $PROJECT_ROOT/progress.txt
📋 status:  $PROJECT_ROOT/prd.json
⚠️  Lembre de: E2E antes do PR
═══════════════════════════════════════
```

## Formato prd.json

```json
{
  "project": "nome-do-projeto",
  "created": "2026-04-23T02:30:00Z",
  "stories": [
    {
      "id": "feat-001",
      "title": "Adicionar validacao de CPF",
      "description": "Adicionar rule de validacao de CPF no model User usando Laravel Validator",
      "acceptanceCriteria": [
        "CPF valido passa",
        "CPF invalido retorna erro 422",
        "Testes cobrem caso valido e invalido"
      ],
      "priority": 1,
      "passes": false
    }
  ]
}
```

## Formato progress.txt

```
# devorq-auto progress — nome-do-projeto
# Formato: [HH:MM] ✅|❌ Story Title — PASSED|FAILED

[14:23] ✅ feat-001: Adicionar validacao de CPF — PASSED
[14:31] ✅ feat-002: Criar migration para coluna cpf — PASSED
[14:40] ✅ feat-003: Adicionar endpoint GET /users/{id}/cpf — PASSED
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Todas iterations completadas com sucesso |
| 1 | Erro de deteccao (sem SPEC.md, sem .git) |
| 2 | Abortado pelo usuario |
| 3 | Verification failed — usuario escolheu abortar |
| 4 | Delegate failed — erro no sub-agente |
| 5 | prd.json nao encontrado e geracao falhou |

## Arquivos de Saida

| Arquivo | Descricao |
|---------|-----------|
| `prd.json` | Stories com status (passes: true/false) |
| `progress.txt` | Log append-only de cada iteracao |
| `.devorq-auto/` | Diretorio de trabalho (branch, estado) |

## Regras de Ouro

1. **Stories pequenas** — se uma story demora mais de 10 min, esta grande demais. Quebre-a antes.
2. **Verify sempre** — nunca commita sem check-story.sh passar.
3. **Contexto limpo** — sub-agente recebe SOMENTE: id, title, acceptanceCriteria, repo path. Nada de outras stories.
4. **Progress append-only** — nunca sobrescreva. Only append.
5. **Abort facil** — usuario pode Ctrl+C. O que foi verificado e commitado fica.

## Sinergia com DEVORQ v3

- **systematic-debugging**: se check-story.sh detecta falha, carregar skill automaticamente
- **verification-before-completion**: graftada dentro de check-story.sh como gate final
- **devorq (v3)**: devorq-auto e modo acelerado do DEVORQ — nao substitui. GATE-1 a GATE-7 continuam valendo para o fluxo geral.

## Limitacoes

- Nao substitui o DEVORQ manual — e acelerador para fases de implementacao pura
- Nao faz decisoes arquiteturais — story ambigua = PARA e pergunta
- Nao gera codigo de alta complexidade sozinho — stories complexas podem precisar de intervencao
- Funciona melhor com PHP/Laravel (base DEVORQ) mas e agnostico de stack

## Dependencias

```bash
jq         # Ler/escrever prd.json
git        # branches, commits
python3    # prd-from-spec.sh (opcional, pode ser bash puro)
delegate_task  # Sub-agentes (nativo Hermes)
```

---

**Versao:** 1.0.0
**Criado em:** 2026-04-23
**Padrao:** DEVORQ v3 (Ralph-inspired, contexto limpo por iteracao)
