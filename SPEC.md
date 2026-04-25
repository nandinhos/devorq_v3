# DEVORQ v3 — Specification

> **Princípio de auto-construção:** o DEVORQ constrói a si mesmo.
> Sistema operacional → usa-se para construir a si mesmo → refina → cresce.

**Versão:** 3.4.0 | **Atualizado:** 2026-04-25

---

## 1. Visão

**O que é:** Framework bash puro para metodologia de desenvolvimento sistemático.
- Captura lições aprendidas (nunca mais o mesmo erro)
- Impõe gates bloqueantes (disciplina硬耦合)
- Gera handoffs consistentes entre sessões e agentes

**O que não é:** Uma aplicação web, plataforma fullstack, ou sistema de gerenciamento de projetos.

**Stack:**
- Bash 5+ (puro shell, sem dependências externas)
- jq 1.7+ (binary estático em ~/bin quando sem apt)
- Git
- SSH (para comunicação com HUB remoto via SSH mux)

**Filosofia:** O computador faz o trabalho repetitivo. O developer foca em decisões.

---

## 2. Arquitetura

### Estrutura de Diretórios

```
devorq_v3/
├── bin/devorq                  # CLI entry point (source libs)
├── lib/
│   ├── lessons.sh              # lessons::capture|search|validate|apply|sync_vps|export
│   ├── gates.sh                # 7 gates bloqueantes
│   ├── compact.sh              # handoff JSON
│   ├── context.sh              # ctx_lint|stats|pack|merge|set|clear
│   ├── context7.sh             # ctx7_check|search|resolve|compare
│   ├── debug.sh                # debug::check + devorq::debug (4 fases)
│   ├── stats.sh                # stats::run — métricas de uso
│   └── vps.sh                  # vps::check|exec|pg_exec (SSH mux)
├── scripts/
│   ├── sync-push.py            # local → HUB PostgreSQL
│   └── sync-pull.py            # HUB PostgreSQL → local
├── .devorq/                    # Estado local (NÃO COMMITEAR)
│   ├── state/
│   │   ├── context.json        # Contexto atual do projeto
│   │   ├── session.json        # Dados da sessão corrente
│   │   └── lessons/            # Lições capturadas localmente
│   └── version
├── SPEC.md                     # Esta especificação
├── README.md                   # Visão geral + quick start
├── INSTALL.md                  # Guia de instalação
├── EXTRAS.md                   # Context-Mode, Context7, HUB, Self-Building
└── TROUBLESHOOTING.md          # Problemas comuns + soluções
```

### DEV-MEMORY HUB (repo separado: dev-memory-laravel)

```
VPS srv163217:6985
├── PostgreSQL
│   ├── devorq.lessons    (id, title, problem, solution, stack[], tags[], embedding, project, source, validated, applied, validated_at, metadata, created_at, updated_at)
│   ├── devorq.memories   (id, project, content, tags[], embedding, metadata, created_at, updated_at)
│   ├── devorq.sessions   (id, project, started_at, ended_at, handoff_id, summary)
│   └── devorq.handoffs   (id, from_agent, to_agent, context, created_at)
└── dev-memory-laravel    (interface web — repo separado)
```

**Acesso PostgreSQL:**
```bash
ssh -p 6985 root@187.108.197.199 "docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study -c 'SELECT * FROM devorq.lessons LIMIT 5;'"
```

---

## 3. Os 7 Gates (Bloqueantes)

Cada gate é verde ou vermelho. **Vermelho = para e corrige.**

```
┌────────┬────────────────────────┬──────────────────────────────────────────┐
│ GATE   │ NOME                    │ CRITÉRIO                                 │
├────────┼────────────────────────┼──────────────────────────────────────────┤
│ GATE-1 │ Spec Exists             │ SPEC.md existe e não está vazio           │
│ GATE-2 │ Tests Pass              │ devorq test passa (estrutura OK)         │
│ GATE-3 │ Context Documented      │ devorq context mostra estado válido        │
│ GATE-4 │ Lessons Reviewed        │ devorq lessons search encontrou lições    │
│ GATE-5 │ Handoff Ready           │ devorq compact gera JSON válido           │
│ GATE-6 │ Context7 Checked         │ docs consultadas (sempre passa — WARN OK)│
│ GATE-7 │ Systematic Debug         │ se erro: devorq debug antes de continuar  │
└────────┴────────────────────────┴──────────────────────────────────────────┘
```

**GATE-6 é especial:** Nunca bloqueia. É um aviso para consultar documentação. Mesmo que a API Context7 falhe ou esteja offline, GATE-6 passa.

**GATE-7 é reativo:** Só entra em ação quando há erro. Se não há erro, GATE-7 é ignorado.

---

