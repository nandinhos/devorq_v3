# DEVORQ v3

> Framework bash puro para metodologia de desenvolvimento sistemático.
> Captura lições aprendidas, impõe gates bloqueantes, gera handoffs consistentes.

---

## O que é

DEVORQ é uma **CLI bash** que impõe disciplina de desenvolvimento através de gates bloqueantes e captura sistemática de lições aprendidas.

- **Instalação:** `git clone` + adicionar ao PATH
- **Pré-requisito:** Bash 5+, Git, jq (binary estático incluso)
- **Funciona:** 100% offline (core), ou conectado ao DEV-MEMORY HUB (via SSH)

## Quick Start

```bash
# 1. Clonar
git clone https://github.com/nandinhos/devorq_v3.git
cd devorq_v3

# 2. Instalar (copia bin/devorq para ~/bin)
make install   # ou: cp bin/devorq ~/bin/ && chmod +x ~/bin/devorq

# 3. Inicializar em qualquer projeto
cd /projects/meu-projeto
devorq init

# 4. Executar gates
devorq gate 1    # Verifica SPEC.md
devorq gate 2    # Testa estrutura
devorq gate 3    # Documenta contexto

# 5. Capturar lição aprendida
devorq lessons capture \
  --title "jq install in rootless Docker" \
  --problem "jq binary needed but no apt-get in rootless container" \
  --solution "curl -L jq-linux64 binary to ~/bin" \
  --stack "bash" --tags "devorq,docker,jq"

# 6. Sincronizar com HUB (opcional)
devorq sync push   # Envia lessons → dev-memory-laravel
```

## Arquitetura

```
DEVORQ CORE (bash puro, zero deps externos)
├── bin/devorq           CLI principal (source libs)
├── lib/
│   ├── lessons.sh       Capture, search, validate, apply
│   ├── gates.sh         7 gates bloqueantes
│   ├── compact.sh       Context compression + handoff
│   └── vps.sh           SSH mux para HUB remoto
└── .devorq/             Estado local (não commitar)

DEV-MEMORY HUB (repo separado: dev-memory-laravel)
├── DevorqHubService.php  Sincronização DEVORQ ↔ HUB
├── schema devorq.*       PostgreSQL no VPS srv163217
└── Interface web         Visualização de lições/memórias
```

## Comandos

| Comando | Descrição |
|---------|-----------|
| `devorq init` | Inicializar `.devorq/` no projeto |
| `devorq help` | Lista todos os comandos |
| `devorq version` | Versão atual |
| `devorq gate [1-7]` | Executar gate específico |
| `devorq lessons capture` | Capturar lição aprendida |
| `devorq lessons search <query>` | Buscar lições locais |
| `devorq lessons validate` | Validar com Context7 |
| `devorq context` | Ver contexto atual |
| `devorq compact` | Gerar handoff JSON |
| `devorq vps check` | Verificar conexão HUB |
| `devorq sync push` | Enviar lessons → HUB |
| `devorq sync pull` | Receber lessons ← HUB |

## Os 7 Gates

| Gate | Critério |
|------|----------|
| GATE-1 | `SPEC.md` existe e não está vazio |
| GATE-2 | `devorq test` passa (testa estrutura) |
| GATE-3 | `devorq context` mostra estado atual |
| GATE-4 | `devorq lessons search` encontrou lições relevantes |
| GATE-5 | `devorq compact` gera JSON válido |
| GATE-6 | Docs consultadas (mesmo que rejeite) |
| GATE-7 | Se erro: `devorq debug` antes de continuar |

## Documentação

- [SPEC.md](SPEC.md) — Especificação completa
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Problemas e soluções

---

**Versão:** 3.2.0
**Repo:** https://github.com/nandinhos/devorq_v3
**Autor:** Fernando Dos Santos (Nando)
