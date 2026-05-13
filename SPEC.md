# DEVORQ v3.6.0 — Specification

> **Princípio de auto-construção:** o DEVORQ constrói a si mesmo.
> Sistema operacional → usa-se para construir a si mesmo → refina → cresce.

**Versão:** 3.6.0 | **Atualizado:** 2026-05-13

---

## 1. Visão

**O que é:** Framework bash puro para metodologia de desenvolvimento sistemático.

**Funcionalidades principais:**
- Captura lições aprendidas (nunca mais o mesmo erro)
- Impõe gates bloqueantes (disciplina)
- Gera handoffs consistentes entre sessões e agentes
- Sistema de testes E2E para garantir qualidade
- Code review automatizado

**O que não é:** Uma aplicação web, plataforma fullstack, ou sistema de gerenciamento de projetos.

**Stack:**
- Bash 5+ (puro shell, sem dependências externas obrigatórias)
- jq 1.7+ (binary estático em ~/bin quando sem apt)
- Git
- SSH (para comunicação com HUB remoto via SSH mux)
- Node.js 18+ (para testes E2E opcionais)
- Playwright (para testes E2E opcionais)

**Filosofia:** O computador faz o trabalho repetitivo. O developer foca em decisões.

---

## 2. Arquitetura

### Estrutura de Diretórios

```
devorq_v3/
├── bin/
│   └── devorq                      # CLI entry point (source libs)
├── lib/
│   ├── commands/                    # Módulos de comandos CLI
│   │   ├── workflow.sh            # init, test, flow, gate
│   │   ├── lessons.sh            # capture, search, validate, approve, compile
│   │   ├── context.sh            # context, compact
│   │   ├── exploration.sh        # scope, ddd, env, spec, unify
│   │   ├── foundation.sh         # foundation
│   │   ├── integration.sh        # sync, vps, context7
│   │   ├── utils.sh             # version, upgrade, uninstall, build, stats
│   │   ├── skills.sh            # skills
│   │   ├── debug.sh             # debug
│   │   └── execution.sh         # mode, auto, review
│   ├── lessons.sh              # lessons core logic
│   ├── gates.sh                # 7+ gates bloqueantes
│   ├── compact.sh              # handoff JSON
│   ├── context.sh              # ctx_lint|stats|pack|merge|set|clear
│   ├── context7.sh            # ctx7_check|search|resolve|compare
│   ├── debug.sh                # debug::check + devorq::debug (4 fases)
│   ├── stats.sh                # stats::run — métricas de uso
│   ├── vps.sh                  # vps::check|exec|pg_exec (SSH mux)
│   ├── auto.sh                # AUTO mode (story-by-story)
│   ├── spec.sh                # SPEC validation
│   └── unify.sh               # UNIFY phase
├── skills/                     # Skills do ecossistema
│   ├── project-foundation/    # 5W2H, Premissas, Riscos, Requisitos, Restrições
│   ├── env-context/           # Detecção automática de ambiente
│   ├── scope-guard/          # Contrato de escopo
│   ├── ddd-deep-domain/       # Domain-Driven Design
│   ├── devorq-auto/          # Modo autônomo
│   ├── devorq-mode/          # Seletor AUTO/CLASSIC
│   ├── devorq-code-review/   # Code review multi-agente
│   └── learned-lesson/        # Skills geradas de lições
├── scripts/
│   ├── sync-push.py          # local → HUB PostgreSQL
│   ├── sync-pull.py           # HUB PostgreSQL → local
│   ├── ci-test.sh            # Testes CI/CD
│   ├── e2e-test.sh          # Testes E2E bash
│   ├── validate-rules.sh      # Validação de diretrizes
│   └── cleanup-bin.sh         # Script de refatoração modular
├── e2e-tests/                # Testes E2E Playwright
│   ├── playwright.config.ts   # Configuração Playwright
│   ├── package.json          # Dependências Node.js
│   ├── tests/               # Suítes de testes
│   │   ├── debug.spec.ts     # Testes de debug
│   │   ├── devorq-cli.spec.ts # Testes de CLI
│   │   ├── gates.spec.ts     # Testes de gates
│   │   └── lessons.spec.ts   # Testes de lessons
│   └── reports/             # Relatórios de testes
├── .github/
│   └── workflows/
│       └── ci.yml           # CI/CD GitHub Actions
├── docs/                     # Documentação adicional
│   ├── SYSTEM_LEVANTAMENTO.md # Levantamento completo do sistema
│   ├── MELHORIAS_V3.md       # Melhorias e testes E2E
│   ├── REFATORACAO_PLANO.md  # Plano de refatoração
│   ├── PLANO_CORRECAO_CODE_REVIEW.md # Plano de correção
│   ├── COMPORTAMENTO_ESPERADO.md # Comportamento esperado
│   └── CODE_REVIEW_COMPLETO.md # Code review completo
├── .devorq/                  # Estado local (NÃO COMMITEAR)
│   ├── state/
│   │   ├── context.json     # Contexto atual do projeto
│   │   ├── session.json    # Dados da sessão corrente
│   │   ├── handoff.json   # Handoff para próxima sessão
│   │   └── lessons/       # Lições capturadas localmente
│   │       └── captured/   # Lições locais
│   ├── skills/             # Skills geradas
│   └── rules/              # Regras específicas
├── .trae/
│   └── project_rules.md     # Diretrizes do projeto
├── .devorq.bak/            # Backup antes de refatoração
├── SPEC.md                  # Esta especificação
├── README.md                # Visão geral + quick start
├── INSTALL.md               # Guia de instalação
├── EXTRAS.md                # Context-Mode, Context7, HUB, Self-Building
├── VERSION                  # Versão atual
└── prd.json                 # Product Requirements Document
```

