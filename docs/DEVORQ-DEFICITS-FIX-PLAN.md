# SPEC: Corrigir os 2 Déficits Técnicos do DEVORQ

**Versão:** 1.0.0
**Data:** 2026-05-21
**Autor:** Nando (Fernando Dos Santos)
**Engine:** DEVORQ v3.6.7
**Status:** RESOLVIDO — 2026-05-23 (v3.7.1)

---

## Resumo Executivo

Dois déficits técnicos identificados na análise do artigo do Marcelo Guerra:

| # | Déficit | Prioridade | Esforço | Status |
|---|---------|-----------|---------|--------|
| 1 | **SPEC desatualizada** — `DEVORQ-COMMIT-VISUAL-SPEC.md` diz "aguardando implementação" mas features estão em produção há 3 versões | 🔴 Alta | Baixo | ✅ RESOLVIDO |
| 2 | **Observabilidade do agente quebrada** — Loki ingester loop "not ready", push retorna 204 mas queries vaziam | 🔴 Alta | Alto | ✅ RESOLVIDO |

### Resolução (2026-05-23)

**Deficit 1:** Merge da branch `origin/main` (commit `fa21549`) trouxe:
- `lib/visual.sh` — `devorq verify` (Playwright + manual)
- `lib/commit.sh` — `devorq commit` manual
- `lib/rules.sh` — sistema de regras enforced
- `DEVORQ-COMMIT-VISUAL-SPEC.md` → `Status: IMPLEMENTADO v3.7.0`
- `CHANGELOG.md` → entrada `[3.7.1]` com todas as features documentadas

**Deficit 2:** Pipeline OTel migrado para Prometheus Pushgateway:
- `~/claude_otel_wrapper.py` → `push_to_gateway("https://observer.fssdev.com.br")` (HTTPS)
- Pushgateway :9091 → Prometheus :9090 → Grafana :3002
- Loki abandonado para métricas (stack ainda existe, não removido)
- Skill `devorq-observability` atualizada com arquitetura Pushgateway

**Resultado:** DEVORQ v3.7.1 — 12/12 stories done, 7/7 gates verdes, merge `origin/main` aplicado

---

## Deficit 1: SPEC Desatualizada — ✅ RESOLVIDO

### Diagnóstico

**Arquivo:** `docs/DEVORQ-COMMIT-VISUAL-SPEC.md`
**Status atual:** `Status: Validado — aguardando implementação`
**Realidade:** Features implementadas e em produção:

| Feature | Implementada em | Status no doc |
|---------|----------------|---------------|
| `lib/visual.sh` (devorq verify) | v3.6.5 | ⚠️ Não mencionado |
| `lib/commit.sh` (devorq commit manual) | v3.6.5 | ⚠️ Não mencionado |
| `scripts/debug-systematic.sh` | v3.6.5 | ⚠️ Não mencionado |
| Trigger automático systematic-debugging | v3.6.5 | ⚠️ Não mencionado |
| Commit manual pós-verificação | v3.6.5 | ⚠️ Não mencionado |
| Sistema de regras enforced | v3.6.6 | ⚠️ Não mencionado |
| `devorq brainstorm` | v3.6.6 | ⚠️ Não mencionado |
| `devorq grill` | v3.6.6 | ⚠️ Não mencionado |
| shellcheck 0 errors | v3.6.7 | ⚠️ Não mencionado |

### Contradição com Princípios DEVORQ

O artigo do Marcelo diz: "O que aparece no board como adoção é, em muitos casos, marketing." A SPEC desatualizada erode credibilidade do framework — o documento diz que nada foi implementado quando na verdade tudo está funcionando há 3 versões. Isso contradiz o princípio DEVORQ de "verificar antes de commit" — se a documentação não reflete a realidade, o framework perde valor como referência.

### Solução Proposta

1. Atualizar `docs/DEVORQ-COMMIT-VISUAL-SPEC.md`:
   - `Status:` → `IMPLEMENTADO v3.6.5`
   - `Versão DEVORQ:` → `3.6.7` (versão atual)
   - Adicionar seção "Histórico de Implementação" com datas
   - Adicionar link para `lib/visual.sh`, `lib/commit.sh`, `scripts/debug-systematic.sh`

2. Atualizar `CHANGELOG.md`:
   - Adicionar entrada `[3.6.7]` com lista completa das features implementadas desde `[3.6.5]`
   - Garantir que todas as features da SPEC estejam documentadas

