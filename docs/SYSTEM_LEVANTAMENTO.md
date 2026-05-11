# Levantamento Completo do Sistema DEVORQ v3

> **Data do Levantamento:** 2026-05-11
> **Autor:** Análise de Código - Trae IDE
> **Propósito:** Documentação completa para criação de diagramas de fluxo

---

## Visão Geral do Sistema

O **DEVORQ** é um framework bash puro para metodologia de desenvolvimento sistemático que visa resolver o problema da perda de contexto entre sessões de desenvolvimento e agentes de IA. O sistema implementa gates bloqueantes, captura lições aprendidas, e gera handoffs consistentes entre sessões.

---

## 1. Arquitetura do Sistema

### 1.1 Estrutura de Diretórios

```
devorq_v3/
├── bin/
│   └── devorq                    # CLI entry point (source libs)
├── lib/
│   ├── lessons.sh               # Módulo de lições aprendidas
│   ├── gates.sh                 # Sistema de 8 gates bloqueantes
│   ├── compact.sh               # Geração de handoff JSON
│   ├── context.sh               # Gerenciamento de contexto
│   ├── context7.sh              # Integração com Context7 API
│   ├── debug.sh                 # Debug sistemático em 4 fases
│   ├── stats.sh                 # Métricas de uso
│   ├── vps.sh                   # Conexão SSH/VPS HUB
│   ├── auto.sh                  # Modo AUTO story-by-story
│   ├── spec.sh                  # Validação de SPEC.md
│   └── unify.sh                 # Fase de fechamento/unificação
├── scripts/
│   ├── sync-push.py             # Sincronização local → HUB PostgreSQL
│   ├── sync-pull.py             # Sincronização HUB → local
│   ├── e2e-test.sh             # Testes end-to-end
│   └── ci-test.sh              # Testes CI/CD
├── skills/                      # Skills especializados
│   ├── project-foundation/      # 5W2H, Premissas, Riscos, Requisitos, Restrições
│   ├── env-context/            # Detecção automática de ambiente
│   ├── scope-guard/            # Contrato de escopo
│   ├── ddd-deep-domain/        # Domain-Driven Design
│   ├── devorq-auto/            # Modo autônomo
│   ├── devorq-mode/            # Seletor de modo AUTO/CLASSIC
│   ├── devorq-code-review/     # Code review multi-agente
│   └── learned-lesson/          # Skills geradas de lições
├── .devorq/                    # Estado local do projeto
│   └── state/
│       ├── context.json         # Contexto atual do projeto
│       ├── session.json        # Dados da sessão
│       ├── handoff.json        # Handoff para próxima sessão
│       └── lessons/
│           ├── captured/        # Lições locais
│           └── downloaded/      # Lições do HUB
└── docs/                       # Documentação adicional
```

### 1.2 Tecnologias e Dependências

| Tecnologia | Versão Mínima | Propósito | Obrigatório |
|------------|---------------|-----------|-------------|
| Bash | 5.0+ | Shell principal | ✅ |
| jq | 1.7+ | Processamento JSON | ⚠️ Opcional |
| Git | Qualquer | Controle de versão | ✅ |
| SSH | Qualquer | Conexão com HUB VPS | ⚠️ Opcional |
| Python3 | 3.x | Scripts de sincronização | ⚠️ Opcional |
| PostgreSQL | - | Armazenamento HUB | ⚠️ HUB Remoto |

---

## 2. Fluxo Principal de Execução (Flow)

### 2.1 Fluxo Completo de Gates

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          DEVORQ FLOW COMPLETO                           │
└─────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │  devorq init    │  ← Inicialização do projeto
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   devorq flow   │  ← Início do workflow sistemático
    │   "<intent>"    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────────────────────────────────────────────────────┐
    │                      GATE 0 (OPCIONAL)                          │
    │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
    │  │env-context   │  │scope-guard  │  │ ddd-deep-domain      │  │
    │  │Detecta stack │  │Contrato de   │  │ Exploração DDD se    │  │
    │  │ambiente      │  │escopo        │  │ keywords detectadas  │  │
    │  └──────────────┘  └──────────────┘  └──────────────────────┘  │
    └─────────────────────────────────────────────────────────────────┘
             │
             ▼
    ┌─────────────────────────────────────────────────────────────────┐
    │                      GATE 0.5 (BLOQUEANTE)                     │
    │  ┌──────────────────────────────────────────────────────────┐   │
    │  │              PROJECT FOUNDATION                          │   │
    │  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐ ┌────────┐│   │
    │  │  │ 5W2H   │ │Premis │ │ Riscos │ │Requisitos│ │Restri ││   │
    │  │  │.json   │ │sas    │ │.json   │ │.json    │ │coes   ││   │
    │  │  └────────┘ └────────┘ └────────┘ └──────────┘ └────────┘│   │
    │  └──────────────────────────────────────────────────────────┘   │
    │                    Validação: devorq foundation validate        │
    └─────────────────────────────────────────────────────────────────┘
             │
             ▼
    ┌─────────────────┐
    │   GATE 1        │  ← SPEC.md existe?
    │   BLOQUEANTE    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   GATE 2        │  ← Testes passam?
    │   BLOQUEANTE    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   GATE 3        │  ← Contexto documentado?
    │   BLOQUEANTE    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   GATE 4        │  ← Lições revisadas?
    │   BLOQUEANTE    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   GATE 5        │  ← Handoff pronto?
    │   BLOQUEANTE    │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   GATE 5.5      │  ← UNIFY executado?
    │   AVISO         │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   GATE 6        │  ← Context7 consultado?
    │   AVISO         │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────────────────────────────────────────────────────┐
    │                      [WORK] IMPLEMENTAÇÃO                        │
    │                                                                  │
    │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
    │  │ Implementar  │  │ Capturar     │  │ Buscar lições        │   │
    │  │ feature     │  │ lições       │  │ passadas             │   │
    │  └──────────────┘  └──────────────┘  └──────────────────────┘   │
    │                                                                  │
    │  Se ERRO → GATE 7 (Debug Sistemático)                          │
    └─────────────────────────────────────────────────────────────────┘
             │
             ▼
    ┌─────────────────┐
    │   GATE 7        │  ← Debug sistemático?
    │   SE ERRO       │     (4 fases)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │   devorq sync   │  ← Sincronização com HUB
    │   push/pull     │     (opcional)
    └────────┬────────┘
             │
             ▼
    ┌─────────────────┐
    │  FIM DA SESSÃO  │
    └─────────────────┘
