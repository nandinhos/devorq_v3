# DEVORQ — Refatoração de Instalação e Unificação

**Versão:** 1.0.0  
**Data:** 2026-05-20  
**Autor:** Análise — Fernando Dos Santos (Nando)  
**Stack:** DEVORQ v3.6.3  
**Status:** Rascunho para validação

---

## 1. Resumo Executivo

O DEVORQ está em uso real mas apresenta **3 instalações concorrentes**, nenhuma delas com o PATH configurado corretamente, e um sistema de lições parallelo (`.aidev/`) que nunca foi migrado. Esta especificação documenta o diagnóstico completo e define o plano de unificação.

---

## 2. Diagnóstico — Instalações Concurrentes

### 2.1 Mapa de Instalações

```
DESVINCULADAS DO PATH (não usadas):
  ~/.devorq_v3/          → v3.5.0   (clone antigo, 2026-05-10)
  ~/devorq/              → v3.4.1   (clone ainda mais antigo, 2026-04-26)

ATIVA NO PATH (sendo usada):
  ~/projects/devorq_v3/  → v3.6.3   (única com git remote, 2026-05-18) ← CANÔNICA
```

### 2.2 PATH Atual

```
Posição no PATH:
  1. /home/nandodev/devorq/bin          ← ATIVA (v3.4.1 — DESATUALIZADA)
  2. /home/nandodev/.devorq/bin         ← fantasma (não existe)
  ...
  8. /home/nandodev/.local/bin          → symlink para projects/devorq_v3
```

| Posição | Origem | Conteúdo | Usada? |
|---------|--------|----------|--------|
| 1 | `~/devorq/` | v3.4.1, 11 libs, 3 skills | **SIM** |
| 2 | `~/.devorq/` | inexistente | NÃO |
| 8 | `~/.local/bin/devorq` | symlink → projects/devorq_v3 | NÃO (nunca alcançada) |

**Conclusão**: O sistema está rodando **v3.4.1** quando a versão mais nova é **v3.6.3** (1.2 releases atrás).

### 2.3 Comparação de libs entre v3.4.1 e v3.6.3

| Arquivo | v3.4.1 | v3.6.3 | Diferença |
|---------|--------|--------|-----------|
| `auto.sh` | ❌ | ✅ | v3.6.0+ adicionou AUTO mode |
| `compact.sh` | ✅ | ✅ | — |
| `context.sh` | ✅ | ✅ | reestruturado em `lib/commands/` |
| `context7.sh` | ✅ | ✅ | — |
| `debug.sh` | ✅ | ✅ | reestruturado em `lib/commands/` |
| `gates.sh` | ✅ | ✅ | — |
| `lessons.sh` | ✅ | ✅ | expandido com approve/compile |
| `spec.sh` | ❌ | ✅ | v3.6.0+ |
| `stats.sh` | ✅ | ✅ | — |
| `unify.sh` | ❌ | ✅ | v3.6.0+ |
| `vps.sh` | ✅ | ✅ | — |
| `helpers.sh` | ❌ | ✅ | v3.6.0+ |
| `lib/commands/` | ❌ | ✅ | 8 subcomandos modularizados |

### 2.4 Comparação de skills entre v3.4.1 e v3.6.3

| Skill | v3.4.1 | v3.6.3 |
|-------|--------|--------|
| `ddd-deep-domain` | ✅ | ✅ |
| `devorq-auto` | ✅ | ✅ |
| `devorq-code-review` | ✅ | ✅ |
| `devorq-mode` | ✅ | ✅ |
| `env-context` | ❌ | ✅ |
| `grill-with-docs` | ❌ | ✅ |
| `learned-lesson` | ❌ | ✅ (em `~/.devorq_v3/`) |
| `project-foundation` | ❌ | ✅ |
| `scope-guard` | ❌ | ✅ |
| `security-hardening` | ❌ | ✅ |

---

## 3. Diagnóstico — Lições `.aidev/`

### 3.1 Inventário

| Arquivo | Tipo | Tema | Avaliação |
|---------|------|------|-----------|
| `kb/2026-05-19-alpine-multiple-instances.md` | Lição única | Livewire 4 bundla Alpine — não usar CDN | ✅ **Migrar** |
| `kb/2026-05-19-clickup-labels-ids.md` | Lição única | Labels ClickUp usam UUIDs — need ID→label lookup | ✅ **Migrar** |
| `kb/2026-05-19-clickup-explorer-lessons.md` | Consolidação | 8 lições do projeto ClickUp Explorer | ⚠️ **Migrar parcialmente** |

### 3.2 Análise Individual

#### `alpine-multiple-instances.md` — Migrar ✅

