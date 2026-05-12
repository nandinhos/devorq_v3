# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: devorq-cli.spec.ts >> DEVORQ CLI - Inicialização >> devorq init deve detectar projeto já inicializado
- Location: tests/devorq-cli.spec.ts:106:7

# Error details

```
Error: expect(received).toContain(expected) // indexOf

Expected substring: "já existe"
Received string:    "[!] Já existe .devorq/ em /tmp/devorq-e2e-sandbox/test-project
"
```

# Test source

```ts
  16  | const DEVORQ_ROOT = path.resolve(__dirname, '../../');
  17  | const DEVORQ_BIN = path.resolve(DEVORQ_ROOT, 'bin/devorq');
  18  | const SANDBOX = '/tmp/devorq-e2e-sandbox';
  19  | 
  20  | /**
  21  |  * Helper para executar comandos
  22  |  */
  23  | function runCommand(cmd: string, cwd: string = DEVORQ_ROOT): { stdout: string; stderr: string; exitCode: number } {
  24  |   // Substitui 'devorq' pelo caminho completo do projeto
  25  |   const adjustedCmd = cmd.replace(/\bdevorq\b/g, DEVORQ_BIN);
  26  |   
  27  |   try {
  28  |     const stdout = execSync(adjustedCmd, { encoding: 'utf-8', cwd });
  29  |     return { stdout, stderr: '', exitCode: 0 };
  30  |   } catch (error: any) {
  31  |     return {
  32  |       stdout: error.stdout?.toString() || '',
  33  |       stderr: error.stderr?.toString() || '',
  34  |       exitCode: error.status || 1
  35  |     };
  36  |   }
  37  | }
  38  | 
  39  | /**
  40  |  * Setup antes de cada teste
  41  |  */
  42  | test.beforeEach(async () => {
  43  |   // Limpar sandbox
  44  |   execSync(`rm -rf ${SANDBOX}`, { encoding: 'utf-8' });
  45  |   execSync(`mkdir -p ${SANDBOX}`, { encoding: 'utf-8' });
  46  | });
  47  | 
  48  | describe('DEVORQ CLI - Comandos Básicos', () => {
  49  |   
  50  |   test('devorq version deve retornar versão', () => {
  51  |     const result = runCommand('devorq version', DEVORQ_ROOT);
  52  |     
  53  |     console.log('Output:', result.stdout);
  54  |     
  55  |     expect(result.exitCode).toBe(0);
  56  |     expect(result.stdout).toContain('DEVORQ');
  57  |     expect(result.stdout).toMatch(/\d+\.\d+\.\d+/);
  58  |   });
  59  | 
  60  |   test('devorq --help deve mostrar help', () => {
  61  |     const result = runCommand('devorq --help', DEVORQ_ROOT);
  62  |     
  63  |     console.log('Output:', result.stdout);
  64  |     
  65  |     expect(result.exitCode).toBe(0);
  66  |     expect(result.stdout).toContain('DEVORQ');
  67  |     expect(result.stdout).toContain('init');
  68  |     expect(result.stdout).toContain('flow');
  69  |     expect(result.stdout).toContain('lessons');
  70  |   });
  71  | 
  72  |   test('devorq -h deve ser equivalente a --help', () => {
  73  |     const result = runCommand('devorq -h', DEVORQ_ROOT);
  74  |     
  75  |     expect(result.exitCode).toBe(0);
  76  |     expect(result.stdout).toContain('DEVORQ');
  77  |   });
  78  | 
  79  |   test('devorq sem argumentos deve mostrar help', () => {
  80  |     const result = runCommand('devorq', DEVORQ_ROOT);
  81  |     
  82  |     expect(result.exitCode).toBe(0);
  83  |     expect(result.stdout).toContain('DEVORQ');
  84  |   });
  85  | });
  86  | 
  87  | describe('DEVORQ CLI - Inicialização', () => {
  88  |   
  89  |   test('devorq init deve criar estrutura .devorq', () => {
  90  |     const projectDir = `${SANDBOX}/test-project`;
  91  |     fs.mkdirSync(projectDir, { recursive: true });
  92  |     
  93  |     const result = runCommand('devorq init', projectDir);
  94  |     
  95  |     console.log('Init output:', result.stdout);
  96  |     
  97  |     expect(result.exitCode).toBe(0);
  98  |     expect(result.stdout).toContain('.devorq');
  99  |     
  100 |     // Verificar estrutura criada
  101 |     expect(fs.existsSync(path.join(projectDir, '.devorq'))).toBe(true);
  102 |     expect(fs.existsSync(path.join(projectDir, '.devorq/state'))).toBe(true);
  103 |     expect(fs.existsSync(path.join(projectDir, '.devorq/state/context.json'))).toBe(true);
  104 |   });
  105 | 
  106 |   test('devorq init deve detectar projeto já inicializado', () => {
  107 |     const projectDir = `${SANDBOX}/test-project`;
  108 |     fs.mkdirSync(projectDir, { recursive: true });
  109 |     
  110 |     // Primeira inicialização
  111 |     runCommand('devorq init', projectDir);
  112 |     
  113 |     // Segunda inicialização (deve detectar)
  114 |     const result = runCommand('devorq init', projectDir);
  115 |     
> 116 |     expect(result.stdout).toContain('já existe');
      |                           ^ Error: expect(received).toContain(expected) // indexOf
  117 |   });
  118 | 
  119 |   test('devorq test deve verificar estrutura', () => {
  120 |     const projectDir = `${SANDBOX}/test-project`;
  121 |     fs.mkdirSync(projectDir, { recursive: true });
  122 |     runCommand('devorq init', projectDir);
  123 |     
  124 |     const result = runCommand('devorq test', projectDir);
  125 |     
  126 |     console.log('Test output:', result.stdout);
  127 |     
  128 |     expect(result.exitCode).toBe(0);
  129 |   });
  130 | });
  131 | 
  132 | describe('DEVORQ CLI - Gates', () => {
  133 |   
  134 |   test('devorq gate 0 deve executar GATE-0', () => {
  135 |     const projectDir = `${SANDBOX}/test-project`;
  136 |     fs.mkdirSync(projectDir, { recursive: true });
  137 |     runCommand('devorq init', projectDir);
  138 |     
  139 |     const result = runCommand('devorq gate 0', projectDir);
  140 |     
  141 |     console.log('Gate 0 output:', result.stdout);
  142 |     
  143 |     // GATE-0 é opcional, então pode passar ou falhar
  144 |     expect(result.stdout).toMatch(/GATE/);
  145 |   });
  146 | 
  147 |   test('devorq gate 1 deve verificar SPEC.md', () => {
  148 |     const projectDir = `${SANDBOX}/test-project`;
  149 |     fs.mkdirSync(projectDir, { recursive: true });
  150 |     runCommand('devorq init', projectDir);
  151 |     
  152 |     const result = runCommand('devorq gate 1', projectDir);
  153 |     
  154 |     console.log('Gate 1 output:', result.stdout);
  155 |     
  156 |     // GATE-1 deve falhar se não existir SPEC.md
  157 |     expect(result.stdout).toMatch(/GATE/);
  158 |   });
  159 | 
  160 |   test('devorq flow deve executar todos os gates', () => {
  161 |     const projectDir = `${SANDBOX}/test-project`;
  162 |     fs.mkdirSync(projectDir, { recursive: true });
  163 |     runCommand('devorq init', projectDir);
  164 |     
  165 |     // Criar SPEC.md básico
  166 |     fs.writeFileSync(
  167 |       path.join(projectDir, 'SPEC.md'),
  168 |       '# Test Project\n\n## Vision\n\nTest project.\n\n## Acceptance Criteria\n\n- [ ] Feature 1\n'
  169 |     );
  170 |     
  171 |     const result = runCommand('devorq flow "test intent"', projectDir);
  172 |     
  173 |     console.log('Flow output:', result.stdout);
  174 |     
  175 |     expect(result.stdout).toMatch(/GATE/);
  176 |   });
  177 | });
  178 | 
  179 | describe('DEVORQ CLI - Lições Aprendidas', () => {
  180 |   
  181 |   test('devorq lessons capture deve capturar lição', () => {
  182 |     const projectDir = `${SANDBOX}/test-project`;
  183 |     fs.mkdirSync(projectDir, { recursive: true });
  184 |     runCommand('devorq init', projectDir);
  185 |     
  186 |     const result = runCommand(
  187 |       `devorq lessons capture "Test lesson" "Test problem" "Test solution"`,
  188 |       projectDir
  189 |     );
  190 |     
  191 |     console.log('Capture output:', result.stdout);
  192 |     
  193 |     expect(result.stdout).toContain('lesson');
  194 |     
  195 |     // Verificar se arquivo foi criado
  196 |     const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
  197 |     if (fs.existsSync(lessonsDir)) {
  198 |       const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
  199 |       expect(files.length).toBeGreaterThan(0);
  200 |     }
  201 |   });
  202 | 
  203 |   test('devorq lessons search deve buscar lições', () => {
  204 |     const projectDir = `${SANDBOX}/test-project`;
  205 |     fs.mkdirSync(projectDir, { recursive: true });
  206 |     runCommand('devorq init', projectDir);
  207 |     
  208 |     // Capturar uma lição primeiro
  209 |     runCommand(
  210 |       `devorq lessons capture "Docker lesson" "Docker problem" "Docker solution"`,
  211 |       projectDir
  212 |     );
  213 |     
  214 |     // Buscar
  215 |     const result = runCommand('devorq lessons search "Docker"', projectDir);
  216 |     
```