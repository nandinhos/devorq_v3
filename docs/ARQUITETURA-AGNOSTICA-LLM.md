# Arquitetura agnóstica LLM — DEVORQ v3.8.5

**Princípio:** `rules/` é a única fonte canônica. Adaptadores (Cursor, Claude, AGENTS.md) são **gerados** por `devorq rules export` — nunca editados em paralelo no repo DEVORQ.

## Camadas

```
rules/*.md                    ← fonte canônica (versionada)
    ↓ devorq rules bootstrap
.devorq/rules/                ← projeto local após init
    ↓ devorq rules export <alvo>
.cursor/rules/  CLAUDE.md  AGENTS.md   ← adaptadores opt-in (locais)
```

## Uso por ferramenta

| Ferramenta | Comando | Saída |
|------------|---------|-------|
| Qualquer LLM | `devorq init` + ler `.devorq/rules/` | Regras no projeto |
| Telegram / orquestrador | `devorq scope lite`, gates, verify | CLI bash |
| Cursor | `devorq rules export cursor` | `.cursor/rules/devorq-discipline.mdc` |
| Claude Code | `devorq rules export claude` | `CLAUDE.md` |
| Multi-tool | `devorq rules export agents` | `AGENTS.md` |

`.cursor/` está no `.gitignore` — cada desenvolvedor gera localmente.

## Orquestrador Telegram

1. Carregar `.devorq/rules/agent-discipline.md` no prompt do agente
2. Antes de codar: `devorq scope lite "<intent>"`
3. Commits via `devorq commit` — nunca append `Co-Authored-By`
4. Regenerar adaptadores após atualizar DEVORQ: `devorq rules export <alvo>`

## Prevenção de coautoria

- Hook `commit-msg` rejeita `Co-Authored-By`
- `scripts/validate-rules.sh` falha se histórico contiver coautoria
- Convenção em `rules/commit-convention.md`

## Histórico Git (v3.8.5)

O histórico `main` foi reorganizado por release (2026-05-23). Re-clone recomendado após force-push de tags.
