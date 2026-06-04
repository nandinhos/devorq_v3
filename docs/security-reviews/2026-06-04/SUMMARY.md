# Security Review — 2026-06-04 (Codex CLI Review do Sprint)

> **Tipo:** Code review multi-agente via Codex CLI (gpt-5.5)
> **Origem:** Sprint de implementacao da SPEC `docs/specs/2026-06-02-code-review-corrections.md`
> **Branch:** `fix/code-review-2026-06-02`
> **Reviewer:** Hermes (orquestracao) + Codex CLI `codex review --uncommitted` (code review)

---

## Contexto

Este review foi conduzido **apos** a implementacao inicial do fix de whitelist SSH em `lib/vps.sh::devorq::vps_exec` (commit `bc18335`). O objetivo era validar que a defesa em camadas proposta realmente bloqueia command injection e que nenhum caller real foi quebrado.

**Por que Codex CLI?** O padrao de code review multi-agente do DEVORQ (skill `devorq-code-review`) usa 5 agentes especializados em paralelo via Kanban Hermes. Para este sprint, como o diff era cirurgico (4 stories bem definidas), optei por uma abordagem mais leve: **1 rodada de codex review** que age como 1 reviewer rigoroso com confidence scoring 0-100. Em 2 rodadas, identificou 2 issues reais que eu nao tinha visto.

---

## Issues Identificados

### [P1] — Bypass via pipe/background standalone (Codex rodada 2)

**Arquivo:** `lib/vps.sh:137`
**Confidence:** 95
**Severidade:** HIGH (mantem a vulnerabilidade que o fix deveria fechar)

**Problema original (apos implementacao inicial):**
A whitelist validava apenas `${cmd%% *}` (primeira palavra do input inteiro). Mas o `sed` que split por `&&`/`||` permitia que `|` (pipe) e `&` (background) standalone passassem — desde que a primeira palavra do input fosse whitelisted.

**Exploit:**
```bash
vps::exec "ls | sh"
# Antes do fix: passa porque primeira palavra e' 'ls' (whitelisted)
# SSH executa: ls | sh  (sh recebe stdin de ls e roda como shell)
```

