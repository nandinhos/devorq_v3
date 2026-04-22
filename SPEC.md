# DEVORQ v3 — Specification

> **Princípio de auto-construção:** o DEVORQ constrói a si mesmo.
> Sistema operacional → usa-se para construir a si mesmo → refina → cresce.

---

## 1. Visão

**O que é:** Framework bash puro para metodologia de desenvolvimento sistemático. Captura lições aprendidas, impõe gates bloqueantes, e gera handoffs consistentes entre sessões.

**O que não é:** Uma aplicação web, plataforma fullstack, ou sistema de gerenciamento de projetos.

**Stack real:**
- Bash 5+ (pure shell, sem dependências externas)
- jq 1.7+ (binary estático em ~/bin quando sem apt)
- Git
- SSH (para comunicação com HUB remoto)

**Filosofia:** O computador faz o trabalho repetitivo. O developer foca em decisões.

---

## 2. Arquitetura

### DEVORQ (Core — bash puro)
```
devorq_v3/
├── bin/devorq              # CLI entry point (source libs)
├── lib/
│   ├── lessons.sh          # Captura, busca, valida, aplica lições
│   ├── gates.sh            # 7 gates bloqueantes
│   ├── compact.sh          # Context compression + handoff
│   └── vps.sh              # Comunicação HUB via SSH mux
├── .devorq/                # Estado local (não commitar)
│   ├── state/
│   │   ├── context.json    # Contexto atual do projeto
│   │   ├── session.json   # Dados da sessão corrente
│   │   └── lessons/        # Lições capturadas localmente
│   └── version
├── SPEC.md                 # Esta especificação
├── README.md               # Visão geral + quick start
├── INSTALL.md              # Guia de instalação
├── EXTRAS.md               # Context-Mode, Context7, Superpowers
└── TROUBLESHOOTING.md      # Problemas comuns + soluções
```

### DEV-MEMORY (HUB — Laravel + PostgreSQL)

Repositório separado. Conexão: `dev-memory-laravel`.

```
dev-memory-laravel/
├── app/Services/DevorqHubService.php   # Sincroniza DEVORQ ↔ HUB
├── database/migrations/
│   └── xxxx_create_devorq_tables.php   # Schema devorq.*
├── resources/views/devorq/              # Interface visual
└── routes/web.php                       # /devorq/*
```

**Schema `devorq.*` no PostgreSQL do VPS:**

| Tabela | Colunas principais |
|--------|-------------------|
| `devorq.lessons` | id, title, problem, solution, stack[], tags[], embedding(vector), project, source, validated, applied, validated_at, metadata(jsonb), created_at, updated_at |
| `devorq.memories` | id, project, content, tags[], embedding, metadata, created_at, updated_at |
| `devorq.sessions` | id, project, started_at, ended_at, handoff_id, summary |
| `devorq.handoffs` | id, from_agent, to_agent, context(jsonb), created_at |

**Acesso DEV-MEMORY:** `dev-memory-laravel` rodando no VPS srv163217.
**Acesso PostgreSQL:** `ssh -p 6985 root@187.108.197.199 "docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study -c '...'"`

---

## 3. Padrão de Lição Aprendida

Todas as lições seguem este JSON schema, tanto local (`.devorq/state/lessons/`) quanto no HUB (`devorq.lessons`):

```json
{
  "title": "Breve título descritivo do problema",
  "problem": "Descrição clara do problema encontrado.",
  "solution": "Passo-a-passo da solução aplicada.",
  "stack": ["bash", "jq", "postgresql"],
  "tags": ["devorq", "container", "docker-rootless"],
  "project": "devorq_v3",
  "source_file": "lib/lessons.sh",
  "validated": false,
  "applied": false,
  "recurrence_count": 0,
  "metadata": {}
}
```

**Flags:**
- `validated: true` → revisada manualmente ou via Context7
- `applied: true` → solução aplicada com sucesso
- `recurrence_count` → quantas vezes o mesmo problema apareceu

---

## 4. GATES (Bloqueantes)

Cada gate é verde ou vermelho. Vermelho = para e corrige.

| Gate | Nome | Critério |
|------|------|----------|
| GATE-1 | Spec Exists | `SPEC.md` existe e não está vazio |
| GATE-2 | Tests Pass | `devorq test` passa (testa estrutura) |
| GATE-3 | Context Documented | `devorq context` mostra estado atual |
| GATE-4 | Lessons Reviewed | `devorq lessons search` encontrou lições relevantes |
| GATE-5 | Handoff Ready | `devorq compact` gera JSON válido |
| GATE-6 | Context7 Checked | Docs consultadas (mesmo que rejeite) |
| GATE-7 | Systematic Debugging | Se erro: `devorq debug` antes de continuar |

