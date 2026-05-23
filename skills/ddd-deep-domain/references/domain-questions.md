# Domain Expert Workshop — Perguntas-Chave

> Use este guia durante o workshop com o domain expert. Cada seção avança a descoberta do modelo mental.

---

## Entidades (O que tem identidade própria?)

### 1. Identificação de Entidades

```
"Me dá um exemplo real de [Entidade] — passo a passo, do início ao fim?"
```

- Captura comportamento real, não teoria
- Revela estados e transições
- Mostra exceptions e edge cases

### 2. Quando dá errado

```
"Quando isso dá errado? Qual o pior cenário que você já viu?"
```

- Identifica invariantes implícitas
- Revela regras de negócio escondidas
- Mostra consequências de violações

### 3. O que não pode mudar nunca

```
"O que não pode mudar nunca nessa entidade?"
```

- Identifica invariantes hard
- Define limites do domínio
-上下文中立，不依赖技术实现

---

## Relações (Como as coisas se conectam?)

### 4. Relacionamentos entre entidades

```
"Como [Entidade A] se relaciona com [Entidade B]?"
"Uma pode existir sem a outra?"
```

- Identifica dependências
- Define agregados
- Revela cardinalidades

### 5. Ciclo de vida

```
"Quem cria [Entidade]? Quem pode destruí-la?"
"O que acontece se [Entidade] for alterada?"
```

- Define responsabilidades
- Identifica root aggregates
- Revela regras de transição

### 6. Independência

```
"Existe alguma entidade que depende de outra para existir?"
"Se [Entidade A] for deletada, o que mais morre?"
```

- Identifica relacionamentos forts
-上下文中立，揭示真正的聚合边界

---

## Contextos Delimitados (Onde as coisas mudam de significado?)

### 7. Contexto cruzando

```
"Você usa a palavra 'Pedido' em quantos contextos diferentes?"
"Alguma coisa que parece igual mas é diferente dependendo de quem vê?"
```

- Identifica bounded contexts
-上下文中立，揭示同一术语的不同含义

### 8. Comparação de contextos

```
"O [Conceito X] em Vendas é o mesmo que em Logística?"
"Se eu pegasse a regra de Vendas e aplicasse em Logística, ia funcionar?"
```

-上下文中立，验证是否真的是不同的上下文
- Identifica translation needs (anti-corruption layer)

### 9. Clientes de cada contexto

```
"Quem são os 'clientes' de cada contexto?"
"Qual time/area é dona de cada contexto?"
```

-上下文中立，identifies stakeholder
-上下文中立，helps with team structure

---

## Invariantes (O que é sempre verdade?)

### 10. Verdades universais

```
"O que é sempre verdade, não importa o que aconteça?"
"Se tudo o mais no sistema falhasse, o que ainda precisa ser garantido?"
```

-上下文中立，identifies core business rules
-上下文中立，no technical jargon

### 11. Regras inegociáveis

```
"Qual regra o negócio NUNCA abre mão?"
"Se essa regra quebrasse, o que morreria?"
```

- Identifica hard invariants
-上下文中立，stakeholder validation
-上下文中立，business continuity rules

### 12. Violações e recuperações

```
"O que acontece se uma invariante for violada?"
"Existe forma de recuperar?"
"Quanto tempo leva pra perceber que violou?"
```

- Identifica detecção mechanisms
-上下文中立，recovery procedures
-上下文中立，business impact

---

## Linguagem (A língua do negócio?)

### 13. Termos técnicos do domínio

```
"Qual palavra vocês usam pra isso?"
"Se eu explicasse errado, você ia me corrigir?"
```

- Identifica linguagem ubíqua
-上下文中立，jargons
-上下文中立，aliases

### 14. Termos técnicos ambíguos

```
"Existe algum termo técnico que significa algo específico aqui?"
"Já usaram a mesma palavra pra coisas diferentes e gerou confusão?"
```

-上下文中立，澄清行业术语
- Identifica sinonímia e polissemia
-上下文中立，helps avoid misunderstandings

### 15. Conceitos órfãos

```
"Algo que o sistema anterior fazia que ninguém sabia por quê?"
"Alguma coisa que foi retirada mas sente falta?"
"Algo que todo mundo faz 'na mão' porque o sistema não suporta?"
```

-上下文中立，legacy knowledge
-上下文中立，manual workarounds
-上下文中立，system gaps

---

## Validação Final (O modelo está pronto?)

### 16. Recognição

```
"Se eu explicasse esse sistema de volta pra você — no seu idioma, sem termos técnicos — você reconheceria?"
"Falta alguma coisa que você esperava ver?"
```

-上下文中立，validates understanding
-上下文中立，confirms completeness

### 17. Completude

```
"Se eu tirasse uma foto desse domínio agora, o que com certeza estaria na foto?"
"E se tirasse daqui a um ano, o que teria mudado?"
```

-上下文中立，captures stable elements
-上下文中立，identifies what changes

### 18. Teste de estresse

```
"Se um novo funcionário lesse só isso, conseguiria explicar o sistema em 5 minutos?"
"Onde você concorda? Onde discorda?"
```

-上下文中立，validates communication clarity
-上下文中立，confirms shared understanding

---

## Resumo — Checklist Final

Antes de fechar o workshop, garantir que:

- [ ] Entidades identificadas com exemplos reais
- [ ] Relações entre entidades mapeadas
- [ ] Contextos delimitados nomeados e diferenciados
- [ ] Invariantes explícitas (não implícitas)
- [ ] Linguagem ubíqua capturada (sinônimos, ambiguidades)
- [ ] Domain expert valida o modelo como correto
- [ ] Nenhuma pergunta crítica ficou sem resposta

---

**Versão:** 1.0.0
**Criado em:** 2026-04-23
**Para usar com:** DEVORQ-DDD skill (ddd-deep-domain)