---

## 3. Sistema de Gates

Cada gate é verde ou vermelho. **Vermelho = para e corrige.**

### Gates Implementados

```
┌────────┬────────────────────────┬──────────────────────────────────────────┐
│ GATE   │ NOME                    │ CRITÉRIO                                 │
├────────┼────────────────────────┼──────────────────────────────────────────┤
│ GATE-0 │ Exploration           │ Skills carregadas (opcional)              │
│ GATE-0.5│ Project Foundation  │ 5W2H, Premissas, Riscos, Requisitos     │
│ GATE-1 │ Spec Exists          │ SPEC.md existe e não está vazio          │
│ GATE-2 │ Tests Pass           │ devorq test passa (estrutura OK)        │
│ GATE-3 │ Context Documented   │ devorq context mostra estado válido      │
│ GATE-4 │ Lessons Reviewed     │ devorq lessons search encontrou lições  │
│ GATE-5 │ Handoff Ready       │ devorq compact gera JSON válido          │
│ GATE-5.5│ UNIFY              │ Fase de fechamento (aviso)              │
│ GATE-6 │ Context7 Checked    │ docs consultadas (sempre passa — WARN OK)│
│ GATE-7 │ Systematic Debug    │ se erro: devorq debug antes de continuar │
└────────┴────────────────────────┴──────────────────────────────────────────┘
```

### Status dos Gates

| Gate | Status | Bloqueante |
|------|--------|------------|
| GATE-0 | ✅ Implementado | Não |
| GATE-0.5 | ✅ Implementado | Sim |
| GATE-1 | ✅ Implementado | Sim |
| GATE-2 | ✅ Implementado | Sim |
| GATE-3 | ✅ Implementado | Sim |
| GATE-4 | ✅ Implementado | Sim |
| GATE-5 | ✅ Implementado | Sim |
| GATE-5.5 | ✅ Implementado | Não |
| GATE-6 | ✅ Implementado | Não |
| GATE-7 | ✅ Implementado | Reativo |

**Nota:** GATE-6 é especial: Nunca bloqueia. É um aviso para consultar documentação. Mesmo que a API Context7 falhe ou esteja offline, GATE-6 passa.

**Nota:** GATE-7 é reativo: Só entra em ação quando há erro. Se não há erro, GATE-7 é ignorado.

---

## 4. Módulos de Comandos

### Comandos CLI Implementados

| Módulo | Comandos | Status |
|--------|----------|--------|
| workflow.sh | init, test, flow, gate | ✅ |
| lessons.sh | capture, search, validate, approve, compile, list, migrate | ✅ |
| context.sh | context, compact | ✅ |
| exploration.sh | scope, ddd, env, spec, unify | ✅ |
| foundation.sh | foundation | ✅ |
| integration.sh | sync, vps, context7 | ✅ |
| utils.sh | version, upgrade, uninstall, build, stats | ✅ |
| skills.sh | skills | ✅ |
| debug.sh | debug | ✅ |
| execution.sh | mode, auto, review | ✅ |

**Total de comandos:** 45+

---

## 5. Sistema de Lições Aprendidas

### Schema JSON

```json
{
  "id": "lesson_20260422_143000_12345",
  "title": "Breve título descritivo do problema",
  "problem": "Descrição clara do problema encontrado",
  "solution": "Passo-a-passo da solução aplicada",
  "stack": ["bash", "jq", "postgresql"],
  "tags": ["devorq", "container", "docker-rootless"],
  "project": "devorq_v3",
  "source_file": "lib/lessons.sh",
  "validated": false,
  "validated_at": null,
  "approved": false,
  "compiled": false,
  "skill_name": null,
  "metadata": {}
}
```

### Flags de Estado

