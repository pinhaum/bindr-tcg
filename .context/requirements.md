# Requisitos — Galeria de Cartas OPTCG (Fase 1)

## Introdução

Este documento define **o que** o sistema deve fazer, sem prescrever como. Cada
requisito tem critérios de aceitação testáveis, escritos como
`QUANDO <evento> ENTÃO o sistema DEVE <comportamento>`.

Regra de uso: se um critério não puder ser transformado em teste automatizado ou
verificação manual objetiva, ele está mal escrito e deve ser reescrito antes de
sair daqui.

Escopo e non-goals: ver `product.md` §3 e §4.

---

## Requisito 1 — Ingestão do catálogo

**User story:** Como usuário, quero que o catálogo de cartas seja carregado
automaticamente de uma fonte externa, para não digitar milhares de cartas à mão.

### Critérios de aceitação

1. O sistema DEVE oferecer um processo de importação executável sob demanda que
   popule cartas, variantes e sets a partir de uma fonte externa configurável.
2. QUANDO a importação encontrar um `card_number` que já existe ENTÃO o sistema
   DEVE atualizar os campos da carta existente em vez de criar duplicata.
3. QUANDO a importação encontrar uma variante já existente (mesma carta + mesmo
   identificador de variante) ENTÃO o sistema DEVE atualizar essa variante em vez
   de criar duplicata.
4. A importação DEVE ser idempotente: executá-la duas vezes com a mesma entrada
   NÃO DEVE alterar o número de registros.
5. QUANDO a importação falhar em um registro individual ENTÃO o sistema DEVE
   registrar o erro com o identificador do registro e continuar processando os
   demais.
6. AO final de cada execução o sistema DEVE persistir um resumo contendo: início,
   fim, status, quantidade criada, atualizada e falhada.
7. A importação NUNCA DEVE apagar ou zerar registros de coleção do usuário, mesmo
   que uma carta desapareça da fonte externa.
8. SE a fonte externa estiver indisponível ENTÃO o sistema DEVE falhar de forma
   explícita, sem deixar o catálogo em estado parcialmente sobrescrito.
9. A configuração da fonte DEVE fixar uma **revisão imutável** do dataset (commit
   ou tag), nunca uma referência móvel como `main`. QUANDO a importação for
   executada ENTÃO o sistema DEVE buscar exatamente a revisão configurada.
10. O resumo de execução do critério 6 DEVE registrar a revisão utilizada, de modo
    que seja possível identificar de qual versão da fonte veio cada importação.
11. A atualização da revisão fixada DEVE ser um ato explícito de quem mantém o
    sistema, nunca efeito colateral de executar a importação.

---

## Requisito 2 — Navegação do catálogo

**User story:** Como usuário, quero navegar por todas as cartas em uma grade
visual, para reconhecer cartas pela arte.

### Critérios de aceitação

1. O sistema DEVE exibir as cartas em grade, mostrando imagem, nome e
   `card_number`.
2. O sistema DEVE paginar os resultados (paginação clássica ou carregamento
   incremental).
3. QUANDO a imagem de uma carta não carregar ENTÃO o sistema DEVE exibir um
   placeholder com o nome e o `card_number`, sem quebrar o layout.
4. O sistema DEVE permitir ordenar por: `card_number`, nome, custo e power.
5. O sistema DEVE ser utilizável em viewport de 360px de largura sem scroll
   horizontal.

---

## Requisito 3 — Busca textual

**User story:** Como usuário, quero buscar cartas por nome, código ou texto de
efeito, para achar a carta que tenho em mente.

### Critérios de aceitação

1. QUANDO o usuário informar um termo de busca ENTÃO o sistema DEVE retornar
   cartas cujo nome, `card_number` ou texto de efeito contenham o termo.
2. A busca por nome DEVE ser insensível a maiúsculas/minúsculas e a acentuação.
3. QUANDO o termo tiver erro de digitação leve (ex.: 1–2 caracteres) ENTÃO o
   sistema DEVE ainda retornar a carta pretendida entre os resultados.
4. QUANDO o termo corresponder exatamente a um `card_number` ENTÃO essa carta
   DEVE aparecer como primeiro resultado.
