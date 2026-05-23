# Estrutura Modular Proposta - DEVORQ v3.6.0

> **Data:** 2026-05-12
> **Versão:** 3.6.0
> **Status:** Proposta

---

## 1. Estrutura Atual vs Proposta

### 1.1 Estrutura Atual (Monolítica)

```
bin/devorq (1300+ linhas)
├── Bootstrap & Logging
├── Help
├── Comandos (todos em um arquivo):
│   ├── cmd_init
│   ├── cmd_foundation
│   ├── cmd_flow
│   ├── cmd_gate
│   ├── cmd_lessons
│   ├── cmd_context
│   ├── cmd_compact
│   ├── cmd_vps
│   ├── cmd_context7
│   ├── cmd_skills
│   ├── cmd_version
│   ├── cmd_upgrade
│   ├── cmd_test
│   ├── cmd_sync
│   ├── cmd_uninstall
│   ├── cmd_debug
│   ├── cmd_build
│   ├── cmd_stats
│   ├── cmd_scope
│   ├── cmd_ddd
│   ├── cmd_env
│   ├── cmd_spec
│   ├── cmd_unify
│   ├── cmd_mode
│   ├── cmd_auto
│   └── cmd_review
└── Dispatcher (case)
```

### 1.2 Estrutura Proposta (Modular)

```
bin/devorq (200 linhas)
├── Bootstrap
├── Logging
├── Help
├── Helpers
├── Dispatcher
└── source lib/commands/*.sh

lib/commands/
├── workflow.sh          # init, test, flow, gate
├── lessons.sh          # lessons capture/search/validate
├── context.sh          # context, compact
├── exploration.sh      # scope, ddd, env, spec, unify
├── execution.sh        # mode, auto, review
├── foundation.sh       # foundation
├── integration.sh     # sync, vps, context7
├── utils.sh            # version, upgrade, uninstall
├── meta.sh            # debug, build, stats
└── skills.sh         # skills

lib/
├── gates.sh           # Gates (já existe)
├── lessons.sh         # Lessons logic (já existe)
├── context.sh         # Context logic (já existe)
├── context7.sh        # Context7 (já existe)
├── debug.sh           # Debug (já existe)
├── stats.sh           # Stats (já existe)
├── vps.sh            # VPS (já existe)
├── compact.sh         # Compact (já existe)
├── auto.sh           # Auto mode (já existe)
├── spec.sh           # Spec (já existe)
├── unify.sh          # Unify (já existe)
└── ...outros módulos...
```

---

## 2. Comandos a Extrair

### 2.1 Grupo: Workflow

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| init | Inicializar projeto | Baixa | Alta |
| test | Testar estrutura | Baixa | Alta |
| flow | Workflow completo | Média | Alta |
| gate | Executar gate específico | Média | Alta |

**Arquivo:** `lib/commands/workflow.sh`

### 2.2 Grupo: Lessons

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| lessons capture | Capturar lição | Média | Alta |
| lessons search | Buscar lições | Média | Alta |
| lessons validate | Validar lição | Alta | Alta |
| lessons approve | Aprovar lição | Média | Média |
| lessons compile | Compilar lição | Média | Média |
| lessons list | Listar lições | Baixa | Alta |
| lessons migrate | Migrar lições | Média | Média |

**Arquivo:** `lib/commands/lessons.sh`

### 2.3 Grupo: Context

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| context | Mostrar contexto | Baixa | Alta |
| compact | Gerar handoff | Baixa | Alta |

**Arquivo:** `lib/commands/context.sh`

### 2.4 Grupo: Exploration

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| scope | Validar escopo | Média | Média |
| ddd | DDD workshop | Alta | Média |
| env | Detectar ambiente | Média | Média |
| spec | Validar SPEC | Média | Alta |
| unify | UNIFY phase | Média | Média |

**Arquivo:** `lib/commands/exploration.sh`

### 2.5 Grupo: Foundation

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| foundation | Project Foundation | Alta | Alta |

**Arquivo:** `lib/commands/foundation.sh`

### 2.6 Grupo: Integration

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| sync | Sincronizar com HUB | Média | Alta |
| vps | Testar VPS | Baixa | Alta |
| context7 | Context7 commands | Alta | Alta |

**Arquivo:** `lib/commands/integration.sh`

### 2.7 Grupo: Execution

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| mode | Seletor AUTO/CLASSIC | Média | Alta |
| auto | AUTO mode | Alta | Alta |
| review | Code review | Alta | Média |