**Fix aplicado:**
1. Blocklist de metacaracteres sempre proibidos (P1 global): `;` `` ` `` `$` `()` control chars
2. **Apos** split por `&&`/`||`, cada sub-comando e validado contra `[|&]` antes de checar a whitelist
3. `|` e `&` standalone sao rejeitados explicitamente

**Validacao:**
- Teste funcional: `echo x | grep x` → bloqueado com `[ERROR] sub-comando SSH contem pipe/background nao permitido`
- Codex re-review apos fix: PASS (sem issues de P1)

---

### [P2] — Caller `lessons::sync_vps` quebrado pela whitelist (Codex rodada 1)

**Arquivo:** `lib/vps.sh:122-127`
**Confidence:** 100
**Severidade:** HIGH (regressao funcional — sync de licoes com VPS quebra)

**Problema original (implementacao baseada em exemplo da SPEC):**
A SPEC do code review 2026-06-01 listou 14 comandos para a whitelist: `systemctl, journalctl, docker, ls, cat, grep, tail, head, ps, free, df, uptime, whoami, pwd`. Implementei exatamente esses 14. Porem o caller real `lib/lessons.sh:408` (funcao `lessons::sync_vps`) chama:

```bash
vps::exec "mkdir -p ~/.devorq/lessons && cat > ~/.devorq/lessons/${safe_name}"
```

A primeira palavra `mkdir` nao estava na whitelist. Resultado: **toda vez que `devorq lessons capture` tentasse sincronizar com VPS, falhava com erro de comando nao permitido**.

**Causa raiz:**
A SPEC original do code review listou comandos baseado no exemplo de uso do `vps_pg_exec` (`docker exec ... psql`). Nao cobriu todos os callers reais do `vps_exec`.

**Fix aplicado:**
1. Adicionado `mkdir` a whitelist com comentario explicito do caller
2. Refatorado para split por `&&`/`||` + validacao por sub-comando (cobre o caso `mkdir && cat`)

**Validacao:**
- Teste funcional: `mkdir -p /tmp/lessons && cat > /tmp/lessons/x.json` → aceito
- Caller real `lessons::sync_vps` agora passa o gate de seguranca e pode sincronizar

**Licao aprendida (capturada em `.devorq/state/lessons/`):**
> Whitelist SSH deve cobrir TODOS os callers, nao apenas o exemplo da SPEC. Antes de implementar whitelist, sempre rodar `grep -rn "funcao ALVO" lib/ bin/ scripts/` e listar cada caller com seu input esperado.

---

## Issues que NAO foram problemas (falsos positivos descartados)

| Issue alegada | Avaliacao | Decisao |
|---|---|---|
| `path traversal vps.sh:30` (issue #9 do code review 2026-06-01) | Ja mitigado com `case "$real_path" in "$real_base"*)` (sintaxe equivalente ao `[[ == base* ]]` esperado) | **NAO modificado** — comportamento ja correto. Licao capturada. |
| `SQL injection vps.sh:152` (issue #7) | Mitigado parcialmente (uso de `docker exec` via SSH + `dangerous_pattern` ja existe). Fix adicional fora de escopo da SPEC. | **NAO modificado** — decisao da SPEC original. |

---

## Metodologia do Review

### Ferramenta

```bash
cd /home/nandodev/projects/devorq_v3
codex review --uncommitted
```

`codex-cli 0.136.0` com model `gpt-5.5` (default do CLI; `gpt-5-codex` nao suportado com ChatGPT account), `reasoning_effort=medium`, `sandbox=read-only`, `approval=never`.

### Como o Codex foi usado

- **Rodada 1:** Review do diff inicial. Identificou P2 (caller quebrado).
- **Aplicado fix P2** (adicionar `mkdir` + split por sub-comando).
- **Rodada 2:** Re-review do diff atualizado. Identificou P1 (`ls | sh` bypassa).
- **Aplicado fix P1** (blocklist de `|&` por sub-comando).
- **Validacao final:** 11/11 testes funcionais, 7/7 gates verdes, shellcheck 0 errors.

### Comparacao com code review multi-agente completo

A skill `devorq-code-review` define 5 agentes em paralelo (CLAUDE.md compliance, bug scan, git history, PR history, code comments). Para este sprint, usei 1 agente Codex CLI porque:
- Diff era cirurgico (4 stories bem definidas, ~50 LOC)
- Issues ja conhecidas do code review anterior (2026-06-01) davam contexto
- Velocidade > profundidade para este escopo

**Recomendacao:** Para sprints maiores (>200 LOC ou 5+ stories), usar o code review multi-agente completo via Kanban Hermes.

---

## Resumo Executivo

| Metrica | Valor |
|---|---|
| Issues identificados | 2 (1 P1 HIGH, 1 P2 HIGH) |
| Issues confirmados via teste | 2/2 |
| Iteracoes necessarias | 2 |
| Tempo total de review + fix | ~30 min |
| Licoes capturadas | 5 |
| Commits do sprint | 5 (1 security fix + 2 docs + 1 rules + 1 specs) |
| Cobertura de testes funcionais | 11/11 (4 positivos + 7 negativos) |
| Gates verdes | 7/7 |

**Conclusao:** O fix de whitelist SSH em 2 camadas (blocklist + whitelist) e' robusto contra os vetores de ataque testados. O code review via Codex CLI foi eficiente para este escopo cirurgico.

---

## Cross-references

- **SPEC original:** `docs/specs/2026-06-02-code-review-corrections.md`
- **Code review origem (2026-06-01):** `docs/security-reviews/2026-06-01/PATCHES.md`
- **Implementacao:** commit `bc18335` em `fix/code-review-2026-06-02`
- **Licoes:** `.devorq/state/lessons/lesson_20260604_*.json` (5 arquivos)
- **Changelog:** `CHANGELOG.md` entrada `[3.8.4]`
