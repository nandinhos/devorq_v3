# EXTRAS.md — DEVORQ v3

> Tópicos avançados: Context-Mode, Context7, Superpowers, HUB, e Self-Building.

---

## Context-Mode (Compressão de Contexto)

**Problema:** Context window é limitado. Sessões longas saturam o contexto.

**Solução:** O Context-Mode monitora o tamanho do contexto e comprime proativamente.

### Funções (lib/context.sh)

```bash
devorq context lint    # Valida context.json — campos obrigatórios
devorq context stats   # Mostra tamanho em chars/tokens
devorq context pack    # Comprime para handoff minimal
devorq context merge   # Merge de dois contextos
devorq context set     # Define campo (project, intent, stack...)
devorq context clear   # Limpa contexto
```

### Campos do context.json

```json
{
  "project": "nome-do-projeto",
  "intent": "o que estamos fazendo agora",
  "stack": ["bash", "jq", "postgresql"],
  "gates_completed": [1, 2, 3],
  "pending_gates": [4, 5, 6],
  "last_session": "2026-04-22T04:00:00Z",
  "pending": "implementar fase 4",
  "errors": [],
  "stuck_gates": []
}
```

### Alertas

- **>60k tokens (240k chars):** `ctx_pack` sugere compressão
- **>120k tokens:** GATE-3 alerta que contexto está crítico

### GATE-3 Integration

`devorq gate 3` verifica automaticamente:
1. context.json existe — se não, cria com `ctx_set`
2. Campos obrigatórios — `ctx_lint` valida
3. Intent preenchido — sem intent = alerta

---

## Context7 Integration

**Problema:** Como saber se a documentação oficial recomenda uma abordagem diferente da que planejamos?

**Solução:** Consultar a documentação oficial via Context7 antes de implementar.

### Configuração

```bash
# Opção 1: via env
export OPENAI_API_KEY=sk-...

# Opção 2: via config file
echo "OPENAI_API_KEY=sk-..." >> ~/.devorq/config
```

### Funções (lib/context7.sh)

```bash
devorq context7 check           # Verifica se API está respondendo
devorq context7 search "<q>"   # Busca docs por query
devorq context7 resolve "<lib>"# Resolve library ID + busca
devorq context7 compare "<a>" "<b>" # Compara 2 libs
```

### GATE-6 Integration

`devorq gate 6` executa `ctx7_check` automaticamente:
- API configurada e respondendo → PASS
- API key missing → WARN (não bloqueia)
- API offline → WARN (não bloqueia)

**Regra:** GATE-6 nunca bloqueia. É um aviso para consultar docs.

### Exemplo de Uso

```bash
# Antes de escolher SQLite vs PostgreSQL para um projeto:
devorq context7 search "postgresql vs sqlite performance"

# Validar lição aprendida contra docs:
devorq context7 resolve "mongodb/mongodb-node"
```

---

## Superpowers Framework

**Compatibilidade:** DEVORQ pode carregar skills do Superpowers Framework via `skill_view`.

### Skills Relacionadas

| Skill | Uso |
|-------|-----|
| `systematic-debugging` | GATE-7 workflow |
| `test-driven-development` | Antes de implementar |
| `github-code-review` | GATE antes de commit |
| `plan` | Decomposição de tasks |
| `subagent-driven-development` | Multi-LLM workflows |

### Carregar Skill

```bash
# Via Hermes Agent:
skill_view(name="systematic-debugging")

# O agente carrega o SKILL.md e segue as instruções automaticamente
```

---

## DEV-MEMORY HUB (Laravel + PostgreSQL)

**Problema:** Lições aprendidas ficam locais. Como compartir entre máquinas?

**Solução:** Sincronização com HUB remoto via SSH.

### Arquitetura

```
Local (.devorq/state/lessons/) ←→ SSH ←→ VPS srv163217:6985
                                              └── PostgreSQL
                                              └── dev-memory-laravel
                                              └── Tabelas: devorq.*
```