```

### 2.2 Diagrama de Decisão por Gate

```
                    ┌─────────────────┐
                    │    INÍCIO       │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │ GATE PASSOU?     │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │ SIM          │              │ NÃO
              ▼              │              ▼
    ┌─────────────────┐      │   ┌─────────────────┐
    │ Avança para     │      │   │ GATE BLOQUEANTE │
    │ próximo gate    │      │   │ STOP - Corrige  │
    └────────┬────────┘      │   └─────────────────┘
             │               │              │
             ▼               │              ▼
    ┌─────────────────┐      │   ┌─────────────────┐
    │ Fim dos gates?  │      │   │ Corrige         │
    └────────┬────────┘      │   │ problema        │
             │               │   └────────┬────────┘
    ┌────────┴────────┐      │            │
    │ SIM             │NÃO   │            ▼
    ▼                 │      │   ┌─────────────────┐
    ┌─────────┐       │      │   │ Revalida gate  │
    │FIM/WORK│       │      │   └────────┬────────┘
    └─────────┘       │      │            │
                      ▼      │            │
             Retorna ao loop  └────────────┘
```

---

## 3. Módulos Principais

### 3.1 Módulo de Gates (gates.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                    SISTEMA DE GATES                             │
│                                                                 │
│  GATE 0   │ Exploration (OPCIONAL)                              │
│           │ ├── env-context: Detecta stack/ambiente             │
│           │ ├── scope-guard: Contrato de escopo               │
│           │ └── ddd-deep-domain: Exploração DDD se keywords     │
│           │                                                     │
│  GATE 0.5 │ Project Foundation (BLOQUEANTE)                     │
│           │ └── Valida 5W2H, Premissas, Riscos, Requisitos,     │
│           │     Restrições                                       │
│           │                                                     │
│  GATE 1   │ Spec Exists (BLOQUEANTE)                           │
│           │ └── SPEC.md existe e tem conteúdo                   │
│           │                                                     │
│  GATE 2   │ Tests Pass (BLOQUEANTE)                            │
│           │ └── devorq test, shellcheck, PHPUnit/Pest           │
│           │                                                     │
│  GATE 3   │ Context Documented (BLOQUEANTE)                     │
│           │ └── context.json com project/intent/stack           │
│           │                                                     │
│  GATE 4   │ Lessons Reviewed (BLOQUEANTE)                       │
│           │ └── Lições capturadas no projeto                    │
│           │                                                     │
│  GATE 5   │ Handoff Ready (BLOQUEANTE)                         │
│           │ └── compact::generate gera JSON válido              │
│           │                                                     │
│  GATE 5.5 │ UNIFY (AVISO)                                      │
│           │ └── Fase de fechamento/unificação                   │
│           │                                                     │
│  GATE 6   │ Context7 Checked (AVISO)                            │
│           │ └── Documentação consultada (NUNCA BLOQUEIA)        │
│           │                                                     │
│  GATE 7   │ Systematic Debug (SE ERRO)                          │
│           │ └── 4 fases de debug se problema detectado          │
│           │                                                     │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Módulo de Lições Aprendidas (lessons.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                  CICLO DE VIDA DE LIÇÕES                         │
│                                                                 │
│  ┌─────────────┐                                                │
│  │ CAPTURE     │  ← Captura momento que aprende                  │
│  │             │     devorq lessons capture                       │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐                                                │
│  │ VALIDATE    │  ← Valida com Context7                          │
│  │             │     devorq lessons validate                     │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐                                                │
│  │ APPROVE     │  ← Aprova para skill                           │
│  │             │     devorq lessons approve                     │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐                                                │
│  │ COMPILE     │  ← Compila para skill                          │
│  │             │     devorq lessons compile                     │
│  └──────┬──────┘                                                │
│         │                                                       │
│         ▼                                                       │
│  ┌─────────────┐                                                │
│  │ APPLY       │  ← Aplica a novo contexto                      │
│  │             │     lições::apply                              │
│  └─────────────┘                                                │
│                                                                 │
│  ARMAZENAMENTO:                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐    │
│  │ LOCAL          │  │ HUB (VPS)      │  │ SKILLS         │    │
│  │ .devorq/state/ │  │ PostgreSQL     │  │ Geradas de     │    │
│  │ lessons/       │  │ devorq.lessons │  │ lições         │    │
│  └────────────────┘  └────────────────┘  └────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Módulo de Contexto (context.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                    GERENCIAMENTO DE CONTEXTO                      │
│                                                                 │
│  context.json                                                    │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ {                                                           ││
│  │   "project": "nome-do-projeto",                             ││
│  │   "intent": "o que estamos fazendo",                        ││
│  │   "stack": ["bash", "jq", "postgresql"],                   ││
│  │   "gates_completed": [1, 2, 3],                            ││
│  │   "pending_gates": [4, 5, 6],                              ││
│  │   "last_session": "2026-05-11T...",                        ││
│  │   "pending": "implementar fase 4",                          ││
│  │   "errors": [],                                             ││
│  │   "stuck_gates": []                                        ││
│  │ }                                                           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  OPERAÇÕES:                                                     │
│  ┌────────────────┬──────────────────────────────────────────┐│
│  │ ctx_lint       │ Valida sanidade do context.json          ││
│  ├────────────────┼──────────────────────────────────────────┤│
│  │ ctx_stats      │ Mostra tamanho em chars/tokens           ││
│  ├────────────────┼──────────────────────────────────────────┤│
│  │ ctx_pack       │ Comprime para handoff minimal            ││
│  ├────────────────┼──────────────────────────────────────────┤│
│  │ ctx_merge      │ Merge de dois contextos                  ││
│  ├────────────────┼──────────────────────────────────────────┤│
│  │ ctx_set        │ Define campo específico                  ││
│  ├────────────────┼──────────────────────────────────────────┤│
│  │ ctx_clear      │ Limpa contexto                           ││
│  └────────────────┴──────────────────────────────────────────┘│
│                                                                 │
│  LIMITES:                                                       │
│  > 60k tokens  →  Alerta amarelo (sugere compressão)           │
│  > 120k tokens →  Crítico (GATE-3 alerta vermelho)            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Módulo de Compactação/Handoff (compact.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                     COMPACTAÇÃO DE CONTEXTO                      │
│                                                                 │
│  compact::generate()                                            │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                          INPUT                              ││
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      ││
│  │  │context.json │  │git status    │  │gates_completed│     ││
│  │  └──────────────┘  └──────────────┘  └──────────────┘      ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    PROCESSAMENTO                             ││
│  │  • Extrai project, stack, intent                            ││
│  │  • Calcula pending_gates                                    ││
│  │  • Lista arquivos untracked                                 ││
│  │  • Timestamp UTC                                            ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                          OUTPUT                             ││
│  │  handoff.json                                             ││
│  │  ┌─────────────────────────────────────────────────────┐   ││
│  │  │ {                                                     │   ││
│  │  │   "handoff": {                                       │   ││
│  │  │     "project": "devorq_v3",                          │   ││
│  │  │     "stack": "bash,jq,postgresql",                  │   ││
│  │  │     "intent": "implementar feature X",               │   ││
│  │  │     "gates_completed": [1,2,3],                     │   ││
│  │  │     "pending_gates": ["GATE-4","GATE-5"],           │   ││
│  │  │     "untracked_files": ["src/new/"],                │   ││
│  │  │     "timestamp": "2026-05-11T..."                   │   ││
│  │  │   }                                                   │   ││
│  │  │ }                                                     │   ││
│  │  └─────────────────────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  FUNÇÕES RELACIONADAS:                                          │
│  • compact::load  - Carrega handoff anterior                    │
│  • compact::diff  - Compara dois handoffs                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.5 Módulo de Debug Sistemático (debug.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                 DEBUG SISTEMÁTICO (4 FASES)                      │
│                                                                 │
│  PRINCÍPIO: "SEM CAUSA RAIZ = SEM FIX"                          │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    PHASE 1: CAPTURE                     │   │
│  │                                                          │   │
│  │  Coleta evidências:                                       │   │
│  │  • Mensagem de erro exata                               │   │
│  │  • Passos para reproduzir                                │   │
│  │  • Mudanças recentes                                    │   │
│  │  • Estado do sistema                                     │   │
│  │                                                          │   │
│  │  Ferramenta: debug::check                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    PHASE 2: INVESTIGATE                │   │
│  │                                                          │   │
│  │  Identifica causa raiz:                                 │   │
│  │  • desk::trace (funções/variáveis)                     │   │
│  │  • debug::recent_changes (git log)                      │   │
│  │  • Análise de padrões                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    PHASE 3: HYPOTHESIZE                │   │
│  │                                                          │   │
│  │  Formula hipótese clara:                                │   │
│  │  "Eu acho que X é a causa porque Y"                    │   │
│  │                                                          │   │
│  │  Validação: A hipótese explica TODO o comportamento?   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    PHASE 4: IMPLEMENT                  │   │
│  │                                                          │   │
│  │  Menor fix possível para testar hipótese                 │   │
│  │  1 variável por vez. Sem "while I'm here".             │   │
│  │                                                          │   │
│  │  REGRA: 3+ tentativas = Architecture Pattern Detected   │   │
│  │          STOP → discuta com usuário                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.6 Módulo Context7 (context7.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                    INTEGRAÇÃO CONTEXT7                           │
│                                                                 │
│  DETECÇÃO AUTOMÁTICA DE MÉTODO (prioridade):                    │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐  │
│  │   CLI     │→ │   MCP     │→ │   API     │→ │   NONE    │  │
│  │ (ctx7)    │  │(opencode) │  │(REST)     │  │(offline)  │  │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘  │
│                                                                 │
│  FUNÇÕES:                                                       │
│  ┌─────────────────┬───────────────────────────────────────┐  │
│  │ ctx7_check      │ Verifica se API está respondendo      │  │
│  ├─────────────────┼───────────────────────────────────────┤  │
│  │ ctx7_search     │ Busca documentação por query          │  │
│  ├─────────────────┼───────────────────────────────────────┤  │
│  │ ctx7_resolve    │ Resolve library ID + busca docs       │  │
│  ├─────────────────┼───────────────────────────────────────┤  │
│  │ ctx7_compare    │ Compara 2 libs para uma query        │  │
│  ├─────────────────┼───────────────────────────────────────┤  │
│  │ ctx7_detect     │ Detecta método disponível             │  │
│  └─────────────────┴───────────────────────────────────────┘  │
│                                                                 │
│  GATE-6 COMPORTAMENTO:                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  API configurada + respondendo  ─────────────► PASS ✅  │   │
│  │  API key missing                      ─────────► WARN ⚠️│   │
│  │  API offline/falhou                    ─────────► WARN ⚠️│   │
│  │                                                         │   │
│  │  ⚠️ GATE-6 NUNCA BLOQUEIA                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.7 Módulo de Conexão VPS/HUB (vps.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                     CONEXÃO VPS HUB                              │
│                                                                 │
│  ARQUITETURA:                                                   │
│  ┌──────────────────────────┐    SSH Mux     ┌───────────────┐│
│  │  MÁQUINA LOCAL            │◄──────────────►│  VPS HUB      ││
│  │                           │   (~0.3s/cmd)  │               ││
│  │  ┌─────────────────┐     │                │ ┌───────────┐││
│  │  │ devorq CLI      │     │                │ │PostgreSQL │││
│  │  │ sync-push.py    │────►│                │ │           │││
│  │  │ sync-pull.py    │◄────│                │ │ devorq.   │││
│  │  └─────────────────┘     │                │ │ lessons   │││
│  │                           │                │ │ memories  │││
│  └───────────────────────────┘                │ │ sessions  │││
│                                                │ │ handoffs  │││
│                                                │ └───────────┘││
│                                                └───────────────┘│
│                                                                 │
│  FUNÇÕES:                                                       │
│  ┌─────────────────┬───────────────────────────────────────┐  │
│  │ vps::check      │ Testa conexão SSH                     │  │
│  ├─────────────────┼───────────────────────────────────────┤  │
│  │ vps::exec       │ Executa comando no VPS via SSH        │  │
│  ├─────────────────┼───────────────────────────────────────┤  │
│  │ vps::pg_exec    │ Executa SQL no PostgreSQL             │  │
│  ├─────────────────┼───────────────────────────────────────┤  │
│  │ vps::lessons_   │ Conta lições no HUB                  │  │
│  │ count           │                                       │  │
│  └─────────────────┴───────────────────────────────────────┘  │
│                                                                 │
│  SSH MULTIPLEXING:                                              │
│  • ControlMaster: auto                                          │
│  • ControlPath: /tmp/devorq-ssh-mux                            │
│  • ControlPersist: 600s                                         │
│                                                                 │
│  CONFIGURAÇÃO:                                                  │
│  VPS_HOST=187.108.197.199                                      │
│  VPS_PORT=6985                                                 │
│  VPS_USER=root                                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.8 Módulo AUTO Mode (auto.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                    MODO AUTO (STORY-BY-STORY)                   │
│                                                                 │
│  PADRÃO RALPH: Tarefa grande → Stories pequenas → Loop com     │
│                contexto limpo → Uma story por iteração           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                      PRd.json                           │   │
│  │  ┌───────────────────────────────────────────────────┐   │   │
│  │  │ stories: [                                        │   │   │
│  │  │   {id: "feat-001", title: "...", priority: 10},  │   │   │
│  │  │   {id: "feat-002", title: "...", priority: 20},  │   │   │
│  │  │   ...                                             │   │   │
│  │  │ ]                                                 │   │   │
│  │  └───────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    LOOP-AUTO.SH                         │   │
│  │                                                          │   │
│  │  1. Seleciona story (prioridade mais alta)              │   │
│  │  2. delegate_task(story + acceptance criteria)          │   │
│  │  3. check-story.sh (verificação)                        │   │
│  │  4. git commit                                          │   │
│  │  5. Atualiza passes=true no prd.json                    │   │
│  │  6. Append em progress.txt                              │   │
│  │  7. Repete                                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   GERAÇÃO DE PRD                         │   │
│  │                                                          │   │
│  │  prd-from-spec.sh                                        │   │
│  │  • Lê SPEC.md                                            │   │
│  │  • Quebra em stories atômicas                           │   │
│  │  • Extrai acceptance criteria                            │   │
│  │  • Salva prd.json                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.9 Módulo UNIFY (unify.sh)

```
┌─────────────────────────────────────────────────────────────────┐
│                    FASE UNIFY (FECHAMENTO)                      │
│                                                                 │
│  unify::run()                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  1. Parsear ACs do SPEC.md (Given/When/Then)           │   │
│  │  2. Verificar status de cada AC                        │   │
│  │  3. Identificar desvios e gaps                         │   │
│  │  4. Auto-capturar lições dos desvios                   │   │
│  │  5. Gerar UNIFY.md                                     │   │
│  │  6. Atualizar context.json                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    UNIFY.md                             │   │
│  │  # UNIFY - feature_X - 2026-05-11                      │   │
│  │                                                          │   │
│  │  ## Acceptance Criteria Status                           │   │
│  │  | AC | Status | Evidence |                             │   │
│  │  |----|---------|----------------------------------|     │   │
│  │  | 1  | PASS    | Output verificado...                  |   │
│  │  | 2  | FAIL    | Faltando feature Y...                 |   │
│  │  | 3  | DEFERRED| Planejado para v2...                 |   │
│  │                                                          │   │
│  │  ## Gaps Identificados                                   │   │
│  │  - ...                                                   │   │
│  │                                                          │   │
│  │  ## Lições Capturadas                                    │   │
│  │  - ...                                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Skills do Ecossistema