## 4. Líções Aprendidas

### Schema JSON

```json
{
  "id": "lesson_20260422_143000_12345",
  "title": "Breve título descritivo do problema",
  "problem": "Descrição clara do problema encontrado",
  "solution": "Passo-a-passo da solução aplicada",
  "stack": ["bash", "jq", "postgresql"],
  "tags": ["devorq", "container", "docker-rootless"],
  "project": "devorq_v3",
  "source_file": "lib/lessons.sh",
  "validated": false,
  "validated_at": null,
  "applied": false,
  "recurrence_count": 0,
  "metadata": {}
}
```

### Flags de Estado

| Flag | Significado |
|------|-------------|
| `validated: false` | Precisa de validação manual ou via Context7 |
| `validated: true` | Revisada — solução confirmada |
| `applied: false` | Solução documentada mas ainda não testada |
| `applied: true` | Solução aplicada com sucesso |
| `recurrence_count: N` | Quantas vezes o mesmo problema apareceu |

---

## 5. Fases de Desenvolvimento

```
FASE 1  ████████████████████  100%  ✅  Core bash + gates + lessons
FASE 2a ████████████████████  100%  ✅  PostgreSQL schema devorq.*
FASE 2b ████████████████████  100%  ✅  Sync push/pull Python scripts
FASE 3  ████████████████████  100%  ✅  Context-Mode (lib/context.sh)
FASE 4  ████████████████████  100%  ✅  Context7 integration (lib/context7.sh)
FASE 5  ████████████████████  100%  ✅  Systematic debug (lib/debug.sh)
FASE 6  ████████████████████  100%  ✅  Documentação (README+INSTALL+EXTRAS)
FASE 7  ████████████████████  100%  ✅  Self-building (build+upgrade+uninstall)
FASE 8  ████████████████████  100%  ✅  Meta-stats (devorq stats)
```

### Fase 1 — Core Funcional ✅
CLI bash puro funcionando offline.

**Implementado:**
- `bin/devorq` (CLI source-based, 13 comandos)
- `lib/lessons.sh` (capture/search/validate/apply, jq fallback)
- `lib/gates.sh` (7 gates bloqueantes)
- `lib/compact.sh` (handoff JSON)
- `lib/vps.sh` (SSH mux check)
- `lib/context.sh` (ctx_lint, ctx_stats, ctx_pack, ctx_merge, ctx_set, ctx_clear)
- `lib/context7.sh` (ctx7_check, ctx7_search, ctx7_resolve, ctx7_compare)
- `lib/debug.sh` (debug::check, devorq::debug, debug::trace, debug::recent_changes)
- `devorq context` expandido com subcommands (lint|stats|pack|merge|set|clear)
- `devorq debug [erro]` — workflow interativo 4-phase
- `devorq build` — executa todos os gates + testes

### Fase 2 — HUB Remoto ✅

#### Fase 2a — PostgreSQL Schema ✅
- Schema `devorq` criado no VPS srv163217:5433
- 4 tabelas: lessons, memories, sessions, handoffs
- pgvector 0.8.2 ativo com ivfflat index

#### Fase 2b — Sync Scripts ✅
- `scripts/sync-push.py` — local → HUB com json.dumps escape
- `scripts/sync-pull.py` — HUB → local (downloaded/)
- `lib/vps.sh` — SSH mux para conexão rápida (~0.3s/comando)

### Fase 3 — Context-Mode ✅
Compressão de contexto token-aware.

**Implementado:**
- `lib/context.sh` (ctx_lint, ctx_stats, ctx_pack, ctx_merge, ctx_set, ctx_clear)
- GATE-3 agora auto-cria context.json e valida com ctx_lint
- Alertas: >60k tokens = sugere compressão, >120k = contexto crítico

### Fase 4 — Context7 Integration ✅
Wrapper para consulta de documentação oficial.

**Implementado:**
- `lib/context7.sh` (ctx7_check, ctx7_search, ctx7_resolve, ctx7_compare)
- GATE-6 integrado com ctx7_check
- Fallback: avisa sobre API key missing, nunca bloqueia

### Fase 5 — Systematic Debugging ✅
Workflow automático para resposta a panes.

**Implementado:**
- `lib/debug.sh` (debug::check, devorq::debug 4-phase workflow)
- GATE-7 implementada com debug::check passivo

### Fase 6 — Documentação ✅
Docs profissionais e testadas.

**Implementado:**
- `README.md` (visão, quick start, filosofia)
- `INSTALL.md` (instalação padrão e rápida)
- `EXTRAS.md` (Context-Mode, Context7, HUB, Self-Building)
- `TROUBLESHOOTING.md` (problemas comuns + soluções)
- `SPEC.md` (esta especificação)

