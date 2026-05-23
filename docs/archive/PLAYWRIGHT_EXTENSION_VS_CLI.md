# Playwright Extension vs CLI - Guia Prático

> Comparação prática para testar CLI bash com Playwright

---

## O que você vai aprender

1. ✅ Como usar **Playwright Extension** no VS Code
2. ✅ Como usar **Playwright CLI** com Node.js
3. ✅ Diferenças práticas entre os dois
4. ✅ Quando usar cada um

---

## 1. Playwright Extension (VS Code)

### O que é?

Extensão do VS Code que permite **gravar, executar e debugar testes Playwright** diretamente no editor.

### Instalação

1. Abra VS Code
2. Pressione `Ctrl+Shift+X` (Extensions)
3. Procure por **"Playwright Test for VSCode"**
4. Clique **Install**

### Interface

```
┌────────────────────────────────────────────────────────┐
│                   VS CODE - PLAYWRIGHT                   │
├────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │ TEST EXPLORER                                    │  │
│  ├─────────────────────────────────────────────────┤  │
│  │ ▼ DEVORQ CLI Tests                               │  │
│  │   ▼ devorq                                        │  │
│  │     ✅ version                                    │  │
│  │     ✅ help                                       │  │
│  │     ⏳ init                                       │  │
│  │     ❌ gates                                     │  │
│  └─────────────────────────────────────────────────┘  │
│                                                         │
│  ▶ Run All Tests    🔴 Stop    🔄 Refresh    📊 Report │
│                                                         │
├────────────────────────────────────────────────────────┤
│ OUTPUT: 3/4 testes passaram (75%)  ⏱️ 2.5s           │
└────────────────────────────────────────────────────────┘
```

### Como Gravar Teste (Record)

1. Clique no ícone **🎬 Record** no Test Explorer
2. O browser vai abrir
3. Navegue e interaja com a página
4. Clique em **Stop Recording**
5. O código é gerado automaticamente!

### Como Executar Testes

- **Um teste:** Clique no ícone ▶️ ao lado do teste
- **Todos:** Clique em **Run All Tests**
- **Debug:** Clique em **🔴 Debug** (entra no VS Code Debugger)

### Atalhos Úteis

| Atalho | Ação |
|--------|------|
| `Ctrl+Shift+P` | Command Palette |
| Digite "Playwright" | Comandos da extensão |
| `F5` | Debug teste atual |

### Prós ✅

- Zero configuração
- Gravar testes automaticamente
- Debug visual
- Feedback rápido
- Interface intuitiva

### Contras ❌

- Funcionalidade limitada
- Sem CI/CD nativo
- Menos opções de relatórios

---

## 2. Playwright CLI (Node.js)

### O que é?

Biblioteca npm para automação de testes com **controle total** via código.

### Instalação

```bash
cd e2e-tests
npm install
npx playwright install chromium
```

### Estrutura do Projeto

```
e2e-tests/
├── playwright.config.ts    # Configurações
├── package.json
├── tests/
│   ├── devorq-cli.spec.ts   # Seus testes
│   └── ...
└── reports/                 # Relatórios HTML
```

### Como Executar

```bash
# Todos os testes
npm test

# Testes específicos
npm test -- tests/devorq-cli.spec.ts

# Modo visual (headed)
npm test -- --headed

# Modo UI (nova interface)
npm test -- --ui

# Debug interativo
npm test -- --debug

# Apenas testes que contêm "version"
npm test -- --grep "version"
```

### Relatórios

```bash
# Abrir relatório HTML
npm run report

# Gerar screenshot em falha
# (automático se configurado)
```

### Prós ✅

- Flexibilidade total
- CI/CD integration
- Relatórios detalhados
- Screenshots/Videos
- Paralelização
- Custom reporters

### Contras ❌

- Mais código para escrever
- Curva de aprendizado
- Setup manual

---

## 3. Comparação Prática

### Cenário: Testar `devorq version`

#### Com Extension (Gravar)

1. Clicar em **🎬 Record**
2. Abrir terminal
3. Digitar `devorq version`
4. Parar gravação
5. Código gerado:

```typescript
test('devorq version', async ({ page }) => {
  await page.goto('terminal');
  await page.fill('input', 'devorq version');
  await page.click('button:has-text("Run")');
  await expect(page.locator('.output')).toContainText('DEVORQ');
});
```

#### Com CLI (Escrever)

