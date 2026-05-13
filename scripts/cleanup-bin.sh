#!/usr/bin/env bash
# scripts/cleanup-bin.sh — Remove código duplicado do bin/devorq
#
# Remove todas as funções cmd_* do bin/devorq
# mantendo apenas dispatcher e auto-load
#
# USO: bash scripts/cleanup-bin.sh

set -euo pipefail

BIN_FILE="${DEVORQ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/bin/devorq"
BACKUP="${BIN_FILE}.backup-$(date +%Y%m%d_%H%M%S)"

if [ ! -f "$BIN_FILE" ]; then
    echo "Erro: bin/devorq não encontrado"
    exit 1
fi

echo "Limpando bin/devorq..."
echo "Arquivo: $BIN_FILE"

# Backup
cp "$BIN_FILE" "$BACKUP"
echo "Backup: $BACKUP"

# Identifica linhas onde começam e terminam as funções cmd_*
# Remove blocos que começam com "devorq::cmd_" e terminam com "}"
python3 << 'PYTHON'
import re
import sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

# Padrão: de "devorq::cmd_" até o próximo "}"
# Mas mantendo funções que são helpers (não cmd_)

lines = content.split('\n')
result = []
i = 0
skip_until = -1

while i < len(lines):
    line = lines[i]
    
    # Se estamos pulando linhas
    if i <= skip_until:
        # Verificar se esta linha fecha a função
        if line.strip() == '}':
            skip_until = -1
        i += 1
        continue
    
    # Se a linha começa com devorq::cmd_ (função de comando)
    if re.match(r'^devorq::cmd_', line) or re.match(r'^\s+devorq::cmd_', line):
        # Encontrar onde termina esta função
        j = i + 1
        brace_count = 0
        started = False
        while j < len(lines):
            if '{' in lines[j]:
                brace_count += lines[j].count('{')
                started = True
            if '}' in lines[j]:
                brace_count -= lines[j].count('}')
            if started and brace_count == 0:
                break
            j += 1
        skip_until = j
        i += 1
        continue
    
    result.append(line)
    i += 1

with open(sys.argv[1], 'w') as f:
    f.write('\n'.join(result))

print(f"Limpeza concluída! Removidas {len(lines) - len(result)} linhas")
PYTHON

echo "$BIN_FILE"

echo ""
echo "Limpagem concluída!"
echo ""
echo "Resumo:"
echo "  - Funções cmd_* removidas (usar módulos em lib/commands/)"
echo "  - Auto-load mantido (carrega lib/commands/*.sh)"
echo "  - Dispatcher mantido (case que chama devorq::cmd_*)"