**Arquivo:** `lib/commands/execution.sh`

### 2.8 Grupo: Utils

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| version | Mostrar versão | Baixa | Alta |
| upgrade | Atualizar DEVORQ | Média | Alta |
| uninstall | Remover DEVORQ | Média | Alta |

**Arquivo:** `lib/commands/utils.sh`

### 2.9 Grupo: Meta

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| debug | Workflow debug | Alta | Alta |
| build | Self-building | Alta | Alta |
| stats | Estatísticas | Baixa | Alta |

**Arquivo:** `lib/commands/meta.sh`

### 2.10 Grupo: Skills

| Comando | Função | Complexidade | Prioridade |
|---------|--------|-------------|------------|
| skills | Gerenciar skills | Média | Alta |

**Arquivo:** `lib/commands/skills.sh`

---

## 3. Benefícios da Refatoração

### 3.1 Manutenibilidade
- **Antes:** 1300+ linhas em um arquivo
- **Depois:** ~100-200 linhas por módulo
- **Ganho:** ~10x mais fácil de manter

### 3.2 Testabilidade
- **Antes:** Difícil testar comandos individuais
- **Depois:** Testar cada módulo separadamente
- **Ganho:** Cobertura > 80%

### 3.3 Reusabilidade
- **Antes:** Funções acopladas
- **Depois:** Módulos independentes
- **Ganho:** Reusar em outros projetos

### 3.4 Performance
- **Antes:** Carregar tudo mesmo que não use
- **Depois:** Carregar apenas o necessário
- **Ganho:** ~30% mais rápido

---

## 4. Plano de Migração

### Fase 1: Preparação (1 dia)
1. [x] Backup do código atual
2. [ ] Criar estrutura de diretórios
3. [ ] Documentar comportamento atual
4. [ ] Setup testes

### Fase 2: Extrair Comandos Básicos (2 dias)
1. [ ] lib/commands/workflow.sh (init, test, flow, gate)
2. [ ] lib/commands/lessons.sh
3. [ ] lib/commands/context.sh
4. [ ] Testar compatibilidade

### Fase 3: Extrair Comandos Avançados (2 dias)
1. [ ] lib/commands/exploration.sh
2. [ ] lib/commands/execution.sh
3. [ ] lib/commands/foundation.sh
4. [ ] Testar compatibilidade

### Fase 4: Extrair Comandos Restantes (1 dia)
1. [ ] lib/commands/integration.sh
2. [ ] lib/commands/utils.sh
3. [ ] lib/commands/meta.sh
4. [ ] lib/commands/skills.sh
5. [ ] Testar compatibilidade

### Fase 5: Limpeza (1 dia)
1. [ ] Remover código duplicado
2. [ ] Refinar documentação
3. [ ] Executar todos os testes
4. [ ] Validar performance

---

## 5. Critérios de Sucesso

| Critério | Baseline | Meta |
|----------|----------|------|
| Linhas bin/devorq | 1300+ | < 300 |
| Linhas por módulo | - | < 200 |
| Cobertura testes | 0% | > 80% |
| Tempo execução | baseline | -10% |
| Erros lint | ? | 0 |

---

## 6. Riscos e Mitigação

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|------------|
| Quebrar CLI | Alta | Alto | Testes E2E antes/depois |
| Perder funcionalidade | Média | Alto | Backup, testes |
| Regressões | Alta | Médio | Testes de regressão |

---

## 7. Testes Necessários

### 7.1 Testes Unitários
- Cada função separada
- Mocks para dependências
- Coverage > 80%

### 7.2 Testes de Integração
- Módulos working together
- CLI interface intacta

### 7.3 Testes E2E
- Comandos completos
- Fluxos de trabalho
- Edge cases

---

## 8. Estimativa de Esforço

| Fase | Dias | Complexidade |
|------|------|-------------|
| Preparação | 1 | Baixa |
| Comandos Básicos | 2 | Alta |
| Comandos Avançados | 2 | Alta |
| Comandos Restantes | 1 | Média |
| Limpeza | 1 | Baixa |
| **Total** | **7** | - |

---

## 9. Próximos Passos Imediatos

1. Criar diretório `lib/commands/`
2. Criar primeiro módulo (workflow.sh)
3. Testar compatibilidade
4. Iterar

---

*Documento criado para planejamento de refatoração - DEVORQ v3.6.0*
