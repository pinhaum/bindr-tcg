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
   A fonte vigente é a apitcg (`GET /api/products?tcg=one-piece&type=card` e `GET /api/one-piece/sets`), autenticada
   pelo header `x-api-key` com a chave lida de `APITCG_API_KEY`. SE a chave
   estiver ausente ENTÃO o processo DEVE abortar antes de qualquer requisição. A
   chave NUNCA DEVE aparecer em snapshot, log, `error_log` ou saída do processo.
   *(emendado em 2026-09-29, fonte-apitcg)*
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
9. A apitcg não publica revisão imutável. QUANDO a importação buscar a fonte ENTÃO
   o sistema DEVE gravar o payload bruto em `storage/ingestion/apitcg-<UTC>.json`
   antes de normalizar qualquer registro, e esse **snapshot** cumpre o papel da
   revisão fixada. A importação executada com `SNAPSHOT=<arquivo>` DEVE
   reprocessar esse arquivo sem nenhuma requisição de rede.
   *(emendado em 2026-09-29, fonte-apitcg; o texto anterior exigia uma revisão
   imutável — commit ou tag — do dataset da optcgjson, AD-001)*
10. O resumo de execução do critério 6 DEVE registrar a origem utilizada em
    `import_runs.source_revision`: o nome do arquivo do snapshot e o SHA-256 do
    conteúdo dele, de modo que seja possível identificar de qual busca veio cada
    importação. *(emendado em 2026-09-29, fonte-apitcg)*
11. Buscar uma fonte nova DEVE ser um ato explícito de quem mantém o sistema
    (`ingestion:import` sem `SNAPSHOT`); reprocessar um snapshot existente NÃO
    DEVE tocar a rede. Nenhum snapshot é substituído nem apagado pela importação.
    *(emendado em 2026-09-29, fonte-apitcg)*

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

1. O sistema DEVE exibir, para cada set, a quantidade de **números de carta
   distintos** possuídos (o numerador do critério 5) e o denominador do critério 5.
   *(emendado em 2026-09-30, fonte-apitcg; o texto anterior contava variantes
   distintas possuídas sobre o total de variantes do set)*
2. O sistema DEVE exibir o percentual de conclusão por set.
3. O sistema DEVE permitir navegar de um set para o catálogo já filtrado por
   aquele set.
4. O cálculo de progresso DEVE contar **números de carta distintos**, não cópias
   nem impressões: duas impressões não-parallel do mesmo `card_number` no mesmo
   set contam uma vez. Só entram variantes presentes na fonte (Req. 1.7).
   *(emendado em 2026-09-30, fonte-apitcg; na apitcg um mesmo número tem mais de
   uma impressão não-parallel no set, e contar variantes passaria de 100%)*
5. O percentual de conclusão de um set DEVE usar como denominador
   `sets.base_set_size`, derivado na ingestão: os `card_number` distintos do set
   cujo prefixo é o código do set, quando eles forem maioria estrita entre os
   números distintos do set; senão, todos os números distintos do set. O
   numerador conta, do mesmo universo, os números para os quais o usuário possui
   ao menos uma variante presente do set que não seja parallel. O percentual
   NUNCA DEVE passar de 100%.
   *(emendado em 2026-09-30, fonte-apitcg; o texto anterior usava o
   `baseSetSize` da optcgjson, que a apitcg não publica)*
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
   fixos (fixture), sem depender de rede e sem `APITCG_API_KEY`. A fixture é
   `spec/fixtures/apitcg-subset.json`, recortada de um snapshot real da apitcg e
   verificada por `python3 spec/verify_fixture.py`.
   *(emendado em 2026-09-29, fonte-apitcg; substitui
   `spec/fixtures/optcgjson-subset.json`)*
