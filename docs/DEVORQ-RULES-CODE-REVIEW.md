# DEVORQ — Code Review: Rules System Investigation

**Data:** 2026-05-21
**Versão DEVORQ:** 3.6.5
**Escopo:** Análise do sistema de rules e sua aplicação no fluxo

---

## Problema Relatado

Nando percebeu que "as definições que deixamos claro no projeto não estão sendo colocadas em prática ou não estão sendo usadas em determinados momentos".

---

## Análise — Code Review Completo

### 1. O que existe em `rules/`

| Regra | Arquivo | Conteúdo | Status |
|-------|---------|----------|--------|
| Commit Convention | `rules/commit-convention.md` | Formato `escopo(fase): descrição (detalhamento)` | ✅ Criado |
| Visual Verification | `rules/visual-verification.md` | Gate de verificação visual + systematic-debugging | ✅ Criado |
| Brainstorm | `rules/brainstorm.md` | Gates de captura durante brainstorm | ✅ Criado |
| Grill | `rules/grill.md` | Regras de sparring | ✅ Criado |
| Índice | `rules/README.md` | Hierarquia e como sobrescrever | ✅ Criado |

**Total: 5 arquivos em `rules/`**

---

### 2. Onde as regras DEVEMIAM ser aplicadas

| Regra | Momento esperado | Implementado? | Funcionando? |
|-------|-----------------|---------------|-------------|
| `commit-convention` | Antes de `git commit` | ❌ NÃO | ❌ NÃO |
| `visual-verification` | Após `devorq build`, antes do commit | ⚠️ Parcial | ⚠️ Parcial |
| `brainstorm` | Ao iniciar `devorq brainstorm` | ❌ NÃO EXISTE | ❌ NÃO |
| `grill` | Ao iniciar `devorq grill` | ❌ NÃO EXISTE | ❌ NÃO |

---

### 3. O que ESTÁ funcionando (e onde)

#### ✅ O que funciona:

**`lib/commit.sh` — Validação de commit**
- `VALID_SCOPES` e `VALID_PHASES` existem como arrays bash
- `devorq::commit::interactive()` valida escopo e fase
- `devorq::commit::from_story()` gera commit válido

**`lib/visual.sh` — Verificação visual**
- `devorq::verify::run()` executa gates + verificação
- `devorq verify --playwright` e `devorq verify --manual`
- Trigger de systematic-debugging quando falha

**`lib/auto.sh` — Fluxo AUTO com verificação**
- Após implementar, chama `devorq::verify::run()`
- Pausa para commit manual
- Não commita automaticamente mais

---

### 4. O que NÃO funciona — Problemas Encontrados

#### PROBLEMA 1: `rules/` não é carregado em nenhum lugar

**Sintoma:** Os arquivos em `rules/` existem mas nunca são lidos ou aplicados.

**Causa:** Não existe nenhuma função `devorq::rules::load()` ou equivalente no bin/devorq.

**Onde deveria estar:** No bootstrap do `bin/devorq` (após carregar libs), antes dos comandos.

**Impacto:**
- `rules/commit-convention.md` existe mas não é usado para validar mensagens
- `rules/visual-verification.md` existe mas não é referenciado por `lib/visual.sh`
- `rules/brainstorm.md` e `rules/grill.md` referenciam comandos que não existem (`devorq brainstorm`, `devorq grill`)

---

#### PROBLEMA 2: Commit validation existe mas não é aplicado automaticamente

**Sintoma:** `lib/commit.sh` tem `VALID_SCOPES` e `VALID_PHASES` mas não é chamado automaticamente por nenhum gate.

**Causa:** `devorq::auto::git_commit()` foi removido, mas não há replacement que use a validação.

**Fluxo atual:**
```
devorq auto → implementa → devorq build → devorq verify (manual) → devorq commit --story
```