5. QUANDO nenhum resultado for encontrado ENTÃO o sistema DEVE exibir estado
   vazio explícito com o termo buscado e opção de limpar os filtros.
6. A busca DEVE poder ser combinada com todos os filtros do Requisito 4.

---

## Requisito 4 — Filtros

**User story:** Como usuário, quero filtrar por atributos do jogo, para responder
perguntas como "quais Characters vermelhos de custo 3 com counter 2000 existem?".

### Critérios de aceitação

1. O sistema DEVE permitir filtrar por: cor, tipo de carta, set, raridade,
   attribute, trait, custo, power e counter.
2. O filtro de custo, power e counter DEVE aceitar faixa (mínimo e máximo).
3. QUANDO múltiplos filtros forem aplicados ENTÃO o sistema DEVE combiná-los com
   `E` lógico entre categorias diferentes.
4. QUANDO múltiplos valores da mesma categoria forem selecionados (ex.: vermelho
   e verde) ENTÃO o sistema DEVE combiná-los com `OU` lógico dentro da categoria.
5. QUANDO o filtro de cor selecionar uma cor ENTÃO cartas multicoloridas que
   contenham aquela cor DEVEM ser incluídas.
6. O sistema DEVE exibir os filtros ativos e permitir remover cada um
   individualmente.
7. O estado de busca e filtros DEVE ser refletido na URL, de forma que a URL
   possa ser compartilhada ou recarregada reproduzindo o mesmo resultado.
8. O sistema DEVE exibir a contagem total de cartas que satisfazem os filtros
   atuais.

---

## Requisito 5 — Detalhe da carta e variantes

**User story:** Como colecionador, quero ver todas as impressões de uma carta,
porque a arte alternativa é um item de coleção diferente da arte base.

### Critérios de aceitação

1. O sistema DEVE exibir uma página de detalhe com todos os campos conhecidos da
   carta e a imagem em resolução maior.
2. A página DEVE listar todas as variantes de impressão daquela carta, cada uma
   com sua raridade, set e imagem própria.
3. QUANDO o usuário registrar posse ENTÃO o registro DEVE ser feito **por
   variante**, nunca agregado na carta.
4. A página DEVE exibir o texto de efeito e, quando existir, o texto de trigger,
   preservando quebras de linha.
5. SE um campo não se aplicar ao tipo de carta (ex.: `life` em um Character)
   ENTÃO o sistema NÃO DEVE exibir aquele campo.

---

## Requisito 6 — Conta de usuário

**User story:** Como usuário, quero que minha coleção esteja vinculada a mim,
para poder acessá-la de mais de um dispositivo.

### Critérios de aceitação

1. O sistema DEVE permitir criar conta, autenticar e encerrar sessão.
2. A senha DEVE ser armazenada apenas como hash, com algoritmo de hashing de
   senha reconhecido.
3. QUANDO um usuário não autenticado acessar o catálogo ENTÃO o sistema DEVE
   permitir a navegação e a busca.
4. QUANDO um usuário não autenticado tentar alterar coleção ou wishlist ENTÃO o
   sistema DEVE exigir autenticação.
5. Um usuário NUNCA DEVE conseguir ler ou alterar a coleção de outro usuário.

---

## Requisito 7 — Coleção pessoal

**User story:** Como colecionador, quero registrar quantas cópias de cada
variante eu tenho, para saber minha coleção real.

### Critérios de aceitação

1. O sistema DEVE permitir definir uma quantidade possuída, inteira e
   não-negativa, para cada variante de carta.
2. O sistema DEVE permitir incrementar e decrementar a quantidade em uma ação
   única, sem abrir formulário.
3. QUANDO a quantidade for definida como zero ENTÃO o sistema DEVE tratar a
   variante como não possuída.
4. O sistema NÃO DEVE permitir quantidade negativa.
5. QUANDO o usuário registrar posse a partir da grade do catálogo ENTÃO a
   atualização DEVE ocorrer sem recarregar a página inteira.
6. O sistema DEVE permitir filtrar o catálogo por "somente as que eu tenho" e
   "somente as que eu não tenho".
