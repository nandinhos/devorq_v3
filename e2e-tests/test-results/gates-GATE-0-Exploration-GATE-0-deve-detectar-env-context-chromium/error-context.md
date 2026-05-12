# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: gates.spec.ts >> GATE-0: Exploration >> GATE-0 deve detectar env-context
- Location: tests/gates.spec.ts:55:7

# Error details

```
Error: expect(received).toMatch(expected)

Expected pattern: /GATE/i
Received string:  ""
```

# Test source

```ts
  1   | import { test, expect, describe } from '@playwright/test';
  2   | import { execSync } from 'child_process';
  3   | import * as fs from 'fs';
  4   | import * as path from 'path';
  5   | 
  6   | /**
  7   |  * DEVORQ Gates E2E Tests
  8   |  * 
  9   |  * Testa todos os gates do sistema DEVORQ v3
  10  |  */
  11  | 
  12  | const SANDBOX = '/tmp/devorq-e2e-sandbox';
  13  | const DEVORQ_BIN = path.resolve(__dirname, '../..', 'bin/devorq');
  14  | 
  15  | function runCommand(cmd: string, cwd: string = SANDBOX): { stdout: string; stderr: string; exitCode: number } {
  16  |   // Substitui 'devorq' pelo caminho completo do projeto
  17  |   const adjustedCmd = cmd.replace(/\bdevorq\b/g, DEVORQ_BIN);
  18  |   
  19  |   try {
  20  |     const stdout = execSync(adjustedCmd, { encoding: 'utf-8', cwd });
  21  |     return { stdout, stderr: '', exitCode: 0 };
  22  |   } catch (error: any) {
  23  |     return {
  24  |       stdout: error.stdout?.toString() || '',
  25  |       stderr: error.stderr?.toString() || '',
  26  |       exitCode: error.status || 1
  27  |     };
  28  |   }
  29  | }
  30  | 
  31  | test.beforeEach(async () => {
  32  |   execSync(`rm -rf ${SANDBOX} && mkdir -p ${SANDBOX}`, { encoding: 'utf-8' });
  33  | });
  34  | 
  35  | describe('GATE-0: Exploration', () => {
  36  |   
  37  |   test('GATE-0 deve executar com intent DDD', () => {
  38  |     const projectDir = `${SANDBOX}/ddd-project`;
  39  |     fs.mkdirSync(projectDir, { recursive: true });
  40  |     runCommand('devorq init', projectDir);
  41  |     
  42  |     // Criar SPEC.md com keywords DDD
  43  |     fs.writeFileSync(
  44  |       path.join(projectDir, 'SPEC.md'),
  45  |       '# Domain Project\n\n## Vision\nDDD domain model.\n\n## Acceptance Criteria\n\n### AC-1: Domain Model\n\nGiven a user is logged in\nWhen they access the domain\nThen they see the model\n'
  46  |     );
  47  |     
  48  |     const result = runCommand('devorq gate 0', projectDir);
  49  |     
  50  |     console.log('GATE-0 DDD output:', result.stdout);
  51  |     
  52  |     expect(result.stdout).toMatch(/GATE.*0/i);
  53  |   });
  54  | 
  55  |   test('GATE-0 deve detectar env-context', () => {
  56  |     const projectDir = `${SANDBOX}/env-project`;
  57  |     fs.mkdirSync(projectDir, { recursive: true });
  58  |     runCommand('devorq init', projectDir);
  59  |     
  60  |     const result = runCommand('devorq gate 0', projectDir);
  61  |     
  62  |     console.log('GATE-0 env output:', result.stdout);
  63  |     
> 64  |     expect(result.stdout).toMatch(/GATE/i);
      |                           ^ Error: expect(received).toMatch(expected)
  65  |   });
  66  | });
  67  | 
  68  | describe('GATE-0.5: Project Foundation', () => {
  69  |   
  70  |   test('GATE-0.5 deve validar foundation docs', () => {
  71  |     const projectDir = `${SANDBOX}/foundation-project`;
  72  |     fs.mkdirSync(projectDir, { recursive: true });
  73  |     runCommand('devorq init', projectDir);
  74  |     
  75  |     // Criar foundation docs básicos
  76  |     fs.writeFileSync(
  77  |       path.join(projectDir, '.devorq/state/5w2h.json'),
  78  |       JSON.stringify({ project: 'test', what: 'test', why: 'test' }, null, 2)
  79  |     );
  80  |     
  81  |     fs.writeFileSync(
  82  |       path.join(projectDir, '.devorq/state/premissas.json'),
  83  |       JSON.stringify({ project: 'test', premissas: [] }, null, 2)
  84  |     );
  85  |     
  86  |     fs.writeFileSync(
  87  |       path.join(projectDir, '.devorq/state/riscos.json'),
  88  |       JSON.stringify({ project: 'test', riscos: [] }, null, 2)
  89  |     );
  90  |     
  91  |     fs.writeFileSync(
  92  |       path.join(projectDir, '.devorq/state/requisitos.json'),
  93  |       JSON.stringify({ project: 'test', requisitos: [] }, null, 2)
  94  |     );
  95  |     
  96  |     fs.writeFileSync(
  97  |       path.join(projectDir, '.devorq/state/restricoes.json'),
  98  |       JSON.stringify({ project: 'test', restricoes: [] }, null, 2)
  99  |     );
  100 |     
  101 |     const result = runCommand('devorq gate 0.5', projectDir);
  102 |     
  103 |     console.log('GATE-0.5 output:', result.stdout);
  104 |     
  105 |     expect(result.stdout).toMatch(/GATE.*0\.5|Foundation/i);
  106 |   });
  107 | });
  108 | 
  109 | describe('GATE-1: Spec Exists', () => {
  110 |   
  111 |   test('GATE-1 deve falhar sem SPEC.md', () => {
  112 |     const projectDir = `${SANDBOX}/no-spec`;
  113 |     fs.mkdirSync(projectDir, { recursive: true });
  114 |     runCommand('devorq init', projectDir);
  115 |     
  116 |     const result = runCommand('devorq gate 1', projectDir);
  117 |     
  118 |     console.log('GATE-1 no-spec output:', result.stdout);
  119 |     
  120 |     expect(result.stdout).toMatch(/GATE.*1|FAIL|SPEC.*not.*found/i);
  121 |   });
  122 | 
  123 |   test('GATE-1 deve passar com SPEC.md válido', () => {
  124 |     const projectDir = `${SANDBOX}/with-spec`;
  125 |     fs.mkdirSync(projectDir, { recursive: true });
  126 |     runCommand('devorq init', projectDir);
  127 |     
  128 |     fs.writeFileSync(
  129 |       path.join(projectDir, 'SPEC.md'),
  130 |       '# Test Project\n\n## Vision\n\nTest.\n\n## Acceptance Criteria\n\n- [ ] Feature 1\n'
  131 |     );
  132 |     
  133 |     const result = runCommand('devorq gate 1', projectDir);
  134 |     
  135 |     console.log('GATE-1 with-spec output:', result.stdout);
  136 |     
  137 |     expect(result.stdout).toMatch(/GATE.*1|PASS/i);
  138 |   });
  139 | 
  140 |   test('GATE-1 deve falhar com SPEC.md vazio', () => {
  141 |     const projectDir = `${SANDBOX}/empty-spec`;
  142 |     fs.mkdirSync(projectDir, { recursive: true });
  143 |     runCommand('devorq init', projectDir);
  144 |     
  145 |     fs.writeFileSync(path.join(projectDir, 'SPEC.md'), '');
  146 |     
  147 |     const result = runCommand('devorq gate 1', projectDir);
  148 |     
  149 |     console.log('GATE-1 empty-spec output:', result.stdout);
  150 |     
  151 |     expect(result.stdout).toMatch(/GATE.*1|FAIL|empty/i);
  152 |   });
  153 | });
  154 | 
  155 | describe('GATE-2: Tests Pass', () => {
  156 |   
  157 |   test('GATE-2 deve verificar estrutura', () => {
  158 |     const projectDir = `${SANDBOX}/test-project`;
  159 |     fs.mkdirSync(projectDir, { recursive: true });
  160 |     runCommand('devorq init', projectDir);
  161 |     
  162 |     fs.writeFileSync(path.join(projectDir, 'SPEC.md'), '# Test\n\n## AC\n- [ ] Test\n');
  163 |     
  164 |     const result = runCommand('devorq gate 2', projectDir);
```