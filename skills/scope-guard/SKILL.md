---
name: scope-guard
description: >
  DEVORQ-SG v1.0.0 — Contrato de escopo explícito para bloquear over-engineering.
  Gera WHITELIST de FAZER/NÃO FAZER/ARQUIVOS antes de qualquer implementação.
  Integra com Context7 para validar DONE_CRITERIA contra docs oficiais.
  Use quando: intent contém "implementar", "criar", "adicionar", "feature".
version: 1.0.0
author: Fernando Dos Santos (Nando)
license: MIT
metadata:
  hermes:
    tags: [devorq, scope, contract, over-engineering, guard]
    related_skills: [devorq, devorq-mode, ddd-deep-domain, systematic-debugging]
    devorq:
      gate: 0
      type: exploration
      mode: [auto, classic]
  stack: [bash, jq]
---

# DEVORQ-SCOPE-GUARD v1.0.0

## Visão Geral

**Princípio:** *"Sem contrato de escopo = sem código."*

**Problema resolvido:** Modelos LLM tendem a "melhorar" o que não foi pedido — adicionar cache, service layers, testes E2E, refatorações. Isso gera commits gigantes, technical debt, e tempo 10x maior.

**Solução:** Contrato de escopo WHITELIST antes de qualquer código.

## Quando Usar

### Triggers (automático)
Intent contém:
- `implementar`, `criar`, `adicionar`, `feature`
- `novo`, `desenvolver`, `construir`

### NÃO dispara para:
- `corrigir`, `fix`, `bug`, `typo`, `erro`
- `editar`, `atualizar` (a menos que seja crítico)
- Tasks triviais (< 5min estimado)

### Gate
- **GATE-0** (pré-implementação, opt-in via triggers)
- Roda ANTES de GATE-1 (Spec exists)

## Arquitetura

```
[NOVA TASK]
    │
    │ intent contém trigger words
    ▼
┌─────────────────────┐
│ scope-guard         │ ← GATE-0 (opcional)
│                     │
│ 1. Gerar contrato   │
│ 2. Aguardar aprovação│
│ 3. checkpoint contínuo│
│ 4. Bloqueio se violar│
└──────────┬──────────┘
           │
           ▼
    GATE-1 (Spec exists)
    GATE-2...GATE-7
```

## Estrutura do Contrato

```markdown
# CONTRATO DE ESCOPO — [nome-da-task]

## IDENTIFICAÇÃO
- **Task**: [resumo]
- **Tipo**: feature | bugfix | refactor | docs
- **Complexidade**: baixa | média | alta

## FAZER (whitelist — só o que está aqui é permitido)
1. [Funcionalidade específica 1]
2. [Funcionalidade específica 2]

## NÃO FAZER (blacklist — nunca fazer)
1. [O que NÃO fazer]
2. [O que NÃO fazer]

## ARQUIVOS (whitelist — só esses podem ser modificados)
- `caminho/arquivo1.ext`
- `caminho/arquivo2.ext`

## ARQUIVOS PROIBIDOS (nunca modificar)
- `app/Models/User.php`
- `config/auth.php`

## DONE_CRITERIA (objetivos verificáveis)
- [ ] Critério 1
- [ ] Critério 2
- [ ] Context7 valida: "[query]"

## RISCO_IDENTIFICADO
- [ ] Risco 1
```

## Processo de Execução

### Step 1: Detectar Necessidade

```bash
# Verifica se intent contém trigger words
echo "$intent" | grep -qiE "implementar|criar|adicionar|feature|novo|desenvolver"
```

### Step 2: Gerar Contrato

Quando trigger detectado, solicitar contrato:

```
Entendi. Antes de implementar, preciso do contrato de escopo.

# CONTRATO DE ESCOPO — [resumo da task]

## FAZER
-

## NÃO FAZER
-

## ARQUIVOS
-

## DONE_CRITERIA
-

Aguardo confirmação ou ajustes.
```

### Step 3: Aguardar Aprovação

- Usuário completa o contrato → validar e prosseguir
- Usuário não responde em 30s → prosseguir com melhor interpretação

### Step 4: Checkpoint Contínuo

A cada 3-5 arquivos modificados:

```
CHECKPOINT ESCOPO:
- Modificados: [lista]
- Dentro de ARQUIVOS? ✅/❌
- Dentro de FAZER? ✅/❌
- Algo do NÃO FAZER? ✅/❌
```

