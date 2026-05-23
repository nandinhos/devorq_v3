# Disciplina do Agente — DEVORQ v3.8+

**Objetivo:** Reduzir erros comuns de LLM em coding — assumptions silenciosas, over-engineering, diffs inflados, tarefas vagas.

**Inspirado em:** [Karpathy Guidelines](https://github.com/multica-ai/andrej-karpathy-skills) — adaptado ao fluxo DEVORQ.

**Tradeoff:** Cautela > velocidade. Tarefas triviais (typo, fix óbvio, <5min) → usar julgamento, pular formalismos.

---

## 1. Pensar Antes de Codar

**Não assumir. Não esconder confusão. Mostrar trade-offs.**

Antes de implementar:
- Explicitar assumptions. Se incerto → **perguntar**.
- Se houver 2+ interpretações → **apresentar**, não escolher em silêncio.
- Se existir abordagem mais simples → **dizer**. Push back quando fizer sentido.
- Se algo estiver unclear → **parar**, nomear o que confunde, perguntar.

**DEVORQ:** Use `devorq grill` para trade-offs complexos. Use `devorq scope --lite` antes de features novas.

---

## 2. Simplicidade Primeiro

**Mínimo código que resolve o problema. Nada especulativo.**

- Sem features além do pedido.
- Sem abstrações para código de uso único.
- Sem "flexibilidade" ou config extra não solicitada.
- Sem error handling para cenários impossíveis.
- Se escreveu 200 linhas e 50 bastam → reescrever.

**Teste:** Um senior diria "overcomplicated"? Se sim → simplificar.

**DEVORQ:** `scope-guard` (whitelist FAZER/NÃO FAZER) para features. Fixes triviais → isentos.

---

## 3. Mudanças Cirúrgicas

**Tocar só o necessário. Limpar só a própria bagunça.**

Ao editar código existente:
- Não "melhorar" código adjacente, comentários ou formatação.
- Não refatorar o que não está quebrado.
- Seguir estilo existente, mesmo que faria diferente.
- Dead code pré-existente → **mencionar**, não deletar (salvo se pedido).

Quando suas mudanças criam órfãos:
- Remover imports/variáveis/funções que **suas** mudanças tornaram unused.
- Não remover dead code pré-existente sem pedido explícito.

**Teste:** Cada linha alterada rastreia diretamente ao pedido do usuário.

**DEVORQ:** `manual-commit` exige aprovação humana antes de commit/push.

---

## 4. Execução Orientada a Metas

**Definir critérios de sucesso. Loop até verificar.**

Transformar tarefas em metas verificáveis:
- "Adicionar validação" → "Escrever testes para inputs inválidos, depois fazer passar"
- "Corrigir bug" → "Teste que reproduz → fix → teste verde"
- "Refatorar X" → "Testes passam antes e depois"

Para tarefas multi-step, plano breve:
```
1. [Passo] → verificar: [check]
2. [Passo] → verificar: [check]
```

**DEVORQ:** Preencher `success_criteria` em `.devorq/state/context.json`. Gates 1–7 + `devorq verify` fecham o loop.

---

## Quando esta regra está funcionando

- Diffs menores e focados
- Menos rewrites por overcomplication
- Perguntas de clarificação **antes** da implementação, não depois dos erros