### 4.1 Mapa de Skills

```
┌─────────────────────────────────────────────────────────────────┐
│                    SKILLS DO ECOSSISTEMA                        │
│                                                                 │
│  EXPLORATION (GATE-0)                                           │
│  ┌─────────────────┬─────────────────────────────────────────┐ │
│  │ env-context     │ Detecta stack, ambiente, binários,       │ │
│  │                 │ gotchas automaticamente na 1ª mensagem   │ │
│  ├─────────────────┼─────────────────────────────────────────┤ │
│  │ scope-guard     │ Contrato de escopo WHITELIST para      │ │
│  │                 │ bloquear over-engineering               │ │
│  ├─────────────────┼─────────────────────────────────────────┤ │
│  │ ddd-deep-domain │ Exploração de domínio (6 etapas) para  │ │
│  │                 │ modelagem correta ANTES de SPEC.md       │ │
│  └─────────────────┴─────────────────────────────────────────┘ │
│                                                                 │
│  FOUNDATION (GATE-0.5)                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ project-foundation                                       │   │
│  │  ├── 5w2h.json          Análise 5W2H completa         │   │
│  │  ├── premissas.json      Premissas e suposições         │   │
│  │  ├── riscos.json         Riscos com severidade/mitigação │   │
│  │  ├── requisitos.json     Requisitos funcionais/não-funcionais│ │
│  │  └── restricoes.json     Restrições do projeto          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  EXECUTION                                                       │
│  ┌─────────────────┬─────────────────────────────────────────┐ │
│  │ devorq-mode     │ Seletor AUTO/CLASSIC baseado em        │ │
│  │                 │ keywords                                 │ │
│  ├─────────────────┼─────────────────────────────────────────┤ │
│  │ devorq-auto     │ Modo autônomo story-by-story via      │ │
│  │                 │ delegate_task                           │ │
│  ├─────────────────┼─────────────────────────────────────────┤ │
│  │ devorq-code-    │ Review multi-agente com confidence    │ │
│  │ review          │ scoring (5 agentes //)                 │ │
│  └─────────────────┴─────────────────────────────────────────┘ │
│                                                                 │
│  UTILITY                                                         │
│  ┌─────────────────┬─────────────────────────────────────────┐ │
│  │ learned-lesson  │ Skills geradas automaticamente de       │ │
│  │                 │ lições aprovadas                        │ │
│  └─────────────────┴─────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Fluxo de Detecção de Skills

```
    ┌─────────────────┐
    │  Nova Mensagem  │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                    INTENT ANALYSIS                       │
    │                                                          │
    │  Keywords detectadas:                                     │
    │  ┌─────────────────────────────────────────────────────┐ │
    │  │ "domínio", "DDD", "modelagem"    → ddd-deep-domain │ │
    │  │ "implementar", "criar", "feature" → scope-guard    │ │
    │  │ "ambiente", "stack", "Docker"     → env-context    │ │
    │  │ "auto", "ralph", "story-by-story" → devorq-auto    │ │
    │  │ "review", "analisar código"       → code-review    │ │
    │  └─────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────┘
             │
             ▼
    ┌─────────────────────────────────────────────────────────┐
    │                    SKILL LOADING                         │
    │                                                          │
    │  1. Identifica skill(s) necessária(s)                    │
    │  2. Carrega scripts do skills/<name>/scripts/          │
    │  3. Executa skill                                       │
    │  4. Atualiza context.json                               │
    └─────────────────────────────────────────────────────────┘