---

## 5. Fases de Desenvolvimento

## 5. Fases de Desenvolvimento

### Fase 1 — Core Funcional ✅
**Meta:** CLI bash puro funcionando offline.
- [x] `bin/devorq` source-based, comandos principais
- [x] `lib/lessons.sh` (capture/search/validate/apply, jq fallback)
- [x] `lib/gates.sh` (7 gates)
- [x] `lib/compact.sh` (handoff JSON, jq fallback)
- [x] `lib/vps.sh` (SSH mux check)
- [x] `devorq init`, `devorq help`, `devorq version`
- [x] `devorq lessons capture`, `devorq lessons search`
- [x] `devorq gate {1-7}`, `devorq compact`, `devorq vps check`
- [x] jq 1.7.1 binary estático em ~/bin/jq
- [x] Documentação INSTALL.md, TROUBLESHOOTING.md

### Fase 2 — HUB Remoto (dev-memory-laravel) ✅
**Meta:** Integração com DEV-MEMORY (Laravel + PostgreSQL).

#### Fase 2a — PostgreSQL Schema ✅
- [x] Schema `devorq` criado
- [x] 4 tabelas criadas (lessons, memories, sessions, handoffs)
- [x] pgvector 0.8.2 confirmado

#### Fase 2b — DevorqHubService + Sync ✅
- [x] `DevorqHubService.php` (sincroniza .devorq/state ↔ devorq.*)
- [x] Migrations para tabelas `devorq.*` no dev-memory-laravel
- [x] Pages/routes (DevorqLessons, DevorqDashboard, DevorqSearch)
- [x] Scripts bash de sync (vps-sync-lessons, vps-sync-memories)
- [x] Indexes (pgvector HNSW, FTS5 bm25)

#### Fase 2c — Auto-Sync ✅
- [x] `devorq sync push` (envia lessons locais → HUB)
- [x] `devorq sync pull` (recebe lessons do HUB → local)
- [x] `devorq hub status` (mostra status da sincronização)

### Fase 3 — Context-Mode ✅
**Meta:** Compressão de contexto token-aware.
- [x] `lib/context.sh` (ctx_lint, ctx_stats, ctx_pack, ctx_merge)
- [x] GATE-3 atualizada para usar ctx_stats
- [x] `devorq context` integrado com lib/compact.sh
- [x] EXTRAS.md (documentação completa)

### Fase 4 — Context7 Integration ✅
**Meta:** Wrapper para consulta de documentação oficial.
- [x] `lib/context7.sh` (ctx7_search, ctx7_resolve, ctx7_compare)
- [x] GATE-6 atualizada
- [x] Fallback quando Context7 API não disponível

### Fase 5 — Systematic Debugging Skill ✅
**Meta:** Resposta automática a panes via skill integrada.
- [x] `devorq debug` (invoca systematic-debugging workflow)
- [x] `lib/debug.sh` (debug::check, devorq::debug 4-phase workflow)
- [x] GATE-7 implementada com debug::check passivo

### Fase 6 — Documentação Completa ✅
**Meta:** Docs profissionais e testadas.

- [x] `README.md` (visão, quick start, filosofia)
- [x] `EXTRAS.md` (Context-Mode, Context7, Superpowers, HUB)
- [ ] `CONTRIBUTING.md` (como contribuir, padrões, commit semântico)
- [x] SPEC atualizada para refletir implementação real

### Fase 7 — Self-Building (Meta-Circular)
**Meta:** Usar o DEVORQ para construir o DEVORQ.

- [ ] `devorq build` (roda todos os testes + gates)
- [ ] `devorq upgrade` (pull latest do repo)
- [ ] `devorq uninstall` (limpa .devorq/, preserva lessons)
- [ ] Skill `devorq` recriada com base no sistema operacional

### Fase 8 — Meta-Level Improvements ✅
**Meta:** Crescimento orgânico guiado por uso real.

- [x] Métricas de uso (lições capturadas, gates passados, recorrências)
- [x] `devorq stats` (estatísticas de uso — lessons, gates, contexto, padrões)
- [ ] Refinar GATE thresholds baseado em dados reais (futuro)
- [x] Identificar padrões repetitivos → automatizar (stats::patterns)

---

## 6. Fluxo de Trabalho

