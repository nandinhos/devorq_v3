# Commit Convention — DEVORQ v3.6+

**Formato:**
```
type(scope): descrição
```

**Types válidos:**

| Type | Uso |
|------|-----|
| `feat` | Funcionalidade nova |
| `fix` | Correção de bug |
| `refactor` | Refatoração sem mudança de comportamento |
| `docs` | Documentação |
| `test` | Testes |
| `style` | Formatação, lint (não afeta código) |
| `perf` | Performance |
| `chore` | Tarefas gerais (deps, config, CI) |

**Scopes DEVORQ:**

```
core | lessons | gates | compact | vps | hub | context | debug | docs | bdd | unify | auto | review | spec | gate0 | mode
```

**Exemplos:**
```
feat(bdd): adiciona lib/spec.sh com validacao BDD Given/When/Then
feat(unify): adiciona lib/unify.sh e fase de fechamento
feat(auto): adiciona devorq-mode e devorq-auto com loop story-by-story
feat(review): adiciona code review multi-agente com scoring 0-100
feat(gate0): adiciona GATE-0 suite com scope-guard e ddd-deep-domain
gates(core): adiciona GATE-5.5 nao bloqueante para UNIFY check
docs(bdd-template): adiciona BDD-TEMPLATE.md com template Given/When/Then
fix(lessons): corrige infer_skill para paths com underscore
refactor(core): extrai lib/environment.sh de devorq-init
chore(deps): atualiza jq para 1.7+
```

**Regras de aplicação (GATE-5+):**
- Commits são feitos **após cada story verificada**, não no fim da sprint
- Cada commit deve representar **uma unidade lógica de mudança**
- Mensagem deve ser atômica: `type(scope): ação exata no que foi feito`
- NUNCA usar commits do tipo "WIP", "temp", "debug"

**Recursos:**
- [Conventional Commits](https://www.conventionalcommits.org/)
- [BDD (Given-When-Then)](https://cucumber.io/docs/gherkin/)