6. O sistema DEVE ser executável localmente com um único comando documentado.
7. As imagens das cartas DEVEM ser entregues ao navegador pela origem da própria
   aplicação. A fonte responde `Cross-Origin-Resource-Policy: same-site`, que faz
   o navegador descartar a imagem em qualquer página fora do domínio dela — um
   `<img>` apontando para a URL original nunca exibe arte (AD-012).
   Com a apitcg, a arte vem do host `tcgplayer-cdn.tcgplayer.com` e `image_url`
   usa a imagem `large`; a restrição de host contra SSRF continua, apontada
   para esse host. *(emendado em 2026-09-29, fonte-apitcg)*

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
   "Catálogo" e, para quem tem sessão, "Minha pasta", "Baralhos" e "Sair", nesta
   ordem; para anônimo, "Entrar" e "Criar conta" no lugar das três últimas.
   *Emendado em 2026-10-02 pela feature `decks` (Req. 14): "Baralhos" entra
   quando o deck passa a existir.*
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
   (preços). *Emendado em 2026-10-02 pela feature `decks` (Req. 14): baralho
   saiu da lista porque passou a existir, e entra pelo critério 1.*

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
    variante em destaque, a mesma da imagem (critério 40). Os demais campos do Req. 5.1 continuam
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

O critério 40 foi acrescentado em 2026-10-01, a pedido do dono: a imagem
principal mostrava sempre a primeira variante, e a arte alternativa só aparecia
na miniatura pequena da lista.

40. QUANDO o usuário escolher uma variante na seção "Variantes na pasta" ENTÃO a
    imagem principal, o selo de quantidade, a legenda de ilustração e a
    raridade e o set do cabeçalho DEVEM passar a ser os dessa variante, sem
    JavaScript. A escolha DEVE ficar na URL (`?variant=<variant_code>`), e a
    variante em destaque DEVE estar marcada na lista. Sem escolha, ou com um
    `variant` que não está entre as variantes listadas, vale a primeira
    variante presente — parâmetro inválido é ignorado, nunca causa erro.

---

## Requisito 14 — Decks (Fase 2)

**User story:** Como jogador, quero montar decks pelas regras do jogo e ver o
que falta na minha pasta para montá-los de verdade, para não conferir à mão,
carta por carta, uma lista feita em outro app.

Requisito da Fase 2, aprovado pelo dono em 2026-10-01. Recorte e decisões em
`.specs/features/decks/spec.md` (DCK-NN, mesma numeração destes critérios).

Regras de montagem confirmadas no Play Guide oficial
(`en.onepiece-cardgame.com/play-guide/`): 1 Leader, deck principal de 50 cartas,
no máximo 4 cópias por `card_number`, e as cartas do deck principal só com cores
do Leader. As 10 DON!! ficam fora (P7). **A lista de banidas não é verificada**
(decisão do dono): ela muda com frequência e a fonte não a traz.

> Confirmado nas Comprehensive Rules v1.2.1 (`en.onepiece-cardgame.com/pdf/rule_comprehensive.pdf`,
> atualizadas em 28/08/2026) em 2026-10-02: (a) a carta multicolorida "is
> treated as a card of every color it possesses" (2-3-5), e só entram no deck
> cartas de cor incluída no Leader (5-1-2-2): a leitura estrita vale; (b) o
> limite de 4 (5-1-2-3) **tem exceções**: efeitos de carta sobre a montagem
> "replace the deck construction rules above" (5-1-2-4). No snapshot da apitcg de
> 2026-10-01 são três cartas com "you may have any number of this card in your
> deck" (OP01-075, OP08-072, OP16-042) e três Leaders que restringem o deck
> (OP12-001, OP13-079, P-117). Tratamento decidido pelo dono em 2026-10-02:
> critérios 43 e 44.
>
> ⚠️ VERIFICAR (c): se o OPTCG Simulator aceita LF na lista exportada; o
> exemplo do dono veio separado por CR. Fica para o teste manual do dono.

### Critérios de aceitação

**Montar**