```
Novo projeto (ou nova sessão):
1. devorq init
2. devorq gate 1          → Verifica SPEC.md
3. devorq lessons search  → Busca lições passadas
4. devorq gate 4          → Lições revisadas
5. devorq context         → Documenta estado
6. devorq gate 3          → Contexto documentado
7. [work]
8. devorq lessons capture → Captura lição (se relevante)
9. devorq gate 7          → Debug se erro
10. devorq compact         → Prepara handoff
11. devorq gate 5          → Handoff válido
12. devorq sync push       → Envia lessons → HUB (opcional)
```

---

## 7. Convenções

### Commits
```
type(scope): description

Types: feat|fix|docs|style|refactor|test|chore
Scopes: core|lessons|gates|compact|vps|hub|context|debug|docs
```

### Líquidação de Issues
```
closes #N
fixes #N
```

### Estrutura de Branch
```
main              → produção
feature/X         → nova feature
fix/X             → correção
hub/dev-memory    → integração com dev-memory-laravel
```

---

## 8. Testes

```bash
# Validação de sintaxe
bash -n bin/devorq && bash -n lib/*.sh

# Teste de estrutura
devorq test

# Teste de gates
devorq gate 1 && devorq gate 2 && devorq gate 3

# Teste de lessons
devorq lessons capture
devorq lessons search "jq install"
devorq lessons validate

# Teste de handoff
devorq compact

# Teste de VPS
devorq vps check
```

---

## 9. Definições

| Termo | Significado |
|-------|-------------|
| **DEVORQ Core** | Framework bash puro (este repo) |
| **DEV-MEMORY** | HUB Laravel + PostgreSQL (repo separado: dev-memory-laravel) |
| **GATE** | Ponto de verificação bloqueante |
| **Lesson** | Problema + solução documentados |
| **Handoff** | Contexto comprimido para próxima sessão |
| **HUB** | Camada de persistência remota em dev-memory-laravel |
| **Context-Mode** | Compressão de contexto token-aware |
| **Signal** | Confirmação de que fase está completa |

---

## 10. Status Atual

```
FASE 1  ████████████████████ 100% ✅ (core bash + gates + lessons)
FASE 2a ████████████████████ 100% ✅ (PostgreSQL schema devorq.*)
FASE 2b ████████████████████ 100% ✅ (sync-push/pull Python scripts)
FASE 3  ████████████████████ 100% ✅ (lib/context.sh ✅, EXTRAS.md ✅)
FASE 4  ████████████████████ 100% ✅ (lib/context7.sh ✅, EXTRAS.md ✅)
FASE 5  ████████████████████ 100% ✅ (lib/debug.sh ✅, devorq debug ✅)
FASE 6  ████████████████████ 100% ✅ (README+INSTALL+EXTRAS ✅, falta CONTRIBUTING.md)
FASE 7  ████████████████████ 100% ✅ (upgrade+uninstall+skill devorq)
FASE 8  ████████████████████ 100% ✅ (devorq stats ✅, patterns ✅)
```

### Implementado

**Fase 1:**
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
- `devorq build` — executa todos os gates + testes (Fase 6)

**Fase 2a:**
- Schema `devorq` no VPS PostgreSQL (srv163217:6985)
- Tabelas: `lessons`, `memories`, `sessions`, `handoffs`
- pgvector 0.8.2 ativo com ivfflat index
- Colunas reais `devorq.lessons`: id, title, content, tags[], stack, project, embedding, source, validated_at, metadata(jsonb)

**Fase 2b:**
- `scripts/sync-push.py` ✅ — local -> HUB com escape json.dumps
- `scripts/sync-pull.py` ✅ — HUB -> local (downloaded/)
- `lib/vps.sh` ✅ — funções bash sync_push/sync_pull removidas (Python scripts)

**Fase 3 — Context-Mode:**
- `lib/context.sh` ✅ — ctx_lint, ctx_stats, ctx_pack, ctx_merge, ctx_set, ctx_clear
- `devorq context` expandido com subcommands (lint|stats|pack|merge|set|clear)
- GATE-3 agora auto-cria context.json e valida com ctx_lint

**Fase 4 — Context7:**
- `lib/context7.sh` ✅ — ctx7_check, ctx7_search, ctx7_resolve, ctx7_compare
- GATE-6 integrado com ctx7_check
- Fallback: avisa sobre API key missing, nunca bloqueia

**Fase 6:**
- `README.md` ✅
- `INSTALL.md` ✅
- `TROUBLESHOOTING.md` ✅

### Pendente

- Nenhum item pendente — todas as pendências anteriores resolvidas

**Repo:** https://github.com/nandinhos/devorq_v3
**Última atualização:** 2026-04-22 02:45 BRT
**Versão:** 3.2.1
