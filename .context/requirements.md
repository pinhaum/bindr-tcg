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
4. O sistema DEVE permitir ordenar por: lançamento, `card_number`, nome, custo e
   power. Na ausência de escolha, o sistema DEVE exibir primeiro as cartas mais
   recentes — data de lançamento do set de estreia da carta, decrescente, com
   set sem data ao final e desempate por `card_number` crescente.
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
9. O sistema DEVE oferecer na grade controles para aplicar filtro de cor, tipo de
   carta, raridade, set e posse sem que o usuário edite a URL. Os filtros por
   faixa (custo, power, counter), `attribute` e `trait` continuam acessíveis pela
   URL e ficam sem controle até decisão própria.

> Acrescentado em 2026-09-22 (feature `navegacao`). Até aqui o Req. 4 era
> satisfeito pelo query object e pelos chips removíveis, mas a grade não tinha
> nenhum controle para **aplicar** filtro — o único caminho era a URL ou o link
> "ver no catálogo" do progresso.

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
5. QUANDO o usuário registrar posse no detalhe da carta ENTÃO a atualização
   DEVE ocorrer sem recarregar a página inteira. A grade do catálogo NÃO DEVE
   oferecer controle de posse: ela só exibe a quantidade possuída (Req. 13.22).

   > Emendado em 2026-09-27 (feature `conformidade`, decisão D4 do dono). O
   > texto anterior pedia o registro "a partir da grade do catálogo". O canvas
   > desenha a grade só com o selo de quantidade, e o registro passa a ficar
   > só no detalhe, onde o critério 2 continua cumprido.
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
7. O sistema DEVE ordenar a lista de sets por uma de duas ordens, escolhida por
   parâmetro de URL, sem JavaScript:
   - **"Recentes" (padrão):** pelo `updated_at` mais novo dos registros de
     coleção do usuário naquele set, do mais novo para o mais antigo;
   - **"Por código":** pelo código do set, crescente.

   Em qualquer das duas ordens, os sets sem posse DEVEM vir no fim, por código;
   com a coleção vazia, a lista inteira fica por código. A ordenação DEVE partir
   do usuário da sessão (Req. 6.5). SE o parâmetro de ordem for desconhecido ou
   inválido ENTÃO o sistema DEVE usar o padrão, sem erro.

   > Acrescentado em 2026-09-27 (feature `conformidade`, decisão D11 do dono).
   > "Recente" é a atividade do usuário, não a data de lançamento: os sets da
   > fixture têm `releaseDate: null`.

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
2. O sistema DEVE importar um CSV no mesmo formato do export. QUANDO uma linha
   referenciar uma variante já possuída ENTÃO o sistema DEVE **substituir** a
   quantidade existente pelo valor do arquivo, sem somar (AD-006).
3. QUANDO uma linha do CSV referenciar uma variante inexistente ENTÃO o sistema
   DEVE reportar essa linha como erro e continuar importando as demais.
4. AO final da importação o sistema DEVE apresentar um resumo com linhas
   importadas, atualizadas e rejeitadas, com o motivo de cada rejeição.
5. O sistema DEVE exibir uma pré-visualização e exigir confirmação antes de
   gravar alterações vindas de CSV. Entre a pré-visualização e a confirmação, o
   arquivo DEVE viver numa tabela `collection_imports` no banco, dona do usuário
   que o enviou, com expiração (AD-007).
6. O sistema DEVE rejeitar o arquivo inteiro se ele contiver mais de 10.000
   linhas de dado (sem contar o cabeçalho), com mensagem em português que diz o
   limite (AD-008).

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
7. As imagens das cartas DEVEM ser entregues ao navegador pela origem da própria
   aplicação. A fonte responde `Cross-Origin-Resource-Policy: same-site`, que faz
   o navegador descartar a imagem em qualquer página fora do domínio dela — um
   `<img>` apontando para a URL original nunca exibe arte (AD-012).

---

## Requisito 12 — Camada de apresentação

**User story:** Como colecionador usando o app em mesa de loja, com o celular perto
do rosto e um booster na outra mão, quero uma interface que não dispute atenção com
a arte das cartas, para achar o que procuro de relance.

O design system que este requisito aplica está em
`.context/design.md` §11. Ele nasceu de proposta derivada dos requisitos de UI
(Req. 2, 4, 7, 11) antes de existir CSS no repositório — não foi extraído do
código. Onde o CSS atual divergir dele, **o design system vence**, exceto no que
os critérios abaixo preservam explicitamente.

### Critérios de aceitação

1. O sistema DEVE declarar todos os valores de cor, tipografia, espaçamento e raio
   como custom properties CSS em `:root`, e nenhum bloco DEVE repetir um valor
   literal que exista como token.