```

---

## 5. Integrações Externas

### 5.1 Mapa de Integrações

```
┌─────────────────────────────────────────────────────────────────┐
│                    INTEGRAÇÕES EXTERNAS                         │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    CONTEXT7 API                          │  │
│  │                                                           │  │
│  │  Endpoint: https://api.context7.io/v1                   │  │
│  │  Auth: OPENAI_API_KEY                                   │  │
│  │  Usos:                                                   │  │
│  │  • Buscar documentação oficial                          │  │
│  │  • Comparar libraries                                    │  │
│  │  • Validar lições aprendidas                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    VPS HUB                             │  │
│  │                                                           │  │
│  │  Host: 187.108.197.199:6985                            │  │
│  │  SSH: root access                                       │  │
│  │  Services:                                              │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │ PostgreSQL Container                             │  │  │
│  │  │ Database: hermes_study                           │  │  │
│  │  │ Schema: devorq                                   │  │  │
│  │  │  ├── lessons (lições aprendidas)                │  │  │
│  │  │  ├── memories (memórias de contexto)            │  │  │
│  │  │  ├── sessions (histórico de sessões)           │  │  │
│  │  │  └── handoffs (histórico de handoffs)          │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │ dev-memory-laravel (interface web - repo sep.)  │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    TEST RUNNERS                          │  │
│  │                                                           │  │
│  │  PHP:                                                     │  │
│  │  • Pest (vendor/bin/pest)                                │  │
│  │  • PHPUnit (vendor/bin/phpunit)                           │  │
│  │  • Laravel (php artisan test)                            │  │
│  │                                                           │  │
│  │  Python:                                                  │  │
│  │  • Pytest                                                 │  │
│  │                                                           │  │
│  │  Bash:                                                    │  │
│  │  • shellcheck                                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    GIT INTEGRATION                       │  │
│  │                                                           │  │
│  │  • git status (untracked files)                          │  │
│  │  • git log (recent changes)                               │  │
│  │  • git commit (auto-commit de lições)                    │  │
│  │  • .gitignore (.devorq ignorado)                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Fluxo de Sincronização

