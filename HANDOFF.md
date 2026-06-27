# HANDOFF — DEVORQ v3.8.5 → continuidade no Codex

> **Para quem pega o trabalho (agente Codex / codex-cli):** este é o ponto de
> retomada. Leia daqui até o fim **antes** de qualquer edição ou commit.
> Gerado em 2026-06-27. Repo: `github.com/nandinhos/devorq_v3` · branch `main`.

---

## 0. Como usar este handoff

1. O Codex carrega `AGENTS.md` automaticamente a cada turno — ele tem os
   **inegociáveis** (formato de commit, proibições). Este `HANDOFF.md` é o
   **snapshot de estado**: cole-o como primeiro prompt da sessão Codex.
2. Rode o Codex em modo que **permita editar** (`--sandbox workspace-write`,
   approval interativo). O uso anterior do Codex neste repo foi só review
   (`sandbox=read-only`); para desenvolver isso não basta.
3. Antes de codar, leia: este arquivo → `AGENTS.md` → `SPEC.md` (escopo) →
   `docs/auditoria-tecnica-2026-06-26.md` (dívida técnica, por ID `DQ-xxx`).

---

## 1. TL;DR do estado

- **DEVORQ é um orquestrador de agentes em Bash** (`bin/devorq` + `lib/` + `scripts/`).
  Não é app Laravel — apesar da skill `laravel` poluindo o `skills/` (ver §8).
- **Backlog da auditoria fechado: DQ-001..DQ-030, 30/30 endereçados**, tudo na
  `main`. Detalhe item-a-item no Apêndice D de `docs/auditoria-tecnica-2026-06-26.md`.
- **CI verde / E2E vermelho conhecido** (ver §5). O `main` está estável.
- **Não há story pendente** no `prd.json` (todas `done` — é artefato histórico
  do sprint v3.8.4). **O próximo milestone ainda NÃO está definido** — ver §7.

**Veredito da auditoria (resumo):** a casca do DEVORQ é boa (router/dispatcher
real, hardening de input sólido), mas o histórico apontava um núcleo de execução
"teatro" (verde ≠ verificado). As correções DQ-001..030 atacaram exatamente isso
(fail-closed no AUTO, fim do wipe de `prd.json`, gates persistidos, observabilidade
real). Releia o §1 da auditoria para o contexto completo — **não confie em memória,
leia o arquivo.**

---

## 2. Duas camadas — o Codex só herda UMA

| Camada | O quê | Codex usa? |
|--------|-------|------------|
| **Portável (CLI Bash)** | `bin/devorq`, `lib/`, `scripts/` | ✅ **Sim — opere por aqui** |
| **Skills do Claude Code** | `skills/devorq-auto`, `skills/devorq-mode`, etc. (invocadas via *Skill tool*) | ❌ Não — Codex não tem Skill tool |

➡️ **Dirija tudo via CLI** (`bin/devorq <cmd>`), nunca via skills. As skills são
adaptadores do Claude Code; a lógica canônica vive em `lib/`/`scripts/`.

### Modo AUTO via Codex (atenção)
O modo AUTO (story-by-story) depende do contrato `DEVORQ_DELEGATE_FN` — uma
função que implementa uma story. **Hoje só o contrato está documentado**
(`AGENTS.md` §"Contrato de delegação"); **não existe adapter Codex funcional**
(era o aceite do DQ-022, que ficou só na documentação). Sem `DEVORQ_DELEGATE_FN`
o loop é **fail-closed** (não marca story como done). Portanto: **não tente rodar
`devorq auto` esperando que ele implemente sozinho** até existir um adapter. Para
desenvolvimento manual, use o fluxo CLASSIC (gates) — ver §4.

---

## 3. Convenções inegociáveis (resumo — fonte: `AGENTS.md`)

- **Commit**: 1ª linha casa `^[a-z]+\([a-z]+\):` → `tipo(escopo): descrição`,
  tipo e escopo **só minúsculas, sem espaço/dígito/hífen**. IDs (`DQ-031`) vão no
  **fim da descrição**. O hook `.git/hooks/commit-msg` **bloqueia** o que fugir.
- **Sem `Co-Authored-By:`** (hook bloqueia). **Português do Brasil.**
- **Sem refatoração fora de escopo. Sem features especulativas.**
- ⚠️ O `CLAUDE.md` global (commit *com* espaço) **não vale aqui** — o hook manda.

---

## 4. Fluxo de trabalho recomendado (CLASSIC, via CLI)

```bash
devorq init                 # bootstrap de regras + hook commit-msg (idempotente)
# edite .devorq/state/context.json: intent + success_criteria
devorq scope lite "<intent>"   # contrato mínimo antes de codar
# ... implemente ...
devorq flow                 # gates 1–7 (use --resume para retomar)
devorq verify
devorq commit               # confirmação [Y/n]; respeita o hook
```

---

## 5. Como VERIFICAR (rode você mesmo — não confie em contagens)

```bash
bash bin/devorq test            # suíte unit (NÃO use grep para filtrar!)
bash scripts/ci-test.sh         # espelha o CI; leia o sumário Pass/Fail INTEIRO
bash scripts/sync-version.sh --check   # drift de versão entre VERSION/CHANGELOG/etc.
bash scripts/security-tests.sh  # path traversal, SSH, SQLi, sanitize
```