2. O sistema DEVE ter **um único tema, escuro**, declarado com `color-scheme: dark`,
   e NÃO DEVE declarar `prefers-color-scheme`.
3. Todo par de texto sobre fundo DEVE atingir contraste de 4.5:1, exceto texto a
   partir de 24px, bordas de controle, anéis de foco e ícones, que DEVEM atingir
   3:1 — verificável por cálculo de luminância relativa sobre os valores dos tokens.
4. O sistema DEVE usar exatamente duas matizes — azul-petróleo (228°) nas
   superfícies, bordas e tinta, e âmbar (66°) na ação — e NÃO DEVE introduzir uma
   terceira, com a exceção única de `danger` (28°).
5. O sistema NÃO DEVE usar sombra nem gradiente em nenhum elemento de interface.
6. Nenhum estado, quantidade ou posse DEVE ser comunicado apenas por cor: posse se
   distingue por presença de badge com número, e estado ativo de filtro por rótulo
   escrito.
7. O sistema DEVE renderizar `card_number` e `variant_code` no estilo monoespaçado
   `code`, em toda ocorrência, inclusive quando inline em meio a texto corrido.
   Exceção: mensagens de flash são texto puro e ficam fora da regra — marcá-las
   exigiria HTML montado no controller e mais uma superfície de escape
   (decisão do dono do produto em 2026-09-22, no fechamento da `interface`).
8. QUANDO uma mensagem for de erro ENTÃO o sistema DEVE distingui-la visualmente de
   uma mensagem de sucesso por mais do que a cor.
9. O anel de foco DEVE ser sólido de 2px em `accent`, com 2px de deslocamento, e
   NÃO DEVE ser translúcido.
10. O sistema NÃO DEVE usar emoji em nenhum ponto da interface.
11. O chip de filtro das seis cores do jogo NÃO DEVE ser preenchido com `accent`;
    sua seleção DEVE ser indicada por anel de 2px em `accent` mais rótulo escrito.
12. As verificações de viewport de 360px do Req. 2.5 DEVEM continuar passando após a
    aplicação dos tokens.

> **Pendência P8 — hexadecimais das seis cores do jogo.** `Red`, `Green`, `Blue`,
> `Purple`, `Black` e `Yellow` são o eixo do filtro do Req. 4 e **não têm valor
> definido**: precisam sair das faces das cartas ou do material da Bandai, nunca de
> estimativa sobre a arte comprimida das cartas. Enquanto não existirem, o critério
> 11 é satisfeito com tratamento neutro (`border-strong` mais rótulo). Quando
> entrarem, cada cor precisa de um par `on-<cor>` verificado — `Yellow` e `Black`
> não suportam o mesmo texto — e `Yellow` precisa ser conferido contra `accent`: a
> menos de ~25° de matiz, quem se desloca é `accent`.

---

## Requisito 13 — Navegação e layout das telas

**User story:** Como colecionador, quero alcançar catálogo e pasta de qualquer
tela com o polegar, e ver o resumo da minha coleção num lugar só, para registrar
uma caixa de boosters e responder "quanto falta do set X?" sem procurar menu.

O layout de referência é o canvas **"Bindr — telas"**
(`claude.ai/artifact/P7WCTR9YkH1i52DWoVwPn8`), externo ao repo. Ele desenha
também baralho (Fase 2) e preços (Fase 3); esses elementos **não** fazem parte
deste requisito. Em divergência, este documento vence (AD-005). Desde
2026-09-27 os artboards versionados em `.specs/features/navegacao/canvas/` são
critério de aceite de cada tela (AD-016, critério 21).

### Critérios de aceitação

1. O sistema DEVE exibir em toda página uma navegação principal com as entradas
   "Catálogo" e, para quem tem sessão, "Minha pasta" e "Sair"; para anônimo,
   "Entrar" e "Criar conta" no lugar das duas últimas.
2. A entrada da página atual DEVE ser marcada com `aria-current="page"` e
   distinguida por mais do que a cor.
3. Em viewport estreita a navegação DEVE ficar fixa na borda inferior, com alvos
   de toque de no mínimo 44px, sem cobrir o fim do conteúdo; em viewport larga
   DEVE ficar numa coluna lateral.
4. "Minha pasta" DEVE ser a página de progresso por set, acrescida do total de
   cópias (Req. 7.7), do número de variantes distintas possuídas e de links para
   a wishlist, o import e o export.
5. Em viewport larga, os controles de filtro do Req. 4.9 DEVEM ficar numa coluna
   ao lado da grade; em viewport estreita, acima dela.
6. Em viewport larga, o detalhe da carta DEVE exibir a arte ao lado dos dados da
   carta; em viewport estreita, empilhado.
