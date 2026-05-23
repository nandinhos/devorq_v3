# Scope: [Nome da Feature]

## Identificação
- **Projeto:** [nome-do-projeto]
- **Responsável:** Fernando
- **Data:** $(date +%Y-%m-%d)
- **Stack:** Laravel 11 + Filament v5

## 1. FAZER
- [ ] Criar Migration
- [ ] Criar Model com relacionamentos
- [ ] Criar Policy (se necessário)
- [ ] Criar Resource Filament
- [ ] Criar Listeners/Jobs (se necessário)
- [ ] Adicionar testes

## 2. NÃO FAZER
- NÃO modificar migrations existentes (criar nova)
- NÃO adicionar lógica de negócio no Controller (usar Service/Action)
- NÃO hardcodar strings (usarlang)
- NÃO ignorar `php artisan test` antes de commitar

## 3. ARQUIVOS
```
database/migrations/          — nova migration
app/Models/                  — Model
app/Policies/                — Policy (se aplicável)
app/Services/ ou app/Actions/ — lógica de negócio
app/Filament/Resources/      — Resource Filament
tests/Feature/               — testes
```

## 4. DONE_CRITERIA
- [ ] Migration executa sem erro
- [ ] Model com fillable, casts, relationships definidos
- [ ] Resource Filament carrega em /admin
- [ ] Policy permite/denega acesso corretamente (se aplicável)
- [ ] `php artisan test` passa (--filter=NomeDaFeature)
- [ ] Code style: `./vendor/bin/pint --test` sem violações
- [ ] Context7 valida se API/controller mudou