### Fase 7 — Self-Building ✅
O DEVORQ constrói a si mesmo.

**Implementado:**
- `devorq build` — executa devorq test + gates 1-7
- `devorq upgrade` — pull latest do repo
- `devorq uninstall` — remove instalação (preserva lessons)
- `devorq skill devorq` — skill auto-gerada

### Fase 8 — Meta-Level Improvements ✅
Crescimento orgânico guiado por uso real.

**Implementado:**
- `devorq stats` — estatísticas de uso (lessons, gates, contexto)
- `stats::patterns` — identifica padrões repetitivos

---

## 6. Fluxo de Trabalho Completo

```
[NOVO PROJETO / NOVA SESSÃO]
         │
         ▼
   ┌───────────┐
   │ devorq    │  Inicializa .devorq/
   │   init    │
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
   │  GATE-6   │  Context7 consultado?
   └───┬───┬───┘
       │   │
    WARN/PASS →无所谓 (nunca bloqueia)
       │
       ▼
   ┌─────────────────┐
   │   [WORK]        │  ← Implementação
   │                 │
   │ lessons capture │  ← Captura nova lição
   │ lessons search  │  ← Busca lição similar
   └────────┬────────┘
            │
       (se erro)
            ▼
   ┌───────────┐
   │  GATE-7   │  devorq debug
   │  (reativo)│  (4-phase investigation)
   └───────────┘
            │
            ▼
   ┌───────────┐
   │  GATE-5   │  devorq compact
   └───┬───┬───┘
       │   │
    PASS  FAIL → corrige → volta
       │
       ▼
   ┌───────────┐
   │ sync push  │  → HUB (opcional)
   └─────┬─────┘
         │
         ▼
   [FIM DA SESSÃO — handoff gerado]
```

---

## 7. Context-Mode

### Problema
Context window é limitado. Sessões longas saturam o contexto e o próximo agente perde informações críticas.

### Solução
Monitoramento proativo do tamanho do contexto com compressão antes que sature.

### Comandos

```bash
devorq context lint    # Valida context.json — campos obrigatórios
devorq context stats   # Mostra tamanho em chars/tokens
devorq context pack    # Comprime para handoff minimal
devorq context merge   # Merge de dois contextos
devorq context set     # Define campo (project, intent, stack...)
devorq context clear   # Limpa contexto
```

### Campos do context.json

```json
{
  "project": "nome-do-projeto",
  "intent": "o que estamos fazendo agora",
  "stack": ["bash", "jq", "postgresql"],
  "gates_completed": [1, 2, 3],
  "pending_gates": [4, 5, 6],
  "last_session": "2026-04-22T04:00:00Z",
  "pending": "implementar fase 4",
  "errors": [],
  "stuck_gates": []
}
```

### Limites de Tamanho

| Limite | Ação |
|--------|------|
| >60k tokens (240k chars) | `ctx_pack` sugere compressão |
| >120k tokens | GATE-3 alerta contexto crítico |

---

## 8. Context7 Integration

### Problema
Como saber se a documentação oficial recomenda uma abordagem diferente da que planejamos?

### Solução
Consultar a documentação oficial via Context7 antes de implementar. GATE-6 nunca bloqueia — é apenas um aviso.

### Configuração

```bash
# Opção 1: via env
export OPENAI_API_KEY=***

# Opção 2: via config file
echo "OPENAI_API_KEY=***" >> ~/.devorq/config
```

### Comandos

```bash
devorq context7 check            # Verifica se API está respondendo
devorq context7 search "<q>"   # Busca docs por query
devorq context7 resolve "<lib>" # Resolve library ID + busca
devorq context7 compare "<a>" "<b>"  # Compara 2 libs
```

### GATE-6 Integration

`devorq gate 6` executa `ctx7_check` automaticamente:
- API configurada e respondendo → **PASS**
- API key missing → **WARN** (não bloqueia)
- API offline → **WARN** (não bloqueia)

---

## 9. Handoff Multi-LLM

### Problema
Trocar de LLM no meio de uma sessão perde contexto.

### Solução
Gerar contexto compactado para o próximo agente.

### Geração

```bash
devorq compact            # Gera .devorq/state/handoff.json
devorq gate 5            # Valida que handoff está pronto
```

### Estrutura do Handoff

```json
{
  "handoff": {
    "project": "devorq_v3",
    "stack": ["bash", "jq"],
    "intent": "implementar feature X",
    "gates_completed": [1, 2, 3, 4, 6],
    "pending_gates": [5],
    "untracked_files": [],
    "timestamp": "2026-04-22T14:30:00Z"
  }
}
```

### Recepção

```bash
# No novo agente:
devorq context merge handoff.json
```

---

## 10. SSH Mux (Performance)

