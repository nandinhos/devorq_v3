# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: lessons.spec.ts >> Lessons - Compilação >> devorq lessons compile deve compilar lição
- Location: tests/lessons.spec.ts:252:7

# Error details

```
Error: expect(received).toMatch(expected)

Expected pattern: /compile|Compile|skill|Skill/i
Received string:  "[SKIP] Não aprovada: lesson_20260512_201323_2002
"
```

# Test source

```ts
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
  220 |     fs.mkdirSync(projectDir, { recursive: true });
  221 |     runCommand('devorq init', projectDir);
  222 |     
  223 |     runCommand('devorq lessons capture "Test" "P" "S"', projectDir);
  224 |     
  225 |     const allResult = runCommand('devorq lessons list all', projectDir);
  226 |     expect(allResult.stdout).toMatch(/lesson|Lição/i);
  227 |     
  228 |     const pendingResult = runCommand('devorq lessons list pending', projectDir);
  229 |     expect(pendingResult.stdout).toMatch(/lesson|Lição/i);
  230 |   });
  231 | });
  232 | 
  233 | describe('Lessons - Migração', () => {
  234 |   
  235 |   test('devorq lessons migrate deve migrar lições', () => {
  236 |     const projectDir = `${SANDBOX}/migrate-project`;
  237 |     fs.mkdirSync(projectDir, { recursive: true });
  238 |     runCommand('devorq init', projectDir);
  239 |     
  240 |     runCommand('devorq lessons capture "Old lesson" "P" "S"', projectDir);
  241 |     
  242 |     const result = runCommand('devorq lessons migrate', projectDir);
  243 |     
  244 |     console.log('Migrate output:', result.stdout);
  245 |     
  246 |     expect(result.stdout).toMatch(/migrate|Migrate|Lição/i);
  247 |   });
  248 | });
  249 | 
  250 | describe('Lessons - Compilação', () => {
  251 |   
  252 |   test('devorq lessons compile deve compilar lição', () => {
  253 |     const projectDir = `${SANDBOX}/compile-project`;
  254 |     fs.mkdirSync(projectDir, { recursive: true });
  255 |     runCommand('devorq init', projectDir);
  256 |     
  257 |     runCommand('devorq lessons capture "Compile test" "P" "S"', projectDir);
  258 |     
  259 |     // Obter ID da lição
  260 |     const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
  261 |     const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
  262 |     
  263 |     if (files.length > 0) {
  264 |       const lessonId = path.basename(files[0], '.json');
  265 |       const result = runCommand(`devorq lessons compile ${lessonId}`, projectDir);
  266 |       
  267 |       console.log('Compile output:', result.stdout);
  268 |       
> 269 |       expect(result.stdout).toMatch(/compile|Compile|skill|Skill/i);
      |                             ^ Error: expect(received).toMatch(expected)
  270 |     }
  271 |   });
  272 | });
  273 | 
  274 | describe('Lessons - Fluxo Completo', () => {
  275 |   
  276 |   test('fluxo completo: capture → validate → approve → compile', () => {
  277 |     const projectDir = `${SANDBOX}/full-lessons-project`;
  278 |     fs.mkdirSync(projectDir, { recursive: true });
  279 |     runCommand('devorq init', projectDir);
  280 |     
  281 |     // 1. Capturar
  282 |     const captureResult = runCommand(
  283 |       'devorq lessons capture "Full test" "Problem" "Solution"',
  284 |       projectDir
  285 |     );
  286 |     expect(captureResult.stdout).toMatch(/lesson|Lição/i);
  287 |     console.log('1. Capture:', captureResult.stdout);
  288 |     
  289 |     // 2. Listar
  290 |     const listResult = runCommand('devorq lessons list', projectDir);
  291 |     expect(listResult.stdout).toMatch(/lesson|Lição/i);
  292 |     console.log('2. List:', listResult.stdout);
  293 |     
  294 |     // 3. Buscar
  295 |     const searchResult = runCommand('devorq lessons search "Full"', projectDir);
  296 |     expect(searchResult.stdout).toMatch(/Full|lesson|Lição/i);
  297 |     console.log('3. Search:', searchResult.stdout);
  298 |     
  299 |     // 4. Validar
  300 |     const validateResult = runCommand('devorq lessons validate', projectDir);
  301 |     console.log('4. Validate:', validateResult.stdout);
  302 |   });
  303 | });
  304 | 
```