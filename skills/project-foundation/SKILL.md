---
name: project-foundation
description: >
  DEVORQ-PF v1.0.0 — Documentação estruturada de projeto (5W2H, Premissas, Riscos,
  Requisitos, Restrições). Cria e valida arquivos persistentes em .devorq/state/.
  Integra com GATE-0.5 como pré-requisito para qualquer implementação.
version: 1.0.0
author: Fernando Dos Santos (Nando)
license: MIT
metadata:
  devorq:
    gate: 0.5
    type: foundation
    mode: [auto, classic]
  stack: [bash, jq]
---

# DEVORQ-PROJECT-FOUNDATION v1.0.0

## Visão Geral

**Princípio:** *"Sem contexto de projeto = sem implementação."*

**Problema resolvido:** Documentação de projeto tradicionalmente existe só em prompts e contexto — não persiste, não é validada, e não comunica escopo/premissas/riscos para o próximo agente ou sessão.

**Solução:** 5 documentos JSON persistentes em `.devorq/state/` que formalizam o contexto de projeto antes de qualquer gate de implementação.

## Os 5 Documentos

| Doc | Propósito | Gate |
|-----|-----------|------|
| `5w2h.json` | Análise 5W2H completa | GATE-0.5 |
| `premissas.json` | Premissas e suposições | GATE-0.5 |
| `riscos.json` | Riscos com severidade e mitigação | GATE-0.5 |
| `requisitos.json` | Requisitos funcionais/não-funcionais | GATE-0.5 |
| `restricoes.json` | Restrições do projeto | GATE-0.5 |

## Quando Usar

### Triggers (automático)
- `devorq init` — cria templates vazios
- `devorq flow "<intent>"` — GATE-0.5 valida antes de prosseguir
- `devorq foundation create` — wizard interativo

### Triggers manuais
- `devorq foundation validate` — valida sem executar flow
- `devorq foundation edit <doc>` — edita doc específico

## Gate

- **GATE-0.5** (bloqueante, pré-GATE-1)
- Valida que todos os 5 foundation docs existem e têm conteúdo mínimo
- Roda DEPOIS de GATE-0 (exploration) e ANTES de GATE-1 (Spec exists)

## Arquitetura

```
[NOVO PROJETO / NOVA SESSÃO]
         │
         ▼ devorq init
    ┌────────────────────────────────┐
    │  .devorq/state/ criado        │
    │  + 5w2h.json (template)       │
    │  + premissas.json (template)  │
    │  + riscos.json (template)     │
    │  + requisitos.json (template)  │
    │  + restricoes.json (template) │
    └────────────────────────────────┘
         │
         ▼ devorq flow "implementar X"
    ┌───────────┐
    │  GATE-0   │ Exploration (opcional)
    └─────┬─────┘
         ▼
    ┌───────────┐
    │ GATE-0.5  │ Foundation docs válidos?
    └─────┬─────┘
         ▼
    ┌───────────┐
    │  GATE-1   │ Spec exists
    └───────────┘
```

## Comandos

```bash
devorq foundation              # Mostra status dos 5 docs
devorq foundation create       # Wizard interativo
devorq foundation validate     # Valida sem flow
devorq foundation edit <doc>   # Edita doc específico
devorq foundation migrate      # Migra de SPEC.md existente
```

## Schemas

### 5w2h.json
```json
{
  "project": "nome-do-projeto",
  "created_at": "2026-05-10T00:00:00Z",
  "updated_at": "2026-05-10T00:00:00Z",
  "what": {
    "description": "O que este projeto é — definição curta e precisa",
    "examples": ["exemplo1", "exemplo2"]
  },
  "why": {
    "description": "Por que este projeto existe — motivação e contexto",
    "business_value": "Qual valor de negócio isto entrega"
  },
  "who": {
    "description": "Para quem este projeto é — público-alvo principal",
    "stakeholders": ["stakeholder1", "stakeholder2"]
  },
  "when": {
    "description": "Quando este projeto é relevante — timeline e marcos",
    "timeline": "Q1 2026 - Q2 2026"
  },
  "where": {
    "description": "Onde este projeto se insere — contexto técnico e organizacional",
    "context": "Stack: Laravel 12 + Livewire 4"
  },
  "how": {
    "description": "Como este projeto será construído — abordagem metodológica",
    "approach": "BDD + TDD, gates bloqueantes"
  },
  "how_much": {
    "description": "Quanto isto custa/esforço — estimativas de custo e tempo",
    "estimated_effort": "8 semanas, 3 desenvolvedores"
  }
}
```

### premissas.json
```json
{
  "project": "nome-do-projeto",
  "created_at": "2026-05-10T00:00:00Z",
  "premissas": [
    {
      "id": "PRE-001",
      "description": "Premissa assumida como verdadeira para este projeto",
      "owner": "nome-do-responsavel",
      "validated": false,
      "validated_at": null,
      "notes": "Observações ou contexto adicional"
    }
  ]
}
```

### riscos.json
```json
{
  "project": "nome-do-projeto",
  "created_at": "2026-05-10T00:00:00Z",
  "riscos": [
    {
      "id": "RISK-001",
      "description": "Descrição do risco identificado",
      "severity": "HIGH",
      "probability": "MEDIUM",
      "impact": "HIGH",
      "mitigation": "Ação preventiva para reduzir probabilidade ou impacto",
      "contingency": "Plano B caso o risco se materialize",
      "status": "OPEN"
    }
  ]
}
```

### requisitos.json
```json
{
  "project": "nome-do-projeto",
  "created_at": "2026-05-10T00:00:00Z",
  "version": "1.0.0",
  "requisitos": [
    {
      "id": "REQ-001",
      "type": "FUNCTIONAL",
      "title": "Título breve do requisito",
      "description": "Descrição completa do requisito",
      "acceptance_criteria": [
        "Critério de aceite 1",
        "Critério de aceite 2"
      ],
      "priority": "MUST",
      "source": "Origem do requisito (stakeholder, regulação, etc)",
      "status": "DRAFT"
    }
  ]
}
```

### restricoes.json
```json
{
  "project": "nome-do-projeto",
  "created_at": "2026-05-10T00:00:00Z",
  "restricoes": [
    {
      "id": "CONST-001",
      "type": "TECHNICAL",
      "description": "Descrição da restrição identificada",
      "source": "Origem da restrição",
      "flexibility": "FIXED",
      "validated": false
    }
  ]
}
```

## Validação GATE-0.5

| Doc | Critério Mínimo |
|-----|----------------|
| `5w2h.json` | Todos os 7 campos (what/why/who/when/where/how/how_much) com `description` não-vazio |
| `premissas.json` | Array `premissas` com pelo menos 1 item |
| `riscos.json` | Array `riscos` com pelo menos 1 item, cada um com `severity` E `mitigation` |
| `requisitos.json` | Array `requisitos` com pelo menos 1 item com `acceptance_criteria` não-vazio |
| `restricoes.json` | Array `restricoes` com pelo menos 1 item |

## Variáveis de Ambiente

| Variável | Default | Descrição |
|----------|---------|----------|
| `DEVORQ_FOUNDATION_DIR` | `.devorq/state/` | Diretório onde os docs são salvos |
| `DEVORQ_BLOCKING_0_5` | `true` | Se `false`, GATE-0.5 não bloqueia |

## Integração com Gates

GATE-0.5 é **bloqueante** por padrão. Para pular em casos especiais:
```bash
DEVORQ_BLOCKING_0_5=false devorq flow "implementar X"
```
