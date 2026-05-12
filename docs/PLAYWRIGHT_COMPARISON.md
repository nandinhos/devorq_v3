# Playwright: CLI vs Extension - Comparação Completa

> **Objetivo:** Entender as diferenças entre Playwright CLI e Playwright Extension (VS Code) para testar CLI bash.

## Visão Geral

### O que é Playwright?

**Playwright** é uma ferramenta da Microsoft para automação de navegadores (Chromium, Firefox, WebKit). Originally projetado para **testes web E2E**, mas pode ser usado para **testar interfaces de terminal** também.

---

## 1. Playwright CLI (Node.js)

### O que é?

Biblioteca Node.js/JavaScript para automação de navegadores via código.

### Instalação

```bash
npm init -y
npm install @playwright/test
npx playwright install chromium
```

### Estrutura de Projeto

```
meu-projeto/
├── playwright.config.ts      # Configurações
├── tests/                    # Testes
│   ├── example.spec.ts
│   └── terminal.spec.ts
├── package.json
└── tsconfig.json
```

### Características

✅ **Prós:**
- Flexibilidade total com código TypeScript/JavaScript
- Integração com CI/CD (GitHub Actions, Jenkins, etc)
- Relatórios detailed com screenshots/videos
- Suporte a múltiplos browsers
- Assertions integradas
- Paralelização de testes
- Hooks (beforeAll, afterAll, etc)

❌ **Contras:**
- Curva de aprendizado maior
- Mais código para escrever
- Necessita setup manual

### Exemplo de Teste CLI

```typescript
// tests/devorq-cli.spec.ts
import { test, expect } from '@playwright/test';
import { execSync } from 'child_process';
import { Terminal } from 'xterm';

test.describe('DEVORQ CLI Tests', () => {
  test('devorq version deve retornar versão', async () => {
    const result = execSync('devorq version', { encoding: 'utf-8' });
    expect(result).toContain('DEVORQ');
    expect(result).toMatch(/\d+\.\d+\.\d+/);
  });

  test('devorq help deve mostrar comandos', async () => {
    const result = execSync('devorq --help', { encoding: 'utf-8' });
    expect(result).toContain('init');
    expect(result).toContain('flow');
    expect(result).toContain('lessons');
  });

  test('devorq init deve criar estrutura', async () => {
    execSync('devorq init', { cwd: '/tmp/test-project' });
    
    const fs = require('fs');
    expect(fs.existsSync('/tmp/test-project/.devorq/state/context.json')).toBe(true);
  });
});
```

---

## 2. Playwright Extension (VS Code)

### O que é?

Extensão do VS Code que permite **gravar e executar testes Playwright diretamente no editor**.

### Instalação

1. Abra VS Code
2. Extensions (Ctrl+Shift+X)
3. Procure "Playwright"
4. Instale "Playwright Test for VSCode"

### Características

✅ **Prós:**
- **Zero config** para começar
- **Record & Playback** - grave ações e gere código automaticamente
- Interface visual no VS Code
- Depuração integrada
- Test Explorer no sidebar
- Quick Pick para executar testes específicos
- Hover sobre testes para ver resultados

❌ **Contras:**
- Funcionalidade limitada vs CLI completo
- Menos opções de configuração avançada
- Depende do VS Code

### Como Usar

1. **Gravar teste:**
   - Clique em "Record" no Test Explorer
   - Execute ações no browser
   - Pare gravação
   - Código é gerado automaticamente

2. **Executar testes:**
   - Selecione teste no Test Explorer
   - Clique "Run" ou "Debug"
   - Veja resultados inline

3. **Keyboard shortcuts:**
   - `Ctrl+Shift+P` → "Playwright: Run Tests"
   - `Ctrl+Shift+P` → "Playwright: Record Tests"

### Exemplo Visual

```
┌─────────────────────────────────────────────┐
│           PLAYWRIGHT TEST EXPLORER          │
├─────────────────────────────────────────────┤
│ ▼ DEVORQ CLI Tests                          │
│   ▶ devorq › version › deve retornar versão │
│   ▶ devorq › help › deve mostrar comandos   │
│   ▶ devorq › init › deve criar estrutura    │
│   ▶ gates › gate-1 › spec exists            │
│   ▶ gates › gate-2 › tests pass            │
├─────────────────────────────────────────────┤
│ ▶ 3/3 testes passaram (100%)  ⚡ 0.5s      │
└─────────────────────────────────────────────┘
```

---

## 3. Comparação Detalhada

### Funcionalidades

| Feature | Playwright CLI | Playwright Extension |
|---------|---------------|---------------------|
| Gravar testes | ❌ Não | ✅ Sim |
| Execução paralela | ✅ Sim | ✅ Sim |
| Screenshots | ✅ Sim | ✅ Sim |
| Videos | ✅ Sim | ✅ Sim |
| Debug | ✅ Sim | ✅ Melhor |
| CI/CD integration | ✅ Sim | ❌ Não |
| Custom reporters | ✅ Sim | ❌ Não |
| Web server | ✅ Sim | ✅ Sim |
| Mobile emulation | ✅ Sim | ✅ Sim |
| Network interception | ✅ Sim | ✅ Sim |
| Browser contexts | ✅ Sim | ✅ Sim |

