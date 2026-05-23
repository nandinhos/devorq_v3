# Análise: Karpathy Guidelines × DEVORQ v3.7.2

**Branch:** `feature/karpathy-skills-analysis` → integrado em **v3.8.0**  
**Fonte:** [multica-ai/andrej-karpathy-skills — CLAUDE.md](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CLAUDE.md)  
**Objetivo:** Identificar o que agrega valor real ao DEVORQ **sem over-engineering**.

---

## 1. O que é o repositório Karpathy (em essência)

Não é um framework. É **um arquivo de ~60 linhas** com 4 princípios comportamentais para LLMs:

| # | Princípio | Problema que ataca |
|---|-----------|-------------------|
| 1 | Think Before Coding | Assumir em silêncio, não perguntar, não mostrar trade-offs |
| 2 | Simplicity First | Over-abstração, features especulativas, 200 linhas onde 50 bastam |
| 3 | Surgical Changes | Refatorar código adjacente, mudar estilo, "melhorar" fora do escopo |
| 4 | Goal-Driven Execution | Tarefas vagas ("conserta auth") sem critério verificável |

**Formato de entrega:** `CLAUDE.md` + `.cursor/rules/*.mdc` + `skills/karpathy-guidelines/SKILL.md` (mesmo conteúdo, 3 canais).

**Tradeoff explícito:** Cautela > velocidade. Tarefas triviais = usar julgamento.

---

## 2. Mapa DEVORQ ↔ Karpathy (o que já existe)

### Princípio 1 — Think Before Coding

| Karpathy pede | DEVORQ já tem | Gap |
|---------------|---------------|-----|
| Explicitar assumptions | `devorq grill`, `rules/grill.md` (trade-offs) | Grill é **opt-in**, não roda em todo task |
| Perguntar se ambíguo | `devorq brainstorm`, GATE-0.5 foundation | Pesado para fix rápido |
| Surface tradeoffs | `rules/grill.md`, `scope-guard` DONE_CRITERIA | Disperso em skills grandes |
| Stop se confuso | GATE-7 debug, manual-commit | Reativo (após erro), não preventivo |

**Veredito:** DEVORQ tem **infraestrutura profunda** mas falta **camada fina always-on** antes de codar.

---

### Princípio 2 — Simplicity First

| Karpathy pede | DEVORQ já tem | Gap |
|---------------|---------------|-----|
| Mínimo código | `scope-guard` — whitelist FAZER/NÃO FAZER | Só dispara em keywords (`implementar`, `criar`…) |
| Sem abstração especulativa | scope-guard bloqueia violação | 294 linhas de SKILL — ironia: guard pesado |
| "Senior diria overcomplicated?" | Lição D16 nos docs | Não enforced automaticamente |
| Exempt trivial tasks | scope-guard: skip fix/typo | ✅ Alinhado com Karpathy |

**Veredito:** **scope-guard é o irmão gêmeo** do Simplicity First — mas é gate opcional, não regra bootstrap.

---

### Princípio 3 — Surgical Changes

| Karpathy pede | DEVORQ já tem | Gap |
|---------------|---------------|-----|
| Só tocar o necessário | `manual-commit` (human approval) | Não instrui o **agente** sobre diff |
| Não refatorar adjacente | `devorq-code-review` fase 2 (5 dimensões) | Pipeline de 8 fases — overkill p/ todo commit |
| Mencionar dead code, não deletar | — | **Ausente** como regra explícita |
| Cada linha traceável ao pedido | scope-guard contrato | Só em features novas |

**Veredito:** Gap claro. DEVORQ controla **quando** commitar, não **como** editar.

---

### Princípio 4 — Goal-Driven Execution

| Karpathy pede | DEVORQ já tem | Gap |
|---------------|---------------|-----|
| Critérios verificáveis | Gates 1-7, `acceptance_criteria` em prd.json | ✅ **DEVORQ é mais forte aqui** |
| Test-first | check-story.sh, E2E Playwright, ci-test | ✅ |
| Plano com verify por step | loop-auto stories, prd.json | CLASSIC manual: menos formalizado |
| Loop até passar | devorq auto, gates bloqueantes | ✅ |

**Veredito:** DEVORQ **supera** Karpathy em execução verificável. Falta só o **ritual de abertura** (transformar pedido vago em critérios antes de codar).

---

## 3. Matriz de decisão — Adotar / Adaptar / Ignorar