### Tabelas

| Tabela | Descrição |
|--------|-----------|
| `devorq.lessons` | Lições aprendidas com embeddings pgvector |
| `devorq.memories` | Memórias de projeto |
| `devorq.sessions` | Histórico de sessões |
| `devorq.handoffs` | Contextos de handoff entre LLMs |

### Comandos

```bash
devorq sync push          # Envia lessons locais → HUB
devorq sync pull          # Recebe lessons do HUB → local
devorq vps check          # Testa conexão SSH
```

### Acesso Direto (desenvolvimento)

```bash
# SSH + PostgreSQL
ssh -p 6985 root@187.108.197.199

# psql dentro do container
docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study

# Criar extension vector (primeiro acesso)
CREATE EXTENSION vector;
```

---

## Self-Building (Meta-Circular)

**Princípio:** O DEVORQ constrói a si mesmo.

### Comandos

```bash
devorq build              # Executa todos os gates + testes
devorq upgrade            # Pull latest do repo
devorq self-patch         # Aplica patch automático
devorq uninstall          # Remove instalação (preserva lessons)
```

### GATE-7 + Systematic Debugging

Quando `devorq build` encontra erro:

1. **Phase 1:** `debug::check` detecta problema
2. **Phase 2:** `devorq debug` guia investigação de causa raiz
3. **Phase 3:** Hipótese formulada
4. **Phase 4:** Fix mínimo implementado
5. **Regra de 3:** 3+ fixes falhados = questionar arquitetura

### Regra de Ouro

> **NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST**

### Fluxo

```
devorq build → erro → devorq debug → investigação → fix → devorq build
     ↑                                                              |
     └───────────────── OK ←────────────────────────────────────────┘
```

---

## Handoff Multi-LLM

**Problema:** Trocar de LLM no meio de uma sessão perde contexto.

**Solução:** Gerar contexto compactado para o próximo agente.

### Geração de Handoff

```bash
devorq compact            # Gera .devorq/state/handoff.json
devorq gate 5             # Valida que handoff está pronto
```

### Estrutura do Handoff

```json
{
  "project": "...",
  "intent": "...",
  "stack": [...],
  "gates_completed": [...],
  "pending": "...",
  "timestamp": "2026-04-22T04:00:00Z"
}
```

### Recepção de Handoff

```bash
# No novo agente:
devorq context merge handoff.json
```

---

## Tips & Tricks

### jq Fallback

Se `jq` não estiver disponível, todas as funções usam fallback grep/sed:

```bash
# jq está em ~/bin/jq (instalado sem root)
export PATH="$HOME/bin:$PATH"
```

### Bash Strict Mode

DEVORQ usa `set -euo pipefail` em todos os scripts. Isso significa:
- `set -e`: sai ao primeiro erro
- `set -u`: erro em variável não definida
- `set -o pipefail`: falha em pipe propaga

### Tokens de Cores

```bash
RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
# Usar: echo -e "${GREEN}[PASS]${RESET} texto"
```

### Debugging

```bash
# Modo verbose
devorq -v gate 3

# Ver função
declare -f ctx_lint

# Trace de erros
bash -x devorq gate 3
```

---

## Trubleshooting Rápido

| Sintoma | Solução |
|---------|---------|
| `devorq: command not found` | `cp bin/devorq ~/bin/ && chmod +x ~/bin/devorq` |
| `lib/gates.sh not found` | Bootstrap não resolve symlink — use `readlink -f` |
| GATE-6 sempre warn | Configurar `OPENAI_API_KEY` |
| `context.json` não encontrado | Executar `devorq init` no projeto |
| jq errors | `curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux64 -o ~/bin/jq && chmod +x ~/bin/jq` |

---

**Versão:** 3.2.x
**Repo:** https://github.com/nandinhos/devorq_v3
**Última atualização:** 2026-04-22