**Stack**: `laravel`, `livewire`, `alpinejs`  
**Problema**: Livewire 4 bundla Alpine.js internamente. CDN duplica instâncias.  
**Solução**: Remover CDN do Alpine quando usar Livewire 4.  
**Formato DEVORQ**: JSON em `.devorq/state/lessons/captured/`

```json
{
  "id": "lesson_clickup_20260519_alpine",
  "title": "Livewire 4 bundla Alpine.js — não usar CDN",
  "problem": "Console mostra 'Detected multiple instances of Alpine running'",
  "solution": "Remover <script defer src='alpine.js'> do layout quando usar @livewireScripts",
  "stack": ["laravel", "livewire", "alpinejs"],
  "tags": ["livewire", "alpinejs", "duplicacao", "cdn"],
  "project": "clickup-explorer",
  "source_file": ".aidev/memory/kb/2026-05-19-alpine-multiple-instances.md",
  "validated": false,
  "applied": false
}
```

#### `clickup-labels-ids.md` — Migrar ✅

**Stack**: `clickup-api`, `custom-fields`  
**Problema**: Campo tipo `labels` retorna array de UUIDs, não labels.  
**Solução**: Lookup ID→label via `type_config.options`.  
**Formato DEVORQ**: JSON.

#### `clickup-explorer-lessons.md` — Migrar parcialmente ⚠️

Contém 8 lições sobre ClickUp API integration. Muitas são específicas demais do projeto ClickUp Explorer (taxonomia de campos financeiros, hierarquia). As lições técnicas amplas (Alpine duplicação, labels UUIDs) devem migrar. As específicas de domínio podem ficar no projeto como documentação, não como lição reutilizável.

### 3.3 Recomendação de Migração

```
Lições a migrar para .devorq/state/lessons/captured/:
  1. alpine-multiple-instances       → 1 JSON
  2. clickup-labels-ids              → 1 JSON

Total: 2 lições migráveis
```

