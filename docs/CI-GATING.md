# CI Gating — DEVORQ

Status atual dos workflows de CI e como promover o E2E a **required check**.

---

## Estado atual (v3.8.5)

| Workflow | Trigger | Bloqueia PR? | É required check? |
|----------|---------|--------------|-------------------|
| `ci.yml` (`CI`) | push + pull_request | ✅ via shellcheck `--severity=error` | Configurável (admin) |
| `e2e.yml` (`E2E`) | push + pull_request + merge_group + workflow_dispatch | ✅ via exit code do Playwright (≠0 em falha) | ❌ ainda NÃO |

**O que "bloqueia PR" significa:** o workflow roda no PR e, se falhar, o status check fica vermelho — mas só impede merge se o branch protection listar explicitamente esse check.

**O que "required check" significa:** o branch protection no GitHub Settings exige que o check passe antes do botão "Merge" ficar habilitado.

---

## Por que E2E ainda não é required check

Workflow está pronto e funcional (77/77 PASS local). O que falta é **ação de admin** no GitHub Settings — não há mudança de código que substitua isso.

---

## Como promover E2E a required check (passo manual)

### 1. Settings → Branches → Branch protection rules → `main`

Em **Settings** (do repositório `nandinhos/devorq_v3) → **Branches** → **Branch protection rules** → editar a regra de `main`:

### 2. Em "Require status checks to pass before merging"

- ☑ Marcar **"Require status checks to pass before merging"**
- Em **"Status checks found in the last week for this repository"**, clicar e buscar:
  - **"Playwright E2E"** (nome do job no `e2e.yml`)
- Adicionar à lista

### 3. Verificar

Após salvar, criar um PR de teste (pode ser um commit trivial) e confirmar:
- O check `E2E / Playwright E2E` aparece na lista de required checks
- Se E2E falhar, o botão "Merge" fica desabilitado

### 4. Opcional — replicar para `dev`

Se `dev` também é branch protegida, repetir para `dev`.

---

## Triggers suportados pelo `e2e.yml`

| Evento | Quando dispara | Por que |
|--------|----------------|---------|
| `push` (main/dev/master) | push direto na branch | validação pós-merge |
| `pull_request` (main/dev/master) | PR aberto/sincronizado | feedback pré-merge |
| `merge_group` | merge queue | suporte a merge queues |
| `workflow_dispatch` | trigger manual | debug / reprodutibilidade |

`concurrency` está configurado para cancelar runs antigos do mesmo `pull_request` quando há force-push, economizando minutos de CI.

---

## Por que NÃO mover E2E para dentro de `ci.yml`

Considerado e descartado:

| Opção | Por que não |
|-------|-------------|
| Unificar tudo em `ci.yml` | E2E é pesado (~5 min) — desacoplar permite feedback mais rápido de lint/tests |
| Job dependente no `ci.yml` (`needs: e2e`) | GitHub Actions cross-workflow `needs` é instável; melhor manter workflow próprio |

A arquitetura atual (workflows separados, ambos rodando em paralelo no PR) é a correta para DEVORQ.

---

## Critério de saída da Fase 5

> Workflow E2E verde e bloqueante; suites de segurança/sync no CI propagando exit code; ShellCheck bloqueia merge; fonte única de gates consumida por flow e self-build com labels fiéis; construtos GNU-only encapsulados.

Checklist:
- ✅ E2E workflow verde (77/77 Playwright)
- ✅ Security tests (27 → 36 corretos, 0 falhas)
- 🟡 Security/sync no CI (não estão em ci.yml ainda — fora do escopo desta rodada)
- ✅ ShellCheck `--severity=error` bloqueia merge em ci.yml
- ✅ Fonte única de gates via `DEVORQ_GATE_SEQUENCE` (DQ-028)
- ✅ `sed_inplace` portável GNU/BSD (DQ-029)

**Falta apenas:** promoção E2E a required check via GitHub Settings (passo admin acima).