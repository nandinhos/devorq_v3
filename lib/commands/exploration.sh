#!/usr/bin/env bash
# lib/commands/exploration.sh — DEVORQ Exploration Commands
#
# Comandos: scope, ddd, env, spec, unify
#
# Estrutura modular extraída de bin/devorq

set -euo pipefail

# ============================================================
# HELP
# ============================================================

exploration::help() {
    cat << 'EOF'
EXPLORATION COMMANDS:
  scope validate <arquivo>     Validar contrato de escopo
  scope template [tipo]        Template de escopo (laravel|filament|default)
  scope lite "<intent>"        Contrato mínimo FAZER/NÃO FAZER/VERIFICAR
  ddd explore|validate       Workshop DDD
  env detect                  Detectar ambiente
  spec validate|template     Validar SPEC.md
  unify [feature] [--auto]    Fase UNIFY
EOF
}

# ============================================================
# scope
# ============================================================

devorq::cmd_scope() {
    local sub="${1:-}"
    local scope_root="${DEVORQ_ROOT}/skills/scope-guard"

    case "$sub" in
        validate)
            local contract="${2:-}"
            [ -z "$contract" ] && devorq::error "Uso: devorq scope validate <arquivo.md>"
            local validator="${scope_root}/scripts/scope-validate.sh"
            if [ ! -f "$validator" ]; then
                devorq::error "scope-validate.sh nao encontrado"
            fi
            if bash "$validator" "$contract"; then
                devorq::success "Contrato valido"
                return 0
            else
                devorq::fail "Contrato incompleto"
                return 1
            fi
            ;;
        template)
            local type="${2:-default}"
            devorq::info "Template de contrato de escopo:"
            echo ""
            case "$type" in
                laravel)
                    cat << 'EOFTEMPLATE'
# CONTRATO DE ESCOPO — [nome-da-feature]

## IDENTIFICAÇÃO
- **Task**: [resumo da feature]
- **Tipo**: feature | bugfix | refactor
- **Complexidade**: baixa | media | alta
- **Stack**: Laravel 11 + Filament v5

## 1. FAZER
1. [ ] Criar Migration
2. [ ] Criar Model com fillable/casts/relationships
3. [ ] Criar Service ou Action (logica de negocio)
4. [ ] Criar Policy (se aplicavel)
5. [ ] Criar Resource Filament
6. [ ] Criar testes (Feature ou Unit)

## 2. NAO FAZER
1. NAO modificar migrations existentes (criar nova)
2. NAO colocar logica no Controller (usar Service/Action)
3. NAO hardcodar strings (usar lang())
4. NAO commitar se `php artisan test` falhar
5. NAO ignorar `composer.lock` mudou apos `git pull`

## 3. ARQUIVOS
- database/migrations/
- app/Models/
- app/Services/ ou app/Actions/
- app/Policies/
- app/Filament/Resources/
- tests/Feature/

## 4. DONE_CRITERIA
- [ ] Migration executa sem erro
- [ ] Model: fillable, casts, relationships definidos
- [ ] Resource Filament carrega em /admin
- [ ] Policy permite/nega acesso corretamente
- [ ] `php artisan test --filter=NomeDaFeature` passa
- [ ] `./vendor/bin/pint --test` sem violacoes
EOFTEMPLATE
                    ;;
                filament)
                    cat << 'EOFFILAMENT'
# CONTRATO DE ESCOPO — [nome-do-resource]

## IDENTIFICAÇÃO
- **Task**: [nome do Resource]
- **Tipo**: feature | refactor
- **Complexidade**: baixa | media | alta
- **Stack**: Filament v5

## 1. FAZER
1. [ ] Criar/editar Model (fillable, casts, relationships)
2. [ ] Criar Resource com schema de formulario
3. [ ] Criar RelationManagers (se relacionamentos)
4. [ ] Definir header actions (Create, Edit, Delete)
5. [ ] Definir table columns
6. [ ] Verificar getTitle(), getLabel(), getNavigationLabel()
7. [ ] Adicionar testes Feature

## 2. NAO FAZER
1. NAO usar `$formSchema` (v5 = Infolists)
2. NAO criar logica de negocio no Resource (usar Service/Action)
3. NAO esquecer `canAccessRecord()` se usar Policies
4. NAO ignorar ordem de tabs se usar Tab layout

## 3. ARQUIVOS
- app/Filament/Resources/[Nome]Resource.php
- app/Filament/Resources/[Nome]Resource/
- app/Models/[Model].php
- app/[Services|Actions]/
- tests/Feature/Filament/[Nome]ResourceTest.php

## 4. DONE_CRITERIA
- [ ] Resource acessible em /admin/[route-name]
- [ ] List page: table columns renderizam
- [ ] Create page: form submete sem erro
- [ ] Edit page: carrega dados existentes
- [ ] Delete: funciona com confirmation
- [ ] RelationManagers: carregam dados relacionados
- [ ] `php artisan test --filter=[Nome]Resource` passa
EOFFILAMENT
                    ;;
                *)
                    cat << 'EOFDEFAULT'