1. QUANDO o usuário autenticado criar um deck com um nome ENTÃO o sistema DEVE
   criá-lo vazio, sem Leader, pertencente a esse usuário, e abrir a página dele.
2. O deck DEVE ser um Leader opcional mais entradas `(carta, quantidade)` que
   referenciam `cards`, nunca `card_variants`, com no máximo uma entrada por
   carta por deck garantida no banco.
3. ENQUANTO houver um deck em edição, o detalhe de cada carta não-Leader DEVE
   exibir incremento e decremento da quantidade dela nesse deck, com a
   quantidade atual visível.
4. ENQUANTO houver um deck em edição, o detalhe de uma carta Leader DEVE exibir
   a ação "Usar como Leader", que substitui o Leader do deck.
5. QUANDO o usuário incrementar ou decrementar uma carta no deck ENTÃO o sistema
   DEVE aplicar a alteração em uma única ação, sem recarregar a página inteira.
6. QUANDO o decremento levar a quantidade a zero ENTÃO o sistema DEVE remover a
   entrada do deck.
7. A página do deck DEVE exibir o Leader e as cartas do deck principal
   agrupadas em Character, Event e Stage, ordenadas por custo e depois por
   `card_number`, com a quantidade de cada uma e o total "N / 50".
8. A lista de decks DEVE exibir cada deck do usuário com nome, Leader, total
   "N / 50" e status.
9. QUANDO o usuário excluir um deck ENTÃO o sistema DEVE pedir confirmação e,
   confirmada, remover o deck sem alterar coleção nem wishlist.
10. QUANDO o usuário renomear um deck ENTÃO o sistema DEVE manter Leader e
    entradas.

**Validar**

11. O status do deck DEVE ser calculado a cada leitura, nunca persistido, como
    exatamente um de `válido`, `incompleto` ou `inválido`.
12. `válido`: há Leader, o deck principal soma exatamente 50, nenhuma carta passa
    de 4 cópias (salvo a exceção do critério 43) e toda carta tem só cores do
    Leader.
13. `inválido`: o deck principal passa de 50, alguma carta não isenta pelo
    critério 43 passa de 4 cópias ou,
    havendo Leader, alguma carta tem cor que o Leader não tem.
14. `incompleto`: nem `válido` nem `inválido` — sem Leader ou com menos de 50
    cartas, sem violação do critério 13.
15. QUANDO o status não for `válido` ENTÃO a página do deck DEVE listar cada
    motivo em português, nomeando as cartas envolvidas.
16. A carta multicolorida DEVE contar como tendo todas as suas cores ao mesmo
    tempo (Comprehensive Rules 2-3-5).
17. A página do deck DEVE exibir o aviso "A lista de banidas não é verificada".
18. Uma regra do jogo NUNCA DEVE recusar a gravação de uma alteração; a violação
    aparece só no status.
19. A carta ausente da fonte DEVE continuar no deck, contando para as regras,
    marcada como "fora da fonte".

**O que falta na pasta**

20. As cópias possuídas de uma carta DEVEM ser a soma das quantidades de todas
    as variantes dela na coleção do usuário, presentes ou não na fonte.
21. A página do deck DEVE exibir, para o Leader e cada carta, a quantidade
    pedida, a possuída e a que falta, `max(0, pedida − possuída)`.
22. A página do deck DEVE exibir o total que falta, ou "Você tem todas as cartas
    deste deck" quando for zero e o deck tiver Leader ou entradas. Deck sem
    Leader e sem entradas DEVE exibir "Este deck ainda não tem cartas".
23. O que falta DEVE ser derivado da coleção atual a cada leitura, sem
    sincronização gravada.

**Importar e exportar (formato do OPTCG Simulator)**

24. QUANDO o usuário importar uma lista ENTÃO o sistema DEVE criar um deck novo,
    nunca alterar um existente, com o nome informado ou o do Leader importado.
    Sem nome e sem Leader na lista, a importação DEVE ser recusada pedindo um
    nome, sem criar deck.
