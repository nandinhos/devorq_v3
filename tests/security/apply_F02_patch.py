#!/usr/bin/env python3
"""Patch F-02: hard require jq em ctx_set, remove sed fallback."""
import sys
import re

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Strategy: encontrar o bloco dentro da funcao ctx_set()
# 1. Localizar "ctx_set() {" no texto
# 2. Dentro desse escopo, encontrar "if command -v jq" ate o "fi" final
# 3. Substituir

# Encontra o inicio da funcao ctx_set
m = re.search(r'^ctx_set\(\) \{', content, re.MULTILINE)
if not m:
    print(f"[F-02] Funcao ctx_set nao encontrada em {path}")
    sys.exit(1)

# Pega o corpo da funcao ate o "}" correspondente
# Estrategia simples: pegar ate o proximo "^}" (fim de top-level)
func_start = m.start()
# Procura o primeiro ^} que vem DEPOIS de func_start
m_end = re.search(r'^\}', content[func_start:], re.MULTILINE)
if not m_end:
    print(f"[F-02] Nao encontrei fim da funcao ctx_set")
    sys.exit(1)

func_body = content[func_start:func_start + m_end.start()]

# Dentro do corpo, encontrar o bloco if/else
# Especificamente: o bloco que tem "Fallback grep+sed rudimentar" (sinal seguro)
# Substituir esse bloco pelo novo

new_block = '''    # PATCH F-02: exigir jq (sed fallback era vulneravel a injection)
    if ! command -v jq &>/dev/null; then
        echo "[ERROR] ctx_set requer 'jq' instalado (sed fallback removido por seguranca)" >&2
        echo "        Instale: apt install jq  /  brew install jq" >&2
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    if echo "$value" | jq -e . >/dev/null 2>&1; then
        jq --arg f "$field" --argjson v "$value" '.[$f] = $v' "$ctx_file" > "$tmp"
    else
        jq --arg f "$field" --arg v "$value" '.[$f] = $v' "$ctx_file" > "$tmp"
    fi
    mv "$tmp" "$ctx_file"
'''

# Localizar inicio do bloco: "if command -v jq" dentro do func_body
# Localizar fim do bloco: o "fi" que termina o if/else
# Como o "Fallback grep+sed" é único, vamos usar como ancora

anchor_start = "if command -v jq &>/dev/null; then"
idx_start = func_body.find(anchor_start)
if idx_start < 0:
    print(f"[F-02] Bloco 'if command -v jq' nao encontrado dentro de ctx_set")
    sys.exit(1)

# Achar o "fi" que fecha esse if/else
# A logica: contar ifs/elif/fis a partir de idx_start
# Como sabemos que o else tem "Fallback grep+sed rudimentar", podemos buscar
# o "fi" que vem apos essa string
fallback_idx = func_body.find("Fallback grep+sed rudimentar", idx_start)
if fallback_idx < 0:
    print(f"[F-02] 'Fallback grep+sed rudimentar' nao encontrado")
    sys.exit(1)

# Achar o "fi" que fecha tudo (4 espacos de indent)
# Padrao: ^    fi$ comeca na linha
m_fi = re.search(r'^    fi$', func_body[fallback_idx:], re.MULTILINE)
if not m_fi:
    print(f"[F-02] Nao encontrei 'fi' final do bloco")
    sys.exit(1)

idx_end = fallback_idx + m_fi.end()

# Substituir no content
abs_start = func_start + idx_start
abs_end = func_start + idx_end

new_content = content[:abs_start] + new_block + content[abs_end:]
with open(path, 'w') as f:
    f.write(new_content)
print(f"[F-02] Patch aplicado em {path}")
print(f"       Substituiu {abs_end - abs_start} chars por {len(new_block)} chars")
sys.exit(0)
