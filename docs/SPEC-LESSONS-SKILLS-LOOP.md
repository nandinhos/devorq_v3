# SPEC — LESSONS → SKILLS Auto-Development Loop

**Versão:** 1.0.0 | **Data:** 2026-04-24 | **Status:** draft

---

## 1. Visão

### Problema

DEVORQ captura lições aprendidas (`lessons::capture`), valida com Context7 (`lessons::validate`), mas **não fecha o loop**: lições validadas não se transformam automaticamente em skills que previnem o erro no futuro.

### Solução

Pipeline fechado: **lição → validação Context7 → aprovação usuário → skill gerada → commit + push**

### Comparação com Estado Atual

| Aspecto | Estado Atual | Estado Final |
|---------|-------------|-------------|
| Captura | ✅ `lessons::capture` | ✅ Igual |
| Validação | ✅ `lessons::validate` (Context7) | ✅ Igual |
| Aprovação | ❌ Não existe | ✅ `devorq lessons approve <id>` |
| Skill generation | ❌ Não existe | ✅ `lessons::compile` |
| Auto-trigger | ❌ Não existe | ✅ Prompt após `validate` |
| Commit+push | ❌ Manual | ✅ Automático (com flag) |

---

## 2. Conceitos Core

### Princípio

> "Uma lição que vira skill é uma lição que nunca mais precisa ser capturada."

### Ciclo de Vida da Lição

```
captured → validated (Context7) → approved (usuário) → compiled (skill) → applied
```

- **captured**: Salva localmente via `lessons::capture`
- **validated**: Context7 confirmou que solução está correta
- **approved**: Usuário decidiu que merece skill própria
- **compiled**: Gerou/atualizou skill em `skills/<name>/`
- **applied**: Skill foi carregada e está ativa

### Campo `approved` no JSON

```json
{
  "id": "lesson_20260424_120000",
  "title": "Laravel Sail WWWUSER",
  "problem": "Arquivos criados como root no container Docker",
  "solution": "Adicionar WWWUSER=$(id -u) no .env",
  "stack": "laravel",
  "tags": ["docker", "permissions", "laravel"],
  "validated": true,
  "validated_at": "2026-04-24T12:00:00Z",
  "approved": false,
  "approved_by": null,
  "approved_at": null,
  "skill_path": null,
  "source": "session"
}
```

### Skill Path Convention

Lições aprovadas com tag `laravel` → `skills/laravel/`
Lições aprovadas com tag `docker` → `skills/docker/`
Lições sem tag ou multi-tag → skill genérica `learned-lesson/`

---

## 3. Arquitetura

### Estrutura de Arquivos

```
devorq_v3/
├── lib/
│   └── lessons.sh              # + lessons::approve, lessons::compile
├── skills/
│   ├── learned-lesson/         # Skill genérica para lições compiladas
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   ├── compile.sh      # Compila lição → skill
│   │   │   └── render.sh       # Gera output da lição
│   │   └── references/
│   │       └── approved/       # Lições aprovadas (raw JSON)
│   └── laravel/                # Exemplo: skill específica por stack
│       └── references/
│           └── approved/
├── .devorq/state/lessons/
│   └── captured/               # *.json (campo approved adicionado)
```

### Dependências

- `lib/lessons.sh` — captura, busca, validação existente
- `lib/context7.sh` — validação Context7
- `skills/scope-guard/` — referência para formato de skills
- `bin/devorq` — comando `devorq lessons approve`

---

## 4. Workflow Completo

### Fluxo Principal

```
[1] devorq lessons capture "título" "problema" "solução"
         ↓
[2] devorq lessons validate
         ↓ Context7 valida
    ┌────────────────────────────────┐
    │ lessons::validate retorna:     │
    │ - validated_count: N           │
    │ - skipped_count: M             │
    │ - Lista de lessons validadas   │
    └────────────────────────────────┘
         ↓
[3] Prompt automático:
    "3 lições validadas. Aprovar para skill? [Y/n]"
         ↓
[4] devorq lessons approve <id> [--skill=<name>] [--auto]
         ↓
[5] lessons::compile gera/atualiza skill
         ↓
[6] Prompt:
    "Skill 'laravel Sail permissions' gerada. Commit + push? [Y/n]"
         ↓
[7] git add + commit + push
```

### Fluxo Alternativo (Manual)

```
# Aprovar sem prompt (batch)
devorq lessons approve --all --skill=laravel --auto

# Aprovar lição específica
devorq lessons approve lesson_20260424_120000 --skill=docker

# Compilar sem aprovar (preview)
devorq lessons compile --dry-run
```

---

## 5. Implementação Técnica

### 5.1 Campo `approved` — lessons.sh

Adicionar campos ao schema JSON:

