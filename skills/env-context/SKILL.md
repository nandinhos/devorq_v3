---
name: env-context
description: Detecta automaticamente stack, ambiente, binários e gotchas do projeto na primeira mensagem da sessão
triggers:
  - "nova sessão"
  - "primeira mensagem"
  - "início de sessão"
  - "ambiente"
  - "stack"
  - "Docker"
  - "portas"
---

# env-context — Contexto Automático de Ambiente

> **Regra de Ouro**: Primeira mensagem da sessão = contexto de ambiente, sempre.

## Quando Usar

**OBRIGATÓRIO** — primeira mensagem de toda nova sessão ou após 30min de inatividade.

** NÃO ** — em mensagens subsequentes da mesma sessão (exceto se trigger explícito como `stack` ou `ambiente`).

## Propósito

1. **Eliminar debugging evitável**: Docker, portas, binários ausentes
2. **Detectar stack automaticamente**: Laravel, Node, Python, etc
3. **Identificar ambiente**: Docker/Sail/Local/Host
4. **Mapear gotchasknown**: Armadilhas conhecidas do projeto

## Output

Gera um bloco de contexto no início da sessão:

```
=== DEVORQ ENVIRONMENT CONTEXT ===

Project: [nome-do-projeto]
Stack: [PHP 8.x / Laravel 12.x / MySQL 8.x]
Runtime: [Docker | Sail | Local | Host]
Commands: [vendor/bin/sail | docker exec | npm run]
Ports: [80:8080, 3306:3306]
Binaries: [php, composer, artisan, npm, mysql]
GOTCHAS: [
  - DOCKER: usar WWWUSER=1000 no .env
  - VITE: npm run build após assets
  - DB: local=MySQL, prod=PostgreSQL
]

LLM: [detectado via prompt actual]
===
```

## Processo

### Step 1: Detectar Projeto

```bash
# Identificar projeto
ls -la
cat .env 2>/dev/null | head -10
cat composer.json 2>/dev/null | head -5
cat package.json 2>/dev/null | head -5
```

### Step 2: Detectar Stack

```bash
# PHP/Laravel
php -v 2>/dev/null | head -1
[ -f artisan ] && echo "Laravel detected"
[ -f composer.json ] && grep -E '"laravel|"php"' composer.json | head -3

# Node
node -v 2>/dev/null
npm -v 2>/dev/null
[ -f package.json ] && grep -E '"dependencies|"devDependencies"' package.json | head -3

# Python
python3 --version 2>/dev/null
[ -f requirements.txt ] && head -5
[ -f pyproject.toml ] && head -5

# Detectar via arquivos
ls *.{json,php,py,rs,go,java} 2>/dev/null | head -20
```

### Step 3: Detectar Ambiente

```bash
# Docker?
[ -f docker-compose.yml ] && echo "Docker: YES"
[ -f docker-compose.yml ] && grep -E "image:|ports:" docker-compose.yml | head -5

# Sail (Laravel)?
[ -f docker-compose.yml ] && grep -q "sail" docker-compose.yml && echo "Runtime: Sail"

# Ports
docker-compose ps 2>/dev/null || echo "Docker: not running"

# Binários disponíveis
for bin in php node python3 composer npm pip cargo go java; do
  which "$bin" 2>/dev/null && echo "  ✓ $bin"
done
```

### Step 4: Detectar Gotchas

```bash
# Known issues do projeto
[ -f .env ] && grep -E "WWWUSER|DB_|APP_|DB_HOST" .env | head -5

# Docker permissions
[ -f docker-compose.yml ] && grep -E "WWWUSER|USER|PUID|PGID" docker-compose.yml

# Vite
[ -f vite.config.js ] || [ -f vite.config.ts ] && echo "Vite: YES"

# DB mismatch
[ -f .env ] && grep "DB_CONNECTION" .env
```

### Step 5: Gerar Contexto

Gerar o bloco `=== DEVORQ ENVIRONMENT CONTEXT ===` conforme formato acima.

## GOTCHAS Conhecidos

Se detectado automaticamente, incluir:

| Tipo | Condição | Gotcha |
|------|----------|--------|
| DOCKER | `docker-compose.yml` existe | Usar `docker-compose exec app` ou `vendor/bin/sail` |
| WWWUSER | `.env` contém WWWUSER= | Definir `WWWUSER=$(id -u)` no .env |
| VITE | `vite.config.js` existe | `npm run build` após modificar assets |
| DB_MISMATCH | `.env` DB_CONNECTION=sqlite | **CUIDADO**: prod usa PostgreSQL, não usar SQLite |
| PERMISSIONS | `docker-compose.yml` sem WWWUSER | Arquivos criados como root no container |
| PORTS | `docker-compose.yml` ports mapeadas | Usar portas mapeadas (não as internas) |

## Decisão de Projeto Type

### Greenfield (novo projeto)
- PRD existe?
- ERD existe?
- Estrutura inicial a criar

### Brownfield (em andamento)
- Analisar código existente
- Respeitar padrões encontrados
- Usar lessons.sh para documentar armadilhas

### Legado (refatoração necessária)
- Identificar tech debt
- Mapear dependências
- Planejar refatoração incremental

## Integração com Skills Existentes

- **`scope-guard`**: Após env-context, se task for `implementar/criar/adicionar`, disparar scope-guard
- **`lessons.sh`**: Se encontrar gotcha novo, perguntar se quer salvar como lesson
- **`context.sh`**: Resultado do env-context populates `context.json` fields

## Débito Prevenido

- **D17**: Environment não declarado
- **D2**: Docker permissions (WWWUSER)

## Limitações

- Não detecta stack se não houver arquivos indicador (composer.json, package.json, etc.)
- GOTCHAS são genéricos; lições específicas do projeto via `lessons.sh`
- Se nenhuma ferramenta disponível (php, node, python), assume projeto bash/shell
