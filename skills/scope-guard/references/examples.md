# scope-guard — Exemplos de Contratos

## Exemplo 1: Feature Simples

**Input:** `"Adicionar validação de email no form de contato"`

```markdown
# CONTRATO DE ESCOPO — Validação Email Form Contato

## IDENTIFICAÇÃO
- **Task**: Validar email no form de contato
- **Tipo**: feature
- **Complexidade**: baixa

## FAZER
1. Adicionar validação de formato email no campo
2. Mostrar mensagem de erro inline abaixo do campo
3. Bloquear submit se email inválido

## NÃO FAZER
- NÃO criar service layer
- NÃO adicionar storage de contatos
- NÃO enviar email de confirmação
- NÃO criar testes E2E

## ARQUIVOS
- `resources/views/contact.blade.php`
- `app/Http/Controllers/ContactController.php`

## ARQUIVOS PROIBIDOS
- `app/Services/`
- `database/migrations/`

## DONE_CRITERIA
- [ ] Email inválido mostra erro inline
- [ ] Submit bloqueado com email inválido
- [ ] Email válido prossegue normalmente
```

---

## Exemplo 2: Feature Média (API)

**Input:** `"Criar API REST para gerenciamento de tarefas"`

```markdown
# CONTRATO DE ESCOPO — API REST Tarefas

## IDENTIFICAÇÃO
- **Task**: CRUD API REST tarefas
- **Tipo**: feature
- **Complexidade**: média
- **Estimativa**: 4h

## FAZER
1. Criar modelo Task com campos: title, description, status, due_date
2. Criar migration
3. Criar controller com endpoints: GET, POST, PUT, DELETE
4. Criar routes em api.php
5. Retornar JSON padronizado

## NÃO FAZER
- NÃO implementar autenticação (fez separado)
- NÃO criar paginação
- NÃO criar filtros avançados
- NÃO documentar com Swagger

## ARQUIVOS
- `app/Models/Task.php`
- `database/migrations/*_create_tasks_table.php`
- `app/Http/Controllers/TaskController.php`
- `routes/api.php`

## ARQUIVOS PROIBIDOS
- `app/Http/Middleware/`
- `config/auth.php`

## DONE_CRITERIA
- [ ] GET /api/tasks retorna lista
- [ ] POST /api/tasks cria tarefa
- [ ] PUT /api/tasks/{id} atualiza
- [ ] DELETE /api/tasks/{id} remove
- [ ] Validação de campos
- [ ] Testes unitários passando
```

---

## Exemplo 3: Bug Fix

**Input:** `"Corrigir bug de login que não valida senha"`

```markdown
# CONTRATO DE ESCOPO — Fix Validação Login

## IDENTIFICAÇÃO
- **Task**: Bug — login não valida senha
- **Tipo**: bugfix
- **Complexidade**: baixa
- **Estimativa**: 30min

## FAZER
1. Adicionar validação de senha não vazia
2. Verificar que Auth::attempt() é chamado corretamente
3. Testar cenário: senha errada → rejected

## NÃO FAZER
- NÃO modificar estrutura do banco
- NÃO alterar regra de senha (isso é feature futura)
- NÃO adicionar "remember me"

## ARQUIVOS
- `app/Http/Controllers/Auth/LoginController.php`
- `app/Http/Requests/LoginRequest.php` (criar se não existir)

## ARQUIVOS PROIBIDOS
- `app/Models/User.php`
- `database/migrations/`

## DONE_CRITERIA
- [ ] Senha errada retorna erro 401
- [ ] Senha correta faz login
- [ ] Sem empty string accepted
```

---

## Exemplo 4: Refatoração

**Input:** `"Refatorar controller de usuários para service"`

```markdown
# CONTRATO DE ESCOPO — Refatorar UserController

## IDENTIFICAÇÃO
- **Task**: Extrair lógica do UserController para UserService
- **Tipo**: refactor
- **Complexidade**: média
- **Estimativa**: 2h

## FAZER
1. Criar app/Services/UserService.php
2. Mover lógica de UserController para UserService
3. Manter rotas iguais
4. Garantir que testes existentes passam

## NÃO FAZER
- NÃO alterar comportamento existente
- NÃO criar novos endpoints
- NÃO modificar models
- NÃO adicionar features

## ARQUIVOS
- `app/Http/Controllers/UserController.php`
- `app/Services/UserService.php` (novo)
- `tests/Feature/UserControllerTest.php`

## ARQUIVOS PROIBIDOS
- `routes/api.php`
- `app/Models/`

## DONE_CRITERIA
- [ ] Testes passam sem modificação
- [ ] Rotas unchanged
- [ ] Response unchanged
```

---

## Trigger Words que Disparam scope-guard

| Trigger | Ação |
|---------|------|
| `implementar` | scope-guard |
| `criar` | scope-guard |
| `adicionar` | scope-guard |
| `feature` | scope-guard |
| `novo` | scope-guard |
| `desenvolver` | scope-guard |
| `construir` | scope-guard |
| `refatorar` | scope-guard |
| `extrair` | scope-guard |

## Trigger Words que NÃO Disparam

| Trigger | Ação |
|---------|------|
| `corrigir` | skip |
| `fix` | skip |
| `bug` | skip |
| `typo` | skip |
| `erro` | skip |
| `editar` | skip (a menos que crítico) |
| `atualizar` | skip (a menos que crítico) |