7. As verificações de 360px do Req. 2.5 e os critérios do Req. 12 DEVEM continuar
   passando.
8. A navegação NÃO DEVE exibir entrada para funcionalidade que não existe
   (baralho, preços).

Os critérios 9 a 14 foram acrescentados em 2026-09-24, depois que o dono do
produto reprovou a revisão visual da `navegacao`. A implementação cumpria os
critérios 1 a 8 e mesmo assim não se parecia com o canvas, porque nenhum deles
descrevia a forma visual. Eles trazem para cá o que o canvas desenha e que
passa a ser obrigatório.

9. Em viewport estreita, as entradas da barra inferior DEVEM dividir a largura
   da barra em partes iguais, e a entrada atual DEVE ter fundo distinto das
   demais, além do peso de fonte.
10. Em viewport larga, a coluna lateral DEVE ter largura fixa e superfície
    elevada, separada do conteúdo por borda. No catálogo, ela DEVE conter os
    controles de filtro abaixo da navegação.
11. Os controles de cor, tipo, raridade e posse DEVEM ser chips de no mínimo
    44px de altura que aplicam ou removem o valor com um toque, sem JavaScript.
    O chip ativo DEVE exibir um sinal de remoção visível, e seu nome acessível
    DEVE dizer que o toque remove o filtro. O set continua num controle de
    seleção.
12. O catálogo DEVE exibir sempre a contagem de resultados. Com filtro ativo,
    DEVE exibir também quantos filtros estão ativos e a ação "Limpar filtros".
13. Em "Minha pasta", os indicadores do critério 4 DEVEM aparecer como cartões
    com o número em destaque, e cada set DEVE ter uma barra de progresso ao lado
    da contagem "possuídas / total".
14. "Minha pasta" DEVE oferecer a ação "Adicionar cartas", que leva ao
    catálogo.

Os critérios 15 a 20 foram acrescentados em 2026-09-26, depois da primeira
revisão com as telas renderizadas em navegador (AD-015). A implementação
cumpria os critérios 1 a 14, mas a render mostrou a navegação no pé da coluna
lateral, um vão entre os grupos de filtro, nenhuma carta na primeira tela do
catálogo no celular e um detalhe sem a imagem maior que o Req. 5.1 já pedia.

15. Em viewport larga, a navegação DEVE ficar logo abaixo da marca, no topo da
    coluna lateral. As entradas da navegação NÃO DEVEM ser sublinhadas.
16. Em viewport larga, no catálogo, navegação e filtros DEVEM ocupar uma
    superfície contínua, com espaçamento fixo entre os grupos de filtro.
17. Em viewport estreita, os controles de filtro DEVEM ficar recolhidos por
    padrão num controle que diz quantos filtros estão ativos, e os filtros
    ativos DEVEM continuar visíveis e removíveis com ele recolhido. Em viewport
    larga, os controles DEVEM ficar sempre visíveis.
18. O campo de busca e o botão "Buscar" DEVEM ter alvo de no mínimo 44px e as
    superfícies do design system. A linha de status DEVE ficar alinhada à grade.