```bash
# Novo campo no capture
approved="${approved:-false}"
approved_by="${approved_by:-}"
approved_at="${approved_at:-}"
skill_path="${skill_path:-}"

# Função para marcar como approved
lessons::approve() {
    local id="${1:-}"
    local skill_name="${2:-}"
    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local file="${dir}/${id}.json"

    # Validar que existe
    [ ! -f "$file" ] && echo "Lição não encontrada: $id" && return 1

    # Verificar se validada
    if command -v jq &>/dev/null; then
        local validated
        validated=$(jq -r '.validated // false' "$file")
        [ "$validated" != "true" ] && echo "Lição precisa ser validada primeiro (Context7)" && return 1
    fi

    # Determinar skill_path
    [ -z "$skill_name" ] && skill_name=$(lessons::_infer_skill "$file")
    local skill_path="skills/${skill_name}"

    # Atualizar JSON
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if command -v jq &>/dev/null; then
        jq \
            --arg ts "$ts" \
            --arg skill_path "$skill_path" \
            --arg skill_name "$skill_name" \
            '.approved = true | .approved_at = $ts | .skill_path = $skill_path | .approved_by = "user"' \
            "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    fi

    echo "✅ Aprovada: $id → $skill_path"
}
```

### 5.2 lessons::_infer_skill — Inferir skill por tags

```bash
lessons::_infer_skill() {
    local file="$1"
    local tags=""

    if command -v jq &>/dev/null; then
        tags=$(jq -r '.tags | join(",")' "$file" 2>/dev/null || echo "")
    fi

    # Prioridade: primeira tag que corresponde a skill existente
    local skill_map="laravel,docker,postgres,mysql,git,nginx,filament"
    IFS=',' read -ra TAG_ARR <<< "$tags"
    for tag in "${TAG_ARR[@]}"; do
        [[ ",$skill_map," = *",$tag,"* ]] && echo "$tag" && return 0
    done

    # Fallback: extrair do stack
    if command -v jq &>/dev/null; then
        local stack
        stack=$(jq -r '.stack // "learned-lesson"' "$file" 2>/dev/null)
        echo "$stack"
    else
        echo "learned-lesson"
    fi
}
```

### 5.3 lessons::compile — Compilar lição → skill

```bash
lessons::compile() {
    local lesson_id="${1:-}"
    local skill_path="${2:-}"
    local dry_run="${3:-false}"

    local dir="${DEVORQ_LESSONS_DIR}/captured"
    local file="${dir}/${lesson_id}.json"

    # Ler lição
    if ! command -v jq &>/dev/null; then
        echo "[ERROR] jq necessário para compile"
        return 1
    fi

    local title problem solution tags stack
    title=$(jq -r '.title' "$file")
    problem=$(jq -r '.problem' "$file")
    solution=$(jq -r '.solution' "$file")
    tags=$(jq -r '.tags | join(", ")' "$file")
    stack=$(jq -r '.stack // ""' "$file")

    [ -z "$skill_path" ] && skill_path=$(jq -r '.skill_path // "skills/learned-lesson"' "$file")

    # Criar diretórios
    mkdir -p "${skill_path}/references/approved"
    mkdir -p "${skill_path}/scripts"

    # Copiar lição approved
    cp "$file" "${skill_path}/references/approved/${lesson_id}.json"

    # Atualizar SKILL.md se existir, ou criar
    local skill_md="${skill_path}/SKILL.md"
    if [ -f "$skill_md" ]; then
        # Adicionar entrada à seção Approved Lessons
        local entry="- **${title}**: ${problem} → ${solution} (${tags})"
        if grep -q "## Approved Lessons" "$skill_md" 2>/dev/null; then
            # Inserir antes de "##" final ou no fim
            sed -i "/## Approved Lessons/a\\$entry" "$skill_md"
        else
            echo "" >> "$skill_md"
            echo "## Approved Lessons" >> "$skill_md"
            echo "$entry" >> "$skill_md"
        fi
    else
        # Criar skill do zero
        cat > "$skill_md" << SKELLEOF
---
name: $(basename "$skill_path")
description: Use quando detectar problema relacionado a $(echo "$tags" | cut -d',' -f1)
triggers:
  - "$(echo "$problem" | cut -d' ' -f1-3)"
SKELLEOF
        cat >> "$skill_md" << SKELLEOF

# $(basename "$skill_path") — Skill Gerada

> Auto-generated from approved lesson: $lesson_id

## Problema
$problem

## Solução
$solution

## Tags
$tags

## Stack
$stack

## Approved Lessons
- **$title**: $problem → $solution ($tags)
SKELLEOF
    fi

    if [ "$dry_run" = "true" ]; then
        echo "[DRY RUN] Skill seria gerada em: $skill_path"
        echo "  Title: $title"
        echo "  Tags: $tags"
    else
        echo "✅ Skill compilada: $skill_path"
        echo "   $title"
        lessons::_update_skill_index "$skill_path"
    fi
}

lessons::_update_skill_index() {
    local skill_path="$1"
    local skill_name
    skill_name=$(basename "$skill_path")

    # Atualizar índice global de skills
    local index_file="skills/.index.md"
    local entry="- **$skill_name**: $(date +%Y-%m-%d)"

    if [ -f "$index_file" ]; then
        grep -q "$skill_name" "$index_file" || echo "$entry" >> "$index_file"
    else
        echo "# Skills Index" > "$index_file"
        echo "## Auto-generated from approved lessons" >> "$index_file"
        echo "$entry" >> "$index_file"
    fi
}
```