- **Não crave número de testes** — fontes divergem (68/74/75) conforme o lote.
  Rode e leia o sumário completo. **Lição da auditoria:** 2 regressões de CI
  escaparam porque alguém filtrou a saída com `grep`. **Veja Pass/Fail inteiro.**
- **E2E é VERMELHO esperado**: ~6/77 testes Playwright pré-existentes falham
  (`.github/workflows/e2e.yml`). O *install* já foi corrigido (DQ-026); os 6
  testes são uma story própria. **Não queime esforço "consertando" esse sinal**
  a menos que essa seja explicitamente a tarefa.

### ⚠️ Poluição de estado ao rodar suites
Rodar as suites **suja** `.devorq/state/lessons/captured/` (e pode gerar
`skills/<algo>/` auto-gerado). **Sempre** restaure depois:

```bash
git checkout -- .devorq/state/ ; git clean -fdn   # confira o que seria removido
```

Não commite esse lixo. (É a provável origem do `skills/laravel/` atual — ver §8.)

---

## 6. O que está FEITO

- Backlog auditoria **DQ-001..DQ-030: 30/30** (detalhe: Apêndice D da auditoria).
  Highlights: fim do wipe de `prd.json` (DQ-004), AUTO fail-closed (DQ-005),
  `gates_completed` persistido + `flow --resume` (DQ-007), trilha JSONL com
  `run_id` (DQ-018), SSH mux por-uid + guard de segredos (DQ-014/015),
  `DEVORQ_GATE_SEQUENCE` fonte única (DQ-028), `sed_inplace` portável (DQ-029).
- `main` com CI verde; `.devorq/version` e `VERSION` em **3.8.5**.

---

## 7. O que está EM ABERTO (honesto — defina o milestone)

> O backlog formal está fechado. "Terminar o projeto" precisa de um **próximo
> milestone definido pelo dono**. Itens residuais conhecidos, em ordem de valor:

1. **DQ-022 incompleto — adapter Codex funcional para `DEVORQ_DELEGATE_FN`.**
   O aceite era "≥1 adaptador não-Hermes funciona end-to-end"; só a documentação
   foi entregue. **Sem isso o modo AUTO não roda fora do Hermes.** Maior alavanca
   se o objetivo é AUTO no Codex. (`skills/devorq-auto/scripts/loop-auto.sh`,
   `AGENTS.md`.)
2. **E2E Playwright: 6/77 falhando** — story própria (`e2e-tests/`,
   `scripts/e2e-test.sh`). Tornar E2E verde + *gating* fecha o aceite da Fase 5.
3. **Locking de escrita concorrente** em `.devorq/state/*.json` — resíduo
   não-bloqueante (single-user; escritas já são `tmp+mv` atômicas). Baixa prio.
4. **Higiene imediata** (ver §8).

**Decisão pendente do dono:** qual o próximo milestone? (a) adapter Codex p/ AUTO,
(b) E2E verde+gating, (c) nova feature de produto, (d) só manutenção. Sem isso,
o Codex deve ficar em **manutenção/higiene** e não inventar roadmap.

---

## 8. Higiene imediata (faça antes de começar feature)

- **`skills/laravel/` + `skills/.index.md` (untracked) = CRUFT.** A lição `l1`
  tem title `"T"`, problema `"p"`, solução `null` — placeholder gerado num test
  run (05:42). **Não commite.** Remova:
  ```bash
  git clean -fdn   # revise
  git clean -fd skills/laravel skills/.index.md
  ```
- **Branches locais `fix/auditoria-*`** já foram integradas na `main` — podem ser
  podadas (`git branch -d` após confirmar merge).

---

## 9. Mapa rápido do código

| Caminho | Papel |
|---------|-------|
| `bin/devorq` | Entry point / dispatcher CLI |
| `lib/commands/`, `lib/dispatchers/` | Roteamento comando→módulo (1 dispatcher por módulo) |
| `lib/gates.sh` | Gates + `DEVORQ_GATE_SEQUENCE` (fonte única) |
| `lib/auto.sh`, `skills/devorq-auto/scripts/loop-auto.sh` | Modo AUTO (loop story-by-story) |
| `lib/context.sh` | Estado em `.devorq/state/context.json` (`gates_completed`, `run_id`) |
| `lib/commit.sh` | Commit seguro (guard de segredos, confirmação) |
| `lib/vps.sh`, `scripts/sync-*.py` | VPS/HUB sync (SQL parametrizado, sem root hardcoded) |
| `lib/context7.sh`, `lib/lessons/` | Validação Context7 + lições aprendidas |
| `scripts/*-tests.sh`, `scripts/ci-test.sh` | Suítes de teste (ver §5) |
| `docs/auditoria-tecnica-2026-06-26.md` | **Dívida técnica completa, IDs DQ-xxx / R-xx** |

---

*Dúvida de priorização: rastreie tudo pelos IDs `DQ-xxx` (§10 da auditoria) e
`R-xx` (§9 da auditoria). Em caso de conflito entre docs e código, **o código e o
hook são a verdade** — docs podem estar com drift.*
