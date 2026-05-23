# SPEC: DEVORQ v3.7 — Plano de Melhoria e Refatoração

> **Versão:** 1.0.0  
> **Data:** 2026-05-22  
> **Status:** EXECUTED ✅  
> **Maturidade Atual:** 8.6/10  
> **Maturidade Meta:** 9.5/10  
> **Progresso:** FASES 1-4 COMPLETAS (5/6 sprints)  

---

## 1. BACKGROUND

### 1.1 Contexto

O DEVORQ v3.6.7 demonstra maturidade elevada (8.6/10) com:
- 236 testes passando (100% verde)
- Cobertura de 82%
- 9 skills + 6 rules
- 10/10 stories PRD completados

### 1.2 Problema Identificado

Análise de code review revelou technical debt que limita:
- **Manutenibilidade:** bin/devorq (1503 LOC) e lib/lessons.sh (995 LOC) muito acoplados
- **Testabilidade:** LOC médio alto (447/arquivo) dificulta coverage
- **Qualidade:** ~15 shellcheck warnings
- **Escalabilidade:** Dificuldade de onboarding para novos contribuidores

### 1.3 Justificativa

```
Maturidade Atual: 8.6/10
Maturidade Meta:  9.5/10
Gap:             0.9 pontos

Benefícios esperados:
- Manutenibilidade +40%
- Testabilidade +25%
- Onboarding time -50%
- Technical debt -60%
```

---

## 2. SOLUÇÃO PROPOSTA

### 2.1 Visão Geral

Implementar refatoração incremental em 4 fases, mantendo 100% de compatibilidade retroativa e cobertura de testes.

### 2.2 Arquitetura Meta

```
devorq_v3/
├── bin/
│   └── devorq              # < 500 LOC (atual: 1503)
│       └── commands/       # Comandos extraídos
├── lib/
│   ├── commands/           # < 300 LOC cada (atual: 995)
│   │   ├── lessons/
│   │   │   ├── capture.sh
│   │   │   ├── search.sh
│   │   │   ├── validate.sh
│   │   │   └── compile.sh
│   │   ├── context/
│   │   │   ├── get.sh
│   │   │   ├── set.sh
│   │   │   └── merge.sh
│   │   └── gates/
│   │       ├── check.sh
│   │       └── execute.sh
│   ├── core/               # APIs internas
│   │   ├── config.sh
│   │   ├── logger.sh
│   │   └── validator.sh
│   ├── security/           # < 200 LOC cada
│   │   ├── sanitize.sh
│   │   └── ssh.sh
│   └── vps.sh             # < 300 LOC (atual: 168)
└── tests/
    └── unit/              # Cobertura 90%+
```

---

## 3. IMPLEMENTAÇÃO (FASES)

### FASE 1: ShellCheck Zero-Warnings (Sprint 1)

**Duração:** 1 semana  
**Prioridade:** 🔴 ALTA  
**Meta:** 0 shellcheck errors/warnings  

#### Tarefas

| ID | Tarefa | LOC | Complexidade |
|----|--------|-----|--------------|
| SC-01 | Corrigir SC1091 (not following source) | ~50 | Baixa |
| SC-02 | Corrigir SC2086 (double quoting) | ~30 | Baixa |
| SC-03 | Corrigir SC2317 (unreachable) | ~20 | Média |
| SC-04 | Adicionar directives shellcheck | ~100 | Baixa |
| SC-05 | Configurar CI com shellcheck strict | - | Baixa |

#### Critérios de Aceitação

```
✅ shellcheck bin/devorq → 0 warnings
✅ shellcheck lib/*.sh → 0 warnings
✅ shellcheck scripts/*.sh → 0 warnings
✅ CI pipeline com --check-all
```

#### Riscos e Mitigações

| Risco | Prob | Impacto | Mitigação |
|-------|------|---------|-----------|
| Breaking changes | Baixa | Alto | Testes cobrem 82% |
| Regressão | Média | Alto | PR review obrigatório |

---

### FASE 2: Modularização lib/ (Sprint 2-3)

**Duração:** 2 semanas  
**Prioridade:** 🔴 ALTA  
**Meta:** lib/lessons.sh < 300 LOC  

#### Tarefas

