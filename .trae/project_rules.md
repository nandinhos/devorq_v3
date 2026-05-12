# Diretrizes do Projeto DEVORQ v3

## Sobre Este Arquivo

Este arquivo contém as diretrizes e regras de desenvolvimento para o projeto DEVORQ v3. Todas as pessoas e agentes que trabalharem neste projeto devem seguir estas diretrizes.

---

## Diretrizes Globais

### Planejamento

- **SEMPRE** planeje antes da implementação
- Se algum requisito estiver incerto, faça perguntas de esclarecimento
- Use a `AskUserQuestionTool` quando apropriado
- Nunca assuma, sempre confirme

### Commits

- **NUNCA** adicione o Claude/Trae como coautor nos commits
- Esta é uma regra **RÍGIDA**
- Commits devem ser feitos apenas pelo autor principal do projeto

### Permissões

- Se precisar executar qualquer comando com `sudo`, peça para o usuário executar
- Nunca assuma permissões elevadas
- Sempre peça confirmação antes de ações destrutivas

### Agentes

- **NUNCA** execute mais de 3 agentes simultaneamente
- Agentes em excesso causam:
  - Sobrecarga de sistema
  - Conflitos de recursos
  - Dificuldade de debugging
  - Resultados imprevisíveis

### Perguntas

- **SEMPRE** faça perguntas ao usuário usando a `AskUserQuestionTool`
- Quando houver múltiplas abordagens válidas, pergunte qual o usuário prefere
- Se algo não estiver claro, pergunte antes de assumir

### Resolução de Problemas

Quando encontrar um problema ou bug:

1. **Pare** - Não continue sem entender o problema
2. **Pense** - Analise as possíveis causas
3. **Depure** - Use ferramentas de debug para investigar
4. **Entenda** - Identifique a causa raiz
5. **Resolva** - Implemente a correção
6. **Teste** - Verifique que a correção funciona
7. **Continue** - Retorne ao trabalho normal

---

## Diretrizes de Desenvolvimento

### Testes

Após implementar qualquer funcionalidade ou correção:

#### 1. Cobertura de Testes

- Os testes **DEVEM** cobrir a nova funcionalidade
- Os testes **DEVEM** cobrir os casos extremos relevantes
- Os testes **DEVEM** realmente validar o comportamento esperado
- Evite falsos positivos (testes que passam mas não testam corretamente)

#### 2. Execução de Testes

- **TODOS** os testes devem passar (verde) antes de realizar o commit
- Se algum teste falhar, **NÃO** faça commit até que todos passem
- Execute testes em paralelo quando fizer sentido
- Parallelização **NÃO** deve introduzir instabilidade

#### 3. Commits

Após verificar que os testes estão passando:

1. Use mensagens de commit no padrão **Conventional Commits**
2. Formato: `tipo(scope): descrição`
3. Tipos válidos:
   - `feat`: Nova funcionalidade
   - `fix`: Correção de bug
   - `docs`: Documentação
   - `test`: Testes
   - `refactor`: Refatoração
   - `perf`: Performance
   - `ci`: CI/CD
   - `chore`: Tarefas gerais

4. Envie para `origin` após o commit

### Projetos Laravel e Filament

- **SEMPRE** prefira criar arquivos através dos comandos **Artisan**
- Exemplos:
  ```bash
  php artisan make:model User
  php artisan make:controller UserController
  php artisan make:migration create_users_table
  ```
- **NUNCA** crie arquivos manualmente quando existir comando Artisan
- Isso garante:
  - Estrutura correta
  - Namespaces corretos
  - Registro automático
  - Consistência com o framework

### Projetos Bash/Puro

- Use `shellcheck` para validar scripts bash
- Sigra convenções de nomenclatura
- Adicione comentários quando necessário
- Mantenha scripts simples e legíveis

---

## Estrutura de Diretórios do Projeto

```
devorq_v3/
├── bin/                    # CLI entry point
├── lib/                    # Bibliotecas/modules
├── skills/                 # Skills do ecossistema
├── scripts/               # Scripts auxiliares
├── tests/                  # Testes (se aplicável)
├── docs/                   # Documentação
├── .devorq/              # Estado local (não versionar)
└── .trae/                # Configurações do Trae
    └── project_rules.md   # Este arquivo
```

---

## Workflow de Desenvolvimento

### 1. Nova Funcionalidade

```
1. Planejar → Perguntas → Entender requisitos
2. Implementar → Desenvolver código
3. Testar → Executar testes
4. Se testes falham → Corrigir → Voltar ao passo 3
5. Se testes passam → Commitar → Enviar para origin
```

### 2. Correção de Bug

```
1. Identificar → Entender o problema
2. Criar teste → Que reproduza o bug
3. Corrigir → Implementar solução
4. Verificar → Teste agora passa?
5. Se passa → Commitar → Enviar para origin
6. Se falha → Voltar ao passo 3
```

### 3. Refatoração

```
1. Identificar → O que precisa refatorar
2. Planejar → Como refatorar sem quebrar
3. Executar → Refatorar
4. Testar → Todos os testes passam?
5. Se passam → Commitar → Enviar para origin
6. Se falham → Corrigir → Voltar ao passo 3
```

---

## Configuração de Ambiente

### Dependências Obrigatórias

- Bash 5.0+
- Git
- jq 1.7+ (opcional, mas recomendado)
- Node.js 18+ (para testes E2E)

### Dependências Opcionais

- SSH (para conexão com HUB VPS)
- PostgreSQL client (para sync)
- Python3 (para scripts auxiliares)

---

## Boas Práticas

### Código

- Mantenha funções pequenas e focadas
- Uma função = uma responsabilidade
- Evite código duplicado
- Use nomes descritivos
- Comente código complexo (não óbvio)

### Git

- Commits atômicos (uma mudança por commit)
- Mensagens claras e descritivas
- Branches descritivas
- Merge via Pull Requests

### Documentação

- Documente decisões de design
- Mantenha README atualizado
- Adicione exemplos quando necessário
- Documente APIs públicas

### Performance

- Otimize apenas quando necessário
- Meça antes de otimizar
- Evite otimização prematura
- Priorize legibilidade

---

## Recursos

### Documentação

- [SPEC.md](file:///home/nandodev/projects/devorq_v3/SPEC.md) - Especificação do sistema
- [README.md](file:///home/nandodev/projects/devorq_v3/README.md) - Visão geral
- [docs/](file:///home/nandodev/projects/devorq_v3/docs/) - Documentação adicional

### Testes

- [e2e-tests/](file:///home/nandodev/projects/devorq_v3/e2e-tests/) - Testes E2E
- [scripts/e2e-test.sh](file:///home/nandodev/projects/devorq_v3/scripts/e2e-test.sh) - Script de testes E2E
- [scripts/ci-test.sh](file:///home/nandodev/projects/devorq_v3/scripts/ci-test.sh) - Testes CI

### Skills

- [skills/](file:///home/nandodev/projects/devorq_v3/skills/) - Skills do ecossistema

---

## Contato

- **Autor:** Fernando Dos Santos (Nando)
- **Email:** nando@devorq.com
- **GitHub:** https://github.com/nandinhos/devorq_v3

---

## Última Atualização

**Versão:** 1.0.0  
**Data:** 2026-05-12  
**Status:** Ativo

---

*Este documento deve ser seguido por todas as pessoas e agentes que trabalharem no projeto DEVORQ v3.*
