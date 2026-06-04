# SPEC: Correções do Code Review 2026-06-01

> **Versão alvo:** DEVORQ v3.8.3
> **Branch:** `fix/code-review-2026-06-02`
> **Origem:** Code review via Kanban Hermes (t_15139089) + 5 lanes paralelas (t_d3099a54, t_e757bb22, t_98893f04, t_c7c0c8aa, t_c6ec4c9a)
> **Data:** 2026-06-02
> **Status:** RASCUNHO — aguardando martelo final do Nando em cada story

## Contexto

Em 2026-06-01, rodei 5 workstreams de code review READ-ONLY sobre o DEVORQ v3.8.2 (`main` @ `621467c`). O review encontrou 10 issues com confidence >= 80. Entre o review (01/06) e a abertura desta SPEC (02/06), o commit `470c5b1 fix(security): corrige 4 vulnerabilidades do code review 2026-06-01` já tratou 4 issues (Co-Authored-By do HEAD, shell injection `lessons.sh:572`, hook não instalado, reformat cosmético).

**Estado real hoje (HEAD `38dbb8b` em 2026-06-02):**

| # | Issue original | Status em 02/06 |
|---|----------------|-----------------|
| 1 | Co-Authored-By no HEAD `621467c` | ✅ Resolvido (HEAD novo `38dbb8b`) |
| 2 | Shell injection `lessons.sh:572` (`$entry` em `sed -i`) | ✅ Resolvido (F-06 em `470c5b1`: `grep -iF --`) |
| 3 | Command injection `vps.sh:117` (`$cmd` cru no SSH) | ❌ **AINDA ABERTO** |
| 4 | Escopo `release(...)` em 15 commits históricos | ❌ **AINDA ABERTO** |
| 5 | Hook `commit-msg` não instalado no próprio repo | ✅ Resolvido (D-1+D-2 em `470c5b1`) |
| 6 | Phantom feature `devorq self-patch` em EXTRAS.md | ❌ **AINDA ABERTO** |
| 7 | SQL injection `vps.sh:152` (escape só de `'`) | ❌ **AINDA ABERTO** |
| 8 | Doc drift: SPEC.md diz 7 gates, código tem 10 | ❌ **AINDA ABERTO** |
| 9 | Path traversal `vps.sh:30` (sem checagem de containment) | ⚠ Parcialmente mitigado (usa `realpath`, falta `[[ == base* ]]`) |
| 10 | Reformat cosmético + `stats` field no commit `621467c` | ✅ Resolvido (HEAD novo) |

**Decisões já marteladas pelo Nando em 2026-06-02:**

1. Command injection → **whitelist de comandos** permitidos (systemctl, journalctl, docker, ls, cat, grep, tail, head, ps, free, df, uptime, whoami, pwd)
2. Escopo `release(...)` → **adicionar à whitelist** (atualizar `commit-convention.md` + `lib/rules.sh:603-610` + regex do hook)
3. Phantom feature `self-patch` → **remover de EXTRAS.md** (mover para roadmap futuro)
4. Doc drift 7-vs-10 gates → **atualizar SPEC.md** (alinhar doc com 10 gates reais)
5. Bônus path traversal → **adicionar checagem de containment** com `[[ "$real_path" == "$real_base"* ]]` (junto com item 1)

## Princípios desta SPEC

- **Sem inventar features.** Esta SPEC NÃO inclui: testes E2E novos, refactor de estilo, mudanças de arquitetura, otimizações de performance, cobertura de tipo de dado além do necessário.
- **Mudanças cirúrgicas.** Cada story altera 1-3 arquivos. Sem "melhorias cosméticas" além do necessário para a correção.
- **Sem commit automático.** Cada story termina com `passes: true` apenas após confirmação manual do Nando (regra `rules/manual-commit.md`).
- **Validação por commit, não por story.** Stories #1 e #5 (mesmo arquivo `lib/vps.sh`, mesmo bug class) podem ser agrupadas em 1 commit `fix(security)` se fizer sentido.

## Stories

### fix-sec-001: Whitelist de comandos SSH + checagem de containment

**Arquivos:** `lib/vps.sh` (linhas 110-130 — função `devorq::vps_exec`; linhas 25-50 — função `devorq::sanitize_path`)
**Escopo do commit:** `fix(security)`
**Fase:** `fix`
**Dependências:** nenhuma

