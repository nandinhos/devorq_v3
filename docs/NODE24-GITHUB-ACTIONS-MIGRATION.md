# GitHub Actions: Migração Node.js 20 → 24

**Data:** 24 de Abril de 2026  
**Autor:** Fernando Dos Santos (Nando)  
**Tags:** `github-actions`, `node-js`, `devops`, `ci-cd`

---

## Sumário

1. [O Problema](#1-o-problema)
2. [Causa Raiz](#2-causa-raiz)
3. [Sintomas](#3-sintomas)
4. [Soluções Possíveis](#4-soluções-possíveis)
5. [Solução Definitiva: `actions/checkout@v6`](#5-solução-definitiva-actionscheckoutv6)
6. [Passo a Passo da Migração](#6-passo-a-passo-da-migração)
7. [Script de Correção Automática](#7-script-de-correção-automática)
8. [Outras Actions Que Podem Ser Afetadas](#8-outras-actions-que-podem-ser-afetadas)
9. [Referências](#9-referências)

---

## 1. O Problema

A partir de **setembro de 2026**, o GitHub Actions vai **remover Node.js 20** dos runners `ubuntu-latest`, `windows-latest` e `macos-latest`. A partir de **junho de 2026**, actions compiladas para Node.js 20 vão ser forçadas a rodar em Node.js 24 por padrão.

Isso significa que qualquer workflow GitHub Actions que use actions baseadas em Node.js 20 **sem suporte a Node.js 24** vai quebrar a partir de setembro de 2026.

---

## 2. Causa Raiz

### Timeline de deprecação

| Data | Evento |
|---|---|
| **19/Set/2025** | GitHub anuncia deprecação do Node.js 20 nos runners |
| **2/Jun/2026** | Node.js 24 se torna o padrão nos runners; Node.js 20 ainda disponível mas deprecated |
| **16/Set/2026** | **Node.js 20 removido dos runners** — actions sem suporte a Node 24 vão falhar |

### Por que o warning aparece

O runner detecta que a action usa `engines: { node: "20" }` (ou similar) e mostra um warning de deprecação. O GitHub oferece duas abordagens:

1. **Workaround** (temporário): `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` — força a action a rodar no Node 24 mesmo sendo Node 20
2. **Solução definitiva**: fazer upgrade para versão da action que suporta nativamente Node.js 24

### Por que o workaround não é suficiente

O `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` **não elimina o warning** porque:
- O runner ainda detecta que a action *almeja* Node 20
- O forcing é feito em nível de runtime do runner, não em nível de compilação da action
- O GitHub ainda mostra a anotação "being forced to run on Node.js 24" — o warning persiste
- É uma flag de compatibilidade, não uma correção da action em si

---

## 3. Sintomas

### No GitHub Actions UI

```
⚠️ Annotations (1 warning / 2 warnings)

ShellCheck Lint / Test Suite
Node.js 20 is deprecated. The following actions are running on 
Node.js 20 and may not work as expected: actions/checkout@v4. 
Actions will be forced to run with Node.js 24 by default starting 
June 2nd 2026. Node.js 20 will be removed from the runner on 
September 16th 2026. Please check if updated versions of these 
actions are available that support Node.js 24.
```

### Com workaround ativo (FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true)

```
⚠️ Annotations (2 warnings)

Node.js 20 is deprecated. The following actions target Node.js 20 
but are being forced to run on Node.js 24: actions/checkout@v4.
```

**Observação:** O workaround apenas muda o texto do warning — ele não elimina a anotação.

---

## 4. Soluções Possíveis

### Solução A — Workaround (❌ Não recomendado)

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

**Problemas:**
- Não elimina o warning
- Flag pode ser removida em versões futuras do runner
- Não é uma correção real — apenas um band-aid

### Solução B — Pinar action para versão específica + workaround (⏸️ Temporário)

Mesma coisa que acima — workaround não resolve o problema.

### Solução C — Upgrade para action com suporte Node.js 24 nativo (✅ **Definitivo**)

Fazer upgrade para a versão mais recente da action, que já tem `engines: { node: "24" }`.

---

## 5. Solução Definitiva: `actions/checkout@v6`

### Por que o `actions/checkout@v6` funciona

O `actions/checkout@v6` (lançado em Novembro 2025, última release v6.0.2 em Janeiro 2026) é compilado com Node.js 24 nativo. Isso significa:

- `engines: { node: "24" }` no `package.json` da action
- Nenhum warning de deprecação
- Suporte completo às features mais recentes do runner
- Performance potencialmente melhor

### Releases do actions/checkout

| Versão | Node.js | Status |
|---|---|---|
| `v4` | Node 20 | ⚠️ Deprecated — mostra warning |
| `v5` | Node 20? | Pouco usado, verificar |
| `v6` | **Node 24** | ✅ **Recomendado — sem warnings** |

> ⚠️ **Nota:** O `actions/checkout@v5` nunca chegou a ser amplamente adotado. O v6 é a versão atual e recomendado pelo time do GitHub Actions.

### Como verificar qual versão usar

```bash
# Listar releases no GitHub
gh release list --repo actions/checkout
```

O `v6.0.2` (9 de Janeiro 2026) é a versão mais recente e estável.

---

## 6. Passo a Passo da Migração

### 6.1 Identificar todos os workflows com actions afetadas

```bash
# No diretório raiz do projeto
grep -r "actions/checkout@v" .github/workflows/ 2>/dev/null
grep -r "uses: actions/"     .github/workflows/ 2>/dev/null
```

### 6.2 Fazer o upgrade do `actions/checkout`

**Antes:**
```yaml
- name: Checkout
  uses: actions/checkout@v4
```

**Depois:**
```yaml
- name: Checkout
  uses: actions/checkout@v6
```

### 6.3 Remover workaround se existir

Se o workflow tiver:
```yaml
env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

**Remover** — não é mais necessário com `v6`.

### 6.4 Commit e push

```bash
git add .github/workflows/
git commit -m "fix(ci): upgrade actions/checkout v4→v6 (Node.js 24 native, zero warnings)"
git push origin main
```

### 6.5 Verificar no GitHub Actions

1. Ir em **Actions** → ver o workflow run mais recente
2. Verificar **Annotations** — deve estar vazio (sem warnings)
3. Verificar **Status** dos jobs — deve ser `Success`

---

## 7. Script de Correção Automática

Para projetos com múltiplos workflows, use este script:

```bash
#!/usr/bin/env bash
# fix-node24.sh — Corrige todos os workflows para usar actions/checkout@v6

set -euo pipefail

WORKFLOWS_DIR=".github/workflows"

if [ ! -d "$WORKFLOWS_DIR" ]; then
  echo "❌ $WORKFLOWS_DIR não encontrado. Execute no raiz do projeto."
  exit 1
fi

echo "🔍 Procurando actions/checkout@v4 em workflows..."

FOUND=0
for wf in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
  [ -f "$wf" ] || continue

  # Substituir v4, v5 por v6
  if grep -q "uses: actions/checkout@v4\|uses: actions/checkout@v5" "$wf"; then
    echo "✅ Corrigindo: $wf"
    sed -i 's|uses: actions/checkout@v4|uses: actions/checkout@v6|g' "$wf"
    sed -i 's|uses: actions/checkout@v5|uses: actions/checkout@v6|g' "$wf"
    FOUND=$((FOUND + 1))
  fi

  # Remover workaround se existir
  if grep -q "FORCE_JAVASCRIPT_ACTIONS_TO_NODE24" "$wf"; then
    echo "🧹 Removendo workaround FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 de: $wf"
    sed -i '/FORCE_JAVASCRIPT_ACTIONS_TO_NODE24/d' "$wf"
    sed -i '/env:/,/FORCE_JAVASCRIPT_ACTIONS_TO_NODE24/d' "$wf"
    FOUND=$((FOUND + 1))
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "✅ Nenhuma correção necessária — workflows já estão atualizados."
else
  echo ""
  echo "📋 Alterações feitas:"
  git diff "$WORKFLOWS_DIR"
fi
```

Salve em `scripts/fix-node24.sh`, chmod +x, e execute:

```bash
chmod +x scripts/fix-node24.sh
./scripts/fix-node24.sh
```

---

## 8. Outras Actions Que Podem Ser Afetadas

Além do `actions/checkout`, outras actions oficiais podem ter o mesmo problema. Sempre verificar:

```bash
gh release view v6 --repo actions/checkout --json body --jq '.body'
```

### Actions mais comuns a verificar

| Action | v4 (Node 20) | v6 (Node 24) |
|---|---|---|
| `actions/checkout` | ⚠️ | ✅ |
| `actions/setup-node` | ⚠️ | ✅ |
| `actions/cache` | ⚠️ | ✅ |
| `actions/upload-artifact` | ⚠️ | ✅ |
| `actions/download-artifact` | ⚠️ | ✅ |
| `actions/github-script` | ⚠️ | ✅ |

> **Dica:** Sempre use `actions/setup-node@v4` junto com Node 24 para garantir compatibilidade total.

### Exemplo de workflow atualizado

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Test Suite
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '24'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

  lint:
    name: Lint
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v6

      - name: Run shellcheck
        run: shellcheck bin/**/*.sh lib/**/*.sh
```

---

## 9. Referências

- **[GitHub Blog — Deprecation of Node.js 20 on GitHub Actions runners](https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/)**
- **[actions/checkout Releases](https://github.com/actions/checkout/releases)**
- **[actions/checkout v6.0.0 Changelog](https://github.com/actions/checkout/blob/v6.0.0/CHANGELOG.md)**
- **[GitHub Actions runner images](https://github.com/actions/runner-images)** — imagens do runner com detalhes de Node.js disponível
- **[FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 Environment Variable](https://github.com/actions/checkout/issues/2360)** — Issue discutindo a variável de ambiente

---

## Resumo

| item | detalhes |
|---|---|
| **Problema** | Node.js 20 removido dos GitHub Actions runners em 16/Set/2026 |
| **Sintoma** | Warning annotations no CI: "Node.js 20 is deprecated" |
| **Workaround** | `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` — não elimina warning, apenas mitiga |
| **Solução definitiva** | Upgrade para `actions/checkout@v6` (Node 24 nativo) |
| **Ação necessária** | Substituir `actions/checkout@v4` → `actions/checkout@v6` em todos os workflows |
| **Remover** | Qualquer `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` após upgrade |
| **Timeline** | Fazer a migração antes de Junho 2026 para evitar surpresas |

---

*Documento criado em 24/Abril/2026 com base na correção do projeto devorq_v3 (commit `b2e2176`).*