| Flag | Significado |
|------|-------------|
| `validated: false` | Precisa de validação manual ou via Context7 |
| `validated: true` | Revisada — solução confirmada |
| `approved: false` | Pendente de aprovação para skill |
| `approved: true` | Aprovada para virar skill |
| `compiled: false` | Não compilada em skill |
| `compiled: true` | Compilada em skill |

---

## 6. Testes

### Suite de Testes CI

```bash
bash scripts/ci-test.sh
# Resultado: 38/38 tests passing
```

### Testes E2E Playwright

```bash
cd e2e-tests
npm test
# Testes de CLI, gates, lessons, context
```

### Cobertura de Testes

| Tipo | Quantidade | Status |
|------|-----------|--------|
| CI Tests | 38 | ✅ |
| E2E Tests | 50+ | ✅ |
| shellcheck | - | ⚠️ Pending |

---

## 7. Fases de Desenvolvimento

### Status das Fases

```
FASE 1  ████████████████████  100%  ✅  Core bash + gates + lessons
FASE 2a ████████████████████  100%  ✅  PostgreSQL schema devorq.*
FASE 2b ████████████████████  100%  ✅  Sync push/pull Python scripts
FASE 3  ████████████████████  100%  ✅  Context-Mode (lib/context.sh)
FASE 4  ████████████████████  100%  ✅  Context7 integration (lib/context7.sh)
FASE 5  ████████████████████  100%  ✅  Systematic debug (lib/debug.sh)
FASE 6  ████████████████████  100%  ✅  Documentação (README+INSTALL+EXTRAS)
FASE 7  ████████████████████  100%  ✅  Self-building (build+upgrade+uninstall)
FASE 8  ████████████████████  100%  ✅  Meta-stats (devorq stats)
FASE 9  ████████████████████  100%  ✅  Refatoração modular (lib/commands/)
FASE 10 ████████████████████  100%  ✅  Testes E2E (Playwright)
FASE 11 ███░░░░░░░░░░░░░░░░  25%  🔄  Code Review (correções)
```

### Fase Atual: Code Review e Correções

**Status:** Em andamento

**Objetivos:**
1. Corrigir vulnerabilidades de segurança críticas
2. Padronizar nomenclatura
3. Aumentar cobertura de testes
4. Implementar tratamento de erros consistente

**Problemas Identificados no Code Review:**

#### Críticos (Devem ser corrigidos antes de produção)
| # | Problema | Severidade | Módulo |
|---|----------|------------|---------|
| 1 | Credenciais expostas em variáveis | 🔴 CRÍTICA | Segurança |
| 2 | SSH sem validação de host | 🔴 CRÍTICA | VPS |
| 3 | Injeção de comando | 🔴 CRÍTICA | Input validation |
| 4 | Path traversal | 🔴 CRÍTICA | File handling |

#### Altos (Devem ser corrigidos em breve)
| # | Problema | Severidade | Módulo |
|---|----------|------------|---------|
| 5 | Nomenclatura inconsistente | 🔴 ALTA | Código |
| 6 | Exit codes inconsistentes | 🔴 ALTA | Erro handling |
| 7 | Validação de input ausente | 🔴 ALTA | Input validation |
| 8 | shellcheck warnings | 🟡 MÉDIA | Código |

---

## 8. DEV-MEMORY HUB (repo separado: dev-memory-laravel)

```
VPS srv163217:6985
├── PostgreSQL
│   ├── devorq.lessons    (id, title, problem, solution, stack[], tags[], embedding, project, source, validated, applied, validated_at, metadata, created_at, updated_at)
│   ├── devorq.memories   (id, project, content, tags[], embedding, metadata, created_at, updated_at)
│   ├── devorq.sessions   (id, project, started_at, ended_at, handoff_id, summary)
│   └── devorq.handoffs   (id, from_agent, to_agent, context, created_at)
└── dev-memory-laravel    (interface web — repo separado)
```

**Acesso PostgreSQL:**
```bash
ssh -p 6985 root@187.108.197.199 "docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study -c 'SELECT * FROM devorq.lessons LIMIT 5;'"
```

---

## 9. Diretrizes de Desenvolvimento

### Diretrizes Globais

1. **Planejamento** - Sempre planeje antes da implementação
2. **Comunicação** - Use `AskUserQuestionTool` para perguntas
3. **Commits** - Nunca adicione Claude como coautor
4. **Permissões** - Peça para executar sudo
5. **Agentes** - Máximo 3 agentes simultâneos
6. **Metodologia** - Problema → Pense → Depure → Entenda → Resolva → Teste → Continue

### Diretrizes de Código

