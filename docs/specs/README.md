# 📐 SPECs DEVORQ v3

> **Convencao:** Cada sprint que produz decisoes de design persistentes gera uma SPEC em `docs/specs/YYYY-MM-DD-<slug>.md`. A SPEC e' a fonte canonica do que foi decidido, e o CHANGELOG e' a fonte canonica do que foi implementado.

---

## Indice de SPECs

| Data | Slug | Status | Cobertura |
|------|------|--------|-----------|
| 2026-06-05 | `v3.8.5-dogfooding` | ✅ IMPLEMENTADO (v3.8.5) | 5 stories: E2E revival 100% (77/77), refactor bin/devorq 1503→180 LOC, refactor lib/lessons.sh 1045→96 LOC + 4 modulos, sync-version.sh, close v3.8.4 cycle |
| 2026-06-02 | `code-review-corrections` | ✅ IMPLEMENTADO (v3.8.4) | 4 stories: fix-sec-001 (whitelist SSH), fix-rules-002 (escopo release), docs-extras-003 (remove self-patch), docs-spec-004 (gates 7→10) |
| 2026-06-02 | `prd-2026-06-02.json` | ✅ DERIVADO | PRD gerado por `prd-from-spec.sh` para o loop auto story-by-story |

---

## Template de SPEC

Toda SPEC DEVE seguir este template minimo:

```markdown
# SPEC: <titulo-descritivo>

> **Versao alvo:** vX.Y.Z
> **Branch:** `feature/<slug>` ou `fix/<slug>`
> **Origem:** <code review X, feedback Y, demanda Z>
> **Data:** YYYY-MM-DD
> **Status:** RASCUNHO | AGUARDANDO VALIDACAO | IMPLEMENTADO | CANCELADO

## Contexto
<por que essa SPEC existe, qual problema resolve>

## Decisoes de Design (validadas com usuario)
| # | Topico | Decisao | Justificativa |

## Principios desta SPEC
<regras que limitam escopo — ex: "sem inventar features">

## Stories
### <story-id>: <titulo>
**Arquivos:** <lista>
**Escopo do commit:** <escopo>
**Fase:** <fase>
**Dependencias:** <nenhuma | story X>
**Acceptance criteria:**
- [ ] AC-1
- [ ] AC-2
**Fora do escopo:**
- <o que NAO fazer>

## Resumo de esforco
| Story | Arquivos | LOC | Risco |

## Validacao pre-commit
<comandos exatos para validar antes de commitar>

## O que NAO esta nesta SPEC (declarado explicitamente)
<itens fora de escopo, declarados para evitar escopo creep>

## Riscos e mitigacoes
| Risco | Mitigacao |

## Aprovacao
- [ ] Nando aprovou <story-id>
```

---

## Workflow de uma SPEC

```
1. Demanda/issue identificada (code review, feedback, sprint planning)
         |
         v
2. Criar docs/specs/YYYY-MM-DD-<slug>.md (status: RASCUNHO)
         |
         v
3. Martelar decisoes de design com Nando (decisao por decisao)
         |
         v
4. Marcar decisoes validadas na secao "Decisoes de Design"
         |
         v
5. Implementar stories atomicamente (1 commit por story ou agrupado)
         |
         v
6. Code review (codex CLI para sprints cirurgicos, multi-agente para >200 LOC)
         |
         v
7. Atualizar CHANGELOG.md com entrada da versao + cross-ref a SPEC
         |
         v
8. Status da SPEC: RASCUNHO -> IMPLEMENTADO
```

---

## Cross-references

- **Regras de code review:** `docs/DEVORQ-RULES-CODE-REVIEW.md`
- **Conveção de commits:** `docs/DEVORQ-COMMIT-VISUAL-SPEC.md`
- **Skill que automatiza parte do workflow:** `devorq-auto` (gera `prd.json` da SPEC e roda loop story-by-story)
- **Indice geral de docs:** `docs/README.md`
