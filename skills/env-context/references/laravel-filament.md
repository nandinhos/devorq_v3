# Laravel/Filament — Referência de Gotchas

> Gotchas específicos de Laravel e Filament para `env-context`.
> доповнюється automaticamente via `lessons.sh`.

---

## Docker / Sail

| Condição | Gotcha | Solução |
|----------|--------|---------|
| `docker-compose.yml` com `sail` | SAIL: usar `vendor/bin/sail` em vez de `docker-compose exec` | Prefixo: `./vendor/bin/sail artisan` |
| Sem `WWWUSER` no `.env` | ARQUIVOS: criados como root dentro do container | Adicionar `WWWUSER=$(id -u)` no `.env` |
| `docker-compose exec app` funciona | CUIDADO: comandos artisan dentro do container podem ter path diferente | Preferir `./vendor/bin/sail` quando Sail está ativo |
| `.env` com `DB_HOST=mysql` (nome do serviço) | DB: host MySQL dentro do compose é o nome do serviço, não `localhost` | `DB_HOST=mysql` (nome do serviço compose) |

---

## Laravel General

| Condição | Gotcha | Solução |
|----------|--------|---------|
| `composer.lock` mudou | LOCK: lock file mudou — rodar `composer install` antes de qualquer operação | Sempre fazer `composer install` após `git pull` |
| `APP_ENV=production` no `.env` | ENV: ambiente production — debug desabilitado, cache ativo | Para dev, mudar para `APP_ENV=local` |
| `php artisan` retorna "command not found" | PATH: verificar se está na raiz do projeto (onde está `artisan`) | `php artisan` deve funcionar na raiz |
| Arquivos em `bootstrap/cache/` não existem | CACHE: diretório cache não existe — criar com `php artisan cache:clear` primeiro | `mkdir -p bootstrap/cache && chmod -R 775 bootstrap/cache` |
| `php artisan config:cache` foi rodado | CONFIG: config cacheado — mudanças no `.env` não têm efeito até `config:clear` | Após mudar `.env`: `php artisan config:clear` |
| `routes/web.php` muito grande | ROUTES: arquivo de rotas crescendo — considerar módulos com `Route::prefix()` | Usar `Route::controller()` ou separar por domínio |

---

## Filament v4

| Condição | Gotcha | Solução |
|----------|--------|---------|
| Usando `RelationManager` | RELATION: `RelationManager` precisa de método `$formSchema` ou `$tableColumns` definido | Verificar se o relacionamento no Model está com `$this->belongsToMany()->withPivot()` |
|自定义 Actions usando `Action::make()` | ACTION: Actions Filament v4 usam `getMountUrl()` diferente de v5 | Documentar qual versão está em uso |
| Plugin Spatie/Laravel-Permission | PERMISSION: `$roles` no resource precisa de `canAccessRecord()` customizado | Implementar `canAccessRecord` no Resource: `return auth()->user()->hasRole('admin');` |
| Form com `Tabs` | TABS: ordem dos campos importa dentro de tabs — cada tab é independente | Agrupa lógica, não repete campos entre tabs |
| Table com `Filters` | FILTER: filtrosglobais vs filtros de coluna — filtros de coluna são mais performáticos | Preferir `Filters::filter()` de coluna quando possível |

---

## Filament v5

| Condição | Gotcha | Solução |
|----------|--------|---------|
| Resource `getRelations()` mudou | RELATIONS: em v5, `getRelations()` retorna `RelationManagers` diretamente, não array | Atualizar: `return [$this->relationManagers['orders']];` → `return [$this->orders()];` |
| `Infolists` substituindo `Schemas` | SCHEMA: v5 introduz `Infolists` para páginas de detalhes, `Schemas` agora só para formulários | Migrar `SimpleLayout::` para `Infolists\Components\Section::` |
| Actions agora em `Actions\Action` | ACTIONS: `Actions\Action::make()` agora usa `Actions\Contracts\HasActions` | Actions declaradas em `getHeaderActions()` e `getTableActions()` |
| `Table\Factories\CustomPattern` | TABLE: v5 tem padrão de colunas factory — usar para repetir padrões | `Column::factory()->make()` para colunas repetitivas |
| Testes com Filament Test Helpers | TESTS: v5 tem `Livewire\Tests` específicos para Filament | `composer require --dev filament/testing` |