19. O detalhe da carta DEVE exibir a imagem maior do Req. 5.1 numa coluna
    própria em viewport larga; em viewport estreita, conforme o critério 30. As
    variantes DEVEM ser listadas em linhas, cada uma com sua imagem (Req. 5.2).
    Os controles de posse no detalhe DEVEM ter alvo de no mínimo 44px.
    *(Emendado em 2026-09-27: o texto anterior pedia a imagem maior "em
    destaque" também no celular, o que empurrava contra o canvas; decisão D8.)*
20. Em "Minha pasta", cada set DEVE ocupar uma linha sem moldura, com a contagem
    "possuídas / total" na mesma linha do nome, e os links de wishlist, import e
    export DEVEM formar um grupo de ações secundárias separado de "Adicionar
    cartas".

Os critérios 21 a 39 foram acrescentados em 2026-09-27 (feature `conformidade`),
depois que o dono reprovou de novo a revisão visual: os critérios anteriores
copiavam traços isolados do canvas, e a composição de cada tela nunca virou
critério. A partir daqui o artboard é critério de aceite (AD-016).

21. Catálogo, detalhe e "Minha pasta" DEVEM seguir, em 390px e em 1280px, os
    artboards versionados em `.specs/features/navegacao/canvas/`. Toda
    divergência entre tela e artboard DEVE estar coberta por um critério deste
    requisito ou por uma exclusão registrada na spec da feature. Em dúvida
    visual, vale o artboard; em conflito com um critério escrito, vale o
    critério (AD-005).

**Catálogo**

22. O tile da grade DEVE exibir a quantidade possuída só como um selo numérico
    sobre o canto superior direito da arte, e só com sessão e quantidade maior
    que zero. A grade NÃO DEVE ter controle de posse (Req. 7.5).
23. Para anônimo, o convite a entrar para registrar posse DEVE aparecer uma
    única vez, na linha de status, e não em cada tile.
24. O tile DEVE exibir a raridade ao lado do código quando a carta tem uma
    variante só; com mais de uma, a legenda "N impressões".
25. Em viewport de 1280px, a grade DEVE ter cinco colunas. Em larguras menores,
    as colunas se reorganizam sem scroll horizontal (Req. 2.5).
26. A linha de status DEVE ser uma frase única, "N cartas · M filtros ativos",
    com "Limpar filtros" à direita quando houver filtro. Em viewport larga ela
    DEVE ficar na mesma linha do campo de busca.
27. O campo de busca DEVE ter o rótulo "Buscar por nome ou card_number" e um
    código de carta como exemplo no placeholder.
28. O catálogo NÃO DEVE exibir o total de cópias da coleção; esse total fica em
    "Minha pasta" (critério 4, Req. 7.7).
29. Os chips de cor DEVEM seguir a ordem Red, Green, Blue, Purple, Black,
    Yellow; os de raridade, a ordem de valor da raridade; os de tipo, o nome com
    inicial maiúscula. Ordem e capitalização são apresentação: o valor enviado na
    URL não muda.

**Detalhe da carta**

30. Em viewport estreita, o detalhe DEVE exibir uma miniatura da arte ao lado do
    título, e a imagem maior do Req. 5.1 DEVE abrir num controle que expande no
    próprio lugar, sem JavaScript.
31. O cabeçalho do detalhe DEVE exibir, como chips, o tipo, a raridade e a cor
    da carta (e o counter, em viewport larga), e uma linha "nome do set ·
    código". Raridade e set são da variante: o cabeçalho usa os da primeira
    variante listada, a mesma da imagem. Os demais campos do Req. 5.1 continuam
    visíveis, em forma compacta, respeitando o Req. 5.5.
32. O texto de trigger (Req. 5.4) DEVE aparecer dentro da seção de efeito.
33. A seção de variantes DEVE se chamar "Variantes na pasta". Cada linha DEVE
    exibir o código da variante, "raridade · tipo de arte", o set, uma miniatura
    própria menor que a imagem principal e, com sessão, a quantidade possuída
    ("não tenho" quando zero) com o controle `−` `[n]` `+`, em que `[n]` só
    exibe a quantidade e não é editável.
34. "Voltar ao catálogo" DEVE ser um botão bordado de no mínimo 44px, sem seta.
    Em viewport larga ele DEVE ficar na coluna lateral, abaixo de um divisor.
35. O detalhe DEVE exibir o selo de quantidade sobre a imagem principal quando o
    usuário tem sessão e possui a variante, e a legenda "Ilustração: nome"
    quando a variante tem ilustrador conhecido.

**Minha pasta**

36. O nome de cada set DEVE ser o link para o catálogo filtrado por ele
    (Req. 9.3). O percentual (Req. 9.2) DEVE aparecer junto da contagem
    "possuídas / total", e a contagem de parallels (Req. 9.6) como legenda da
    linha. A pasta NÃO DEVE exibir a contagem total de sets.
37. A pasta DEVE oferecer a escolha de ordem do Req. 9.7 como chips-link junto
    do título "Progresso por set", com o chip da ordem atual marcado.
38. A ação "Adicionar cartas à pasta" DEVE ficar fixa acima da barra inferior
    em viewport estreita e na coluna lateral, abaixo de um divisor, em viewport
    larga.
39. Em viewport larga, os cartões de indicador DEVEM ter a largura do artboard,
    um quarto da coluna de conteúdo cada, sem esticar.

---

## Rastreamento de pendências

### Resolvidas

| # | Pendência | Decisão | Onde |
|---|---|---|---|
| P1 | Escolha e validação da fonte de dados do catálogo | (AD-001) | task 0.1, `.specs/STATE.md`, `docs/adr/001-fonte-de-dados-do-catalogo.md` |
| P2 | Confirmação dos campos, raridades, sets e attributes reais | (task 0.2) | `.context/tasks.md`, fixture validada |
| P3 | Definição de "set completo" (Req. 9) | (AD-003) | task 0.3, `.specs/STATE.md`, `docs/adr/002-stack-set-completo-e-imagens.md` |
| P4 | Escolha de stack | (AD-002) | task 0.3, `.specs/STATE.md`, `docs/adr/002-stack-set-completo-e-imagens.md` |

### Em aberto

| # | Pendência | Onde |
|---|---|---|
| P8 | Hexadecimais das seis cores do jogo (Req. 12.11) | Req. 12 (emenda de 2026-09-29) |