### 5.4 Comando `devorq lessons approve` — bin/devorq

```bash
devorq::cmd_lessons() {
    local sub="${1:-}"
    shift || true

    case "$sub" in
        capture)
            # Existing
            ;;
        search)
            # Existing
            ;;
        validate)
            # Existing
            # ADICIONAR: prompt após validate
            ;;
        approve)
            local lesson_id=""
            local skill_name=""
            local auto="false"

            while [ $# -gt 0 ]; do
                case "$1" in
                    --all)
                        auto="true"
                        shift
                        ;;
                    --skill=*)
                        skill_name="${1#*=}"
                        shift
                        ;;
                    *)
                        lesson_id="$1"
                        shift
                        ;;
                esac
            done

            if [ -z "$lesson_id" ] && [ "$auto" != "true" ]; then
                echo "Uso: devorq lessons approve <id> [--skill=<name>] [--all]"
                return 1
            fi

            if [ "$auto" = "true" ]; then
                # Aprovar todas as validadas
                local count=0
                for f in "${DEVORQ_LESSONS_DIR}/captured/"*.json; do
                    [ -f "$f" ] || continue
                    local validated
                    validated=$(jq -r '.validated // false' "$f" 2>/dev/null)
                    local approved
                    approved=$(jq -r '.approved // false' "$f" 2>/dev/null)
                    if [ "$validated" = "true" ] && [ "$approved" != "true" ]; then
                        local id
                        id=$(basename "$f" .json)
                        lessons::approve "$id" "$skill_name"
                        ((count++)) || true
                    fi
                done
                echo "Aprovadas: $count lições"
            else
                lessons::approve "$lesson_id" "$skill_name"
            fi
            ;;
        compile)
            local lesson_id=""
            local dry_run="false"

            while [ $# -gt 0 ]; do
                case "$1" in
                    --dry-run) dry_run="true"; shift ;;
                    *) lesson_id="$1"; shift ;;
                esac
            done

            if [ -z "$lesson_id" ]; then
                # Compilar todas as approved
                for f in "${DEVORQ_LESSONS_DIR}/captured/"*.json; do
                    [ -f "$f" ] || continue
                    local approved
                    approved=$(jq -r '.approved // false' "$f" 2>/dev/null)
                    if [ "$approved" = "true" ]; then
                        lessons::compile "$(basename "$f" .json)" "" "$dry_run"
                    fi
                done
            else
                lessons::compile "$lesson_id" "" "$dry_run"
            fi
            ;;
        *)
            echo "Uso: devorq lessons [capture|search|validate|approve|compile]"
            ;;
    esac
}
```

### 5.5 Auto-trigger no validate

No final de `lessons::validate`, adicionar:

```bash
# Após mostrar resultado do validate, se tiver lições validadas
if [ "$validated_count" -gt 0 ]; then
    echo ""
    read -p "[$validated_count] lições validadas. Aprovar para skill? [Y/n]: " confirm
    confirm="${confirm:-Y}"
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        devorq lessons approve --all
        echo ""
        read -p "Compilar skills? [Y/n]: " compile_confirm
        compile_confirm="${compile_confirm:-Y}"
        if [[ "$compile_confirm" =~ ^[Yy]$ ]]; then
            devorq lessons compile
        fi
    fi
fi
```

---

## 6. Integração com Skills Existentes

| Skill | Integração |
|-------|-----------|
| `scope-guard` | Lições de escopo geradas → atualizam `references/` da skill |
| `env-context` | Lições de gotchas → adicionadas à tabela em `references/laravel-filament.md` |
| `ddd-deep-domain` | Lições DDD validadas → compiladas para `skills/ddd-deep-domain/` |
| `learned-lesson` | Skill genérica fallback para lições sem tag específica |

---

## 7. Migração

### Compatibilidade com JSON existente

Lições existentes ganham novos campos com valor padrão:

```bash
# Migration: adicionar campos approved a todos os JSON existentes
for f in "${DEVORQ_LESSONS_DIR}/captured/"*.json; do
    [ -f "$f" ] || continue
    if command -v jq &>/dev/null; then
        if ! jq -e '.approved' "$f" >/dev/null 2>&1; then
            jq '.approved = false | .approved_at = null | .approved_by = null | .skill_path = null' \
                "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
            echo "Migrado: $(basename "$f")"
        fi
    fi
done
```

---

## 8. Testes

### Testes Unitários

```bash
# test_lessons_approve
cd /tmp/devorq_v3_work
mkdir -p .devorq/state/lessons/captured
cat > /tmp/test_lesson.json << 'EOF'
{
  "id": "lesson_test_001",
  "title": "Test Lesson",
  "problem": "Test problem",
  "solution": "Test solution",
  "validated": true,
  "approved": false,
  "tags": ["laravel"]
}
EOF
cp /tmp/test_lesson.json .devorq/state/lessons/captured/

# Test approve
DEVORQ_LESSONS_DIR="$(pwd)/.devorq/state/lessons" \
  lessons::approve "lesson_test_001" "laravel"

# Verify
jq '.approved, .approved_at, .skill_path' \
  .devorq/state/lessons/captured/lesson_test_001.json

# Test compile
DEVORQ_LESSONS_DIR="$(pwd)/.devorq/state/lessons" \
  lessons::compile "lesson_test_001" "" "true"  # dry-run

# Test infer
echo '{"tags": ["docker", "laravel"]}' | jq -r '.tags[0]'
# Expected: docker (primeira tag que existe como skill)
```

### Teste de Integração

```bash
# Fluxo completo
devorq lessons capture "WWWUSER fix" "Arquivos root no Sail" "WWWUSER=\$(id -u)"
devorq lessons validate
# (Context7 valida)
devorq lessons approve --all --skill=laravel
devorq lessons compile
# Verificar: skills/laravel/references/approved/lesson_*.json existe
# Verificar: skills/laravel/SKILL.md tem entrada
```

---

## 9. Rollout — Fases

### Fase 1: Core (essa spec)
- [ ] Adicionar campos `approved` ao schema JSON
- [ ] Criar `lessons::approve`
- [ ] Criar `lessons::_infer_skill`
- [ ] Criar `lessons::compile`
- [ ] Adicionar comando `devorq lessons approve`
- [ ] Adicionar comando `devorq lessons compile`
- [ ] Migration para lições existentes
- [ ] Testes unitários

### Fase 2: Auto-trigger
- [ ] Prompt após `devorq lessons validate`
- [ ] Flag `--auto` para skip prompts
- [ ] Commit + push automático (com gate de confirmação)

### Fase 3: Skill Index
- [ ] `skills/.index.md` atualizado automaticamente
- [ ] `devorq skills list` mostra skills geradas
- [ ] Integração com `devorq load`

### Fase 4: Context7 Validation Improvements
- [ ] `lessons::validate` usa `ctx7_resolve` com stack correto
- [ ] Fuzzy match: mesma solução para problemas similares
- [ ]建议 de tags automaticamente via Context7

---

## 10. Critérios de Aceitação

| # | Critério | Validação |
|---|----------|-----------|
| 1 | `lessons::approve` adiciona campos ao JSON | `jq .approved` retorna `true` |
| 2 | `lessons::compile` gera/atualiza skill | `skills/laravel/SKILL.md` existe |
| 3 | `devorq lessons approve --all` processa batch | Todas as validated viram approved |
| 4 | Tag inference funciona | `learned-lesson` se nenhuma tag bate |
| 5 | Migration não quebra lições existentes | `jq .validated` ainda funciona |
| 6 | `devorq lessons validate` trigger prompt | Output contém "Aprovar para skill?" |
| 7 | Skill compilada tem estrutura válida | SKILL.md tem YAML frontmatter |
| 8 | dry-run não modifica arquivos | Nenhum arquivo novo após `--dry-run` |
| 9 | Conflitos de JSON são tratados | Lição já approved não é duplicada |
| 10 | git commit + push funciona com token | `git log` mostra commit da skill |

---

## 11. Decisões

| Decisão | Opções | Escolha | Razão |
|---------|--------|---------|-------|
| Skill fallback | `learned-lesson` ou `misc` | `learned-lesson` | Mais descritivo |
| Batch approve | automático ou com confirmação | `--all` flag + confirmação | Segurança |
| Compile target | por lição ou todas approved | Ambos (`<id>` ou sem args) | Flexibilidade |
| Skill path | inline na lição ou inferido | Inferido por tag + fallback | Não precisa hardcode |
| Commit after compile | automático ou manual | Prompt com default Y | Permite revisão |