Quando usuário executa `devorq commit --story feat-001`, a validação de escopo/fase funciona. MAS:
- Se usuário faz `git commit` direto (sem `devorq commit`), não há validação
- Não há pre-commit hook
- Não há gate que impeça commit sem `devorq commit`

---

#### PROBLEMA 3: Comandos `brainstorm` e `grill` não existem

**Sintoma:** `rules/brainstorm.md` e `rules/grill.md` documentam gatilhos para `devorq brainstorm` e `devorq grill`, mas esses comandos não estão no `bin/devorq`.

**Causa:** Os arquivos foram criados como "regras" mas os comandos correspondentes nunca foram implementados.

**Impacto:** As regras de brainstorm/grill são pura documentação — não têm efeito prático.

---

#### PROBLEMA 4: `rules/visual-verification.md` não é referenciado

**Sintoma:** `rules/visual-verification.md` documenta o fluxo completo de verificação visual, mas `lib/visual.sh` não faz referência a ele.

**Causa:** `lib/visual.sh` foi criado de forma independiente, sem ler `rules/visual-verification.md`.

---

#### PROBLEMA 5: `.devorq/rules/` local nunca é carregado

**Sintoma:** `rules/README.md` diz que projeto pode sobrescrever regras com `.devorq/rules/<nome>.md`, mas não existe mecanismo de carregamento.

**Causa:** Hierarquia global > local documentada mas não implementada.

---

### 5. Fluxo atual vs Fluxo esperado

#### Fluxo atual (parcial):

```
devorq auto
    → implementa
    → devorq build (gates 1-7)
    → devorq verify (Playwright ou manual)
    → devorq commit --story <id> (valida se调用 devorq commit)
    → git commit (sem validação extra)
```

#### Fluxo esperado (regras aplicadas):

```
devorq auto
    → implementa
    → devorq build (gates 1-7)
    → devorq verify (Playwright ou manual)
    → devorq commit (valida escopo/fase contra rules/commit-convention.md)
    → git commit (pre-commit hook valida formato)
    → mark_pass
```

---

## Diagnóstico Final

### O que está funcionando ✅

1. `devorq commit` — validação de escopo/fase quando usado
2. `devorq verify` — verificação visual (Playwright + manual)
3. `systematic-debugging trigger` — quando teste falha
4. `rules/` directory — estrutura existe com documentação

### O que NÃO está funcionando ❌

1. **`devorq rules` — comando não existe**
   - Não há como listar, validar ou aplicar regras

2. **`rules/` não é carregado automaticamente**
   - Arquivos existem mas nunca são lidos pelo sistema

3. **Commit sem `devorq commit` ignora convenção**
   - `git commit` direto bypassa toda validação

4. **Comandos `brainstorm` e `grill` não existem**
   - Regras documentadas mas não implementadas

5. **Hierarquia global > local não funciona**
   - `.devorq/rules/` não é carregado

---

## Recomendações de Correção

### Prioridade ALTA

1. **Criar `devorq rules` comando** — lista e aplica regras
2. **Criar `devorq::rules::load()` — carrega rules/ no bootstrap
3. **Criar pre-commit hook** — valida commits contra convenção
4. **Implementar `devorq brainstorm`** — ou remover rules/brainstorm.md

### Prioridade MÉDIA

5. **Implementar `devorq grill`** — ou remover rules/grill.md
6. **Adicionar referência a `rules/` em `lib/visual.sh`**
7. **Adicionar referência a `rules/` em `lib/commit.sh`**

### Prioridade BAIXA

8. **Implementar hierarquia global > local** — carregar .devorq/rules/ após global

---

## Métricas

| Item | Valor |
|------|-------|
| Arquivos em `rules/` | 5 |
| Regras com implementação de comando | 0 |
| Comandos mencionados em regras que existem | 0/2 |
| Validação de commit aplicada automaticamente | ❌ NÃO |

---

*Análise concluída em 2026-05-21*