1. **Testes** - Cobertura completa após implementação
2. **Validação** - Todos os testes devem passar (verde)
3. **Commits** - Conventional Commits em português
4. **Commits** - Aguardar validação manual antes de fazer
5. **Commits** - Sem emojis
6. **Commits** - Sem co-autoria
7. **Laravel** - Use Artisan para criar arquivos

### Formato de Commits

```
tipo(escopo): descrição em português

Exemplos:
feat(gates): implementa gate 0.5 com validacao foundation
fix(lessons): corrige captura em projetos novos
docs(arquitetura): adiciona documentacao da arquitetura
test(gates): implementa testes e2e para gates
```

---

## 10. Critérios de Qualidade

### Code Review (2026-05-13)

| Aspecto | Pontuação | Status |
|---------|----------|--------|
| Estrutura | 7/10 | ⚠️ OK |
| Qualidade de Código | 5/10 | ❌ PRECISA MELHORAR |
| Performance | 7/10 | ⚠️ OK |
| Segurança | 6/10 | ❌ PRECISA MELHORAR |
| Testes | 6/10 | ⚠️ PRECISA MELHORAR |
| Documentação | 7/10 | ⚠️ OK |
| Manutenibilidade | 6/10 | ❌ PRECISA MELHORAR |

**Veredicto:** ⚠️ **APROVADO COM RESSALVAS**

O sistema funciona e atende aos requisitos básicos, mas possui **múltiplas áreas críticas** que precisam de atenção antes de produção.

### Metas de Qualidade

| Métrica | Atual | Meta |
|---------|-------|------|
| Testes CI | 38/38 | 38/38 ✅ |
| Testes E2E | 50+/50+ | 100% |
| Cobertura | ~40% | > 80% |
| shellcheck | ⚠️ Warnings | 0 warnings |
| Code smells | ⚠️ 30+ | < 10 |
| Vulnerabilidades | 4 críticas | 0 |

---

## 11. Próximos Passos

### Imediato (Esta semana)
1. Corrigir vulnerabilidades de segurança críticas (#1-#4)
2. Implementar validação de inputs em todas funções
3. Padronizar nomenclatura de funções

### Curto prazo (2 semanas)
1. Aumentar cobertura de testes para 60%+
2. Corrigir todos shellcheck warnings
3. Implementar tratamento de erros consistente

### Médio prazo (1 mês)
1. Refatorar funções muito longas
2. Adicionar docblocks em todas funções
3. Atualizar toda documentação

---

## 12. Recursos

### Documentação
- [README.md](file:///home/nandodev/projects/devorq_v3/README.md) - Visão geral
- [INSTALL.md](file:///home/nandodev/projects/devorq_v3/INSTALL.md) - Guia de instalação
- [EXTRAS.md](file:///home/nandodev/projects/devorq_v3/EXTRAS.md) - Features extras

### Análises
- [docs/CODE_REVIEW_COMPLETO.md](file:///home/nandodev/projects/devorq_v3/docs/CODE_REVIEW_COMPLETO.md) - Code review completo
- [docs/COMPORTAMENTO_ESPERADO.md](file:///home/nandodev/projects/devorq_v3/docs/COMPORTAMENTO_ESPERADO.md) - Comportamento esperado
- [docs/PLANO_CORRECAO_CODE_REVIEW.md](file:///home/nandodev/projects/devorq_v3/docs/PLANO_CORRECAO_CODE_REVIEW.md) - Plano de correção

### Testes
- [scripts/ci-test.sh](file:///home/nandodev/projects/devorq_v3/scripts/ci-test.sh) - Testes CI
- [e2e-tests/](file:///home/nandodev/projects/devorq_v3/e2e-tests/) - Testes E2E

---

## 13. Changelog

### v3.6.0 (2026-05-13)
- ✅ Refatoração modular completa (10 módulos em lib/commands/)
- ✅ Sistema de testes E2E com Playwright
- ✅ Diretrizes de desenvolvimento (.trae/project_rules.md)
- ✅ Code review completo realizado
- 🔄 Correções de code review em andamento

### v3.5.0 (2026-05-09)
- ✅ Sistema de gates expandido (GATE-0, GATE-0.5)
- ✅ Skills do ecossistema
- ✅ Project Foundation docs

### v3.4.0 (2026-05-08)
- ✅ AUTO mode (story-by-story)
- ✅ UNIFY phase
- ✅ DDD integration

### v3.3.0 (2026-05-07)
- ✅ VPS HUB integration
- ✅ Sync push/pull
- ✅ PostgreSQL schema

### v3.2.0 (2026-05-06)
- ✅ Lessons learned system
- ✅ Context7 integration
- ✅ Systematic debug

### v3.1.0 (2026-05-05)
- ✅ Core CLI
- ✅ 7 gates bloqueantes
- ✅ Handoff system

---

*Documento mantido sob controle de versão*
*Última atualização: 2026-05-13*