```
┌─────────────────────────────────────────────────────────────────┐
│                    SINCRONIZAÇÃO HUB                             │
│                                                                 │
│  SYNC-PUSH (Local → HUB)                                        │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │.devorq/state/│    │   SSH Mux    │    │  PostgreSQL  │    │
│  │lessons/*.json│───►│              │───►│ devorq.lessons│   │
│  └──────────────┘    └──────────────┘    └──────────────┘    │
│       PYTHON                                                        │
│    sync-push.py                                                   │
│                                                                 │
│  SYNC-PULL (HUB → Local)                                         │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │ devorq.lessons│    │   SSH Mux    │    │.devorq/state/│    │
│  │  PostgreSQL  │───►│              │───►│lessons/       │    │
│  └──────────────┘    └──────────────┘    └──────────────┘    │
│                                                                 │
│  COMANDOS:                                                       │
│  devorq sync push  → Envia lições locais para HUB              │
│  devorq sync pull  → Recebe lições do HUB para local          │
│  devorq vps check  → Testa conexão com VPS                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Fluxos de Dados

### 6.1 Fluxo de Dados Principal

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXO DE DADOS                               │
│                                                                 │
│  INPUT                          PROCESSAMENTO         OUTPUT    │
│  ──────                         ─────────────         ──────    │
│                                                                 │
│  ┌─────────┐                    ┌──────────────┐    ┌─────────┐│
│  │ User    │                    │              │    │ handoff ││
│  │ Intent  │───────────────────►│ devorq flow  │───►│.json    ││
│  └─────────┘                    │              │    └─────────┘│
│                                │   GATES 0-7   │              │
│                                │              │    ┌─────────┐│
│                                │  [CHECK]     │───►│context  ││
│                                │  [VALIDATE]  │    │.json    ││
│                                │  [COMPRESS]  │    └─────────┘│
│                                │  [GENERATE]  │              │
│                                └──────────────┘    ┌─────────┐│
│                                                     │ lessons ││
│                                                     │/*.json  ││
│                                                     └─────────┘│
│                                                                 │
│  PERMANENTE:                                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ .devorq/state/  (Local - por projeto)                    │  │
│  │ • context.json (estado atual)                            │  │
│  │ • session.json (sessão corrente)                         │  │
│  │ • handoff.json (para próximo agente)                     │  │
│  │ • lessons/captured/*.json (lições locais)               │  │
│  │ • 5w2h.json, premissas.json, etc (foundation)          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  HUB (Remoto):                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ VPS PostgreSQL                                            │  │
│  │ • devorq.lessons (todas lições validadas)               │  │
│  │ • devorq.memories (memórias de contexto)                │  │
│  │ • devorq.sessions (histórico de sessões)                │  │
│  │ • devorq.handoffs (histórico de handoffs)             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Fluxo de Contexto por Sessão

```
┌─────────────────────────────────────────────────────────────────┐
│                    CICLO DE VIDA DO CONTEXTO                    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                     NOVA SESSÃO                          │  │
│  │                                                           │  │
│  │  1. devorq init (se não existe .devorq/)               │  │
│  │  2. Carrega handoff.json da sessão anterior              │  │
│  │  3. Atualiza context.json com estado                     │  │
│  │  4. GATE-3 valida contexto                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   DURANTE SESSÃO                         │  │
│  │                                                           │  │
│  │ ctx_set "intent" "implementar feature X"                 │  │
│  │ ctx_set "gates_completed" [1, 2, 3]                    │  │
│  │ ctx_set "errors" [] (se debug)                           │  │
│  │                                                           │  │
│  │ CONTEXTO CRESCE ──────────────────────────────────────►  │  │
│  │                                                           │  │
│  │ > 60k tokens? → ctx_pack sugere compressão               │  │
│  │ > 120k tokens? → CRÍTICO - compressão obrigatória        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   FIM DA SESSÃO                           │  │
│  │                                                           │  │
│  │  1. devorq compact (gera handoff.json)                  │  │
│  │  2. devorq sync push (envia lições para HUB)            │  │
│  │  3. context.json fica no projeto                         │  │
│  │  4. Próxima sessão carrega handoff.json                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Casos de Uso Principais