**Acceptance criteria:**
- [ ] `devorq::vps_exec` valida `$cmd` contra whitelist de comandos permitidos
- [ ] Whitelist contém: `systemctl, journalctl, docker, ls, cat, grep, tail, head, ps, free, df, uptime, whoami, pwd`
- [ ] Comando fora da whitelist retorna erro `[ERROR] comando SSH nao permitido: <cmd>` e exit code diferente de 0
- [ ] `devorq::sanitize_path` adiciona checagem `[[ "$real_path" == "$real_base"* ]]` após `realpath -q`
- [ ] Path fora de `base_dir` retorna erro `[ERROR] path fora do base_dir permitido` e exit code de erro
- [ ] Comandos atualmente em uso (grep em `lib/*.sh` por `vps_exec`) continuam funcionando (todos já estão na whitelist)
- [ ] `bash -n lib/vps.sh` passa
- [ ] `shellcheck lib/vps.sh` retorna 0 errors

**Comandos atualmente em uso (verificar):** `devorq::vps_exec "docker exec ..."` (em `vps_pg_exec` linha 152) — `docker` está na whitelist. OK.

**Fora do escopo:**
- Mudar assinatura de `devorq::vps_exec`
- Adicionar subcomandos compostos (ex: `docker compose ps`)
- Logging das chamadas SSH

---

### fix-rules-002: Adicionar `release` à whitelist de escopos

**Arquivos:**
- `rules/commit-convention.md` (adicionar linha na tabela de escopos válidos)
- `lib/rules.sh` (linha 603-610, hardcoded list)

**Escopo do commit:** `fix(rules)`
**Fase:** `fix`
**Dependências:** nenhuma

**Acceptance criteria:**
- [ ] `rules/commit-convention.md` adiciona `| \`release\` | Bump de versão / version sync |` na tabela de escopos
- [ ] `lib/rules.sh` linha 603-610 adiciona `release` à lista hardcoded
- [ ] Regex do hook (`lib/rules.sh:684` ou equivalente) **permanece** `^[a-z]+\([a-z]+\):` (aceita qualquer escopo) — apenas a validação em `lib/rules.sh:603-610` ganha o item
- [ ] Commit de teste `release(test-spec): spec` é aceito pelo hook
- [ ] Os 15 commits históricos com `release(...)` permanecem no histórico sem rewrite
- [ ] `bash -n lib/rules.sh` passa

**Fora do escopo:**
- Reescrever os 15 commits históricos
- Renomear `release(...)` para `chore(release):` (o escopo `chore` também não está na whitelist, então seria criar o mesmo problema em outro lugar)
- Adicionar fase `release` (fases válidas e escopos válidos são listas separadas; a inconsistência é "escopo sem fase", mas a fase atualmente é `release` mesmo, que é a parte dentro dos parênteses)

---

### docs-extras-003: Remover `devorq self-patch` de EXTRAS.md

**Arquivos:** `EXTRAS.md` (linha que contém `| \`devorq self-patch\` | Aplica patch automático |`)
**Escopo do commit:** `docs(extras)`
**Fase:** `docs`
**Dependências:** nenhuma

**Acceptance criteria:**
- [ ] Linha `| \`devorq self-patch\` | Aplica patch automático |` removida de `EXTRAS.md`
- [ ] `grep -rE "self-patch|self_patch" EXTRAS.md README.md SPEC.md` retorna vazio
- [ ] Referência a `EXTRAS.md` em `SPEC.md:493` permanece (o arquivo continua existindo, só perde 1 feature)
- [ ] `git diff` mostra apenas a linha removida (sem reformatação acidental)

**Fora do escopo:**
- Implementar `devorq self-patch` (escopo: sprint futura)
- Criar `docs/ROADMAP.md` (pode ser feito em SPEC separada se Nando quiser)
- Mencionar a feature em CHANGELOG

---

### docs-spec-004: Alinhar SPEC.md com 10 gates reais

**Arquivos:** `SPEC.md` (linhas 56, 126, 537 — referências a "7 gates")
**Escopo do commit:** `docs(spec)`
**Fase:** `docs`
**Dependências:** nenhuma

**Acceptance criteria:**
- [ ] `SPEC.md:56` (árvore de arquivos, comentário `# 7+ gates bloqueantes`) atualizado para `# 10 gates bloqueantes` (gate_0, gate_0_5, gate_1, gate_2, gate_3, gate_4, gate_5, gate_5_5, gate_6, gate_7)
- [ ] `SPEC.md:537` ("✅ 7 gates bloqueantes") atualizado para `✅ 10 gates bloqueantes`
- [ ] Tabela de gates em SPEC (região GATE-0/0.5/1/2) **verificada e completada** se faltar GATE-3/4/5/5.5/6/7
- [ ] `grep -nE "7 gate|sete gate" SPEC.md` retorna vazio (após edição)
- [ ] `grep -nE "10 gate|gate_0|gate_5_5" SPEC.md` retorna >= 1 match

