# DEVORQ v3

> **Framework bash puro** para metodologia de desenvolvimento sistemático.
> Captura lições aprendidas, impõe gates bloqueantes, gera handoffs consistentes.

**Versão:** 3.2.1 | **Repo:** [github.com/nandinhos/devorq_v3](https://github.com/nandinhos/devorq_v3) | **Autor:** Fernando Dos Santos (Nando)

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

## Stack

```
┌─────────────────────────────────────────────────────────────┐
│                        DEVORQ CORE                          │
│                   100% Bash Puro — Zero Deps                 │
├─────────────────────────────────────────────────────────────┤
│  bash 5+         │  jq 1.7+ (static binary)                │
│  git             │  SSH (conexão HUB)                      │
└─────────────────────────────────────────────────────────────┘
```

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

## Os 7 Gates (Bloqueantes)

```
┌────────┬────────────────────────┬───────────────────────────────────┐
│ GATE   │ NOME                    │ CRITÉRIO                          │
├────────┼────────────────────────┼───────────────────────────────────┤
│  G-1   │ Spec Exists             │  SPEC.md existe e não vazio       │
│  G-2   │ Tests Pass              │  devorq test passa                │
│  G-3   │ Context Documented      │  devorq context mostra estado     │
│  G-4   │ Lessons Reviewed        │  lições relevantes encontradas    │
│  G-5   │ Handoff Ready            │  devorq compact gera JSON válido  │
│  G-6   │ Context7 Checked         │  docs consultadas (nunca bloqueia)│
│  G-7   │ Systematic Debug         │  se erro: devorq debug primeiro   │
└────────┴────────────────────────┴───────────────────────────────────┘
```

**Regra:** Vermelho = para e corrige. Verde = segue em frente.

---

## Fluxo de Trabalho

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
    PASS  FAIL → cria SPEC.md → volta
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
   │  GATE-3   │  contexto documentado?
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
    PASS  WARN →无所谓 (não bloqueia)
       │
       ▼
   ┌─────────────────┐
   │   [WORK]        │  ← Você implementa
   │                 │
   │  lessons capture│  ← Captura lições
   │  lessons search │  ← Busca lições passadas
   └────────┬────────┘
            │
            ▼ (se erro)
   ┌───────────┐
   │  GATE-7   │  devorq debug
   └───────────┘  (investigação sistemática)
            │
            ▼
   ┌───────────┐
   │  GATE-5   │  devorq compact (handoff)
   └───┬───┬───┘
       │   │
    PASS  FAIL → corrige handoff → volta
       │
       ▼
   ┌───────────┐
   │ sync push │  → HUB (opcional)
   └─────┬─────┘
         │
         ▼
   [FIM DA SESSÃO]
```

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
| `devorq gate [1-7]` | Executar gate específico |
| `devorq flow "<intent>"` | Workflow completo (gates 1-7) |
| `devorq build` | Self-building: testa + gates (auto-verifica) |

### Lições Aprendidas
| Comando | Descrição |
|---------|-----------|
| `devorq lessons capture "<t>" "<p>" "<s>"` | Capturar lição |
| `devorq lessons search "<q>"` | Buscar lições locais |
| `devorq lessons validate` | Validar com Context7 |
| `devorq lessons apply [id]` | Marcar como aplicada |

### Contexto
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
| `devorq version` | Versão atual |
| `devorq upgrade` | Atualizar DEVORQ |
| `devorq uninstall` | Remover instalação |

---

## Arquitetura

```
DEVORQ CORE (bash puro — /projects/devorq_v3)
│
├── bin/devorq                  # CLI entry point (source libs)
│
├── lib/
│   ├── lessons.sh             # lessons::capture|search|validate|apply|sync_vps|export
│   ├── gates.sh                # gates::check + 7 gates bloqueantes
│   ├── compact.sh              # compact::run — handoff JSON
│   ├── context.sh              # ctx_lint|stats|pack|merge|set|clear
│   ├── context7.sh             # ctx7_check|search|resolve|compare
│   ├── debug.sh                # debug::check|trace + devorq::debug (4-phase)
│   ├── stats.sh                # stats::run — métricas de uso
│   └── vps.sh                  # vps::check|exec|pg_exec — SSH mux
│
├── scripts/
│   ├── sync-push.py            # Sincroniza local → HUB PostgreSQL
│   └── sync-pull.py            # Sincroniza HUB PostgreSQL → local
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
├── EXTRAS.md                   # Context-Mode, Context7, HUB, Self-Building
└── TROUBLESHOOTING.md          # Problemas comuns + soluções
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
  "applied": false,
  "recurrence_count": 0,
  "metadata": {}
}
```

---

## Convenções de Commit

```
type(scope): description

Types:    feat | fix | docs | style | refactor | test | chore
Scopes:   core | lessons | gates | compact | vps | hub | context | debug | docs
```

**Exemplo:**
```
fix(lessons): implement SSH mux sync and Context7 validation real
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