```typescript
test('devorq version', () => {
  const result = execSync('devorq version', { encoding: 'utf-8' });
  expect(result).toContain('DEVORQ');
  expect(result).toMatch(/\d+\.\d+\.\d+/);
});
```

---

## 4. Quando Usar Cada Um

### Use Extension quando:

- 🔰 Está **aprendendo** Playwright
- 🎬 Quer **gravar** testes rapidamente
- 🔍 Precisa **debugar** visualmente
- 📝 quer **prototipar** testes
- 🧪 Testes **simples** e rápidos

### Use CLI quando:

- 🚀 Precisa de **CI/CD**
- 📊 Quer **relatórios detalhados**
- 🎥 Precisa de **screenshots/videos**
- ⚡ Quer **paralelizar** testes
- 🔧 Precisa de **customização**
- 📈 Testes em **escala**

---

## 5. Estratégia Híbrida (Recomendada)

### Fase 1: Development (Extension)

```
┌─────────────────────────────────────────┐
│  1. Usar Extension para explorar        │
│  2. Gravar testes básicos               │
│  3. Verificar funcionamento rápido      │
│  4. Fazer debug visual                 │
└─────────────────────────────────────────┘
```

### Fase 2: Refinement (CLI)

```
┌─────────────────────────────────────────┐
│  1. Copiar testes para projeto CLI      │
│  2. Adicionar assertions robustas       │
│  3. Organizar em suites                 │
│  4. Adicionar fixtures                 │
└─────────────────────────────────────────┘
```

### Fase 3: Automation (CI/CD)

```
┌─────────────────────────────────────────┐
│  1. Configurar GitHub Actions          │
│  2. Adicionar relatórios                │
│  3. Screenshots on failure             │
│  4. Notificações de falha             │
└─────────────────────────────────────────┘
```

---

## 6. Para Testar CLI Bash

### Abordagem 1: Playwright Extension (Gravar)

1. Instale extensão
2. Crie arquivo de teste `.spec.ts`
3. Clique em **🎬 Record**
4. Use terminal integrado do VS Code
5. Execute `devorq version`
6. Pare gravação
7. Ajuste código gerado

### Abordagem 2: Playwright CLI (Código)

```typescript
// tests/devorq.spec.ts
import { test, expect } from '@playwright/test';
import { execSync } from 'child_process';

test('devorq version', () => {
  const result = execSync('devorq version', { encoding: 'utf-8' });
  expect(result).toContain('DEVORQ');
});

test('devorq init', () => {
  execSync('mkdir /tmp/test && cd /tmp/test && devorq init');
  expect(require('fs').existsSync('/tmp/test/.devorq')).toBe(true);
});
```

---

## 7. Execução Rápida

### Setup Completo

```bash
# 1. Entrar no diretório
cd e2e-tests

# 2. Instalar dependências
npm install

# 3. Instalar browsers
npx playwright install chromium

# 4. Executar testes
npm test
```

### Resultados

```
Running 25 tests using 1 worker

  ✓ devorq version (1.2s)
  ✓ devorq --help (0.8s)
  ✓ devorq init (1.5s)
  ✓ devorq lessons capture (2.1s)
  ...
  
  25 passed (15.3s)
```

---

## 8. Troubleshooting

### Extension não aparece

```bash
# Reiniciar VS Code
code --disable-extensions
code

# Reinstalar extensão
```

### CLI não encontra browsers

```bash
npx playwright install
```

### Testes falhando

```bash
# Ver screenshots
ls test-results/

# Ver logs
cat playwright.log

# Modo headed
npm test -- --headed
```

---

## 9. Recursos

- 📖 [Documentação Playwright](https://playwright.dev/docs/intro)
- 🎬 [Playwright Extension](https://marketplace.visualstudio.com/items?itemName=ms-playwright.test)
- 📚 [API Reference](https://playwright.dev/docs/api/class-page)
- 💬 [Discord Community](https://discord.gg/playwright)

---

## Conclusão

| Aspecto | Extension | CLI |
|---------|-----------|-----|
| **Setup** | 5 min | 15 min |
| **Curva de aprendizado** | Baixa | Média |
| **Flexibilidade** | Média | Alta |
| **CI/CD** | Não | Sim |
| **Screenshots/Videos** | Sim | Sim |
| **Record & Playback** | ✅ Sim | ❌ Não |
| **Debug Visual** | ✅ Excelente | ✅ Bom |

**Recomendação:** Use **Extension** para aprender e prototipar, **CLI** para produção e automação.

---

*Documento criado para fins educacionais - 2026-05-11*