# CONTRATO DE ESCOPO — [nome-da-task]

## IDENTIFICAÇÃO
- **Task**: [resumo]
- **Tipo**: feature | bugfix | refactor
- **Complexidade**: baixa | media | alta

## 1. FAZER
1. [funcionalidade especifica]

## 2. NAO FAZER
1. [o que NAO fazer]

## 3. ARQUIVOS
- caminho/arquivo.ext

## 4. DONE_CRITERIA
- [ ] [criterio verificavel]
EOFDEFAULT
                    ;;
            esac
            ;;
        lite)
            local intent="${2:-}"
            if [ -z "$intent" ]; then
                devorq::error "Uso: devorq scope lite \"<intent>\""
            fi
            devorq::info "Contrato lite — preencha mentalmente antes de codar:"
            echo ""
            echo "# ESCOPO LITE — ${intent}"
            echo ""
            echo "## FAZER (só isto)"
            echo "1. [ ] ..."
            echo ""
            echo "## NÃO FAZER"
            echo "1. Refatorar código adjacente"
            echo "2. Features não pedidas"
            echo ""
            echo "## VERIFICAR (success criteria)"
            echo "1. [ ] ..."
            echo ""
            devorq::info "Para contrato completo: devorq scope template"
            devorq::info "Regras: devorq rules help agent-discipline"
            ;;
        *)
            devorq::info "Scope-Guard — Contrato de Escopo"
            echo ""
            devorq::info "Use: devorq scope lite \"<intent>\""
            devorq::info "     devorq scope validate <arquivo.md>"
            devorq::info "     devorq scope template"
            ;;
    esac
}

# ============================================================
# ddd
# ============================================================

devorq::cmd_ddd() {
    local sub="${1:-}"
    local ddd_root="${DEVORQ_ROOT}/skills/ddd-deep-domain"

    case "$sub" in
        explore)
            devorq::info "DDD Domain Workshop — pressione Ctrl+C para sair"
            echo ""
            devorq::info "Carregue a skill: hermes load ddd-deep-domain"
            devorq::info "Ou leia: ${ddd_root}/SKILL.md"
            echo ""
            devorq::info "Referencias: ${ddd_root}/references/domain-questions.md"
            devorq::info "Validador:  ${ddd_root}/scripts/ddd-validate-spec.sh"
            ;;
        validate)
            local validator="${ddd_root}/scripts/ddd-validate-spec.sh"
            if [ ! -f "$validator" ]; then
                devorq::error "ddd-validate-spec.sh nao encontrado"
            fi
            if bash "$validator"; then
                devorq::success "SPEC.md tem modelo mental valido"
                return 0
            else
                devorq::fail "SPEC.md nao tem alma (entidades, contextos, invariantes)"
                return 1
            fi
            ;;
        *)
            devorq::error "Uso: devorq ddd explore|validate"
            ;;
    esac
}

# ============================================================
# env
# ============================================================

devorq::cmd_env() {
    local sub="${1:-detect}"

    case "$sub" in
        detect)
            local env_root="${DEVORQ_ROOT}/skills/env-context"
            local env_detect="${env_root}/scripts/env-detect.sh"
            if [ ! -f "$env_detect" ]; then
                devorq::error "env-detect.sh nao encontrado em ${env_root}"
            fi
            bash "$env_detect"
            ;;
        *)
            devorq::error "Uso: devorq env detect"
            ;;
    esac
}

# ============================================================
# spec
# ============================================================

devorq::cmd_spec() {
    local sub="${1:-}"

    if [ -z "$sub" ]; then
        devorq::error "Uso: devorq spec validate|template|check-ac"
    fi

    source "${DEVORQ_LIB}/spec.sh" 2>/dev/null || {
        devorq::error "lib/spec.sh nao encontrado"
    }

    case "$sub" in
        validate)
            shift
            spec::validate "$@"
            ;;
        template)
            shift
            local feature="${1:-new-feature}"
            local output="${2:-SPEC.md}"
            spec::template "$feature" "$output"
            ;;
        check-ac)
            spec::check_ac
            ;;
        *)
            devorq::error "Uso: devorq spec validate|template|check-ac"
            ;;
    esac
}

# ============================================================
# unify
# ============================================================

devorq::cmd_unify() {
    local feature="${1:-}"
    local auto=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --auto) auto="--auto"; shift ;;
            --lessons) auto="--lessons"; shift ;;
            -*) shift ;;
            *) feature="$1"; shift ;;
        esac
    done

    source "${DEVORQ_LIB}/unify.sh" 2>/dev/null || {
        devorq::error "lib/unify.sh nao encontrado"
    }

    unify::run "$feature" "$auto"
}
