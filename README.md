# DEVORQ v3

> **Framework bash puro** para metodologia de desenvolvimento sistemático.
> Captura lições aprendidas, impõe gates bloqueantes, gera handoffs consistentes.

**Versão:** 3.4.1 | **Repo:** [github.com/nandinhos/devorq_v3](https://github.com/nandinhos/devorq_v3) | **Autor:** Fernando Dos Santos (Nando)

---

## O Problema que o DEVORQ Resolve

```
Sessão longa → contexto saturado → próximo agente perde informações
              → decisões duplicadas → mesmas falhas se repetem
              → وقت ضائع (tempo perdido)
```

**DEVORQ** é uma CLI bash que impõe disciplina:
- **Gates bloqueantes** — nada avança sem verificação
- **Lições aprendidas** — nunca mais o mesmo erro
- **Handoffs consistentes** — próximo agente começa onde você parou

---

## Quick Start

```bash
# 1. Instalar (uma linha)
curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq_v3/main/bin/devorq -o ~/bin/devorq
chmod +x ~/bin/devorq

# 2. Inicializar projeto
cd /projects/meu-projeto
devorq init

# 3. Workflow completo
devorq flow "implementar feature X"

# 4. Capturar lição aprendida
devorq lessons capture "jq install rootless Docker" \
  --problem "jq binary needed but no apt-get" \
  --solution "curl -L jq-linux64 to ~/bin" \
  --stack bash --tags docker,jq

# 5. Sincronizar com HUB (opcional)
devorq sync push
```

---

## Os 8 Gates (Bloqueantes)

```
┌────────┬────────────────────────┬───────────────────────────────────┐
│ GATE   │ NOME                    │ CRITÉRIO                          │
├────────┼────────────────────────┼───────────────────────────────────┤
│  G-0   │ DDD Validation          │ SPEC.md válido (escopo seguro)    │
│  G-1   │ Spec Exists             │ SPEC.md existe e não vazio       │
│  G-2   │ Tests Pass              │ devorq test passa                │
│  G-3   │ Context Documented      │ devorq context mostra estado     │
│  G-4   │ Lessons Reviewed        │ lições relevantes encontradas    │
│  G-5   │ Handoff Ready           │ devorq compact gera JSON válido  │
│  G-6   │ Context7 Checked        │ docs consultadas (nunca bloqueia)│
│  G-7   │ Systematic Debug        │ se erro: devorq debug primeiro   │
└────────┴────────────────────────┴───────────────────────────────────┘
```

**Regra:** Vermelho = para e corrige. Verde = segue em frente.

**G-0 (DDD):** Valida que o escopo é seguro antes de começar. Previne over-engineering. Executado automaticamente via `devorq ddd validate`.

---

## Modos de Implementação

O DEVORQ oferece **3 modos** para executar o workflow:

### Modo AUTO 🤖 (story-by-story)
Implementação autônoma story por story via `delegate_task`. Recomendado para features grandes/médias.

```
 Usuario                    Sistema
     │                          │
     │ "vamos implementar X"    │
     │─────────────────────────►│
     │                          │ [1] mode-selector.sh detecta intent
     │                          │ [2] Branching: AUTO
     │                          │ [3] Loop: story-by-story via delegate_task
     │                          │     ┌─ prd-from-spec.sh → prd.json
     │                          │     ├─ check-story.sh → G-0..G-7
     │                          │     ├─ lessons pipeline (approve/compile)
     │                          │     └─ devorq-auto skill
     │                          │
     │◄─────────────────────────│
     │    [n stories completadas]
```

### Modo CLASSIC 📝 (gates 1-7 manuais)
Fluxo tradicional gates 1-7 manual. Recomendado para tasks pequenas/rápidas.

### AUTO[N] 🚀 (limitado)
Executa até N stories, depois pausa para review.

---

## Skills do Ecossistema DEVORQ

O framework é composto por skills independentes que se integram ao longo do workflow:

```
devorq_v3/
├── skills/
│   ├── devorq/                   # Core — gates 1-7 + comandos CLI
│   ├── devorq-mode/              # Seletor interativo AUTO/CLASSIC/AUTO[N]
│   ├── devorq-auto/              # Loop autônomo story-by-story
│   ├── devorq-code-review/       # Review multi-agente ultra thorough
│   ├── scope-guard/             # GATE-0 — bloqueia over-engineering
│   ├── ddd-deep-domain/          # GATE-0 — exploração de domínio
│   ├── env-context/              # Auto-detecta stack e gotchas
│   └── learned-lesson/          # Auto-gera skill de lições aprendidas
└── lib/                          # Bibliotecas bash compartilhadas
```

| Skill | Descrição |
|-------|-----------|
| **devorq** | Core framework — gates, lessons, context, compact, debug |
| **devorq-mode** | Seletor interativo — detecta intent e pergunta modo |
| **devorq-auto** | Ralph-style — loop autônomo story-by-story via delegate_task |
| **devorq-code-review** | UltraReview — multi-agent review com gates de aprovação |
| **scope-guard** | GATE-0 — valida que escopo não é over-engineered |
| **ddd-deep-domain** | GATE-0 — workshop interativo de exploração de domínio |
| **env-context** | Auto-detecta stack (Laravel/Filament) + gotchas específicas |
| **learned-lesson** | Gera skill de lições aprendidas automaticamente |

---

## Pipeline de Lessons (Loop Contínuo)

O DEVORQ transforma lições aprendidas em skills automaticamente:

```
captured lesson → approved → compiled → skill gerada → disponível no próximo projeto
```

### Comandos do Lessons Pipeline

| Comando | Descrição |
|---------|-----------|
| `devorq lessons capture "<t>" "<p>" "<s>"` | Capturar lição (title/problem/solution) |
| `devorq lessons search "<q>"` | Buscar lições locais |
| `devorq lessons validate [--auto]` | Validar com Context7 (auto=pula prompts) |
| `devorq lessons approve <id>` | Aprovar lição para skill |
| `devorq lessons approve --all [--skill=<name>] [--auto]` | Aprovar todas |
| `devorq lessons compile [<id>]` | Compilar lições approved → skill |
| `devorq lessons compile --dry-run` | Preview sem modificar arquivos |
| `devorq lessons list [filtro]` | Listar (all\|pending\|approved\|validated\|compiled) |
| `devorq lessons migrate` | Migrar lições existentes (campos approved) |
| `devorq lessons auto-commit <skill> [--auto] [--force]` | Compilar + git commit + push |

---

## Comandos

### Inicialização
| Comando | Descrição |
|---------|-----------|
| `devorq init` | Inicializar `.devorq/` no projeto |
| `devorq test` | Testar estrutura do projeto |

### Gates
| Comando | Descrição |
|---------|-----------|
| `devorq gate [0-7]` | Executar gate específico |
| `devorq flow "<intent>"` | Workflow completo (gates 0-7) |
| `devorq build` | Self-building: testa + gates (auto-verifica) |

### GATE-0 DDD
| Comando | Descrição |
|---------|-----------|
| `devorq ddd explore` | Workshop interativo de exploração de domínio |
| `devorq ddd validate` | Validar SPEC.md (GATE-0) |
| `devorq scope validate <file>` | Validar contrato de escopo |
| `devorq scope template` | Mostrar template de contrato |

### Context & Stack
| Comando | Descrição |
|---------|-----------|
| `devorq context` | Mostrar contexto atual |
| `devorq context lint` | Validar context.json |
| `devorq context stats` | Tamanho do contexto |
| `devorq context pack` | Comprimir para handoff |
| `devorq context set <key> <val>` | Definir campo |
| `devorq compact` | Gerar handoff JSON |

### HUB Remoto
| Comando | Descrição |
|---------|-----------|
| `devorq sync push` | Enviar lessons → HUB |
| `devorq sync pull` | Receber lessons ← HUB |
| `devorq vps check` | Testar conexão VPS |

### Utilitários
| Comando | Descrição |
|---------|-----------|
| `devorq debug [erro]` | Workflow debug sistemático |
| `devorq stats` | Estatísticas de uso |
| `devorq version [--sync]` | Versão atual (+ sync com GitHub) |
| `devorq upgrade [--ff-only]` | Atualizar DEVORQ (ff-only=apenas fast-forward) |
| `devorq uninstall` | Remover instalação |

---

## CI/CD

O DEVORQ inclui pipeline de GitHub Actions que executa 36 testes automaticamente:

```yaml
# .github/workflows/ci.yml
on: [push: main, pull_request: main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6          # Node.js 24 native
      - run: bash scripts/ci-test.sh        # 36 testes
      - run: bash bin/devorq test           # Self-test
      - run: bash bin/devorq ddd validate   # GATE-0 validation

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - run: shellcheck bin/devorq lib/*.sh scripts/*.sh skills/*/scripts/*.sh
```

**Status CI:** 36/36 testes passando ✅

---

## Arquitetura

```
DEVORQ CORE (bash puro — /projects/devorq_v3)
│
├── bin/devorq                  # CLI entry point (source libs)
│
├── lib/
│   ├── lessons.sh             # lessons::capture|search|validate|approve|compile|list|migrate
│   ├── gates.sh                # gates::check + 8 gates bloqueantes (G-0 a G-7)
│   ├── compact.sh              # compact::run — handoff JSON
│   ├── context.sh              # ctx_lint|stats|pack|merge|set|clear
│   ├── context7.sh             # ctx7_check|search|resolve|compare
│   ├── debug.sh                # debug::check|trace + devorq::debug (4-phase)
│   ├── stats.sh                # stats::run — métricas de uso
│   └── vps.sh                  # vps::check|exec|pg_exec — SSH mux
│
├── scripts/
│   ├── ci-test.sh              # Suite de 36 testes CI
│   ├── sync-push.py            # Sincroniza local → HUB PostgreSQL
│   └── sync-pull.py            # Sincroniza HUB PostgreSQL → local
│
├── skills/
│   ├── devorq/                 # Core skill (gates + lessons)
│   ├── devorq-mode/            # Interactive mode selector
│   ├── devorq-auto/            # Autonomous story loop
│   ├── devorq-code-review/     # Multi-agent code review
│   ├── scope-guard/            # GATE-0 — valida escopo contra over-engineering
│   ├── ddd-deep-domain/        # GATE-0 — exploração interativa de domínio
│   ├── env-context/            # Auto-detecta stack + gotchas
│   └── learned-lesson/         # Auto-gera skill de lições approved
│
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions (Node.js 24)
│
├── .devorq/                    # Estado local (NÃO COMMITEAR)
│   ├── state/
│   │   ├── context.json        # Contexto do projeto atual
│   │   ├── session.json        # Dados da sessão corrente
│   │   └── lessons/            # Lições capturadas localmente
│   └── version
│
├── SPEC.md                     # Esta especificação
├── README.md                   # Visão geral + quick start
├── INSTALL.md                  # Guia de instalação
├── EXTRAS.md                  # Context-Mode, Context7, HUB, Self-Building
├── TROUBLESHOOTING.md         # Problemas comuns + soluções
└── docs/
    ├── SPEC-LESSONS-SKILLS-LOOP.md      # Pipeline lessons→skills
    └── NODE24-GITHUB-ACTIONS-MIGRATION.md  # Migração Node 24
```

---

## DEV-MEMORY HUB (VPS Remoto)

Repositório separado: **dev-memory-laravel**

```
┌──────────────────────┐      SSH (mux ~0.3s)      ┌──────────────────────┐
│   DEVORQ CORE        │ ◄────────────────────────► │   VPS srv163217       │
│   (máquina local)    │                            │   187.108.197.199:6985│
│                      │                            │                       │
│   .devorq/state/     │                            │   PostgreSQL          │
│   lessons/           │                            │   ┌───────────────┐  │
│                      │                            │   │ devorq.lessons│  │
│                      │                            │   │ devorq.memories│ │ 
│                      │                            │   │ devorq.sessions│ │ 
│                      │                            │   └───────────────┘  │
│                      │                            │                       │
│                      │                            │   dev-memory-laravel │
│                      │                            │   (interface web)    │
└──────────────────────┘                            └──────────────────────┘
```

### Acesso Direto ao HUB

```bash
# SSH
ssh -p 6985 root@187.108.197.199

# PostgreSQL (via docker exec)
docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study

# Tabelas
# devorq.lessons, devorq.memories, devorq.sessions, devorq.handoffs
```

---

## Schema de Lição Aprendida

```json
{
  "id": "lesson_20260422_143000_12345",
  "title": "jq install in rootless Docker",
  "problem": "jq binary needed but no apt-get available",
  "solution": "curl -L jq-linux64 binary to ~/bin and chmod +x",
  "stack": ["bash", "jq", "docker"],
  "tags": ["docker-rootless", "jq", "install"],
  "project": "devorq_v3",
  "source_file": "lib/lessons.sh",
  "validated": true,
  "validated_at": "2026-04-22T14:30:00",
  "approved": true,
  "approved_at": "2026-04-22T15:00:00",
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
| `approved: true` | Aprovada para virar skill |
| `applied: false` | Solução documentada mas ainda não testada |
| `applied: true` | Solução aplicada com sucesso |
| `recurrence_count: N` | Quantas vezes o mesmo problema apareceu |

---

## Convenções de Commit

```
[type]([escopo]): descrição em português

Types:    feat | fix | docs | style | refactor | test | chore
Escopos:  core | lessons | gates | compact | vps | hub | context | debug | skills | ci | ddd | scope
```

**Exemplo:**
```
feat(skills): add scope-guard — GATE-0 contract for blocking over-engineering
```

---

## Status do Projeto

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
FASE 9  ████████████████████  100%  ✅  Skills ecosystem (devorq-auto, devorq-code-review, devorq-mode)
FASE 10 ████████████████████  100%  ✅  CI/CD (GitHub Actions, 36 testes)
FASE 11 ████████████████████  100%  ✅  GATE-0 DDD (scope-guard, ddd-deep-domain)
FASE 12 ████████████████████  100%  ✅  Lessons Pipeline (approve/compile/list/migrate)
```

**Zero pendências.**

---

## Documentação

| Arquivo | Conteúdo |
|---------|----------|
| [SPEC.md](SPEC.md) | Especificação completa |
| [EXTRAS.md](EXTRAS.md) | Context-Mode, Context7, HUB, Self-Building |
| [INSTALL.md](INSTALL.md) | Guia de instalação |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Problemas e soluções |
| [docs/SPEC-LESSONS-SKILLS-LOOP.md](docs/SPEC-LESSONS-SKILLS-LOOP.md) | Pipeline lessons→skills |
| [docs/NODE24-GITHUB-ACTIONS-MIGRATION.md](docs/NODE24-GITHUB-ACTIONS-MIGRATION.md) | Migração Node 24 |