### Quando Usar Cada Um

#### Use **Playwright CLI** quando:
- Precisar de **CI/CD integration**
- Testes **paralelos em escala**
- Custom reporters ou logging
- Testes de **APIs REST**
- Load testing
- Performance testing
- Relatórios detalhados

#### Use **Playwright Extension** quando:
- **Desenvolvimento rápido** de testes
- **Learning** Playwright
- Debug de testes específicos
- Testar mudanças localizada
- **TDD/BDD** com feedback rápido
- Prototipagem de testes

---

## 4. Abordagem Híbrida (Recomendada)

### Estratégia

1. **Desenvolvimento:** Use **Extension** para criar testes rapidamente
2. **Refinamento:** Mova testes para **CLI** para CI/CD
3. **Manutenção:** Use ambos conforme necessidade

### Fluxo de Trabalho

```
┌─────────────────────────────────────────────────────────┐
│                 DESENVOLVIMENTO DE TESTES                │
└─────────────────────────────────────────────────────────┘

   ┌──────────────┐
   │ Identificar   │
   │ Teste        │
   └──────┬───────┘
          │
          ▼
   ┌──────────────────────────────────────┐
   │         PLAYWRIGHT EXTENSION          │
   │  • Gravar teste                      │
   │  • Verificar no browser              │
   │  • Iterar rapidamente                 │
   └──────────────────┬───────────────────┘
                      │
                      ▼
   ┌──────────────────────────────────────┐
   │           REFATORAR TESTE             │
   │  • Adicionar assertions               │
   │  • Organizar em suites               │
   │  • Adicionar documentação             │
   └──────────────────┬───────────────────┘
                      │
                      ▼
   ┌──────────────────────────────────────┐
   │           PLAYWRIGHT CLI              │
   │  • Executar em CI/CD                  │
   │  • Relatórios detalhados              │
   │  • Screenshots/Videos                │
   └──────────────────────────────────────┘
```

---

## 5. Para Testar CLI Bash

### Abordagem 1: Playwright for Web Apps

Se você tem uma **interface web** que chama a CLI:

```typescript
// Testar interface web que chama devorq
test('web interface deve chamar devorq', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.click('button:has-text("Init")');
  await page.fill('input[name="project"]', 'meu-projeto');
  await page.click('button:has-text("Create")');
  
  // Verificar resultado
  await expect(page.locator('.status')).toContainText('Project created');
  
  // Verificar que devorq foi chamado
  const result = execSync('ls -la /tmp/meu-projeto/.devorq/');
  expect(result.toString()).toContain('context.json');
});
```

### Abordagem 2: Terminal Testing

Testar saída de comandos:

```typescript
// Testar saída de terminal
test('devorq deve mostrar help correto', async () => {
  const { spawn } = require('child_process');
  
  const result = await new Promise((resolve) => {
    const proc = spawn('devorq', ['--help']);
    let output = '';
    
    proc.stdout.on('data', (data) => {
      output += data.toString();
    });
    
    proc.on('close', () => {
      resolve(output);
    });
  });
  
  expect(result).toContain('DEVORQ');
  expect(result).toContain('init');
  expect(result).toContain('lessons');
});
```

### Abordagem 3: VS Code Extension Testing

Se você quer testar **extensão VS Code** que integra com devorq:

```typescript
// test/runTest.ts
import * as path from 'path';
import { runTests } from '@vscode/test-electron';

async function main() {
  try {
    const extensionPath = path.resolve(__dirname, '../');
    const testRunnerPath = path.join(extensionPath, 'test', 'suite', 'index.js');
    
    await runTests({
      extensionPath,
      testRunnerPath,
      launchArgs: ['--disable-extensions']
    });
  } catch (err) {
    console.error('Failed to run tests:', err);
    process.exit(1);
  }
}

main();
```

---

## 6. Conclusão

Para o **DEVORQ v3** (CLI bash), a recomendação é:

### Fase 1: Extension
- Use **Playwright Extension** para explorar e entender o sistema
- Grave testes enquanto usa devorq
- Visualize resultados rapidamente

### Fase 2: CLI
- Migre testes críticos para **Playwright CLI**
- Configure CI/CD
- Adicione relatórios e screenshots

### Fase 3: Automação
- Testes paralelos
- Relatórios customizados
- Integração com HUB

---

## Próximos Passos

1. ✅ Verificar se Playwright está instalado
2. Criar projeto de testes
3. Executar testes básicos
4. Expandir cobertura
5. Configurar CI/CD

---

*Documento criado para fins educacionais - Entendendo Playwright CLI vs Extension*