### 7.1 Caso: Novo Projeto

```
┌─────────────────────────────────────────────────────────────────┐
│            CASO: NOVO PROJETO                                    │
└─────────────────────────────────────────────────────────────────┘

1. cd /projects/novo-projeto

2. devorq init
   └─► Cria .devorq/
       • state/context.json (vazio)
       • state/session.json
       • state/lessons/captured/
       • 5 foundation docs (templates)

3. devorq foundation create
   └─► Wizard interativo para preencher:
       • 5W2H, Premissas, Riscos, Requisitos, Restrições

4. Criar SPEC.md
   └─► Documentar especificação do projeto

5. devorq flow "implementar projeto X"
   └─► Executa gates 0 → 0.5 → 1-7

6. Implementar features via modo AUTO ou CLASSIC

7. devorq sync push
   └─► Sincroniza lições com HUB
```

### 7.2 Caso: Retomar Sessão

```
┌─────────────────────────────────────────────────────────────────┐
│            CASO: RETOMAR SESSÃO                                  │
└─────────────────────────────────────────────────────────────────┘

1. cd /projects/projeto-existente

2. devorq init (se .devorq/ não existir)
   └─► Carrega estado existente

3. devorq compact (carrega handoff.json)
   └─► Identifica:
       • Onde parou
       • Gates pendentes
       • Lições relevantes
       • Pending work

4. devorq lessons search "<tecnologia>"
   └─► Busca lições do HUB relevantes

5. devorq context7 search "<query>"
   └─► Consulta docs oficiais

6. Continua implementação

7. Captura lições durante trabalho
   └─► devorq lessons capture

8. devorq compact (gera novo handoff)
```

