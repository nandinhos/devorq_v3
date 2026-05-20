# DEVORQ Rules — Índice Central

**Propósito:** Regras globais do framework DEVORQ versionadas no repo canônico.

**Hierarquia de carregamento:**
1. `rules/` global em `DEVORQ_ROOT/rules/` — carregado primeiro
2. `.devorq/rules/` local do projeto — carregado **após** e sobrescreve se não conflitar

**Regras disponíveis:**

| Regra | Descrição |
|-------|-----------|
| `commit-convention.md` | Convenções de commit (Conventional Commits + scopes DEVORQ) |

**Quando uma regra é aplicada:**

- **commit-convention**: ao final de cada gate成功 (GATE-5+), antes do `git commit`
- **brainstorm/**: ao iniciar sessão `devorq brainstorm`
- **grill/**: ao iniciar sessão `devorq grill`

**Como criar regra local (projeto):**
```bash
mkdir -p .devorq/rules
# Criar .devorq/rules/<nome>.md
```

**Como sobrescrever regra global:**
- Regra local em `.devorq/rules/<nome>.md` substitui global se não conflitar
- Conflito = mesma regra com lógica contraditória → usar `devorq rules check` para detectar

**Manutenção:**
- Regras globais são mantidas no repo `nandinhos/devorq_v3`
- Lições aprendidas podem gerar novas regras via `devorq lessons capture`