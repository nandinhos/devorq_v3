# AGENTS.md — DEVORQ (instruções agnósticas)

> Documento estável para qualquer LLM, IDE ou orquestrador (Telegram, Claude, Cursor, Copilot).
> **Fonte canônica:** `rules/` no repo DEVORQ. Adaptadores são gerados sob demanda.

## Regras essenciais

| Regra | Arquivo canônico |
|-------|------------------|
| Disciplina do agente | [`rules/agent-discipline.md`](rules/agent-discipline.md) |
| Convenção de commit | [`rules/commit-convention.md`](rules/commit-convention.md) |
| Commits manuais | [`rules/manual-commit.md`](rules/manual-commit.md) |

Após `devorq init`, cópias ficam em `.devorq/rules/`.

## Fluxo recomendado

1. `devorq init` — bootstrap de regras + hook commit-msg
2. Preencher `.devorq/state/context.json` com `intent` e `success_criteria`
3. `devorq scope lite "<intent>"` — contrato mínimo antes de codar
4. Gates 1–7 + `devorq verify`
5. `devorq commit` — **sem** `Co-Authored-By`

## Export para ferramentas

```bash
devorq rules export project   # .devorq/rules/
devorq rules export cursor    # .cursor/rules/ (local, gitignored)
devorq rules export claude    # CLAUDE.md
devorq rules export agents    # AGENTS.md no projeto alvo
```

No repo DEVORQ, este arquivo é mantido manualmente. Em projetos consumidores, `export agents` gera uma cópia adaptada.

## Proibições

- Sem `Co-Authored-By` em commits (hook bloqueia)
- Sem refatoração fora do escopo pedido
- Sem features especulativas

Ver também: [`docs/ARQUITETURA-AGNOSTICA-LLM.md`](docs/ARQUITETURA-AGNOSTICA-LLM.md)