### 7.3 Caso: Feature Complexa (Modo AUTO)

```
┌─────────────────────────────────────────────────────────────────┐
│            CASO: FEATURE COMPLEXA (MODO AUTO)                   │
└─────────────────────────────────────────────────────────────────┘

1. devorq auto
   └─► Mode selector pergunta: AUTO ou CLASSIC?

2. Gerar/validar prd.json
   └─► Se não existe: prd-from-spec.sh
       Se existe: mostra pendentes

3. Loop-auto.sh executa:
   ┌─────────────────────────────────────────┐
   │ LOOP por story:                         │
   │                                         │
   │  a. Seleciona story (prioridade alta)  │
   │  b. delegate_task(story + AC)          │
   │  c. check-story.sh (GATE-1 a GATE-7)   │
   │  d. PASSOU → git commit + AC done      │
   │  e. FALHOU → para e pergunta           │
   │  f. Repete próxima story               │
   └─────────────────────────────────────────┘

4. Ao final: Summary
   └─► Lista de stories completadas
       Repositório pronto para PR
```

---

## 8. Diagramas de Estado

### 8.1 Estado do Projeto

```
                    ┌─────────────────┐
                    │    CRIADO       │
                    └────────┬────────┘
                             │ devorq init
                             ▼
                    ┌─────────────────┐
                    │  INICIALIZADO  │◄────────────────┐
                    └────────┬────────┘                 │
                             │ devorq foundation        │
                             │ create                   │
                             ▼                          │
                    ┌─────────────────┐                 │
                    │   FUNDADO       │─────────────────┘
                    └────────┬────────┘
                             │ SPEC.md criado
                             ▼
                    ┌─────────────────┐
                    │   EM DESENVOLV. │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    BLOQUEADO    │ │  EM IMPLEMENT.  │ │     BLOQUEADO  │
│  (GATE falhou)  │ │                 │ │  (GATE falhou) │
└─────────────────┘ └────────┬────────┘ └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  UNIFY EXECUTED │
                    └────────┬────────┘
                             │ PR aberto
                             ▼
                    ┌─────────────────┐
                    │    CONCLUÍDO   │
                    └─────────────────┘
```

