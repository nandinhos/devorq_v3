---
name: grill-with-docs
description: >
  DEVORQ-GRILL v1.0.0 — Skill de sparring terminológico para DEVORQ v3.6.2.
  Valida o plano contra o glossário existente (CONTEXT.md), detecta
  contradições código vs plano, e cria ADRs quando decisões qualificam.
  Integrada ao GATE-0 como passo não-bloqueante com BREAK/warn forte.
  Use quando: intent contém "implementar/criar/adicionar/feature"
  E projeto tem CONTEXT.md ou código fonte.
version: 1.0.0
author: Fernando Dos Santos (Nando)
license: MIT
metadata:
  hermes:
    tags: [devorq, grill, terminology, context, adr, domain-language]
    related_skills: [devorq, devorq-mode, ddd-deep-domain, scope-guard]
    devorq:
      gate: 0
      type: validation
      mode: [auto, classic]
      blocking: false
  stack: [bash, jq]
triggers:
  intent_keywords: [implementar, criar, adicionar, feature, novo módulo, domínio]
  context_files: [CONTEXT.md, CONTEXT-MAP.md]
  skip_keywords: [bug, fix, corrigir, typo, erro, hotfix, debug]
---

# DEVORQ-GRILL v1.0.0

## Visão Geral

**Princípio:** *"Terminologia vaga é a raiz de todo mal no código."*

**Problema resolvido:** SPEC.md com termos vagos ("customer", "account", "order") que significam coisas diferentes em contextos diferentes. Código que contradiz o plano sem ninguém perceber. Decisões arquiteturais perdidas. O grill-with-docs faz sparring terminológico questão por questão, validando contra o glossário existente e o código real.

## Quando Carrega

**Trigger duplo (ambos devem ser verdade):**

1. Intent contém keywords de feature:
   - `implementar`, `criar`, `adicionar`, `feature`, `novo módulo`, `domínio`

2. Uma das seguintes condições:
   - `CONTEXT.md` existe em `$PROJECT_ROOT/`
   - `CONTEXT-MAP.md` existe em `$PROJECT_ROOT/`
   - Diretório `src/` existe (infere multi-contexto)

## Quando NÃO Carrega

- Intent contém skip_keywords: `bug`, `fix`, `corrigir`, `typo`, `erro`, `hotfix`, `debug`
- Comandos: `devorq init`, `devorq lessons`, `devorq compact`, `devorq sync`, `devorq version`, `devorq stats`, `devorq test`
- AUTO mode dentro do loop story-by-story (só entre sprints)

## Fluxo Interno — 4 Fases

### Fase 1: Domain Awareness (automática)

Executada pelo `grill-detect.sh` — coleta contexto sem bloquear:

1. Detecta `CONTEXT.md` e `CONTEXT-MAP.md`
2. Lista ADRs existentes em `docs/adr/`
3. Extrai termos do INTENT e da SPEC.md
4. Verifica se termos do INTENT existem no glossário
5. Emite BREAK/warn forte com recomendação

**Output:** Relatório de detecção com status de cada arquivo

### Fase 2: Context Initialization (se CONTEXT.md não existe)

Executada pelo `grill-init-context.sh`:

1. Extrai termos candidatos do INTENT
2. Extrai termos da SPEC.md (se existir)
3. Extrai termos do código existente (Models, tabelas, classes)
4. Gera template com `[PLACEHOLDER]` para cada termo não-resolvido
5. NÃO escreve nada sem confirmação do orquestrador

**Critérios de extração:**
- Termos candidatos: substantivos do domínio (não variáveis, não código)
- Zero hallucination: só extrai o que existe de fato
- Se nada encontrado: gera header com instrução "adicione termos manualmente"

### Fase 3: Refinamento Interativo (orquestrador-guided)

Executada pelo `grill-refine.sh` — sessão 1-a-1:

1. Para cada `[PLACEHOLDER]` no template:
   - Orquestrador questiona: "O que significa [TERMO] neste contexto?"
   - Usuário responde ou refina
   - Definição afiada substituída no template
2. Termos resolvidos são confirmados
3. Novos termos podem ser adicionados
4. Quando todos placeholders resolvidos: CONTEXT.md confirmado

**Regras do refinamento:**
- `CONTEXT.md` é glossário PURO — nada de implementação
- Definição: uma frase, o que É, não o que faz
- Mostrar relationships entre termos (cardinalidade quando óbvio)
- "Avoid" list: termos que NÃO devem ser usados para esse conceito

### Fase 4: ADR Evaluation (sempre após fase 3)

Executada pelo `grill-suggest-adr.sh` para cada decisão detectada:

**Só cria ADR se TODAS as 3 condições forem true:**