3. Criar lição aprendida: "Documentação que não reflete código = erosão de credibilidade"

### Critério de Sucesso

- `docs/DEVORQ-COMMIT-VISUAL-SPEC.md` → `Status: IMPLEMENTADO v3.6.5`
- `CHANGELOG.md` → entrada `[3.6.7]` completa e consistente com SPEC
- `devorq build` → 7/7 gates verdes (sem regressão)
- `shellcheck -S error bin/devorq lib/*.sh scripts/*.sh` → 0 errors

### Arquivos a Modificar

```
docs/DEVORQ-COMMIT-VISUAL-SPEC.md   (metadata + seção histórico)
CHANGELOG.md                         (entrada [3.6.7] completa)
```

---

## Deficit 2: Observabilidade do Agente Quebrada — ✅ RESOLVIDO

### Diagnóstico

**Stack atual no VPS:**
- OTel Collector (recebe do wrapper local)
- Prometheus ( scrape mode — pull based)
- Loki 3.3.2 (push mode — recebe do wrapper local)
- Grafana 11.4.0

**Problema identificado:**
- `claude_otel_wrapper.py` → push para Loki API `/loki/api/v1/push`
- Loki retorna 204 (aceito), mas ingester está em loop "not ready"
- Queries retornam vazio — dados não estão consultáveis
- Prometheus existe mas está em scrape mode (pull), não recebe push

**Root cause provável:**
Loki ingester em "not ready" loop indica que o ingester não consegue validar chunks com o armazenamento. Pode ser problema de:
1. Permissão no storage
2. Configuração de chunk/storage
3. Overflow de chunks não flushados
4. Versão Loki incompatível com o storage

### Solução Proposta — Prometheus Pushgateway (alternativa ao Loki)

**Por que Prometheus em vez de corrigir Loki:**
- Prometheus já está rodando no VPS
- Pushgateway aceita push (adequado para workloads efêmeros como agentes)
- Prometheus scrape Pushgateway = dados consultáveis
- Mais simples que debugar ingester do Loki
- Stack OTel já tem exporter para Prometheus (via OTel collector ou direto)

**Arquitetura proposta:**

```
AGENTE LOCAL (claude_otel_wrapper.py)
         │
         ├── Push Loki (atual)  ──→ VPS Loki (broken)
         │
         └── Push Prometheus   ──→ VPS Pushgateway:9091 ──→ Prometheus:9090 ──→ Grafana
```

**Duas opções de implementação:**

#### Opção A: Prometheus Pushgateway (Recomendada)

Modificar `claude_otel_wrapper.py` para:
1. Manter push para Loki (tentativa)
2. Se Loki falhar 3x consecutivas → fallback para Prometheus Pushgateway
3. Pushgateway recebe metrics e Prometheus faz scrape

**Endpoints:**
- Pushgateway: `http://187.108.197.199:9091`
- Prometheus scrape: `http://187.108.197.199:9090`

**Métricas a pushar:**
```
# Agent metrics
hermes_agent_errors_total{agent="claude", type="error"}
hermes_agent_tokens_total{agent="claude"}
hermes_agent_sessions_total{agent="claude", status="complete|fail"}

# DEVORQ metrics
devorq_gates_passed_total{gate="1"|"2"|...}
devorq_lessons_captured_total
devorq_build_duration_seconds
```

#### Opção B: Corrigir Loki ingester

Debugar e corrigir o ingester do Loki:
1. Ver logs do Loki (container ou systemd)
2. Verificar permissões de storage
3. Resetar WAL/chunks
4. Validar configuração de ingester

**Desvantagem:** Mais complexo, mais tempo, root cause pode não ser clara.

### Solução Recomendada: Opção A (Prometheus Pushgateway)

**Fases:**

**Fase 2.1 — Diagnóstico e Configuração Pushgateway**
- Verificar se Pushgateway está rodando no VPS
- Configurar Prometheus para scrape Pushgateway (se ainda não configurado)
- Identificar porta e endpoint do Pushgateway
- Testar conectividadelocal → VPS Pushgateway

**Fase 2.2 — Modificar Wrapper**
- Modificar `claude_otel_wrapper.py`:
  - Adicionar Prometheus Pushgateway como fallback
  - Manter Loki como tentativa primária
  - Após 3 failures consecutivos de Loki → push para Prometheus Pushgateway
