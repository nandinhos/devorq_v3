# Instalação

## Requisitos

- Bash 5+
- Git
- jq (instalado automaticamente se necessário)

## Instalação padrão

```bash
# Clonar o repositório
git clone https://github.com/nandinhos/devorq_v3.git ~/devorq

# Adicionar ao PATH (adicione no ~/.bashrc ou ~/.zshrc)
export PATH="$HOME/devorq/bin:$PATH"

# Verificar instalação
devorq version
```

## Instalação rápida (sem clone)

```bash
# Copiar bin/devorq para ~/bin
curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq_v3/main/bin/devorq -o ~/bin/devorq
chmod +x ~/bin/devorq
```

## jq (se não tiver)

Se `jq` não estiver disponível, o DEVORQ baixa automaticamente:

```bash
curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux64 -o ~/bin/jq
chmod +x ~/bin/jq
```

Isso funciona mesmo em containers Docker sem apt-get.

## Pós-instalação

```bash
# Inicializar em qualquer projeto
cd /projects/meu-projeto
devorq init

# Testar gates
devorq gate 1
devorq gate 2
```

## Desinstalação

```bash
devorq uninstall
# ou manualmente:
rm -rf ~/.devorq
rm ~/bin/devorq
```
