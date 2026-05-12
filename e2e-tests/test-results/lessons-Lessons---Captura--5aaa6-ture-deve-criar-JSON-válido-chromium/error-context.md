# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: lessons.spec.ts >> Lessons - Captura >> devorq lessons capture deve criar JSON válido
- Location: tests/lessons.spec.ts:60:7

# Error details

```
Error: ENOENT: no such file or directory, scandir '/tmp/devorq-e2e-sandbox/capture-json-project/.devorq/state/lessons/captured'
```

# Test source

```ts
  1   | import { test, expect, describe } from '@playwright/test';
  2   | import { execSync } from 'child_process';
  3   | import * as fs from 'fs';
  4   | import * as path from 'path';
  5   | 
  6   | /**
  7   |  * DEVORQ Lessons E2E Tests
  8   |  * 
  9   |  * Testa funcionalidades de lições aprendidas
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
  35  | describe('Lessons - Captura', () => {
  36  |   
  37  |   test('devorq lessons capture deve criar arquivo JSON', () => {
  38  |     const projectDir = `${SANDBOX}/capture-project`;
  39  |     fs.mkdirSync(projectDir, { recursive: true });
  40  |     runCommand('devorq init', projectDir);
  41  |     
  42  |     const result = runCommand(
  43  |       'devorq lessons capture "Docker install" "Docker not found" "Use apt-get install docker.io"',
  44  |       projectDir
  45  |     );
  46  |     
  47  |     console.log('Capture output:', result.stdout);
  48  |     
  49  |     expect(result.stdout).toMatch(/lesson|Lição|saved/i);
  50  |     
  51  |     // Verificar arquivo criado
  52  |     const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
  53  |     if (fs.existsSync(lessonsDir)) {
  54  |       const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
  55  |       console.log('Lessons files:', files);
  56  |       expect(files.length).toBeGreaterThan(0);
  57  |     }
  58  |   });
  59  | 
  60  |   test('devorq lessons capture deve criar JSON válido', () => {
  61  |     const projectDir = `${SANDBOX}/capture-json-project`;
  62  |     fs.mkdirSync(projectDir, { recursive: true });
  63  |     runCommand('devorq init', projectDir);
  64  |     
  65  |     runCommand(
  66  |       'devorq lessons capture "Test lesson" "Test problem" "Test solution"',
  67  |       projectDir
  68  |     );
  69  |     
  70  |     const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
> 71  |     const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
      |                      ^ Error: ENOENT: no such file or directory, scandir '/tmp/devorq-e2e-sandbox/capture-json-project/.devorq/state/lessons/captured'
  72  |     
  73  |     if (files.length > 0) {
  74  |       const content = fs.readFileSync(path.join(lessonsDir, files[0]), 'utf-8');
  75  |       console.log('Lesson content:', content);
  76  |       
  77  |       const lesson = JSON.parse(content);
  78  |       expect(lesson).toHaveProperty('id');
  79  |       expect(lesson).toHaveProperty('title');
  80  |       expect(lesson).toHaveProperty('problem');
  81  |       expect(lesson).toHaveProperty('solution');
  82  |     }
  83  |   });
  84  | 
  85  |   test('devorq lessons capture deve suportar tags', () => {
  86  |     const projectDir = `${SANDBOX}/tags-project`;
  87  |     fs.mkdirSync(projectDir, { recursive: true });
  88  |     runCommand('devorq init', projectDir);
  89  |     
  90  |     const result = runCommand(
  91  |       'devorq lessons capture "Git error" "Merge conflict" "Use git mergetool" --tags "git,merge"',
  92  |       projectDir
  93  |     );
  94  |     
  95  |     console.log('Tags capture output:', result.stdout);
  96  |     
  97  |     expect(result.stdout).toMatch(/lesson|Lição/i);
  98  |   });
  99  | });
  100 | 
  101 | describe('Lessons - Busca', () => {
  102 |   
  103 |   test('devorq lessons search deve encontrar lição', () => {
  104 |     const projectDir = `${SANDBOX}/search-project`;
  105 |     fs.mkdirSync(projectDir, { recursive: true });
  106 |     runCommand('devorq init', projectDir);
  107 |     
  108 |     // Capturar lição
  109 |     runCommand(
  110 |       'devorq lessons capture "Docker lesson" "Docker problem" "Docker solution"',
  111 |       projectDir
  112 |     );
  113 |     
  114 |     // Buscar
  115 |     const result = runCommand('devorq lessons search "Docker"', projectDir);
  116 |     
  117 |     console.log('Search output:', result.stdout);
  118 |     
  119 |     expect(result.stdout).toMatch(/Docker|lesson|Lição/i);
  120 |   });
  121 | 
  122 |   test('devorq lessons search deve mostrar "nenhuma" se não encontrar', () => {
  123 |     const projectDir = `${SANDBOX}/search-empty-project`;
  124 |     fs.mkdirSync(projectDir, { recursive: true });
  125 |     runCommand('devorq init', projectDir);
  126 |     
  127 |     const result = runCommand('devorq lessons search "xyzabc123"', projectDir);
  128 |     
  129 |     console.log('Search empty output:', result.stdout);
  130 |     
  131 |     expect(result.stdout).toMatch(/nenhuma|Nenhum|not.*found|no.*lesson/i);
  132 |   });
  133 | 
  134 |   test('devorq lessons search deve buscar em múltiplas lições', () => {
  135 |     const projectDir = `${SANDBOX}/search-multi-project`;
  136 |     fs.mkdirSync(projectDir, { recursive: true });
  137 |     runCommand('devorq init', projectDir);
  138 |     
  139 |     // Capturar múltiplas lições
  140 |     runCommand('devorq lessons capture "Docker lesson" "D1" "S1"', projectDir);
  141 |     runCommand('devorq lessons capture "Git lesson" "G1" "S2"', projectDir);
  142 |     runCommand('devorq lessons capture "Node lesson" "N1" "S3"', projectDir);
  143 |     
  144 |     // Buscar por Docker
  145 |     const dockerResult = runCommand('devorq lessons search "Docker"', projectDir);
  146 |     expect(dockerResult.stdout).toMatch(/Docker/i);
  147 |     
  148 |     // Buscar por Git
  149 |     const gitResult = runCommand('devorq lessons search "Git"', projectDir);
  150 |     expect(gitResult.stdout).toMatch(/Git/i);
  151 |   });
  152 | });
  153 | 
  154 | describe('Lessons - Validação', () => {
  155 |   
  156 |   test('devorq lessons validate deve validar lições', () => {
  157 |     const projectDir = `${SANDBOX}/validate-project`;
  158 |     fs.mkdirSync(projectDir, { recursive: true });
  159 |     runCommand('devorq init', projectDir);
  160 |     
  161 |     runCommand(
  162 |       'devorq lessons capture "Test" "Problem" "Solution"',
  163 |       projectDir
  164 |     );
  165 |     
  166 |     const result = runCommand('devorq lessons validate', projectDir);
  167 |     
  168 |     console.log('Validate output:', result.stdout);
  169 |     
  170 |     expect(result.stdout).toMatch(/validate|Validate|Lição/i);
  171 |   });
```