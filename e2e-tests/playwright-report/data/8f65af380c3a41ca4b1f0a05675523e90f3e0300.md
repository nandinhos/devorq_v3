# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: devorq-cli.spec.ts >> DEVORQ CLI - Lições Aprendidas >> devorq lessons search deve buscar lições
- Location: tests/devorq-cli.spec.ts:203:7

# Error details

```
Error: expect(received).toMatch(expected)

Expected pattern: /Docker|lesson|Nenhuma/i
Received string:  ""
```

# Test source

```ts
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
  217 |     console.log('Search output:', result.stdout);
  218 |     
> 219 |     expect(result.stdout).toMatch(/Docker|lesson|Nenhuma/i);
      |                           ^ Error: expect(received).toMatch(expected)
  220 |   });
  221 | 
  222 |   test('devorq lessons list deve listar lições', () => {
  223 |     const projectDir = `${SANDBOX}/test-project`;
  224 |     fs.mkdirSync(projectDir, { recursive: true });
  225 |     runCommand('devorq init', projectDir);
  226 |     
  227 |     const result = runCommand('devorq lessons list', projectDir);
  228 |     
  229 |     console.log('List output:', result.stdout);
  230 |     
  231 |     expect(result.stdout).toMatch(/lesson|Lista|Nenhuma/i);
  232 |   });
  233 | });
  234 | 
  235 | describe('DEVORQ CLI - Contexto', () => {
  236 |   
  237 |   test('devorq context deve mostrar contexto', () => {
  238 |     const projectDir = `${SANDBOX}/test-project`;
  239 |     fs.mkdirSync(projectDir, { recursive: true });
  240 |     runCommand('devorq init', projectDir);
  241 |     
  242 |     const result = runCommand('devorq context', projectDir);
  243 |     
  244 |     console.log('Context output:', result.stdout);
  245 |     
  246 |     expect(result.stdout).toMatch(/context|Context|DEVORQ/i);
  247 |   });
  248 | 
  249 |   test('devorq compact deve gerar handoff', () => {
  250 |     const projectDir = `${SANDBOX}/test-project`;
  251 |     fs.mkdirSync(projectDir, { recursive: true });
  252 |     runCommand('devorq init', projectDir);
  253 |     
  254 |     const result = runCommand('devorq compact', projectDir);
  255 |     
  256 |     console.log('Compact output:', result.stdout);
  257 |     
  258 |     // Deve gerar JSON
  259 |     expect(result.stdout).toMatch(/\{|handoff|project/i);
  260 |   });
  261 | });
  262 | 
  263 | describe('DEVORQ CLI - Foundation', () => {
  264 |   
  265 |   test('devorq foundation deve mostrar status', () => {
  266 |     const projectDir = `${SANDBOX}/test-project`;
  267 |     fs.mkdirSync(projectDir, { recursive: true });
  268 |     runCommand('devorq init', projectDir);
  269 |     
  270 |     const result = runCommand('devorq foundation', projectDir);
  271 |     
  272 |     console.log('Foundation output:', result.stdout);
  273 |     
  274 |     expect(result.stdout).toMatch(/Foundation|5W2H|Status/i);
  275 |   });
  276 | 
  277 |   test('devorq foundation status deve mostrar status', () => {
  278 |     const projectDir = `${SANDBOX}/test-project`;
  279 |     fs.mkdirSync(projectDir, { recursive: true });
  280 |     runCommand('devorq init', projectDir);
  281 |     
  282 |     const result = runCommand('devorq foundation status', projectDir);
  283 |     
  284 |     console.log('Foundation status output:', result.stdout);
  285 |     
  286 |     expect(result.stdout).toMatch(/5W2H|premissas|riscos|requisitos|restricoes/i);
  287 |   });
  288 | });
  289 | 
  290 | describe('DEVORQ CLI - Debug', () => {
  291 |   
  292 |   test('devorq debug deve executar workflow de debug', () => {
  293 |     const projectDir = `${SANDBOX}/test-project`;
  294 |     fs.mkdirSync(projectDir, { recursive: true });
  295 |     runCommand('devorq init', projectDir);
  296 |     
  297 |     // Note: debug é interativo, então apenas verificamos que não crasha
  298 |     const result = runCommand('echo "" | devorq debug', projectDir);
  299 |     
  300 |     console.log('Debug output:', result.stdout);
  301 |     
  302 |     expect(result.stdout).toMatch(/Debug|debug|DEBU/i);
  303 |   });
  304 | });
  305 | 
  306 | describe('DEVORQ CLI - Stats', () => {
  307 |   
  308 |   test('devorq stats deve mostrar estatísticas', () => {
  309 |     const projectDir = `${SANDBOX}/test-project`;
  310 |     fs.mkdirSync(projectDir, { recursive: true });
  311 |     runCommand('devorq init', projectDir);
  312 |     
  313 |     const result = runCommand('devorq stats', projectDir);
  314 |     
  315 |     console.log('Stats output:', result.stdout);
  316 |     
  317 |     expect(result.stdout).toMatch(/Stats|stats|Lições/i);
  318 |   });
  319 | });
```