---

## Asset Pipeline (Mix / Vite)

| Condição | Gotcha | Solução |
|----------|--------|---------|
| `vite.config.js` existe | VITE: Laravel 11 usa Vite por padrão — `npm run dev` vs `npm run build` | Para assets: `npm run dev` (desenvolvimento) ou `npm run build` (produção) |
| `npm run dev` não atualiza | VITE HMR: hot module reload pode precisar de `npm run dev -- --host` | Verificar se o navegador está conectando no WebSocket |
| Assets não aparecem em produção | VITE: após `npm run build`, assets ficam em `public/build/` — verificar se `vite.config.js` tem `resolveSync` | `php artisan view:clear` após mudanças em assets |
| `.css` não atualiza | CACHE: navegador ou `vite` pode estar cacheando — hard refresh (`Ctrl+Shift+R`) | Em dev: desabilitar cache no DevTools |

---

## Queue / Jobs

| Condição | Gotcha | Solução |
|----------|--------|---------|
| `php artisan queue:work` não processa | QUEUE: supervisor precisa estar rodando ou usar `php artisan queue:listen` para dev | `supervisorctl restart all` em prod ou `php artisan queue:work` em dev |
| Job demora muito | JOB: jobs síncronos (`SyncJob`) travam o request — usar `Queue::push()` | Em dev: `QUEUE_CONNECTION=sync` é útil, mas NUNCA em produção |
| `JobFailed` event | FAILED: jobs falhados vão para `failed_jobs` table — `php artisan queue:failed-table` cria migration | Verificar com `php artisan queue:retry all` |

---

## Database

| Condição | Gotcha | Solução |
|----------|--------|---------|
| `DB_CONNECTION=sqlite` | DB: SQLite não suporta enum nativo — usar `string` com `Rule::enum()` ou `Str::enum()` | Se prod usa PostgreSQL, nunca usar `enum` migrations |
| `DB_HOST=127.0.0.1` vs `localhost` | DB: `localhost` usa socket Unix, `127.0.0.1` usa TCP — podem dar "connection refused" | Em Docker, usar nome do serviço (`mysql`, `postgres`) não `localhost` |
| Schema rebuild com `migrate:fresh` | SCHEMA: `migrate:fresh` DROP todas as tabelas — NUNCA rodar em produção | Para testar: `php artisan migrate:fresh --seed` em dev local |

---

## Testing (Pest / PHPUnit)

| Condição | Gotcha | Solução |
|----------|--------|---------|
| `php artisan test` não funciona | TEST: verificar se `phpunit.xml` existe na raiz | `composer require --dev phpunit/phpunit` se ausente |
| `RefreshDatabase` trait não funciona | TEST: `RefreshDatabase` precisa de `DATABASE_URL` ou `DB_CONNECTION` configurado | Alternativa: `DatabaseMigrations` que é mais lento mas mais confiável |
| Pest vs PHPUnit | PEST: se projeto usa Pest, testes ficam em `tests/Pest.php` com `uses()` global | Converter: `test('name', fn() => ...)` → `it('name', fn() => ...)` |
| Factory estados em cascata | FACTORY: `->sequence()` pode criar estados conflitantes — usar `afterMaking()` callback | `Model::factory()->for($owner)->make()` em vez de estado na factory |

---

## Context7 Queries — Laravel + Filament

```bash
# Queries úteis para Context7 (usar em GATE-6 para validar lições)
ctx7_resolve "laravel 11" "dependency injection container"
ctx7_resolve "filament v5" "custom infolist components"
ctx7_resolve "laravel" "queue job dispatching testing"
ctx7_compare "laravel" "vite vs mix asset pipeline"
ctx7_compare "filament v4" "filament v5" "relation manager changes"
```
