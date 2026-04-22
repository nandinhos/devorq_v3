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

### Fase 1 — Core Funcional
**Meta:** CLI bash puro funcionando offline.
- [ ] `bin/devorq` source-based, comandos principais
- [ ] `lib/lessons.sh` (capture/search/validate/apply, jq fallback)
- [ ] `lib/gates.sh` (7 gates)
- [ ] `lib/compact.sh` (handoff JSON, jq fallback)
- [ ] `lib/vps.sh` (SSH mux check)
- [ ] `devorq init`, `devorq help`, `devorq version`
- [ ] `devorq lessons capture`, `devorq lessons search`
- [ ] `devorq gate {1-7}`, `devorq compact`, `devorq vps check`
- [ ] jq 1.7.1 binary estático em ~/bin/jq
- [ ] Documentação INSTALL.md, TROUBLESHOOTING.md

### Fase 2 — HUB Remoto (dev-memory-laravel)
**Meta:** Integração com DEV-MEMORY (Laravel + PostgreSQL).

#### Fase 2a — PostgreSQL Schema ✅
- [x] Schema `devorq` criado
- [x] 4 tabelas criadas (lessons, memories, sessions, handoffs)
- [x] pgvector 0.8.2 confirmado

#### Fase 2b — DevorqHubService + Sync
- [ ] `DevorqHubService.php` (sincroniza .devorq/state ↔ devorq.*)
- [ ] Migrations para tabelas `devorq.*` no dev-memory-laravel
- [ ] Pages/routes (DevorqLessons, DevorqDashboard, DevorqSearch)
- [ ] Scripts bash de sync (vps-sync-lessons, vps-sync-memories)
- [ ] Indexes (pgvector HNSW, FTS5 bm25)

#### Fase 2c — Auto-Sync
- [ ] `devorq sync push` (envia lessons locais → HUB)
- [ ] `devorq sync pull` (recebe lessons do HUB → local)
- [ ] `devorq hub status` (mostra status da sincronização)

### Fase 3 — Context-Mode
**Meta:** Compressão de contexto token-aware.

- [ ] `lib/context.sh` (ctx_lint, ctx_stats, ctx_pack, ctx_merge)
- [ ] GATE-3 atualizada para usar ctx_stats
- [ ] `devorq context` integrado com lib/compact.sh

### Fase 4 — Context7 Integration
**Meta:** Wrapper para consulta de documentação oficial.

- [ ] `lib/context7.sh` (ctx7_search, ctx7_resolve, ctx7_compare)
- [ ] GATE-6 atualizada
- [ ] Fallback quando Context7 API não disponível

### Fase 5 — Systematic Debugging Skill
**Meta:** Resposta automática a panes via skill integrada.

- [ ] `devorq debug` (invoca systematic-debugging workflow)
- [ ] `lib/debug.sh` (diagnose, identify, fix, verify loop)
- [ ] GATE-7 implementada

### Fase 6 — Documentação Completa
**Meta:** Docs profissionais e testadas.

- [ ] `README.md` (visão, quick start, filosofia)
- [ ] `EXTRAS.md` (Context-Mode, Context7, Superpowers, HUB)
- [ ] `CONTRIBUTING.md` (como contribuir, padrões, commit semântico)
- [ ] SPEC atualizada para refletir implementação real

### Fase 7 — Self-Building (Meta-Circular)
**Meta:** Usar o DEVORQ para construir o DEVORQ.

- [ ] `devorq build` (roda todos os testes + gates)
- [ ] `devorq upgrade` (pull latest do repo)
- [ ] `devorq uninstall` (limpa .devorq/, preserva lessons)
- [ ] Skill `devorq` recriada com base no sistema operacional

### Fase 8 — Meta-Level Improvements
**Meta:** Crescimento orgânico guiado por uso real.

- [ ] Métricas de uso (lições capturadas, gates passados, recorrências)
- [ ] `devorq stats` (estatísticas de uso)
- [ ] Refinar GATE thresholds baseado em dados reais
- [ ] Identificar padrões repetitivos → automatizar

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
FASE 2b ████░░░░░░░░░░░░░░░░  20% 🔧 (sync-push/pull ✅, falta DevorqHubService)
FASE 3  ░░░░░░░░░░░░░░░░░░░░  0%
FASE 4  ░░░░░░░░░░░░░░░░░░░░  0%
FASE 5  ░░░░░░░░░░░░░░░░░░░░  0%
FASE 6  ████████░░░░░░░░░░░░  40% 🔧 (README+INSTALL+TROUBLESHOOTING ✅)
FASE 7  ░░░░░░░░░░░░░░░░░░░░  0%
FASE 8  ░░░░░░░░░░░░░░░░░░░░  0%
```

### Implementado

**Fase 1:**
- `bin/devorq` (CLI source-based, 12 comandos)
- `lib/lessons.sh` (capture/search/validate/apply, jq fallback)
- `lib/gates.sh` (7 gates bloqueantes)
- `lib/compact.sh` (handoff JSON)
- `lib/vps.sh` (SSH mux check)

**Fase 2a:**
- Schema `devorq` no VPS PostgreSQL (srv163217:6985)
- Tabelas: `lessons`, `memories`, `sessions`, `handoffs`
- pgvector 0.8.2 ativo com ivfflat index
- Colunas reais `devorq.lessons`: id, title, content, tags[], stack, project, embedding, source, validated_at, metadata(jsonb)

**Fase 2b:**
- `scripts/sync-push.py` ✅ — local -> HUB com escape json.dumps
- `scripts/sync-pull.py` ✅ — HUB -> local (downloaded/)

**Fase 6:**
- `README.md` ✅
- `INSTALL.md` ✅
- `TROUBLESHOOTING.md` ✅

### Pendente

- `lib/vps.sh` ✅ — funções bash sync_push/sync_pull removidas (Python scripts)
**Repo:** https://github.com/nandinhos/devorq_v3
**Última atualização:** 2026-04-22 02:45 BRT
**Versão:** 3.2.1
