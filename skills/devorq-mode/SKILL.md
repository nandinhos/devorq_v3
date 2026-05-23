---
name: devorq-mode
description: Seletor de modo DEVORQ — AUTO (story-by-story autonomo via delegate_task) ou CLASSIC (gates 1-7 manuais). Pergunta automaticamente quando o usuario inicia um flow DEVORQ sem especificar modo.
version: 1.0.0
author: Fernando Dos Santos (Nando)
license: MIT
metadata:
  hermes:
    tags: [devorq, mode-selector, auto, classic, flow]
    related_skills: [devorq, devorq-auto, systematic-debugging]
---

# DEVORQ-MODE v1.0.0

## Proposito

Quando o usuario inicia um fluxo DEVORQ sem especificar modo, este skill toma a frente e pergunta: **AUTO ou CLASSIC?**

- **AUTO**: story-by-story via `delegate_task` (recomendado para features grandes/medias)
- **CLASSIC**: gates 1-7 manuais, implementacao direta (recomendado para tasks pequenas/rapidas)

## Fluxo

```
Usuario: "vamos implementar a feature de CPF"
          |
[1] DETECT: project root, SPEC.md, intent
[2] ASK:
    ┌─────────────────────────────────────────┐
    │ ⚡ DEVORQ MODE                          │
    │                                          │
    │ Como quer implementar?                   │
    │                                          │
    │  [1] 🤖 AUTO — story por story          │
    │  [2] 📝 CLASSIC — gates 1-7 direto      │
    │  [3] 🚀 AUTO [N] stories                │
    └─────────────────────────────────────────┘
[3] BRANCH:
    AUTO  → devorq-auto skill + loop-auto.sh
    CLASSIC → devorq gates 1-7 tradicionais
```

## Scripts

| Script | Descricao |
|--------|-----------|
| `mode-selector.sh` | Detecta modo via keywords e exibe menu |
| `loop-auto.sh` | Loop principal AUTO (delegate_task story-by-story) |
| `check-story.sh` | Gate de verificacao por story |
| `prd-from-spec.sh` | Gera prd.json do SPEC.md |

## Keywords

**AUTO**: `auto`, `autonomous`, `ralph`, `story-by-story`, `modo auto`
**CLASSIC**: `classic`, `manual`, `tradicional`, `direto`, `modo classic`

---

**Versao:** 1.0.0
**Criado em:** 2026-04-23
**Autor:** Fernando Dos Santos (Nando)
