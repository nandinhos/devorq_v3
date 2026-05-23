# Commit Convention — DEVORQ v3.6.5+

**Formato:**
```
escopo(fase): descrição (detalhamento)
```

**Exemplo:**
```
feat(bdd): adiciona validação BDD Given/When/Then (lib/spec.sh migrado)
fix(livewire): corrige Alpine duplicado em x-data (remove CDN inline)
refactor(core): extrai devorq::verify para lib/visual.sh
docs(gates): documenta GATE-6 manual verification gate
```

**Regras:**
- Sem emojis
- Sem Co-Authored-By
- Em português do Brasil
- Escopo deve ser um dos escopos válidos
- Fase deve ser uma das fases válidas
- NUNCA usar commits do tipo "WIP", "temp", "debug"

**Escopos válidos:**

| Escopo | Uso |
|--------|-----|
| `core` | Core do DEVORQ, libs principais |
| `models` | Models Eloquent, migrations |
| `services` | Services, repositories |
| `livewire` | Componentes Livewire |
| `notifications` | Notifications, emails |
| `routes` | Rotas, controllers |
| `config` | Configurações, environment |
| `database` | Schema, migrations |
| `tests` | Testes (Unit, Feature, E2E/Playwright) |
| `bdd` | Validação BDD, Gherkin, specs |
| `gates` | Gates DEVORQ |
| `unify` | Fase UNIFY |
| `docs` | Documentação |
| `debug` | Debug sistemático |
| `spec` | SPEC.md, requisitos |
| `lessons` | Lições aprendidas |
| `compact` | Handoff, compact |
| `vps` | VPS, infraestrutura |
| `hub` | HUB, sincronização |
| `context` | Contexto, estado |

**Fases válidas:**

| Fase | Uso |
|------|-----|
| `impl` | Implementação (default) |
| `test` | Testes |
| `verify` | Verificação visual |
| `docs` | Documentação |
| `unify` | UNIFY |
| `debug` | Debug |
| `fix` | Correção |
| `refactor` | Refatoração |

**Quando commitar:**
- Após `devorq verify` passar (100% verde)
- NUNCA commitar com teste vermelho
- Um commit por story (unidade lógica)

**Trigger automático de debug:**
Quando teste falha (Playwright, PHPUnit), systematic-debugging entra em ação automaticamente — ver `rules/visual-verification.md`