1. **Hard to reverse** — custo de mudar depois é significativo
2. **Surprising without context** — leitor futuro ia perguntar "por quê?"
3. **Real trade-off** — havia alternativas concretas e uma foi escolhida por razões

**Exemplos de decisões que QUALIFY:**
- "Usar Stripe em vez de Pagar.me" (mudar = re-implementar webhook inteiro)
- "Event-sourcing para Orders" (surprising — leitor esperaria CRUD)
- "Tabela orders sem foreign key pro user" (trade-off consciente)
- "Monorepo com contextos delimitados" (hard to reverse)

**Exemplos de decisões que NÃO QUALIFY:**
- "Usar Bootstrap vs Tailwind" (fácil reverter)
- "Nome da variável `userId` vs `uid`" (óbvio)
- "Usar PHP 8.2" (não é decisão de domínio)

---

## Formato CONTEXT.md

Ver `references/CONTEXT-FORMAT.md` para especificação completa.

**Estrutura mínima:**

```markdown
# {Nome do Contexto}

{Uma ou duas frases descrevendo o que é e por que existe.}

## Language

**{Termo}**:
{Definição concisa do termo.}
_Avoid_: {aliases a evitar}

## Relationships

- Um **{A}** pertence a exatamente um **{B}**
- Um **{A}** produz um ou mais **{C}**

## Flagged Ambiguities

- "{termo vago}" foi usado para significar X e Y — resolvido: estes são conceitos distintos.
```

---

## Formato ADR

Ver `references/ADR-FORMAT.md` para especificação completa.

**Estrutura mínima:**

```markdown
# {Título curto da decisão}

{1-3 parágrafos: contexto, o que decidimos, e por quê.}
```

**Numeração:** `000N-slug.md` (scan `docs/adr/` → highest 000N → next = 000(N+1))

---

## Integração com DEVORQ Flow

### GATE-0 (gate_0 em lib/gates.sh)

```bash
# === GATE-0 — grill-with-docs (OPCIONAL, pós DDD) ===
# Não-bloqueante com BREAK/warn forte
# Roda APÓS env-context e DDD
# Executado pelo agente (não bloqueia fluxo do devorq flow)

if ! echo "$intent" | grep -qiE "bug|fix|corrigir|typo|erro|hotfix|debug|init|lessons|compact|sync|version|stats|test"; then
    if echo "$intent" | grep -qiE "implementar|criar|adicionar|feature|novo|domínio"; then
        local grill_script="${DEVORQ_ROOT}/skills/grill-with-docs/scripts/grill-detect.sh"
        if [ -f "$grill_script" ]; then
            gate::info 0 "grill-with-docs: verificando contexto..."
            bash "$grill_script" "${PWD}" "$intent" 2>&1 || true
        fi
    fi
fi
```

### AUTO Mode — Entre Sprints

```
SPRINT N concluída
         │
         │  Nova SPEC.md existe (próxima feature)
         │  devorq auto --continue (pré-sprint)
         │
         ▼
    grill-detect.sh em modo "pré-sprint"
         │
         ▼
    Se CONTEXT.md desatualizado vs nova SPEC:
         │
         ▼
    BREAK: "Encontrados N problemas terminológicos."
         │
         ▼
    grill-refine.sh: sessão interativa
         │
         ▼
    CONTEXT.md atualizado + ADRs criados
         │
         ▼
    prd-from-spec.sh → novo prd.json
         │
         ▼
    loop-auto.sh recomeça
```

---

## Arquitetura de Arquivos

```
skills/grill-with-docs/
├── SKILL.md                           # Esta skill
├── scripts/
│   ├── grill-detect.sh                # Fase 1: detecção + BREAK
│   ├── grill-init-context.sh          # Fase 2: template inicial
│   ├── grill-refine.sh                # Fase 3: refinamento 1-a-1
│   ├── grill-suggest-adr.sh           # Fase 4: avaliar ADR
│   └── grill-create-adr.sh            # Fase 4: criar ADR
└── references/
    ├── CONTEXT-FORMAT.md              # Formato do glossário
    └── ADR-FORMAT.md                  # Formato do ADR
```

---

## Exit Codes

| Code | Significado |
|------|-------------|
| 0 | Grill executado com sucesso |
| 1 | Skip (sem CONTEXT.md E sem código, intent=bugfix, etc.) |
| 2 | Erro de usage |
| 3 | Template não pôde ser gerado |

---

## Dependências

```bash
bash 5+      # Execução principal
jq 1.7+      # Parsing de JSON (opcional — fallback sem jq)
git          # Repo detection
```

---

## Versão

**v1.0.0** — 2026-05-18
**Autor:** Fernando Dos Santos (Nando)
**Integração:** DEVORQ v3.6.2 — GATE-0 (não-bloqueante)