| Item Karpathy | Recomendação | Esforço | Motivo |
|---------------|-------------|---------|--------|
| CLAUDE.md inteiro como dependência externa | **Ignorar** | — | DEVORQ deve ser self-contained |
| 4 princípios como `rules/agent-discipline.md` | **Adotar** | ~2h | Thin layer, bootstrap junto com commit-convention |
| `.cursor/rules/*.mdc` | **Adaptar** | ~1h | Opcional: `.cursor/rules/devorq-discipline.mdc` apontando p/ rules/ |
| SKILL.md duplicado | **Ignorar** | — | rules/ + bootstrap já cobrem |
| EXAMPLES.md (14KB) | **Adaptar** | ~3h | 4 exemplos **bash/DEVORQ** em PT, não copiar Python |
| Plugin marketplace | **Ignorar** | — | DEVORQ tem próprio `devorq rules` |
| Goal-driven templates | **Adaptar** | ~4h | Campo `success_criteria` em context.json / story |
| Novo GATE-8 | **Ignorar** | — | Over-engineering |
| scope-guard v2 | **Adaptar** | ~6h | Modo `--lite` (10 linhas) para tasks médias |
| code-review 8 fases p/ todo diff | **Ignorar** | — | Manter opt-in via `devorq review` |

---

## 4. Proposta mínima v3.8 (sem over-engineering)

### P0 — Regra bootstrap (impacto alto, custo baixo)

Criar `rules/agent-discipline.md` (~50 linhas):

```markdown
# Disciplina do Agente — DEVORQ (inspirado Karpathy, adaptado)

## Antes de codar
- Listar assumptions; se incerto → perguntar
- Se 2+ interpretações → apresentar, não escolher em silêncio

## Simplicidade
- Escopo = pedido do usuário. Nada especulativo.
- Tarefa trivial (<5min, typo, fix óbvio) → pular scope-guard

## Diff cirúrgico
- Cada linha alterada deve rastrear ao pedido
- Dead code pré-existente → mencionar, não deletar

## Critério de sucesso
- Transformar pedido vago em: "fazer X → verificar Y"
- Preferir: teste que reproduz → fix → teste verde
```

Integrar em `devorq rules bootstrap` (junto commit-convention + manual-commit).

### P1 — Success criteria no contexto (CLASSIC mode)

Estender template `context.json` do `devorq init`:

```json
{
  "intent": "",
  "success_criteria": [],
  "gates_completed": []
}
```

Gate-3 (`ctx_lint`) avisa se `intent` preenchido mas `success_criteria` vazio.

### P2 — scope-guard lite (opcional)

Não reescrever a skill. Adicionar flag:

```bash
devorq scope --lite "<intent>"
# Output: 5 linhas — FAZER / NÃO FAZER / VERIFICAR
```

Disparo automático só se `DEVORQ_SCOPE=lite` ou intent > N palavras.

### P3 — Exemplos DEVORQ (docs only)

`docs/EXEMPLOS-DISCIPLINA-AGENTE.md` — 4 casos reais do repo (bash CLI, não Python).

---

## 5. O que NÃO fazer (anti-patterns de integração)

1. **Não** criar skill `karpathy-guidelines/` espelhando o repo externo — duplica rules/
2. **Não** adicionar gate bloqueante para "assumptions checklist" — fricciona demais
3. **Não** mergear EXAMPLES.md inteiro — 14KB de Python irrelevante para framework bash
4. **Não** substituir scope-guard — complementar com regra leve
5. **Não** tornar code-review obrigatório — já é opt-in pesado por design

---

## 6. Sinergia com fluxo DEVORQ existente

```
[Sessão inicia]
    │
    ▼
rules/agent-discipline.md (always, via bootstrap)  ← NOVO P0
    │
    ├── intent trivial? → skip scope-guard
    │
    ├── feature nova? → scope-guard (existente)
    │
    ▼
GATE-0.5 foundation (se projeto novo)
GATE-1..7 (existente)
    │
    ▼
check-story / verify (existente)  ← já cobre Goal-Driven
    │
    ▼
manual-commit (existente)  ← human gate
```

Karpathy preenche o **vácuo entre "usuário pediu" e "gates técnicos"**.  
DEVORQ já domina **"gates técnicos → verificação → commit"**.

---

## 7. Conclusão

O repositório Karpathy é elogiado porque resolve **comportamento do LLM** com **simplicidade extrema** (1 arquivo).

O DEVORQ já é **mais robusto em verificação e processo** (gates, prd, E2E, lessons).  
O gap real não é infraestrutura — é **disciplina comportamental fina e always-on**.

**Melhor ROI:** `rules/agent-discipline.md` + bootstrap + `success_criteria` no context.  
**Total estimado:** ~1 dia de trabalho, zero novos gates, zero nova dependência externa.

---

## 8. Próximo passo sugerido

Implementar **P0 + P1** na branch `feature/karpathy-skills-analysis` → release **v3.8.0** com CHANGELOG enxuto.