- Adicionar métricas de agente: errors, tokens, sessions, gates

**Fase 2.3 — Dashboard Grafana**
- Criar dashboard no Grafana para métricas do agente
- Painéis: errors rate, tokens/session, gates pass rate, lessons captured
- Dashboard ID 25255 (já existe — adicionar novos painéis)

**Fase 2.4 — Validação End-to-End**
- Executar `devorq build` e verificar métricas no Grafana
- Verificar que Pushgateway recebe dados
- Verificar que Prometheus faz scrape correto

### Critério de Sucesso

- Métricas do agente aparecem no Grafana (dash Grafana Cloud ID 25255)
- Query `hermes_agent_errors_total` retorna dados
- Dashboards mostram dados de sessões recentes
- Loki permanece configurado (não removido) — fallback

### Arquivos a Modificar

```
/home/nandodev/claude_otel_wrapper.py         (adicionar Prometheus fallback)
/home/nandodev/.hermes/skills/devorq/devorq-observability/references/grafana-loki-fixes.md
~/.hermes/config.yaml                          (se precisar adicionar config de Pushgateway)
```

---

## Plano de Execução

### Ordem de Execução

```
DEFICIT 1 (SPEC) primeiro — menor esforço, resultado rápido
         ↓
DEFICIT 2 (Observabilidade) — maior esforço, resultado mais impactante
```

### Deficit 1 — Estimativa: 30 minutos

| Fase | Ação | Saída |
|------|------|-------|
| 1.1 | Atualizar `docs/DEVORQ-COMMIT-VISUAL-SPEC.md` | Status = IMPLEMENTADO v3.6.5 |
| 1.2 | Documentar features implementadas na SPEC | Seção histórico completa |
| 1.3 | Adicionar entrada `[3.6.7]` no CHANGELOG.md | CHANGELOG completo |
| 1.4 | Criar lição: "doc desactualizada erode credibilidade" | Lesson capturada |
| 1.5 | Verificar `devorq build` + shellcheck | 7/7 gates + 0 errors |

### Deficit 2 — Estimativa: 2-4 horas

| Fase | Ação | Saída |
|------|------|-------|
| 2.1 | Verificar Pushgateway no VPS | Lista de serviços rodando |
| 2.2 | Configurar Prometheus scrape Pushgateway | scrape_config adicionado |
| 2.3 | Modificar `claude_otel_wrapper.py` | Wrapper com Prometheus fallback |
| 2.4 | Adicionar métricas de agente | hero metrics + devorq metrics |
| 2.5 | Criar/editar dashboard Grafana | Painéis com dados reais |
| 2.6 | Teste end-to-end | Dashboards mostrando dados |
| 2.7 | Documentar solução na skill | `grafana-loki-fixes.md` atualizado |

---

## Riscos e Mitigações

| Risco | Probabilidade | Mitigação |
|-------|--------------|-----------|
| Pushgateway não está configurado no VPS | Média | Pré-verificar antes de modificar wrapper |
| Prometheus scrape não funciona | Baixa | Loki ainda existe como fallback |
| Modificar wrapper quebra wrapper atual | Baixa | Testar localmente antes de fazer push |
| Dashboard toma tempo demais | Média | Limitar a 3-4 painéis essenciais |

---

## Recursos Necessários

| Recurso | Onde |
|---------|------|
| Pushgateway endpoint | VPS 187.108.197.199:9091 |
| Acesso SSH ao VPS | `ssh -p 6985 root@187.108.197.199` |
| Grafana Cloud ID 25255 | grafana.fssdev.com.br:3002 |
| Wrapper script | `/home/nandodev/claude_otel_wrapper.py` |
| Skill observabilidade | `~/.hermes/skills/devorq/devorq-observability/` |

---

## Não Incluído Neste Plano

- Alterar arquitetura DEVORQ (sistema de gates, AUTO mode, etc.)
- Criar nova skill fora do escopo
- Modificar banco PostgreSQL do HUB
- Deploy de novos containers no VPS

---

## Validação

Este plano deve ser validado pelo Nando antes de qualquer execução. Ao validar, confirmar:
1. Ordem de execução (Deficit 1 primeiro ou ambos juntos?)
2. Opção A (Prometheus Pushgateway) vs Opção B (corrigir Loki) para Deficit 2
3. Se devorq build pode ser executado durante as mudanças (para validar成果)