### Step 5: Bloqueio

Se escopo violado:

```
🛑 ESCOPO VIOLADO!
- Detectado: [o que fugiu]
- Contrato: [ref]
- Ação: PARAR e perguntar se pode incluir
```

## Integração com Context7

O campo `Context7 valida:` no DONE_CRITERIA permite validar contra docs oficiais:

```
## DONE_CRITERIA
- [ ] Validação Laravel funciona
    Context7 valida: "Laravel validation rules"
- [ ] Erro aparece inline
    Context7 valida: "Blade error messages"
```

### Como funciona

1. O modelo extrai a query do DONE_CRITERIA
2. Roda `devorq context7 search "<query>"`
3. Usa o resultado para validar o critério

## Exemplo Completo

### Input
```
"Implementar login via Google OAuth2"
```

### Output (Contrato)
```markdown
# CONTRATO DE ESCOPO — Login Google OAuth2

## IDENTIFICAÇÃO
- **Task**: Login Google OAuth2
- **Tipo**: feature
- **Complexidade**: média

## FAZER
1. Implementar login via Google OAuth2
2. Criar tabela oauth_providers (se não existir)
3. Adicionar botão "Entrar com Google" na view
4. Salvar access_token e refresh_token
5. Criar rota callback

## NÃO FAZER
- NÃO implementar OAuth Facebook/GitHub
- NÃO criar registro email/senha
- NÃO modificar User table existente
- NÃO implementar 2FA

## ARQUIVOS
- `app/Http/Controllers/Auth/OAuthController.php` (novo)
- `app/Models/OAuthProvider.php` (novo)
- `routes/auth.php`
- `resources/views/auth/login.blade.php`
- `config/services.php`
- `database/migrations/*_create_oauth_providers_table.php` (novo)

## ARQUIVOS PROIBIDOS
- `app/Models/User.php`
- `app/Http/Controllers/Auth/LoginController.php`

## DONE_CRITERIA
- [ ] Usuário consegue fazer login via Google
    Context7 valida: "Laravel Socialite Google OAuth"
- [ ] Token armazenado com encryption
- [ ] Redirect para /dashboard após login
- [ ] Logout funciona (revoga token)
- [ ] Testes passando (min 3)
```

## Anti-Patterns

| Errado | Certo |
|--------|-------|
| Começar a codar sem contrato | Contrato primeiro |
| "Vou melhorar X enquanto estou aqui" | NÃO FAZER bloqueia |
| Modificar arquivo não listado | ARQUIVOS é whitelist |
| "Done quando ficar bom" | Critérios objetivos |
| Adicionar "sempre" features | Escopo restrito |

## Output para o Usuário

```
┌─────────────────────────────────────────────┐
│  🛡️  SCOPE-GUARD — Contrato de Escopo      │
├─────────────────────────────────────────────┤
│                                             │
│  Task: Login Google OAuth2                  │
│  Tipo: feature | Complexidade: média        │
│                                             │
│  FAZER (whitelist):                         │
│    1. Login via Google OAuth2                │
│    2. Tabela oauth_providers                 │
│    3. Botão na view                         │
│                                             │
│  NÃO FAZER (blacklist):                     │
│    1. ❌ Facebook/GitHub OAuth               │
│    2. ❌ Registro email/senha                 │
│    3. ❌ Modificar User table               │
│                                             │
│  ARQUIVOS (whitelist):                      │
│    ✅ OAuthController.php (novo)             │
│    ✅ OAuthProvider.php (novo)               │
│    ✅ routes/auth.php                        │
│    ✅ login.blade.php                        │
│                                             │
│  DONE_CRITERIA:                             │
│    ☐ Login Google funciona                   │
│    ☐ Token criptografado                     │
│    ☐ Redirect /dashboard                    │
│                                             │
│  ⚠️  Confirme para prosseguir               │
└─────────────────────────────────────────────┘
```

## Arquivos

```
skills/scope-guard/
├── SKILL.md                      # Este arquivo
├── scripts/
│   └── scope-validate.sh         # Validador de contrato
└── references/
    └── examples.md               # Contratos de exemplo
```

## Débito que Previne

- **D16**: Especificações vagas → over-engineering
- **D17**: Escopo não declarado → implementação arbitrária
- **D18**: Critérios subjetivos → "done when feels right"