**Fora do escopo:**
- Renomear `gate_5_5` para `gate_5_5` (já é o nome)
- Implementar gate_5_5 no dispatcher principal (se não está sendo chamado, é decisão de feature separada)
- Adicionar documentação de cada gate individual (manter referência à tabela já existente)

---

## Resumo de esforço

| Story | Arquivos alterados | LOC estimadas | Risco |
|-------|-------------------|---------------|-------|
| fix-sec-001 | 1 (`lib/vps.sh`) | ~25 | Médio (touch em SSH) |
| fix-rules-002 | 2 (`commit-convention.md`, `lib/rules.sh`) | ~5 | Baixo (lista) |
| docs-extras-003 | 1 (`EXTRAS.md`) | -1 (remoção) | Mínimo (docs) |
| docs-spec-004 | 1 (`SPEC.md`) | ~3 | Mínimo (docs) |
| **Total** | **4 arquivos únicos** | **~32 LOC** | **Baixo-Médio** |

**Plano de commits:**
1. `fix(security): corrige command injection em vps.sh via whitelist + checagem de path` (stories 1)
2. `fix(rules): adiciona escopo release a whitelist de commit-convention` (story 2)
3. `docs(extras): remove devorq self-patch (nao implementado, planejado para roadmap)` (story 3)
4. `docs(spec): alinha declaracao de gates com implementacao real (10 gates)` (story 4)

Stories 3 e 4 são 100% docs, podem ser combinadas em 1 commit `docs: corrige drift entre codigo e documentacao` se Nando preferir. Decisão do Nando no momento do commit.

## Validação pré-commit (gate por story)

Para cada story:
```bash
# 1. Sintaxe
bash -n <arquivo_alterado>

# 2. Shellcheck (se aplicável)
shellcheck <arquivo_alterado>

# 3. Diff
git diff <arquivo_alterado>  # revisar manualmente

# 4. Para fix-sec-001 especificamente:
#    Confirmar que `devorq::vps_exec` ainda é chamado pelos mesmos callers
grep -rn "vps_exec\|vps_pg_exec" lib/ bin/
```

Para o projeto inteiro (pós-4 commits):
```bash
# Gates DEVORQ
bin/devorq build  # 7/7 gates verdes

# Version sync
diff VERSION .devorq/version  # deve ser vazio
```

## O que NÃO está nesta SPEC (declarado explicitamente)

- ❌ SQL injection `vps.sh:152` (issue #7) — está parcialmente mitigado pelo uso de `docker exec` via SSH (não query SQL direta) e a validação `dangerous_pattern` já existe. Decidir separadamente se vale patch adicional. **NÃO** incluído.
- ❌ Reformat cosmético em commits antigos — fora de escopo.
- ❌ Atualizar README.md com nova lista de gates — coberto indiretamente se SPEC for fonte canônica.
- ❌ Adicionar testes automatizados para `vps.sh` — fora de escopo (projeto é bash puro sem test runner para SSH).
- ❌ Endurecer regex do hook para whitelist real (`^[a-z]+\((core|models|...)\):`) — escolha consciente: a regex permissiva + validação em `lib/rules.sh:603-610` é o design atual.

## Riscos e mitigações

| Risco | Mitigação |
|-------|-----------|
| Whitelist SSH quebra callers existentes | Verificar `grep -rn "vps_exec" lib/ bin/` antes de commitar — todos os callers devem usar comandos da whitelist |
| Hook aceita `release(...)` mas fluxo `devorq commit` tem validação separada | Testar fluxo: `bin/devorq commit --dry-run` com mensagem de release antes de commitar o patch |
| SPEC.md tem múltiplas referências a "7 gates" em regiões diferentes | Grep exaustivo: `grep -nE "7 gate|sete gate" SPEC.md` antes/depois |
| Remoção de `self-patch` quebra algum link externo | Grep antes: `grep -rE "self-patch" --include="*.md" .` — garantir que não há outros docs referenciando |

## Aprovação

- [ ] Nando aprovou `fix-sec-001` (whitelist SSH + containment)
- [ ] Nando aprovou `fix-rules-002` (adicionar `release` à whitelist)
- [ ] Nando aprovou `docs-extras-003` (remover `self-patch`)
- [ ] Nando aprovou `docs-spec-004` (alinhar gates 7→10)

Após todos marcados: rodar `bin/devorq build` (7/7) e validar visualmente com Nando antes de push.