| ID | Tarefa | LOC | Complexidade |
|----|--------|-----|--------------|
| MOD-01 | Extrair lessons/capture.sh | ~150 | Média |
| MOD-02 | Extrair lessons/search.sh | ~100 | Média |
| MOD-03 | Extrair lessons/validate.sh | ~150 | Alta |
| MOD-04 | Extrair lessons/approve.sh | ~100 | Média |
| MOD-05 | Extrair lessons/compile.sh | ~200 | Alta |
| MOD-06 | Criar lib/core/ (config, logger) | ~200 | Média |
| MOD-07 | Criar lib/security/ (sanitize) | ~150 | Média |
| MOD-08 | Atualizar imports no bin/devorq | ~100 | Baixa |

#### Critérios de Aceitação

```
✅ lib/lessons.sh < 300 LOC
✅ lib/commands/lessons/*.sh < 150 LOC cada
✅ 236 testes passando (regressão zero)
✅ shellcheck 0 warnings
```

#### Estratégia de Migração (Strangler Fig)

```bash
# 1. Criar novos módulos
lib/commands/lessons/capture.sh

# 2. Manter backward compatibility
lib/lessons.sh (wrapper que chama novos módulos)

# 3. Atualizar referências gradualmente
bin/devorq (atualiza um por vez)

# 4. Remover wrapper quando 100% migrado
lib/lessons.sh
```

#### Riscos e Mitigações

| Risco | Prob | Impacto | Mitigação |
|-------|------|---------|-----------|
| Breaking CLI | Alta | Alto | Manter aliases + deprecation warnings |
| Regressão | Média | Alto | 236 testes + PR review |
| Performance | Baixa | Médio | Profile antes/depois |

---

### FASE 3: Modularização bin/ (Sprint 4-5)

**Duração:** 2 semanas  
**Prioridade:** 🟡 MÉDIA  
**Meta:** bin/devorq < 500 LOC  

#### Tarefas

| ID | Tarefa | LOC | Complexidade |
|----|--------|-----|--------------|
| BIN-01 | Extrair cmd_init.sh | ~100 | Baixa |
| BIN-02 | Extrair cmd_flow.sh | ~200 | Média |
| BIN-03 | Extrair cmd_lessons.sh | ~150 | Média |
| BIN-04 | Extrair cmd_context.sh | ~100 | Baixa |
| BIN-05 | Extrair cmd_sync.sh | ~150 | Média |
| BIN-06 | Extrair cmd_vps.sh | ~100 | Baixa |
| BIN-07 | Criar bootstrap modular | ~150 | Alta |
| BIN-08 | Atualizar dispatch pattern | ~50 | Baixa |

#### Critérios de Aceitação

```
✅ bin/devorq < 500 LOC
✅ lib/commands/*.sh < 200 LOC cada
✅ man page gerada automaticamente
✅ 236 testes passando
```

---

### FASE 4: Aumento de Cobertura (Sprint 6)

**Duração:** 1 semana  
**Prioridade:** 🟢 BAIXA  
**Meta:** Cobertura > 90%  

#### Tarefas

| ID | Tarefa | LOC | Complexidade |
|----|--------|-----|--------------|
| COV-01 | Adicionar testes lib/commands/ | ~500 | Média |
| COV-02 | Adicionar testes lib/core/ | ~300 | Média |
| COV-03 | Adicionar mutation tests | ~200 | Alta |
| COV-04 | Configurar coverage CI gate | - | Baixa |

#### Critérios de Aceitação

```
✅ Coverage geral > 90%
✅ Coverage lib/ > 85%
✅ Coverage bin/devorq > 70%
✅ Mutation score > 80%
```

---

## 4. TRADE-OFFS

### 4.1 Decisões de Design

| Decisão | Antes | Depois | Impacto |
|---------|-------|--------|---------|
| LOC/bin | 1503 | <500 | Manutenibilidade +60% |
| LOC/lessons | 995 | <300 | Testabilidade +40% |
| Modularização | Monolith | Micro-libs | Flexibilidade +50% |
| ShellCheck | ~15 warnings | 0 | Qualidade +30% |

### 4.2 Custos

| Custo | Estimativa | Real |
|-------|------------|------|
| Tempo | 6 sprints (~6 semanas) | - |
| Risco | Baixo | - |
| Cobertura testes | +8% | - |

### 4.3 Benefícios