**.aidev/** após migração: pode permanecer como está — é criado pelo sistema e não interfere no DEVORQ. **Não é necessário remover.**

---

## 4. Diagnóstico — `rules/` e `skills/`

### 4.1 Situação Atual

```
.devorq/rules/     → CRIA vazio pelo init, NUNCA populado
.devorq/skills/    → CRIA vazio pelo init, NUNCA populado
```

O `devorq init` (bin/devorq, linha 129-134) executa:

```bash
mkdir -p "$devorq_dir/rules"
mkdir -p "$devorq_dir/skills"
```

Nenhum template é copiado. Nenhum conteúdo é adicionado. Eles existem como **placeholders não utilizados**.

### 4.2 Evidência

- `.devorq/rules/` está vazio em **todos** os projetos que usam DEVORQ (clickup, control_events, projects/devorq_v3)
- `.devorq/skills/` está vazio em **todos** os projetos
- Os **skills** reais do DEVORQ ficam em `skills/` **global** do DEVORQ_ROOT, não local ao projeto
- O bin/devorq referencia `skills/devorq-mode/`, `skills/project-foundation/`, etc. via `DEVORQ_ROOT/skills/`

### 4.3 Decisão de Design

| Opção | Descrição | Implicação |
|-------|------------|-------------|
| **A — Manter vazios** | docs: explicar que são placeholders | Mantém compatibilidade, sem功能 |
| **B — Remover do init** | `devorq init` não cria mais esses dirs | Breaking change mínimo |
| **C — Popular com templates** | rules/ com commit-pattern, coding-standards; skills/ com scripts úteis ao projeto | Trabalho de especificação |

**Recomendação: Opção B** — remover do `devorq init`. Esses diretórios nunca foram usados e não há especificação do que deveriam conter. Se no futuro houver necessidade, volta-se com spec.

---

## 5. Plano de Unificação — Instalação Canônica

### 5.1 Objetivo

Manter **1 instalação global** do DEVORQ, localizada em `~/projects/devorq_v3/` (v3.6.3 — a mais nova, com git remote).

### 5.2 Ações de Unificação

#### Passo 1: Corrigir PATH

**Antes:**
```bash
# ~/.bashrc (duas entradas):
export PATH="$HOME/devorq/bin:$PATH"         # ← v3.4.1 (ERRADO)
export PATH="$HOME/devorq/bin:$PATH"         # ← duplicado
```

**Depois:**
```bash
# ~/.bashrc — remover todas as linhas DEVORQ antigas e adicionar:
export PATH="$HOME/projects/devorq_v3/bin:$PATH"
```

#### Passo 2: Remover instalações obsoletas

```bash
# Remover clones antigos (após confirmar que v3.6.3 funciona):
rm -rf ~/devorq/           # v3.4.1 — obsoleto
rm -rf ~/.devorq_v3/        # v3.5.0 — obsoleto
```

#### Passo 3: Garantir que `.local/bin/devorq` aponte para a canônica

```bash
# Se ~/.local/bin/devorq for symlink:
ls -la ~/.local/bin/devorq
# Se apontar para local diferente, corrigir:
# ln -sfn ~/projects/devorq_v3/bin/devorq ~/.local/bin/devorq
```

#### Passo 4: Atualizar v3.6.3 do remote

```bash
cd ~/projects/devorq_v3
git pull origin main
# Confirmar versão:
devorq version  # deve mostrar v3.6.3
```

### 5.3 Diagrama de Estado Futuro

```
ANTES (confuso):
  ~/devorq/                  (v3.4.1 — no PATH)
  ~/.devorq_v3/              (v3.5.0 — fora do PATH)
  ~/projects/devorq_v3/      (v3.6.3 — git remote, MAS NÃO NO PATH)
  ~/.local/bin/devorq        → projects/devorq_v3 (nunca alcançado)

DEPOIS (limpo):
  ~/projects/devorq_v3/      (v3.6.3 — CANÔNICA, git remote)
  ~/.local/bin/devorq        → projects/devorq_v3/bin/devorq
  PATH: ~/projects/devorq_v3/bin primeiro
```

---

## 6. Ações Priorizadas

### 6.1 Alta Prioridade (Fazer Agora)

| # | Ação | Comando/Procedimento | Risco |
|---|------|---------------------|-------|
| A1 | Corrigir PATH | Editar `~/.bashrc`, colocar `~/projects/devorq_v3/bin` primeiro | Baixo |
| A2 | Validar v3.6.3 | `devorq version && devorq test` após correção do PATH | Baixo |
| A3 | Migrar 2 lições .aidev | `devorq lessons capture` para cada uma | Baixo |

### 6.2 Média Prioridade (Após Validação)

| # | Ação | Procedimento | Risco |
|---|------|--------------|-------|
| M1 | Remover `~/devorq/` (v3.4.1) | `rm -rf ~/devorq/` após 1 semana de validação | Médio |
| M2 | Remover `~/.devorq_v3/` (v3.5.0) | `rm -rf ~/.devorq_v3/` após 1 semana de validação | Médio |
| M3 | Atualizar README/INSTALL | Documentar instalação correta como `~/projects/devorq_v3/` | Baixo |

### 6.3 Baixa Prioridade (Futuro)

| # | Ação | Decisão |
|---|------|---------|
| B1 | Remover `rules/` e `skills/` do `devorq init` | Criar issue primeiro |
| B2 | Decidir se `.aidev/` deve ter integração com DEVORQ | Questão de longo prazo |
| B3 | Documentar `rules/` e `skills/` se forem ter propósito | Só se B1 for rejeitado |

---

## 7. Decisões de Design Registradas

| ID | Decisão | rationale |
|----|----------|-----------|
| D1 | `.devorq/rules/` e `.devorq/skills/` são **opcionais e vazios por design** | Nunca foram usados pelo core. Não há spec para eles. |
| D2 | Lições aprendidas vivem em `.devorq/state/lessons/captured/*.json` | Formato JSON, não markdown. Integridade com `devorq lessons` CLI. |
| D3 | Skills DEVORQ ficam em `DEVORQ_ROOT/skills/`, não no projeto | Permite updates globais sem tocar nos projetos |
| D4 | `.aidev/` é **independente** do DEVORQ |Criado por sistema externo. Convive sem conflito. |

---

## 8. Não Mexer (Protegido)

Conforme orientação do usuário, as seguintes localizações **não devem ser modificadas** nesta refatoração:

| Caminho | Razão |
|---------|-------|
| `~/.hermes/skills/devorq*` | Skills do Hermes — atualizados automaticamente pelo Hermes |
| `~/.claude/skills/devorq*` | Skills do Claude Code — ciclo próprio |
| `~/.aidev/` | Sistema embrionário — não é do DEVORQ |

---

## 9. Validação

Após executar as ações de Alta Prioridade, verificar:

```bash
# 1. PATH correto
which devorq
# Esperado: ~/projects/devorq_v3/bin/devorq

# 2. Versão correta
devorq version
# Esperado: DEVORQ v3.6.3

# 3. Teste de estrutura
devorq test
# Esperado: todos os checks [OK]

# 4. Lições migradas
devorq lessons list
# Esperado: listar lições existentes + 2 novas do .aidev
```

---

*Documento gerado em 2026-05-20 — usado para investigação e unificação do DEVORQ v3*