7. O sistema DEVE exibir o total de cartas possuídas, contando cópias.
8. DEVE existir no máximo um registro de coleção por par (usuário, variante),
   garantido no banco de dados e não apenas na aplicação.

---

## Requisito 8 — Wishlist

**User story:** Como colecionador, quero marcar cartas que quero adquirir, para
levar essa lista a trocas e compras.

### Critérios de aceitação

1. O sistema DEVE permitir marcar uma variante como desejada, com quantidade-alvo.
2. O sistema DEVE permitir listar apenas os itens desejados.
3. QUANDO a quantidade possuída de uma variante atingir ou exceder a
   quantidade-alvo ENTÃO o sistema DEVE sinalizar esse item como atendido.
4. O sistema DEVE permitir remover um item da wishlist.

---

## Requisito 9 — Progresso por set

**User story:** Como colecionador, quero ver quanto de cada set eu completei, para
decidir o que caçar.

### Critérios de aceitação

1. O sistema DEVE exibir, para cada set, a quantidade de variantes distintas
   possuídas e o total de variantes do set.
2. O sistema DEVE exibir o percentual de conclusão por set.
3. O sistema DEVE permitir navegar de um set para o catálogo já filtrado por
   aquele set.
4. O cálculo de progresso DEVE contar variantes distintas, não cópias.
5. O percentual de conclusão de um set DEVE usar como denominador as **variantes
   base** do set (`baseSetSize` da fonte), não o total de impressões.
6. O sistema DEVE exibir a contagem de parallels possuídos como **métrica
   separada**, nunca somada ao percentual de conclusão.

> Decidido na task 0.3 (P3) — ver `docs/adr/002-stack-set-completo-e-imagens.md`.
> Contar todas as impressões travaria sets dominados por parallels perto de zero
> permanentemente (em `LimitedProductCard`, 171 de 192 registros são parallels),
> o que não responde à pergunta que este requisito existe para responder.

---

## Requisito 10 — Import e export CSV

**User story:** Como usuário, quero exportar e importar minha coleção em CSV, para
não ficar preso à aplicação e poder migrar de uma planilha existente.

### Critérios de aceitação

1. O sistema DEVE exportar a coleção em CSV contendo, no mínimo: `card_number`,
   identificador da variante, nome da carta e quantidade.
2. O sistema DEVE importar um CSV no mesmo formato do export.
3. QUANDO uma linha do CSV referenciar uma variante inexistente ENTÃO o sistema
   DEVE reportar essa linha como erro e continuar importando as demais.
4. AO final da importação o sistema DEVE apresentar um resumo com linhas
   importadas, atualizadas e rejeitadas, com o motivo de cada rejeição.
5. O sistema DEVE exibir uma pré-visualização e exigir confirmação antes de
   gravar alterações vindas de CSV.

---

## Requisito 11 — Requisitos não-funcionais

### Critérios de aceitação

1. Uma consulta ao catálogo com busca e filtros combinados DEVE responder em
   menos de 500ms no p95, com o catálogo completo carregado, em ambiente de
   desenvolvimento local.
2. As imagens DEVEM ser carregadas de forma preguiçosa (lazy loading) na grade.
3. O sistema DEVE ter índices de banco que sustentem os filtros do Requisito 4 sem
   varredura completa de tabela — verificável por plano de execução.
4. Toda alteração de coleção e wishlist DEVE ter teste automatizado.
5. O pipeline de ingestão DEVE ter teste automatizado com dados de exemplo
   fixos (fixture), sem depender de rede.
6. O sistema DEVE ser executável localmente com um único comando documentado.

---

## Rastreamento de pendências

Itens que **bloqueiam** o início da implementação:

| # | Pendência | Onde |
|---|---|---|
| P1 | Escolha e validação da fonte de dados do catálogo | `product.md` §5.2 |
| P2 | Confirmação dos campos, raridades, sets e attributes reais | `product.md` §6 |
| P3 | Definição de "set completo" (Req. 9) | Req. 9 |
| P4 | Escolha de stack | `design.md` §2 |
