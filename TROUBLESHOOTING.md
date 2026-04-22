# Troubleshooting

## "jq: command not found"

**Causa:** `jq` não está instalado e não há apt-get (container rootless).

**Solução:**
```bash
curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux64 -o ~/bin/jq
chmod +x ~/bin/jq
export PATH="$HOME/bin:$PATH"
```

Verifique: `~/bin/jq --version`

---

## "devorq: command not found"

**Causa:** `bin/devorq` não está no PATH.

**Solução:**
```bash
export PATH="$HOME/devorq/bin:$PATH"
# Ou para persistir:
echo 'export PATH="$HOME/devorq/bin:$PATH"' >> ~/.bashrc
```

---

## "Permission denied" ao executar devorq

**Solução:**
```bash
chmod +x ~/devorq/bin/devorq
# ou
chmod +x ~/bin/devorq
```

---

## "bash: devorq: No such file or directory" mesmo com PATH correto

**Causa:** Provavelmente executando dentro de um container Docker onde `~/bin` é diferente.

**Solução:** Verifique o PATH e a localização do binary:
```bash
echo $PATH
which devorq
ls -la ~/bin/devorq
```

---

## SSH "Connection refused" ao VPS

**Causa:** VPS offline ou porta diferente.

**Solução:** Verifique:
```bash
ssh -p 6985 -o ConnectTimeout=5 root@187.108.197.199 "echo ok"
```

Se falhar: VPS pode estar reiniciando. Aguarde e tente novamente.

---

## PostgreSQL "connection refused" no container

**Causa:** Container `hermesstudy_postgres` não está rodando.

**Solução:**
```bash
ssh -p 6985 root@187.108.197.199 "docker ps | grep postgres"
```

Se não estiver rodando:
```bash
ssh -p 6985 root@187.108.197.199 "docker start hermesstudy_postgres"
```

---

## "No such file or directory" ao importar lib

**Causa:** `DEVORQ_LIB` ou `DEVORQ_ROOT` com caminho errado.

**Solução:**
```bash
export DEVORQ_ROOT="$HOME/devorq"
export DEVORQ_LIB="$DEVORQ_ROOT/lib"
```

Verifique: `ls $DEVORQ_LIB/*.sh`

---

## GATE vermelho (erro) sem detalhe

**Solução:** Execute com bash -x para ver debug:
```bash
bash -x bin/devorq gate 1
```

---

## devorq init não cria .devorq/

**Verifique:**
1. Está em um diretório com permissão de escrita
2. .devorq/ não existe já (init não sobrescreve)
3. `devorq version` mostra versão válida

```bash
rm -rf .devorq  # se quiser recriar
devorq init
```