Conexões com VPS HUB usam SSH multiplexing para speed.

```
Primeira conexão:  ~2-3s (handshake completo)
Conexões siguientes: ~0.3s (via mux socket)
```

```bash
# Config
MUX_SOCK="/tmp/devorq-ssh-mux"     # Socket do mux
ControlPersist=600                 # Mantém conexão por 600s

# Testar
devorq vps check
```

---

## 11. Debugging Sistemático (GATE-7)

Workflow 4-fases quando algo quebra:

```
┌─────────────────────────────────────────────────────────┐
│  PHASE 1: CAPTURE                                        │
│  Coleta evidências: output, logs, estado do sistema      │
│  → debug::check (execução automática em cada gate)      │
├─────────────────────────────────────────────────────────┤
│  PHASE 2: INVESTIGATE                                    │
│  Identifica causa raiz via devorq debug interativo      │
│  → desk::trace, debug::recent_changes                    │
├─────────────────────────────────────────────────────────┤
│  PHASE 3: HYPOTHESIZE                                    │
│  Formula hipótese: "A hipótese explica TODO o bug?"     │
│  → Se 3+ fixes falharem = questionar arquitetura        │
├─────────────────────────────────────────────────────────┤
│  PHASE 4: FIX                                           │
│  Aplica fix mínimo verificado                            │
│  → volta ao gate que falhou                              │
└─────────────────────────────────────────────────────────┘
```

**Regra de Ouro:**
> **NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST**

---

## 12. Definições

| Termo | Significado |
|-------|-------------|
| **DEVORQ Core** | Framework bash puro (este repo) |
| **DEV-MEMORY** | HUB Laravel + PostgreSQL (repo separado) |
| **GATE** | Ponto de verificação bloqueante |
| **Lesson** | Problema + solução documentados |
| **Handoff** | Contexto comprimido para próxima sessão |
| **HUB** | Camada de persistência remota |
| **Context-Mode** | Compressão de contexto token-aware |
| **SSH Mux** | SSH multiplexing para conexões rápidas |
| **Context7** | API de consulta de documentação oficial |

---

## 13. Convenções

### Commits

```
type(scope): description

Types:    feat | fix | docs | style | refactor | test | chore
Scopes:   core | lessons | gates | compact | vps | hub | context | debug | docs
```

### Estrutura de Branch

```
main              → produção
feature/X         → nova feature
fix/X             → correção
hub/dev-memory    → integração com dev-memory-laravel
```

### Líquidação de Issues

```
closes #N
fixes #N
```

---

## 14. Testes

```bash
# Validação de sintaxe shell
bash -n bin/devorq && bash -n lib/*.sh

# Teste de estrutura
devorq test

# Teste de gates
devorq gate 1 && devorq gate 2 && devorq gate 3

# Teste de lessons
devorq lessons capture "test" "problem" "solution"
devorq lessons search "test"
devorq lessons validate

# Teste de handoff
devorq compact

# Teste de VPS
devorq vps check

# Self-build completo
devorq build
```

---

## 15. Commit Convention

Formato obrigatório para todos os commits:

```
escopo(fase): descrição detalhada
```

### Regras

| Regra | Descrição |
|-------|-----------|
| **Idioma** | Português do Brasil |
| **Sem emojis** | Apenas texto |
| **Escopo obrigatório** | Área/arquivo: `auto`, `gates`, `lessons`, `docs`, `lib`, `bin`, `readme`, `spec` |
| **Fase opcional** | Se relacionado a PRD: `(feat-v4-001)`, senão `(core)` |
| **Descrição clara** | Verbo no presente + o que foi feito |

### Exemplos

```
auto(feat-v4-001): adiciona modo hibrido tracker para stories do prd
auto(feat-v4-002): adiciona comando discuss para decisoes de implementacao
gates(core): refatora gate 3 com suporte a context files enhanced
docs(readme): atualiza secao quick start com devorq auto
lessons(core): implementa captura de licoes com validacao context7
bin(core): adiciona comando auto com suporte a --continue
```

### Escopos Válidos

| Escopo | Uso |
|--------|-----|
| `bin` | Changes em bin/devorq |
| `lib` | Changes em qualquer lib/*.sh |
| `auto` | Sistema AUTO mode |
| `gates` | Sistema de gates |
| `lessons` | Sistema de lições |
| `context` | Context files e management |
| `docs` | Documentação |
| `readme` | README.md |
| `spec` | SPEC.md |
| `skills` | Skills do agente |
| `prd` | prd.json e stories |

---

**Repo:** https://github.com/nandinhos/devorq_v3
**Última atualização:** 2026-04-25 03:30 BRT
**Versão:** 3.4.0
**Status:** 100% — Zero pendências
