# Regra: Commits Manuais

## Regra Rígida: Aguardar Validação Manual

### ❌ NÃO FAÇA:
- Commits automáticos após implementação
- Commits parciais durante desenvolvimento
- Push sem autorização

### ✅ FAÇA:
1. Implemente a funcionalidade
2. Execute e valide os testes
3. **AGUARDE** confirmação manual
4. **AGUARDE** confirmação para push

## Fluxo Obrigatório

```
[Implementação] → [Testes] → [Solicitar Commit] → [Aguardar OK] → [Commit]
                                                                       ↓
                                                              [Solicitar Push] → [Aguardar OK] → [Push]
```

## Como Solicitar

Antes de fazer commit, pergunte:
```
Posso fazer o commit?
- Tipo: feat(escopo): descrição
```

Antes de fazer push:
```
Posso fazer o push para origin?
```

## Excessões

- Correções de sintaxe óbvias (`bash -n`)
- shellcheck warnings críticos
-Documentação de ajuda (`--help`)

## Status

**Ativo desde:** 2026-05-21  
**Responsável:** Fernando Dos Santos (Nando)