### 8.2 Estado de Gate

```
┌─────────────────────────────────────────────────────────────────┐
│                    ESTADO DE GATE                                │
└─────────────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │   PENDING    │ ◄── Estado inicial
    └──────┬───────┘
           │ gate executado
           ▼
    ┌──────────────┐
    │  EXECUTING   │ ◄── Durante verificação
    └──────┬───────┘
           │
    ┌──────┴───────┐
    │              │
    ▼              ▼
┌─────────┐  ┌─────────┐
│  PASS   │  │  FAIL   │
└────┬────┘  └────┬────┘
     │            │
     ▼            ▼
┌─────────┐  ┌─────────────┐
│ Proximo │  │  BLOQUEADO  │
│ Gate    │  │  (corrigir) │
└─────────┘  └─────────────┘
                  │
                  │ problema corrigido
                  ▼
            ┌──────────────┐
            │ REVALIDATING │
            └──────┬───────┘
                   │
                   ▼
             Retorna ao loop
```

---

## 9. Resumo das Funcionalidades

### 9.1 Comandos Principais

| Comando | Descrição | Categoria |
|---------|-----------|-----------|
| `devorq init` | Inicializa .devorq/ no projeto | Setup |
| `devorq flow "<intent>"` | Workflow completo (gates 0-7) | Execução |
| `devorq gate [0-7]` | Executa gate específico | Execução |
| `devorq test` | Testa estrutura do projeto | Verificação |
| `devorq lessons capture` | Captura lição aprendida | Conhecimento |
| `devorq lessons search` | Busca lições locais/HUB | Conhecimento |
| `devorq lessons validate` | Valida lição com Context7 | Conhecimento |
| `devorq lessons approve` | Aprova lição para skill | Conhecimento |
| `devorq lessons compile` | Compila lição para skill | Conhecimento |
| `devorq context` | Mostra contexto atual | Contexto |
| `devorq context7 install` | Instala Context7 | Contexto |
| `devorq compact` | Gera handoff JSON | Contexto |
| `devorq foundation` | Project Foundation docs | Foundation |
| `devorq ddd explore` | Workshop DDD | Exploration |
| `devorq scope validate` | Valida contrato de escopo | Exploration |
| `devorq debug` | Workflow debug sistemático | Debug |
| `devorq sync push/pull` | Sincroniza com HUB | Sync |
| `devorq vps check` | Testa conexão VPS | Sync |
| `devorq auto` | Modo AUTO story-by-story | Auto |
| `devorq stats` | Métricas de uso | Analytics |
| `devorq build` | Self-building (build + upgrade) | DevOps |
| `devorq upgrade` | Atualiza DEVORQ | DevOps |
| `devorq uninstall` | Remove instalação | DevOps |

### 9.2 Arquivos de Estado

| Arquivo | Local | Propósito |
|---------|-------|-----------|
| `context.json` | .devorq/state/ | Estado atual do projeto |
| `session.json` | .devorq/state/ | Dados da sessão corrente |
| `handoff.json` | .devorq/state/ | Handoff para próxima sessão |
| `*.json` (lessons) | .devorq/state/lessons/captured/ | Lições aprendidas locais |
| `5w2h.json` | .devorq/state/ | Análise 5W2H |
| `premissas.json` | .devorq/state/ | Premissas do projeto |
| `riscos.json` | .devorq/state/ | Riscos identificados |
| `requisitos.json` | .devorq/state/ | Requisitos funcionais/não-funcionais |
| `restricoes.json` | .devorq/state/ | Restrições do projeto |
| `prd.json` | Raiz do projeto | Stories para modo AUTO |

---

## 10. Próximos Passos para Diagramas

Para criar os diagramas formais, você pode usar esta documentação como base para:

1. **Diagramas de Fluxo (Flowcharts)**
   - Fluxo completo de Gates
   - Ciclo de vida de lições
   - Fluxo de debug sistemático

2. **Diagramas de Arquitetura**
   - Arquitetura de módulos
   - Integração com HUB VPS
   - Hierarquia de skills

3. **Diagramas de Sequência**
   - Sequência de inicialização
   - Sequência de sincronização
   - Sequência de handoff

4. **Diagramas de Estado**
   - Estado do projeto
   - Estado dos gates
   - Estado das lições

5. **Diagramas de Componentes**
   - Relação entre módulos
   - Dependências de bibliotecas

---

## Conclusão

O sistema **DEVORQ v3** é uma estrutura robusta para metodologia de desenvolvimento sistemático com foco em:

- **Disciplina**: Gates bloqueantes que impedem avanço sem verificação
- **Conhecimento**: Captura e reuse de lições aprendidas
- **Continuidade**: Handoffs consistentes entre sessões/agentes
- **Qualidade**: Debug sistemático e code review multi-agente
- **Escalabilidade**: Modo AUTO para features complexas

A arquitetura é modular, extensível via skills, e tolerante a falhas (funciona sem jq, sem Context7, etc.).

---

*Documento gerado automaticamente via análise de código - Trae IDE*