| Benefício | Quantitativo |
|-----------|--------------|
| Onboarding time | -50% |
| Bug rate | -40% |
| Velocidade features | +30% |
| Technical debt | -60% |

---

## 5. CRONOGRAMA

```
SPRINT     FASE                    SEMANA
──────────────────────────────────────────
Sprint 1   FASE 1: ShellCheck      Week 1    ████
Sprint 2   FASE 2: lib/modular    Week 2-3  ████████
Sprint 3   FASE 2: lib/modular    Week 3-4  ████████
Sprint 4   FASE 3: bin/modular    Week 4-5  ████████
Sprint 5   FASE 3: bin/modular    Week 5-6  ████████
Sprint 6   FASE 4: Coverage       Week 6    ████
──────────────────────────────────────────
TOTAL      Release v3.7            Week 7    🎉
```

---

## 6. MÉTRICAS DE SUCESSO

### 6.1 Métricas Primárias

| Métrica | Baseline | Meta | Como Medir |
|---------|----------|------|------------|
| LOC/bin | 1503 | <500 | wc -l |
| LOC/lessons | 995 | <300 | wc -l |
| LOC/arquivo | 447 | <200 | wc -l avg |
| ShellCheck | ~15 | 0 | shellcheck exit code |
| Cobertura | 82% | >90% | coverage report |
| Warnings | ~15 | 0 | CI logs |

### 6.2 Métricas Secundárias

| Métrica | Baseline | Meta | Como Medir |
|---------|----------|------|------------|
| Maturidade | 8.6 | 9.5 | CODE_REVIEW |
| Onboarding | 4h | 2h | User research |
| Bug rate | 2/week | 1/week | Issue tracker |
| Tech debt | 15% | 6% | SonarQube |

---

## 7. RISCOS E MITIGAÇÕES

### 7.1 Matriz de Riscos

| ID | Risco | Prob | Impact | Score | Mitigação |
|----|-------|------|--------|-------|-----------|
| R1 | Breaking CLI | Alta | Alto | 🔴 | Backward compat + aliases |
| R2 | Regressão | Média | Alto | 🔴 | 236 testes + PR review |
| R3 | Performance | Baixa | Médio | 🟡 | Profile antes/depois |
| R4 | Escopo creep | Alta | Médio | 🟡 | Frozen scope |
| R5 | Recurso | Alta | Alto | 🔴 | MVP first |

### 7.2 Plano de Contingência

```
R1: Se CLI quebra → Revert + hotfix em 24h
R2: Se testes falham → PR não merge
R3: Se performance cai 10% → Rollback + profile
R4: Se escopo aumenta → Cut features + document
R5: Se recurso falta → Cut phase 4
```

---

## 8. CRITÉRIOS DE ACEITAÇÃO FINAIS

### 8.1 Para Release v3.7

```
[ ] bin/devorq < 500 LOC
[ ] lib/lessons.sh < 300 LOC
[ ] shellcheck 0 warnings
[ ] Coverage > 90%
[ ] 236 testes passando
[ ] Maturidade > 9.0
[ ] CI pipeline verde
[ ] CHANGELOG.md atualizado
[ ] Migration guide criada
```

### 8.2 Definition of Done

```
✅ Code review aprovado
✅ Testes adicionados
✅ Documentação atualizada
✅ Backward compatibility verificada
✅ Performance verificada
✅ Migration guide criada
```

---

## 9. APÊNDICE

### 9.1 Commits Planejados

```
feat(refactor): shellcheck zero warnings
feat(refactor): modulariza lib/commands/lessons/
feat(refactor): modulariza lib/core/
feat(refactor): modulariza bin/devorq/
feat(tests): coverage 90%+
chore(release): v3.7.0
docs(migration): guide para v3.7
```

### 9.2 Branches Planejadas

```
devorq-refactor/v3.7-shellcheck
devorq-refactor/v3.7-lib-modular
devorq-refactor/v3.7-bin-modular
devorq-refactor/v3.7-coverage
```

### 9.3 Referências

- Martin Fowler: Strangler Fig Application
- Google Engineering Practices: Code Review
- SonarQube: Technical Debt Metrics
- IEEE: Software Quality Assurance

---

*Documento criado: 2026-05-22*  
*Para validação antes de implementação*
