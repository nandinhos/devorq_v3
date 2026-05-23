# Exemplos — Disciplina do Agente (DEVORQ)

Casos práticos para o framework bash DEVORQ. Inspirado em [Karpathy EXAMPLES](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/EXAMPLES.md), adaptado.

---

## 1. Assumptions silenciosas → perguntar

**Pedido:** "Adiciona export de lessons para o HUB"

**Errado:** Implementar sync VPS + JSON + CSV sem perguntar formato.

**Certo:**
```
Antes de implementar, preciso clarificar:
1. Destino: HUB PostgreSQL, arquivo local, ou API?
2. Escopo: todas as lessons ou só approved?
3. Formato: JSON bruto ou skill compilada?

Proposta mínima: devorq lessons list approved → stdout JSON
Verificar: jq . output | devorq lessons validate
```

---

## 2. Over-engineering → simplicidade

**Pedido:** "Adiciona flag --dry-run no devorq commit"

**Errado:** Criar lib/commands/commit/dry-run.sh, config JSON, 3 helpers.

**Certo:** Uma variável `dry_run=false` + `if [[ "$dry_run" == true ]]; then echo preview; return 0; fi` em `lib/commit.sh`.

**Verificar:** `devorq commit --dry-run --story feat-001` imprime mensagem sem commitar.

---

## 3. Diff cirúrgico

**Pedido:** "Corrige exit code do GATE-2 quando devorq test falha"

**Errado:** Reformatar `lib/gates.sh`, renomear funções, adicionar type hints em comentários.

**Certo:** Uma linha: `return 1` após `gate::fail` onde faltava.

**Verificar:** `bash scripts/unit-tests.sh` — teste GATE-2 ainda passa.

---

## 4. Meta verificável

**Pedido:** "Conserta o devorq build"

**Errado:** "Vou revisar e melhorar o build."

**Certo:**
```
Plano:
1. Reproduzir: devorq build → capturar erro → verify: log mostra módulo ausente
2. Fix: source test.sh em cmd_build → verify: devorq build exit 0
3. Regressão: bash scripts/ci-test.sh → verify: 43/43
```

Preencher em `context.json`:
```json
"success_criteria": [
  "devorq build retorna exit 0",
  "scripts/ci-test.sh 43/43 pass"
]
```