25. O formato DEVE ser uma linha `<N>x<card_number>` por carta, com o Leader
    incluído como `1x<card_number>`; aceitar CR, LF e CRLF, ignorar linhas em
    branco e espaços nas bordas e ao redor do `x`, e comparar `card_number` sem
    distinção de caixa.
26. QUANDO uma linha apontar para uma carta Leader ENTÃO ela DEVE virar o Leader
    do deck.
27. QUANDO o mesmo `card_number` aparecer em mais de uma linha ENTÃO as
    quantidades DEVEM ser somadas numa única entrada.
28. SE alguma linha estiver fora do formato, apontar para `card_number`
    inexistente, tiver quantidade fora de 1 a 50, ou a lista tiver mais de um
    Leader, Leader com quantidade diferente de 1, linhas repetidas de uma carta
    cuja soma passe de 50 ou nenhuma carta, ENTÃO o sistema DEVE recusar a
    importação inteira, sem criar deck, listando cada linha com número e
    motivo.
29. SE o texto passar de 200 linhas ou 10.000 caracteres ENTÃO o sistema DEVE
    recusá-lo sem processar e informar o limite.
30. Uma lista aceita que viole regra de montagem DEVE gerar o deck, com status
    `inválido` ou `incompleto`.
31. A exportação DEVE trazer o Leader como `1x<card_number>` na primeira linha e
    uma linha `<N>x<card_number>` por carta, na ordem da página do deck,
    separadas por LF. ⚠️ VERIFICAR (acima).
32. Importar o texto exportado de um deck DEVE produzir o mesmo Leader e as
    mesmas entradas.

**Faltando para os baralhos (pasta)**

33. O que falta de cada carta DEVE ser `max(0, maior quantidade pedida entre os
    decks do usuário − possuída)`, com o Leader contando 1.
34. QUANDO houver ao menos uma carta faltando ENTÃO a pasta DEVE exibir o bloco
    "Faltando para os baralhos" com cada carta, a quantidade que falta e links
    para os decks que a usam.
35. QUANDO o usuário não tiver decks ou nada faltar ENTÃO a pasta DEVE omitir o
    bloco.

**Isolamento, limites e integridade**

36. Um deck de outro usuário DEVE responder 404 a qualquer leitura ou alteração.
37. Toda rota de deck DEVE exigir sessão.
38. Incrementos simultâneos da mesma carta no mesmo deck DEVEM ser todos
    aplicados.
39. A quantidade por carta DEVE ficar entre 1 e 50 e o nome do deck entre 1 e 60
    caracteres; fora disso a gravação é recusada com mensagem em português.
40. A ingestão DEVE preservar todo Leader e toda entrada de deck; nenhuma
    foreign key de deck DEVE usar delete em cascata a partir de `cards`.
41. QUANDO o deck em edição for excluído ENTÃO o detalhe DEVE deixar de exibir
    os controles de deck até outro deck ser escolhido.
42. QUANDO o deck não tiver Leader ENTÃO a regra de cor DEVE ficar fora do
    status e dos motivos.

**Efeitos de carta sobre a montagem (Comprehensive Rules 5-1-2-4)**

43. A carta cujo texto de efeito contém "Under the rules of this game, you may
    have any number of this card in your deck" DEVE ficar isenta do limite de 4
    cópias, continuando sujeita ao limite de 50 do critério 39. A isenção DEVE
    sair do texto do catálogo, sem lista mantida à mão.
44. QUANDO o texto de efeito do Leader contiver "Under the rules of this game"
    seguido de restrição ao deck ("cannot include" ou "can only include") ENTÃO
    a página do deck DEVE exibir o aviso "Este Leader tem regra de montagem
    própria, não verificada" junto com o texto dessa regra. A restrição NÃO DEVE
    ser verificada e NÃO DEVE mudar o status (decisão do dono em 2026-10-02).

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
