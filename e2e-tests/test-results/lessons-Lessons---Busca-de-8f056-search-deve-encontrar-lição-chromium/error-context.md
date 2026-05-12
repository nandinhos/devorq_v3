# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: lessons.spec.ts >> Lessons - Busca >> devorq lessons search deve encontrar lição
- Location: tests/lessons.spec.ts:103:7

# Error details

```
Error: expect(received).toMatch(expected)

Expected pattern: /Docker|lesson|Lição/i
Received string:  ""
```

# Test source

```ts
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
  71  |     const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
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
> 119 |     expect(result.stdout).toMatch(/Docker|lesson|Lição/i);
      |                           ^ Error: expect(received).toMatch(expected)
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
  172 | 
  173 |   test('devorq lessons validate deve funcionar sem Context7', () => {
  174 |     const projectDir = `${SANDBOX}/validate-no-context7`;
  175 |     fs.mkdirSync(projectDir, { recursive: true });
  176 |     runCommand('devorq init', projectDir);
  177 |     
  178 |     runCommand(
  179 |       'devorq lessons capture "Test" "Problem" "Solution"',
  180 |       projectDir
  181 |     );
  182 |     
  183 |     // Forçar sem Context7
  184 |     const result = runCommand(
  185 |       'OPENAI_API_KEY="" devorq lessons validate',
  186 |       projectDir
  187 |     );
  188 |     
  189 |     console.log('Validate no-context7 output:', result.stdout);
  190 |     
  191 |     expect(result.stdout).toMatch(/validate|Validate|Lição/i);
  192 |   });
  193 | });
  194 | 
  195 | describe('Lessons - Aprovação', () => {
  196 |   
  197 |   test('devorq lessons list deve listar lições', () => {
  198 |     const projectDir = `${SANDBOX}/list-project`;
  199 |     fs.mkdirSync(projectDir, { recursive: true });
  200 |     runCommand('devorq init', projectDir);
  201 |     
  202 |     runCommand(
  203 |       'devorq lessons capture "Test 1" "P1" "S1"',
  204 |       projectDir
  205 |     );
  206 |     runCommand(
  207 |       'devorq lessons capture "Test 2" "P2" "S2"',
  208 |       projectDir
  209 |     );
  210 |     
  211 |     const result = runCommand('devorq lessons list', projectDir);
  212 |     
  213 |     console.log('List output:', result.stdout);
  214 |     
  215 |     expect(result.stdout).toMatch(/lesson|Lição|Lista|list/i);
  216 |   });
  217 | 
  218 |   test('devorq lessons list deve filtrar por status', () => {
  219 |     const projectDir = `${SANDBOX}/list-filter-project`;
```