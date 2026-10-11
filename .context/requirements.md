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
   *Emendado em 2026-10-10 pela feature `spa-fundacao` (Req. 17, AD-025): a SPA
   tem tema claro e escuro, com padrão em `prefers-color-scheme` e escolha
   manual. As páginas Hotwire continuam no tema único escuro até saírem
   (`spa-troca`, AD-023); os demais critérios deste requisito valem para os
   dois temas.*
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
> Verificado (c) em 2026-10-05: o OPTCG Simulator aceita LF na lista exportada
> (teste manual do dono na T21 da `decks`; o exemplo do dono veio separado por CR).

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
    separadas por LF (verificado no simulador, acima).
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

## Requisito 15 — Preços (Fase 3)

**User story:** Como colecionador, quero ver quanto vale cada variante e quanto
vale a minha pasta, para saber o que tenho de valor sem consultar carta por
carta num site de mercado.

Requisito da Fase 3, com decisões do dono em 2026-10-05. Recorte em
`.specs/features/precos/spec.md` (PRC-NN, mesma numeração destes critérios).

Fonte: o preço `market` do TCGplayer que a própria apitcg já entrega por produto
(`markets.tcgplayer.prices.market`), lido no Normalize a cada
`ingestion:import`. Não há integração nova nem consulta à apitcg fora da
ingestão (decisão do dono: guardar no banco, não consultar por página). Medido
no snapshot `apitcg-20261001T231649Z.json`: 7.253 produtos, 7.038 com `prices`,
6.903 com `market` numérico; 90 produtos têm mais de uma impressão (Normal e
Foil) sob o mesmo id. O produto do TCGplayer é a `card_variant` deste app
(`variant_code = tcgplayer:<id>`, AD-019), então o preço é atributo da variante
(`design.md` §10). Só o preço atual é guardado; não há histórico. A moeda é USD
e fica explícita no dado, para BRL entrar depois sem migrar o que existe.

### Critérios de aceitação

**Ingestão**

1. QUANDO a ingestão processar um produto cujo `markets.tcgplayer.prices.market`
   seja um número maior ou igual a zero ENTÃO o sistema DEVE gravar na variante
   esse valor, a moeda `USD` e a data e hora em que o import começou.
2. SE o produto vier sem `markets.tcgplayer.prices.market` numérico e maior ou
   igual a zero (ausente, nulo, negativo ou não numérico) ENTÃO o sistema DEVE
   deixar a variante sem preço (valor, moeda e data nulos), mesmo que ela tivesse
   preço antes, e o registro NÃO DEVE falhar por isso.
3. O preço DEVE vir de `markets.tcgplayer.prices`, o preço da impressão principal
   do produto, e nunca de `markets.tcgplayer.printings`, mesmo quando houver mais
   de uma impressão.
4. QUANDO uma variante não vier na fonte num import ENTÃO o sistema DEVE manter o
   último preço dela, com a moeda e a data desse preço.
5. O banco DEVE garantir que valor, moeda e data do preço sejam todos nulos ou
   todos preenchidos, e que o valor nunca seja negativo.
6. O conhecimento do formato de preço da apitcg DEVE ficar só no estágio
   Normalize, como o resto do formato da fonte.
7. QUANDO o mesmo snapshot for importado duas vezes ENTÃO os valores e as moedas
   dos preços DEVEM ser os mesmos depois de cada import, e a coleção do usuário
   DEVE continuar intacta.

**Detalhe da carta**

8. QUANDO alguém abrir o detalhe de uma carta ENTÃO o sistema DEVE exibir, em
   cada variante com preço, o valor no formato `US$ 1.234,56` e o rótulo
   `TCGplayer · market · <dd/mm/aaaa>`, com a data do preço.
9. QUANDO a variante não tiver preço ENTÃO o detalhe DEVE exibir "Sem preço" no
   lugar do valor.
10. O preço no detalhe DEVE ser visível sem sessão, como o resto do catálogo
    (Req. 6.3).

**Valor da pasta**

11. QUANDO o usuário autenticado abrir a pasta ENTÃO o sistema DEVE exibir o
    valor estimado da coleção: a soma de `quantidade × preço` das variantes
    possuídas que têm preço, em USD, no formato `US$ 1.234,56`.
12. QUANDO houver cópias possuídas de variantes sem preço ENTÃO a pasta DEVE
    exibir quantas são, junto do valor estimado ("N cópias sem preço").
13. A pasta DEVE exibir, em cada set, o subtotal `quantidade × preço` das
    variantes possuídas daquele set, agrupando pelo set da variante.
14. O valor da pasta e os subtotais DEVEM considerar só a coleção do usuário da
    sessão (Req. 6.5).
15. QUANDO o usuário não tiver nenhuma cópia com preço ENTÃO a pasta DEVE exibir
    o valor estimado como `US$ 0,00`.
16. O valor estimado e os subtotais por set DEVEM sair de uma consulta agregada,
    sem uma consulta por variante ou por set.

---

## Requisito 16 — Fundação da API JSON

**User story:** Como SPA do Bindr, quero sessão, CSRF, erros e o catálogo em
JSON sob `/api`, para substituir as telas Hotwire sem depender de HTML nem de
redirect.

Requisito da troca de front (AD-023), com decisões do dono em 2026-10-10.
Recorte em `.specs/features/api-fundacao/spec.md` (API-NN, mesma numeração
destes critérios).

A API mora em `/api/*`, sem versão, na mesma origem do Rails. A sessão é o mesmo
cookie assinado do HTML (`httponly`, `same_site: lax`) e toda mutação verifica
CSRF. A serialização usa `jbuilder` (AD-024). Os controllers HTML não mudam; a
API tem controllers próprios que reusam os query objects e os models; lógica
extraída de um controller HTML para objeto compartilhado é permitida, desde que
o comportamento HTML não mude. Esta
feature cobre a infraestrutura e o catálogo; coleção, wishlist, pasta, decks e
portabilidade são fatias seguintes.

### Critérios de aceitação

**Sessão e CSRF**

1. QUANDO `GET /api/session` chegar sem sessão ENTÃO o sistema DEVE responder
   `200` com `user: null` e um `csrf_token`.
2. QUANDO `GET /api/session` chegar com sessão ENTÃO o sistema DEVE responder
   `200` com o e-mail do usuário da sessão e um `csrf_token`.
3. QUANDO `POST /api/session` chegar com credenciais corretas ENTÃO o sistema
   DEVE criar a sessão, gravar o cookie assinado e responder `200` com o
   usuário e um `csrf_token` novo.
4. SE as credenciais estiverem erradas ENTÃO o sistema DEVE responder `401`
   `invalid_credentials` com "E-mail ou senha inválidos.", o mesmo corpo para
   e-mail inexistente e senha errada, sem criar sessão.
5. QUANDO `DELETE /api/session` chegar com sessão ENTÃO o sistema DEVE encerrá-la
   e responder `200` com `user: null` e um `csrf_token` novo.
6. QUANDO `POST /api/registration` chegar com dados válidos ENTÃO o sistema DEVE
   criar a conta, autenticá-la e responder `201` com o usuário e um
   `csrf_token` novo.
7. SE o cadastro for inválido ENTÃO o sistema DEVE responder `422`
   `validation_failed` com as mensagens por campo em pt-BR, sem criar conta nem
   sessão.
8. SE uma mutação em `/api` chegar sem `X-CSRF-Token` válido ENTÃO o sistema
   DEVE responder `422` `invalid_csrf_token` sem executar a action, inclusive
   no login e no cadastro.
9. QUANDO login, cadastro ou logout terminarem ENTÃO o sistema DEVE recusar o
   token anterior e aceitar o devolvido na resposta.

**Contrato de acesso e de erro**

10. SE um endpoint protegido de `/api` for chamado sem sessão ENTÃO o sistema
    DEVE responder `401` `unauthenticated` com "Faça login para continuar.",
    sem redirect.
11. Todo erro de `/api` DEVE ter o corpo `{ "error": { "code", "message",
    "fields" } }`, com mensagem em pt-BR e `fields` igual a `{}` quando o erro
    não é de campo.
12. SE o registro pedido não existir ENTÃO o sistema DEVE responder `404`
    `not_found` com "Não encontrado.".
13. SE o caminho sob `/api` não tiver rota ENTÃO o sistema DEVE responder `404`
    `not_found` em JSON.
14. Todo endpoint de `/api` DEVE responder `application/json`, qualquer que seja
    o `Accept`.
15. SE o navegador for recusado por `allow_browser` ENTÃO o sistema DEVE
    responder `406` `unsupported_browser` em JSON.
16. SE uma exceção não tratada escapar ENTÃO o sistema DEVE responder `500`
    `internal_error` com "Erro inesperado. Tente novamente.", sem dado da
    exceção no corpo.
17. O comportamento dos controllers e das rotas HTML DEVE continuar inalterado:
    a suíte existente passa sem edição.

Caso de borda (emenda do design, 2026-10-10): SE o corpo JSON de uma requisição
a `/api` estiver malformado ENTÃO o sistema DEVE responder `400` `invalid_json`
com "Requisição inválida.", e não `500`.

**Catálogo**

18. QUANDO `GET /api/catalog` chegar ENTÃO o sistema DEVE devolver as cartas da
    página do `CatalogQuery` para os mesmos parâmetros, na mesma ordem, com
    `page`, `per_page`, `total_count`, `total_pages` e `active_filters`.
19. SE houver parâmetro desconhecido ou inválido ENTÃO o sistema DEVE ignorá-lo
    e responder `200`.
20. O filtro `owned` DEVE valer só com sessão e só sobre a coleção do usuário da
    sessão; um `user_id` nos parâmetros nunca muda a coleção lida.
21. Cada carta da lista DEVE trazer só as variantes presentes na fonte,
    ordenadas por `variant_code`.
22. QUANDO `GET /api/catalog/filters` chegar ENTÃO o sistema DEVE devolver
    `CatalogQuery.filter_options`.
23. QUANDO `GET /api/cards/:card_number` chegar ENTÃO o sistema DEVE devolver a
    carta com as variantes que o detalhe HTML lista, as ausentes da fonte
    marcadas com `in_source: false`.
24. O detalhe DEVE indicar a variante em destaque pela regra do CNF-42, a partir
    de `?variant=`.
25. SE a carta não existir ou tiver todas as variantes ocultas para quem pede
    ENTÃO o sistema DEVE responder `404` `not_found`.
26. Os endpoints do catálogo DEVEM funcionar sem sessão.

**Convenções de serialização**

27. Carta e variante DEVEM ser objetos distintos no payload, com as variantes em
    `variants[]` dentro da carta.
28. `cost`, `life`, `power`, `counter` e `block_icon` DEVEM ser `null` quando
    ausentes, nunca `0`.
29. `price` DEVE ser `{ amount, currency, observed_at }`, com `amount` em string
    decimal de duas casas, ou `null` sem preço (AD-022).
30. `image_url` DEVE ser o caminho `/card_images/<variant_code>` do app, nunca a
    URL do CDN.
31. `owned_quantity` (`0` sem item) e `wishlist_target` (`null` sem item) DEVEM
    refletir o usuário da sessão e ser `null` sem sessão.
32. Posse e wishlist DEVEM sair só de `Current.user`; a resposta de um usuário
    nunca contém dado de outro.

---

## Requisito 17 — Fundação da SPA

**User story:** Como colecionador, quero entrar, criar conta e navegar numa SPA
com tema claro ou escuro, servida pelo mesmo endereço do app, para usar o Bindr
sem as páginas Hotwire; e como dono, quero uma base única que as fatias de tela
seguintes herdem.

Requisito da troca de front (AD-023, AD-025), com decisões do dono em
2026-10-10. Recorte em `.specs/features/spa-fundacao/spec.md` (SPA-NN, mesma
numeração destes critérios). Consome o contrato do Req. 16 sem redefini-lo.

A SPA é SvelteKit 3 + Svelte 5, adapter-static em modo SPA, em `frontend/`, sob
`/app` durante a transição. Telas de catálogo, carta, pasta, decks e
portabilidade são fatias seguintes; cada componente nasce na primeira fatia
que o usa.

### Critérios de aceitação

**Entrega na mesma origem**

1. QUANDO `docker compose up` terminar ENTÃO o sistema DEVE servir a SPA em
   `/app` pelo Vite, encaminhando ao Rails todo caminho fora de `/app`, sem
   comando adicional (Req. 11.6).
2. QUANDO o Rails de produção receber `GET /app/<caminho>` sem arquivo no build
   ENTÃO o sistema DEVE responder `200` com a página de entrada da SPA
   (`200.html`) e `Cache-Control: no-cache`. Arquivo inexistente sob `/app/_app/` DEVE
   responder `404`.
3. O Rails de produção DEVE servir os arquivos do build sob `/app/` pelo
   servidor de estáticos, com o cache de longa duração que ele já aplica.
4. As rotas fora de `/app` DEVEM continuar inalteradas: a suíte existente passa
   sem edição.
5. O build da SPA DEVE sair de um estágio Node do `Dockerfile` de produção, sem
   Node na imagem final.

**Cliente HTTP**

6. Toda chamada à API DEVE passar por um único módulo cliente, com cookie da
   mesma origem.
7. Toda mutação DEVE enviar `X-CSRF-Token` com o token vigente.
8. QUANDO uma resposta de sessão, login, cadastro ou logout trouxer
   `csrf_token` ENTÃO o cliente DEVE trocar o token vigente por ele.
9. SE uma resposta vier `401 unauthenticated` ENTÃO o sistema DEVE marcar a
   sessão como anônima e levar a `/app/entrar?return_to=<caminho atual>`,
   salvo no logout, que segue o critério 22.
10. SE uma mutação vier `422 invalid_csrf_token` ENTÃO o cliente DEVE renovar o
    token por `GET /api/session` e reenviar a mutação uma única vez, só se o
    usuário da sessão continuar o mesmo. Se a sessão acabou, DEVE seguir o
    critério 9, salvo no logout, que segue o critério 22; se outra conta
    entrou, DEVE atualizar a sessão, levar a `/app` e avisar "A sessão mudou em
    outra aba. Confira a conta e tente de novo.", sem reenviar. *Decisão do
    dono, 2026-10-10: uma ação nunca é executada em conta diferente da que
    estava na tela.*
11. Erros da API DEVEM chegar à tela com `status`, `code`, `message` e `fields`
    como vieram, sem reescrever a mensagem.
12. SE a requisição falhar sem resposta ou passar de 15 s ENTÃO o erro DEVE ser
    `network_error` com "Sem conexão com o servidor. Tente novamente.".
13. SE a resposta não seguir o envelope do Req. 16 ENTÃO o erro DEVE ser
    `unexpected_response` com "Erro inesperado. Tente novamente.".

**Sessão, entrar e criar conta**

14. QUANDO a SPA carregar ENTÃO o sistema DEVE ler `GET /api/session` antes de
    renderizar a primeira rota.
15. SE essa leitura falhar, por rede, por resposta fora do contrato ou por erro
    da API (como navegador não suportado ou erro interno), ENTÃO o sistema DEVE
    exibir a mensagem e "Tentar novamente", sem renderizar a rota.
16. QUANDO o usuário entrar com credenciais corretas ENTÃO o sistema DEVE
    atualizar a sessão e seguir para o destino pós-login.
17. SE as credenciais forem recusadas ENTÃO o sistema DEVE exibir a mensagem da
    API acima do formulário, manter o e-mail, limpar a senha e focar a
    mensagem.
18. QUANDO o cadastro for aceito ENTÃO o sistema DEVE atualizar a sessão e
    seguir para o destino pós-login.
19. SE o cadastro for recusado com `validation_failed` ENTÃO cada mensagem DEVE
    aparecer junto do seu campo, ligada por `aria-describedby`, com
    `aria-invalid` e foco no primeiro campo inválido.
20. Mensagem de campo sem controle correspondente DEVE aparecer acima do
    formulário, nunca ser descartada.
21. Enquanto um envio estiver pendente, o botão DEVE ficar desabilitado e novo
    envio DEVE ser ignorado.
22. QUANDO o usuário sair ENTÃO o sistema DEVE encerrar a sessão pela API,
    levar a `/app` e avisar "Sessão encerrada."; se a API responder que a
    sessão já tinha acabado (`401`, ou sessão anônima na renovação do
    critério 10, que é como chega o logout feito em outra aba, porque o Rails
    confere o CSRF antes da sessão), o resultado DEVE ser o mesmo.
23. O destino pós-login DEVE ser o `return_to` decodificado só quando começa
    por `/app/` e não contém `//` nem `\`; senão, `/app`.
24. Usuário com sessão em `/app/entrar` ou `/app/criar-conta` DEVE ser levado a
    `/app`.

**Casco de navegação**

25. Toda rota da SPA DEVE exibir a navegação do Req. 13.1, na mesma ordem.
26. Entrada para tela ainda não migrada DEVE apontar para a página Hotwire
    equivalente, com navegação de página inteira.
27. A entrada atual DEVE ter `aria-current="page"` e se distinguir por fundo e
    peso, não só por cor.
28. Abaixo de 64rem, a navegação DEVE ficar fixa embaixo, com entradas iguais,
    alvos de 44px e sem cobrir o fim do conteúdo.
29. A partir de 64rem, a navegação DEVE ficar no topo de uma coluna lateral de
    largura fixa, abaixo da marca, em superfície elevada com borda.
30. Casco e telas DEVEM funcionar em 360px sem scroll horizontal (Req. 2.5).

**Temas claro e escuro**

31. Cor, tipografia, espaço, raio, duração e easing DEVEM ser tokens num único
    arquivo, sem literal repetido nos componentes (Req. 12.1).
32. Cada token de cor DEVE ter valor claro e escuro com o mesmo nome semântico
    do design §11.3; nenhum componente escolhe cor por tema.
33. Os dois temas DEVEM cumprir os contrastes do Req. 12.3, verificados por
    cálculo sobre os tokens.
34. Os dois temas DEVEM usar só azul-petróleo, âmbar e `danger` (Req. 12.4).
35. Com preferência "Sistema" ou ausente, o tema DEVE seguir
    `prefers-color-scheme`, inclusive quando ele mudar com a página aberta.
36. QUANDO o usuário escolher "Claro" ou "Escuro" ENTÃO o tema DEVE mudar na hora
    e a escolha DEVE persistir no dispositivo.
37. O tema efetivo DEVE estar aplicado antes da primeira pintura.
38. SE o armazenamento local falhar ou trouxer valor desconhecido ENTÃO o
    sistema DEVE usar "Sistema", sem erro.
39. `color-scheme` DEVE acompanhar o tema efetivo.
40. O anel de foco do Req. 12.9 DEVE valer nos dois temas.

**Movimento e mensagens**

41. Durações e easing DEVEM ser tokens, e só `transform` e `opacity` animam.
42. Com `prefers-reduced-motion: reduce`, toda duração DEVE ser zero.
43. A troca de rota DEVE usar View Transitions quando o navegador suportar, e
    trocar sem transição nem erro quando não suportar.
44. Mensagem de sucesso DEVE ser anunciada em `aria-live="polite"` e sumir em
    5 s.
45. Mensagem de erro DEVE ter `role="alert"`, distinguir-se por rótulo escrito
    (Req. 12.8) e ficar até ser fechada.
46. Mensagens NÃO DEVEM mover o foco nem deslocar o conteúdo.

---

## Requisito 18 — Catálogo na SPA

**User story:** Como colecionador, quero navegar, buscar e filtrar o catálogo
na SPA, com a mesma URL compartilhável do HTML e a minha posse à vista, para
achar uma carta de relance sem as páginas Hotwire.

Requisito da troca de front (AD-023), escrito em 2026-10-10 sem o dono
presente. Recorte em `.specs/features/spa-catalogo/spec.md` (SCAT-NN, mesma
numeração destes critérios). A régua é a paridade com a grade Hotwire (Req. 2,
3, 4, 12 e 13.5, 13.9–13.12, 13.17, 13.18, 13.21–13.29); o que for além dela
fica fora. Consome `GET /api/catalog` e `GET /api/catalog/filters` do Req. 16
(16.18–16.22, 16.26, 16.31) sem mudar o contrato, e herda cliente, sessão,
casco, temas e mensagens do Req. 17. Onde o Req. 13 diz "sem JavaScript"
(13.11), na SPA vale o equivalente: controle que é link com `href` real. O
detalhe da carta continua Hotwire até a `spa-carta`.

### Critérios de aceitação

**Rota e casco**

1. A SPA DEVE exibir o catálogo em `/app`, com o título de página "Catálogo —
   Bindr" e o cabeçalho "Catálogo", no lugar da página de início do Req. 17.
2. A entrada "Catálogo" da navegação DEVE levar a `/app` sem recarregar a
   página e ficar marcada como atual em `/app` (Req. 17.25, 17.27).
3. O tile DEVE levar a `/app/cartas/<card_number>`, sem recarregar a página
   (emenda da `spa-carta`, Req. 19.3).

**Consulta e URL**

4. QUANDO `/app` abrir ou sua query mudar ENTÃO o sistema DEVE pedir
   `GET /api/catalog` com a query da URL repassada sem alteração.
5. A URL DEVE usar os parâmetros e o formato do design §4.2 (`colors[]=Red`),
   de forma que a query de uma URL `/catalog` aplicada a `/app` reproduza o
   mesmo resultado (Req. 4.7).
6. Todo link que a tela gera DEVE partir dos filtros ativos normalizados da
   última resposta, nunca da query crua: parâmetro descartado pela API não
   reaparece em link.
7. QUANDO a URL mudar por voltar ou avançar do navegador ENTÃO a tela DEVE
   exibir o resultado, o campo de busca e os controles da URL nova.
8. SE chegar a resposta de uma URL que já não é a atual ENTÃO o sistema DEVE
   descartá-la.
9. QUANDO a sessão mudar com o catálogo aberto ENTÃO o sistema DEVE repetir a
   consulta da URL atual.

**Grade e tile**

10. A grade DEVE exibir, por carta, a imagem da primeira variante, o nome e o
    `card_number` em estilo `code` (Req. 2.1, 12.7).
11. Atrás da imagem, o tile DEVE ter um placeholder com nome e `card_number`,
    visível quando a variante não tem imagem ou a imagem falha, sem mudar as
    dimensões do tile (Req. 2.3).
12. O tile DEVE exibir a raridade ao lado do código quando a carta tem uma
    variante, e "N impressões" quando tem mais (Req. 13.24).
13. Com sessão e posse maior que zero, o tile DEVE exibir sobre o canto
    superior direito da arte um selo com a soma das cópias das variantes,
    anunciado como "1 cópia" ou "N cópias"; o tile NÃO DEVE ter controle de
    posse (Req. 13.22).
14. A grade DEVE ter cinco colunas em 1280px e funcionar em 360px sem scroll
    horizontal (Req. 2.5, 13.25).

**Busca**

15. O campo de busca DEVE ter o rótulo "Buscar por nome ou card_number", o
    exemplo "OP01-024" no placeholder e o botão "Buscar", com alvo de 44px
    (Req. 13.18, 13.27).
16. QUANDO o usuário enviar a busca ENTÃO o sistema DEVE navegar com o termo
    em `q`, preservando os demais filtros e a ordenação e descartando `page`.
17. O campo DEVE exibir o termo da busca ativa.

**Filtros**

18. O sistema DEVE oferecer chips de cor, tipo e raridade com os valores de
    `GET /api/catalog/filters`, na ordem devolvida, com o tipo exibido com
    inicial maiúscula e enviado cru (Req. 4.9, 13.29).
19. Cada chip DEVE ser um link para a URL com o valor alternado, preservando
    os demais filtros e descartando `page` (Req. 4.3, 4.4).
20. O chip ativo DEVE exibir sinal de remoção visível, anel de 2px em
    `accent` e nome acessível "Remover filtro <categoria>: <valor>"; o de cor
    NÃO DEVE ser preenchido com `accent` (Req. 12.11, 13.11).
21. Os chips de cor DEVEM usar tratamento neutro enquanto a pendência P8
    estiver aberta.
22. Todo chip e controle de filtro DEVE ter alvo de 44px.
23. O set DEVE ser escolhido num seletor com "Todos os sets" e os sets por
    nome, aplicado pelo botão "Aplicar": um set substitui o filtro de set,
    "Todos os sets" o remove, e os demais filtros ficam.
24. Com mais de um set ativo, o seletor DEVE exibir "N sets selecionados", e
    "Aplicar" com essa opção NÃO DEVE mudar o filtro de set.
25. Com sessão, o sistema DEVE oferecer os chips de posse "Todas", "Tenho" e
    "Não tenho"; "Todas" sem filtro de posse é o atual, sem sinal de remoção.
26. Sem sessão, o sistema NÃO DEVE exibir controle nem chip de posse.
27. Faixas de custo, power e counter, attribute, trait e ordenação DEVEM
    valer pela URL, sem controle, e ser preservados em todo link (Req. 4.9).

**Filtros ativos e linha de status**

28. O sistema DEVE listar os filtros ativos como chips, um por valor, com os
    rótulos do HTML e "Posse", cada um removível sozinho; ordenação e página
    NÃO DEVEM virar chip (Req. 4.6).
29. A linha de status DEVE ser a frase "N cartas", acrescida de " · M filtros
    ativos" com filtro, M igual ao número de chips (Req. 4.8, 13.26).
30. Com filtro e resultado, a linha DEVE oferecer "Limpar filtros", que remove
    todo filtro e mantém a ordenação (Req. 13.12).
31. Sem sessão, a linha DEVE oferecer uma única vez "Entrar para registrar
    posse", levando a `/app/entrar` com retorno à URL atual (Req. 13.23).
32. A partir de 64rem, a linha de status DEVE ficar na mesma linha da busca.

**Disposição dos filtros**

33. A partir de 64rem, os controles DEVEM ficar na coluna lateral, abaixo da
    navegação, numa superfície contínua e sempre visíveis (Req. 13.10, 13.16).
34. Abaixo de 64rem, os controles DEVEM ficar acima da grade, recolhidos por
    padrão num controle "Filtros" que diz quantos estão ativos, com os chips
    ativos visíveis com ele recolhido (Req. 13.5, 13.17).
35. O painel aberto DEVE continuar aberto enquanto o usuário navega dentro do
    catálogo.

**Paginação**

36. Com mais de uma página, o sistema DEVE exibir "Anterior", "Página X de Y"
    e "Próxima", cada link preservando os filtros ativos (Req. 2.2).

**Estados**

37. Sem resultado, o sistema DEVE exibir "Nenhuma carta encontrada para
    <termo>." quando há busca, ou "Nenhuma carta corresponde aos filtros
    aplicados." quando não há, com "Limpar filtros" (Req. 3.5).
38. Enquanto a consulta da URL atual estiver pendente por mais de 200 ms, a
    grade DEVE exibir dez tiles esqueleto, marcada como ocupada e anunciando
    "Carregando cartas…".
39. SE a consulta do catálogo falhar ENTÃO o sistema DEVE exibir no lugar da
    grade a mensagem do erro e "Tentar novamente", mantendo busca e filtros
    utilizáveis.
40. SE a consulta das opções de filtro falhar ENTÃO o sistema DEVE exibir no
    painel a mensagem do erro e "Tentar novamente", mantendo a grade e os
    chips ativos.

**Foco e anúncio**

41. Navegação que só muda a query de `/app` NÃO DEVE mover o foco para o
    conteúdo principal; chip do painel, "Aplicar" e "Buscar" DEVEM manter o
    foco no controle acionado.
42. QUANDO um chip da lista de filtros ativos for removido ENTÃO o foco DEVE
    ir ao chip seguinte, ou ao anterior, ou à linha de status.
43. QUANDO o usuário trocar de página ENTÃO o foco DEVE ir à linha de status.
44. A contagem de resultados DEVE ser anunciada em região `aria-live="polite"`
    a cada resposta.

**API**

45. A fatia NÃO DEVE criar nem mudar endpoint: consome só `GET /api/catalog` e
    `GET /api/catalog/filters` como o Req. 16 os define.

---

## Requisito 19 — Detalhe da carta na SPA

**User story:** Como colecionador, quero abrir uma carta na SPA, ver todas as
impressões com preço e registrar quantas cópias tenho de cada uma num toque,
com o número mudando na hora, para montar a pasta pelo celular sem as páginas
Hotwire.

Requisito da troca de front (AD-023), escrito em 2026-10-10 sem o dono
presente. Recorte em `.specs/features/spa-carta/spec.md` (SCAR-NN, mesma
numeração destes critérios). A régua é a paridade com o detalhe Hotwire (Req.
5, 7.1–7.5, 8.1, 13.6, 13.19, 13.30–13.35, 13.40 e 15.8–15.10); o que for além
dela fica fora. É fatia vertical: consome `GET /api/cards/:card_number` do Req.
16 (16.23–16.25, 16.27–16.32) sem mudar o contrato e cria os endpoints de posse
e de desejo que a tela precisa, no padrão do Req. 16. Herda cliente, sessão,
casco, temas, movimento e mensagens do Req. 17 e o tile do Req. 18. O controle
do deck em edição (Req. 14, DCK-03..05) fica para a `spa-decks`, dona do estado
de deck em edição; durante a transição ele continua no detalhe Hotwire. A
remoção de desejo e a lista de desejos (Req. 8.2–8.4) ficam com a fatia que
migrar a lista.

As duas escolhas de contrato P9 e P10 foram decididas pelo dono em 2026-10-11
com as opções recomendadas (AD-027).

### Critérios de aceitação

**Rota e carga**

1. A SPA DEVE exibir o detalhe em `/app/cartas/<card_number>`, com o título de
   página "<nome> (<card_number>) — Bindr" e o nome da carta como cabeçalho de
   nível 1.
2. QUANDO a rota abrir ou o `card_number` da URL mudar ENTÃO o sistema DEVE
   pedir `GET /api/cards/:card_number` com o `card_number` codificado e o
   `variant` da URL repassado.
3. O tile do catálogo DEVE levar a `/app/cartas/<card_number>` sem recarregar a
   página. Este critério substitui o destino Hotwire do Req. 18.3.
4. "Voltar ao catálogo" DEVE ser um botão bordado de no mínimo 44px, sem seta,
   que leva a `/app` sem recarregar a página; em viewport larga, na coluna
   lateral abaixo de um divisor (Req. 13.34).
5. SE a API responder `404 not_found` ENTÃO o sistema DEVE exibir no lugar do
   detalhe o título de página "Carta não encontrada — Bindr", a mensagem da API
   e "Voltar ao catálogo".
6. SE a consulta falhar com outro erro ENTÃO o sistema DEVE exibir a mensagem
   do erro e "Tentar novamente", que repete a consulta.
7. Enquanto a consulta estiver pendente por mais de 200 ms, o detalhe DEVE ser
   marcado como ocupado e anunciar "Carregando carta…".
8. SE chegar a resposta de uma carta que já não é a da URL ENTÃO o sistema DEVE
   descartá-la.
9. QUANDO a sessão mudar com o detalhe aberto ENTÃO o sistema DEVE repetir a
   consulta da carta atual.

**Cabeçalho e dados**

10. A imagem principal DEVE ser a da variante em destaque, com texto
    alternativo "<nome> <variant_code>" e, atrás dela, um placeholder com nome
    e `card_number`, visível sem imagem ou com falha, sem mudar as dimensões.
11. Abaixo de 64rem, o detalhe DEVE exibir a miniatura da arte ao lado do
    título e a imagem maior num controle "Ver imagem maior" que expande no
    lugar, fechado por padrão (Req. 13.30).
12. A partir de 64rem, a imagem maior DEVE ficar numa coluna própria ao lado
    dos dados, sempre visível (Req. 13.6, 13.19).
13. O cabeçalho DEVE exibir como chips o tipo com inicial maiúscula, a
    raridade da variante em destaque, uma entrada por cor e, a partir de 64rem,
    "Counter N" quando o counter se aplica e existe; e a linha "<nome do set> ·
    <código do set>" da variante em destaque (Req. 13.31).
14. QUANDO a variante em destaque estiver ausente da fonte ENTÃO o cabeçalho
    DEVE exibir "Variante fora da fonte".
15. Com sessão e quantidade da variante em destaque maior que zero, a imagem
    principal DEVE ter o selo "1 cópia" ou "N cópias", com o mesmo valor
    exibido no controle de posse dessa variante (Req. 13.35).
16. QUANDO a variante em destaque tiver ilustrador ENTÃO o detalhe DEVE exibir
    "Ilustração: <nome>" (Req. 13.35).
17. O detalhe DEVE exibir Custo, Power, Life, Attribute, Traits e Block só
    quando o campo se aplica ao tipo da carta e tem valor; `0` é valor e
    aparece (Req. 5.1, 5.5).
18. QUANDO a carta tiver efeito ou trigger ENTÃO o detalhe DEVE exibir a seção
    "Efeito" com o texto como texto puro, preservando as quebras de linha, e o
    trigger dentro dela, depois do efeito, sob o rótulo "Trigger" (Req. 5.4,
    13.32).

**Variantes**

19. A seção "Variantes na pasta" DEVE listar as variantes na ordem da API, cada
    uma com miniatura própria, código, "<raridade> · <tipo de arte>" e
    "<nome do set> (<código do set>)" (Req. 5.2, 13.33).
20. A variante ausente da fonte DEVE exibir "fora da fonte".
21. Cada variante DEVE exibir o preço como `US$ 1.234,56` com o rótulo
    "TCGplayer · market · <dd/mm/aaaa>", a data no fuso de São Paulo, ou "Sem
    preço" sem preço, com ou sem sessão (Req. 15.8–15.10).
22. A miniatura DEVE ser link para a própria carta com `?variant=<variant_code>`,
    com nome acessível "Mostrar <variant_code> na imagem principal" e
    `aria-current="true"` na variante em destaque.
23. QUANDO o usuário escolher uma variante ENTÃO imagem principal, selo,
    ilustração, raridade e set do cabeçalho DEVEM passar a ser os dela, com a
    URL trocada sem novo item no histórico e sem nova consulta (Req. 13.40).
24. Com `variant` ausente ou fora das variantes listadas, a variante em
    destaque DEVE ser a primeira presente na fonte, ou a primeira listada se
    nenhuma estiver presente.

**Posse**

25. Com sessão, cada variante DEVE exibir a quantidade possuída ("não tenho"
    em zero) e o controle `−` `[n]` `+`, em que `[n]` só exibe; botões de no
    mínimo 44px, com os nomes acessíveis "Remover uma cópia de <nome>
    <variant_code>" e "Adicionar uma cópia de <nome> <variant_code>"
    (Req. 7.2, 13.19, 13.33).
26. Sem sessão, cada variante DEVE exibir "Entrar para registrar posse" no
    lugar do controle, levando a `/app/entrar` com retorno à URL atual.
27. QUANDO o usuário acionar `+` ENTÃO o valor exibido DEVE subir 1 antes da
    resposta da API, e o sistema DEVE enviar um incremento daquela variante.
28. QUANDO o usuário acionar `−` com o valor exibido maior que zero ENTÃO o
    valor exibido DEVE descer 1 antes da resposta, e o sistema DEVE enviar um
    decremento.
29. Com o valor exibido em zero, o `−` DEVE ter `aria-disabled="true"`,
    continuar focável e, acionado, não enviar nada e anunciar "Você não tem
    cópias desta variante para remover." (Req. 7.4).
30. Cada toque DEVE gerar exatamente uma operação na API, enviada na ordem dos
    toques, cada uma depois da resposta da anterior na mesma variante.
31. QUANDO não houver operação pendente na variante ENTÃO o valor exibido DEVE
    ser o `owned_quantity` da última resposta.
32. SE uma operação falhar ENTÃO o sistema DEVE descartar as operações ainda
    não enviadas da variante, voltar o valor à última quantidade confirmada e
    exibir a mensagem do erro como veio.
33. QUANDO a última operação pendente da variante terminar com sucesso ENTÃO a
    quantidade DEVE ser anunciada em região `aria-live="polite"`, com o nome da
    carta e o código da variante.
34. O foco DEVE continuar no botão acionado durante e depois da operação.

**Desejo**

35. Com sessão, cada variante DEVE ter um grupo com nome acessível "Marcar
    <nome> <variant_code> como desejada", o campo numérico de rótulo visível
    "Quero" com o alvo atual e o botão "Quero esta", ou "Atualizar desejo"
    quando já há desejo (Req. 8.1).
36. QUANDO o alvo for aceito ENTÃO o sistema DEVE avisar "<nome> <variant_code>
    na lista de desejos: 1 cópia." (ou "N cópias.") e o botão DEVE passar a
    "Atualizar desejo".
37. SE o alvo for recusado com `validation_failed` ENTÃO a mensagem DEVE
    aparecer junto do campo, ligada por `aria-describedby`, com `aria-invalid`,
    foco no campo e o valor digitado mantido.
38. Enquanto o envio estiver pendente, o botão DEVE ficar desabilitado e novo
    envio DEVE ser ignorado (Req. 17.21).

**Transição grade → detalhe**

39. QUANDO o usuário for de um tile ao detalhe ENTÃO a arte do tile DEVE se
    transformar na imagem principal visível do detalhe dentro da transição de
    rota do Req. 17.43.
40. QUANDO o usuário voltar do detalhe ao catálogo e o tile da carta estiver na
    grade ENTÃO a imagem principal DEVE se transformar na arte do tile.
41. Com `prefers-reduced-motion: reduce` ou sem View Transitions, a troca DEVE
    acontecer sem transformação e sem erro (Req. 17.42, 17.43).

**API de posse e de desejo**

42. QUANDO `POST /api/cards/:card_number/variants/:variant_code/increment`
    chegar com sessão ENTÃO o sistema DEVE somar 1 à posse do usuário da sessão
    naquela variante, criando o registro se faltar, e responder `200` com
    `{ data: { variant_code, owned_quantity } }`. *(Formato da rota: P9,
    decidida em AD-027.)*
43. QUANDO `POST /api/cards/:card_number/variants/:variant_code/decrement`
    chegar com sessão ENTÃO o sistema DEVE subtrair 1 se a posse for maior que
    zero e responder `200` com a quantidade resultante; em zero ou sem
    registro, DEVE responder `200` com `owned_quantity: 0`, sem criar registro.
    *(Resposta em zero: P10, decidida em AD-027.)*
44. Incrementos e decrementos simultâneos da mesma variante DEVEM somar todos,
    sem perder operação e sem chegar a quantidade negativa (Req. 7.4, 7.8).
45. QUANDO `PUT /api/cards/:card_number/variants/:variant_code/wishlist`
    chegar com sessão e `target_quantity` inteiro maior ou igual a 1 ENTÃO o
    sistema DEVE criar ou atualizar o desejo do usuário da sessão e responder
    `200` com `{ data: { variant_code, wishlist_target } }`.
46. SE `target_quantity` faltar ou não for inteiro maior ou igual a 1 ENTÃO o
    sistema DEVE responder `422` `validation_failed` com `fields.target_quantity`
    igual a `["Informe um número inteiro maior ou igual a 1."]`, sem gravar.
47. SE a carta não existir ou a variante não for dela ENTÃO os três endpoints
    DEVEM responder `404` `not_found`, sem gravar.
48. Os três endpoints DEVEM exigir sessão (`401 unauthenticated`) e CSRF
    (`422 invalid_csrf_token`), e ler e gravar só o usuário da sessão: um
    `user_id` no corpo ou na query nunca muda o registro tocado (Req. 6.5).
49. O comportamento e as rotas HTML DEVEM continuar inalterados: a suíte
    existente passa sem edição. O `CollectionItemsController` passa a
    delegar o SQL de posse ao model `CollectionItem`, sem mudar respostas,
    mensagens nem rotas (decisão do dono em 2026-10-11).

---

## Requisito 20 — Pasta e lista de desejos na SPA

**User story:** Como colecionador, quero abrir a minha pasta na SPA e ver de
relance quanto tenho, quanto vale e quanto falta de cada set, e conferir e
limpar a minha lista de desejos, para responder "quanto falta do set X?" sem as
páginas Hotwire.

Requisito da troca de front (AD-023), escrito em 2026-10-10 sem o dono
presente. Recorte em `.specs/features/spa-pasta/spec.md` (SPAS-NN, mesma
numeração destes critérios). A régua é a paridade com `/progress` e `/wishlist`
do Hotwire (Req. 7.7, 8.2–8.4, 9, 13.4, 13.13, 13.14, 13.20, 13.21,
13.36–13.39 e 15.11–15.16); o que for além dela fica fora. É fatia vertical:
cria `GET /api/progress`, `GET /api/wishlist` e a remoção de desejo, no padrão
do Req. 16, e herda cliente, sessão, casco, temas, movimento e mensagens do
Req. 17, o link de set do catálogo do Req. 18 e o detalhe do Req. 19. O bloco
"o que falta para os decks" da pasta (Req. 14, DCK-33..35) fica para a
`spa-decks`; import e export continuam Hotwire até a `spa-portabilidade`. O
número interpolado dos indicadores nasce aqui (tabela da `spa-fundacao`).

A escolha de contrato P11 foi decidida pelo dono em 2026-10-11 com a opção
recomendada (AD-027).

### Critérios de aceitação

**Rota e carga**

1. A SPA DEVE exibir a pasta em `/app/pasta`, com o título de página "Minha
   pasta — Bindr" e o cabeçalho de nível 1 "Minha pasta".
2. A entrada "Minha pasta" da navegação DEVE levar a `/app/pasta` sem
   recarregar a página e ficar marcada como atual em `/app/pasta` com qualquer
   query. Este critério substitui o destino Hotwire do Req. 17.26 para essa
   entrada.
3. SE a sessão estiver anônima quando `/app/pasta` ou `/app/pasta/desejos`
   abrir ENTÃO o sistema DEVE levar a `/app/entrar?return_to=<caminho e query
   atuais>`, sem chamar a API da tela.
4. QUANDO `/app/pasta` abrir ou sua query mudar ENTÃO o sistema DEVE pedir
   `GET /api/progress` repassando só o `order` da URL, quando houver.
5. SE chegar a resposta de uma URL que já não é a atual ENTÃO o sistema DEVE
   descartá-la.
6. QUANDO uma consulta da pasta ou da lista de desejos passar de 200 ms sem
   resposta ENTÃO a região do conteúdo DEVE ficar com `aria-busy="true"` e o
   texto "Carregando pasta…" ou "Carregando lista de desejos…"; antes disso a
   tela mantém o conteúdo anterior.
7. SE a consulta falhar com erro que não seja `401` ENTÃO o sistema DEVE exibir
   a mensagem do erro como veio e o botão "Tentar novamente", que repete a
   consulta; o `401` segue o Req. 17.9.

**Indicadores**

8. A pasta DEVE exibir três cartões de indicador, nesta ordem: o total de
   cópias com o rótulo "carta na pasta" (1) ou "cartas na pasta"; as variantes
   distintas possuídas com "carta diferente" (1) ou "cartas diferentes"; e o
   valor estimado no formato `US$ 1.234,56` com o rótulo "valor estimado"
   (Req. 7.7, 13.4, 13.13, 15.11).
9. QUANDO houver cópias possuídas sem preço ENTÃO o cartão de valor DEVE exibir
   "1 cópia sem preço" ou "N cópias sem preço"; sem elas, nenhuma nota
   (Req. 15.12).
10. QUANDO o usuário não tiver cópia com preço ENTÃO o valor estimado DEVE ser
    `US$ 0,00` (Req. 15.15).
11. A partir de 64rem, cada cartão de indicador DEVE ter um quarto da largura
    da coluna de conteúdo, sem esticar (Req. 13.39).

**Número interpolado**

12. QUANDO os indicadores aparecerem pela primeira vez na tela ENTÃO cada
    número DEVE ir de zero ao valor da resposta, com a duração e a curva dos
    tokens `--duration-slow` e `--ease-standard` (Req. 17.41).
13. QUANDO um indicador mudar de valor com a pasta aberta ENTÃO o número DEVE ir
    do valor exibido ao novo, com a mesma duração e curva; com o mesmo valor,
    nada se move.
14. Com `prefers-reduced-motion: reduce`, o número DEVE aparecer direto no
    valor final, sem valor intermediário (Req. 17.42).
15. Os valores intermediários DEVEM ficar fora da árvore de acessibilidade: o
    texto acessível de cada indicador é sempre o valor final com o rótulo, e o
    indicador não é região viva.
16. Os valores intermediários DEVEM usar o formato do final (inteiro nas
    contagens, `US$` com duas casas no valor) com algarismos tabulares, sem
    deslocar o conteúdo, e o valor final exibido DEVE ser a formatação exata do
    `amount` da resposta.

**Progresso por set**

17. A pasta DEVE exibir o título de nível 2 "Progresso por set" e, junto dele,
    os chips-link "Recentes" (`/app/pasta?order=recent`) e "Por código"
    (`/app/pasta?order=code`), numa lista nomeada "Ordenar sets", com
    navegação sem recarga e `aria-current="page"` no chip do `order` devolvido
    pela API, nunca da query crua (Req. 9.7, 13.37).
18. A lista de sets DEVE seguir a ordem da resposta, ter como nome acessível o
    título "Progresso por set" e não exibir a contagem total de sets
    (Req. 13.36).
19. Cada set DEVE ocupar uma linha sem moldura, com o código do set em estilo
    `code` e o nome do set como link para `/app?sets[]=<código>` sem recarga, de
    nome acessível "<nome> (<código>): ver no catálogo" (Req. 9.3, 13.20,
    13.36).
20. QUANDO o set tiver `base_size` ENTÃO a linha DEVE exibir "<possuídas> /
    <base_size> · <percentual>%" na linha do nome, uma barra de progresso
    `aria-hidden` com valor igual às possuídas e máximo igual ao `base_size`, e
    a legenda "<possuídas> de <base_size> do set base" (Req. 9.1, 9.2, 13.13).
21. QUANDO o set não tiver `base_size` ENTÃO a linha DEVE exibir só as
    possuídas, sem barra nem percentual, e a legenda "Percentual indisponível:
    este set não informa o tamanho do set base."; nunca "0%" nem "100%".
22. A legenda DEVE exibir os parallels como "<possuídos> de <total> parallel"
    (total 1) ou "parallels", em elemento irmão do percentual e nunca dentro
    dele (Req. 9.6, AD-003).
23. Cada set DEVE exibir "valor <subtotal>" no formato `US$ 1.234,56`,
    inclusive `US$ 0,00` (Req. 15.13).

**Ações**

24. A pasta DEVE oferecer a ação "Adicionar cartas à pasta", que leva a `/app`
    sem recarga: abaixo de 64rem fixa acima da barra inferior, sem cobrir o fim
    da lista; a partir de 64rem na coluna lateral, abaixo de um divisor, com o
    texto "Adicionar cartas" (Req. 13.14, 13.38).
25. A pasta DEVE oferecer, num grupo de ações secundárias separado de
    "Adicionar cartas", "Baixar minha coleção (CSV)" (`/collection/export`, com
    página inteira), "Lista de desejos" (`/app/pasta/desejos`, sem recarga) e
    "Importar coleção" (`/collection/import`, com página inteira) (Req. 13.4,
    13.20).
26. A 390px e a 1280px, a pasta DEVE ter a composição da página `/progress` do
    Hotwire, que segue os artboards "Mobile-Pasta" e "Desktop-Pasta"
    (Req. 13.21).

**Lista de desejos**

27. A SPA DEVE exibir a lista de desejos em `/app/pasta/desejos`, com o título
    de página "Lista de desejos — Bindr" e o cabeçalho de nível 1 "Lista de
    desejos", pedindo `GET /api/wishlist` ao abrir.
28. QUANDO a lista vier vazia ENTÃO o sistema DEVE exibir "Você ainda não
    marcou nenhuma carta como desejada." e "Abra o detalhe de uma carta no
    catálogo e escolha a impressão que quer adquirir.", com "catálogo" como
    link para `/app` sem recarga.
29. QUANDO houver itens ENTÃO o sistema DEVE exibir "1 item" ou "N itens" e uma
    lista na ordem da resposta (Req. 8.2).
30. Cada item DEVE exibir o nome da carta e o `variant_code` em estilo `code`
    como link para `/app/cartas/<card_number>` sem recarga, e "<possuídas> de
    <alvo> cópia" (alvo 1) ou "cópias".
31. Cada item DEVE exibir o rótulo escrito "Atendido" quando `fulfilled` for
    verdadeiro, e "Faltam N" (N = alvo − possuídas) quando não for, nunca só
    por cor (Req. 8.3, 12.8).
32. Cada item DEVE ter o botão "Remover", com alvo de no mínimo 44px e nome
    acessível "Remover <nome> <variant_code> da lista de desejos (atendido)" ou
    "(faltam N)" (Req. 8.4).
33. QUANDO o usuário acionar "Remover" ENTÃO o sistema DEVE pedir a remoção do
    desejo pela API e, no sucesso, tirar o item da lista, atualizar a contagem
    e avisar "Item removido da lista de desejos." (Req. 17.44).
34. QUANDO um item for removido ENTÃO o foco DEVE ir para o "Remover" do item
    seguinte; sem seguinte, para o do anterior; com a lista vazia, para o
    cabeçalho "Lista de desejos".
35. Enquanto a remoção de um item estiver pendente, o botão dele DEVE ficar
    desabilitado e novo acionamento DEVE ser ignorado; os outros itens
    continuam acionáveis.
36. SE a remoção falhar ENTÃO o sistema DEVE manter o item e exibir a mensagem
    do erro como veio (Req. 17.11, 17.45); `401` e sessão trocada seguem o
    Req. 17.9 e 17.10.

**API da pasta e da lista de desejos**

37. QUANDO `GET /api/progress` chegar com sessão ENTÃO o sistema DEVE responder
    `200` com `{ data: { order, summary, sets } }` do usuário da sessão.
38. O `order` DEVE ser `recent` ou `code`; parâmetro ausente, desconhecido,
    vazio ou em lista DEVE valer `recent`, com `200` (Req. 9.7).
39. O `summary` DEVE trazer `total_copies`, `distinct_variants`,
    `estimated_value` (`{ amount, currency }`, `amount` em string decimal de
    duas casas, moeda `USD`) e `unpriced_copies`, com os mesmos números da
    pasta Hotwire para o mesmo usuário (Req. 7.7, 15.11, 15.12).
40. Cada item de `sets` DEVE trazer `code`, `name`, `owned_numbers` (limitado
    ao `base_size` quando ele existe), `base_size` (`null` quando ausente ou
    zero), `completion_percent` (inteiro arredondado como no HTML, no máximo
    100, `null` sem `base_size`), `parallel_owned`, `parallel_total` e `value`
    (`{ amount, currency }`), com os números da linha da pasta Hotwire
    (Req. 9.1–9.6, 15.13).
41. `summary` e `sets` DEVEM sair de um número de consultas que não cresce com
    a quantidade de sets, variantes ou itens de coleção (Req. 15.16, AD-021).
42. QUANDO `GET /api/wishlist` chegar com sessão ENTÃO o sistema DEVE responder
    `200` com os desejos do usuário da sessão em `data[]`, cada um com
    `card_number`, `card_name`, `variant_code`, `target_quantity`,
    `owned_quantity` e `fulfilled` (posse maior ou igual ao alvo), do mais
    antigo para o mais novo, num número de consultas que não cresce com a
    lista (Req. 8.2, 8.3).
43. QUANDO `DELETE /api/cards/:card_number/variants/:variant_code/wishlist`
    chegar com sessão e CSRF válidos ENTÃO o sistema DEVE apagar o desejo do
    usuário da sessão naquela variante e responder `200` com `{ data: {
    variant_code, wishlist_target: null } }`; sem desejo, DEVE responder o
    mesmo `200` sem apagar nada. *(Chave e resposta sem desejo: P11,
    decidida em AD-027.)*
44. SE a carta não existir ou a variante não for dela ENTÃO a remoção DEVE
    responder `404` `not_found`, sem apagar.
45. Os três endpoints DEVEM exigir sessão (`401 unauthenticated`), a remoção
    DEVE exigir CSRF (`422 invalid_csrf_token`), e todos DEVEM ler e apagar só
    registros do usuário da sessão: um `user_id` no corpo ou na query nunca
    muda o registro lido ou apagado (Req. 6.5).
46. Os controllers e as rotas HTML DEVEM continuar inalterados: a suíte
    existente passa sem edição.

---

## Requisito 21 — Decks na SPA

**User story:** Como jogador, quero listar, criar, montar, importar e exportar
meus decks na SPA, com status pelas regras do jogo e o que falta na pasta, e
somar cartas ao deck em edição pelo detalhe da carta, para montar um deck pelo
celular sem as páginas Hotwire.

Requisito da troca de front (AD-023), escrito em 2026-10-10 sem o dono
presente. Recorte em `.specs/features/spa-decks/spec.md` (SDEC-NN, mesma
numeração destes critérios). A régua é a paridade com as telas Hotwire de deck
(Req. 14, DCK-01..44, e Req. 13.1); o que for além dela fica fora. As regras de
montagem, o cálculo do status, dos motivos, dos avisos e do que falta e o
formato da lista continuam nos objetos do Req. 14 (`Deck::Legality`,
`DeckShortfallQuery`, `Deck::ListText`); a SPA exibe o que a API devolve e não
repete regra. É fatia vertical: cria os endpoints de deck sob `/api`, no padrão
do Req. 16, e acrescenta o deck em edição ao payload do detalhe da carta
(Req. 16.23). Herda cliente, sessão, casco, temas, movimento e mensagens do
Req. 17, o detalhe e o stepper otimista do Req. 19 e a pasta do Req. 20, e
cobre o que essas fatias deixaram para ela: o controle do deck em edição no
detalhe (Req. 19, DCK-03..05) e o bloco "Faltando para os baralhos" da pasta
(Req. 20, DCK-33..35).

O deck em edição continua na sessão do Rails (`session[:editing_deck_id]`,
concern `EditingDeck`), o mesmo que o Hotwire lê: durante a transição, escolher
o deck numa tela vale na outra. A escolha de contrato marcada DECISÃO PENDENTE
abaixo (P12) tem opção recomendada e está no *Rastreamento de pendências*.

### Critérios de aceitação

**Rotas e carga**

1. A SPA DEVE exibir a lista de decks em `/app/baralhos`, com o título de
   página "Baralhos — Bindr" e o cabeçalho de nível 1 "Baralhos".
2. A entrada "Baralhos" da navegação DEVE levar a `/app/baralhos` sem
   recarregar a página e ficar marcada como atual em `/app/baralhos` com
   qualquer query. Este critério substitui o destino Hotwire do Req. 17.26 para
   essa entrada.
3. SE a sessão estiver anônima quando uma rota sob `/app/baralhos` abrir ENTÃO
   o sistema DEVE levar a `/app/entrar?return_to=<caminho e query atuais>`, sem
   chamar a API da tela.
4. ENQUANTO a consulta de uma tela de deck estiver pendente há mais de 200 ms,
   o sistema DEVE marcar a tela com `aria-busy="true"` e anunciar "Carregando
   baralhos…" ou "Carregando deck…"; antes disso, DEVE manter o conteúdo
   anterior.
5. SE chegar a resposta de uma URL que já não é a atual ENTÃO o sistema DEVE
   descartá-la sem alterar a tela.
6. SE a consulta de uma tela de deck falhar com erro que não seja `404
   not_found` ENTÃO o sistema DEVE exibir a mensagem do erro e "Tentar
   novamente", que repete a consulta.

**Lista de decks**

7. A lista DEVE exibir cada deck do usuário, na ordem da API, com o nome como
   cabeçalho de nível 2 e link para `/app/baralhos/<id>` sem recarga, "Leader"
   com "<nome> (<card_number>)" ou "Sem Leader", "Cartas" com "N / 50" e
   "Status" com "válido", "incompleto" ou "inválido" (Req. 14.8).
8. SE o usuário não tiver decks ENTÃO a lista DEVE exibir "Você ainda não tem
   decks.".
9. A lista DEVE oferecer os links "Novo deck", para `/app/baralhos/novo`, e
   "Importar lista", para `/app/baralhos/importar`, sem recarga.

**Criar, renomear e excluir**

10. As telas `/app/baralhos/novo` e `/app/baralhos/<id>/renomear` DEVEM ter o
    título de página "Novo deck — Bindr" e "Renomear deck — Bindr", o mesmo
    texto como cabeçalho de nível 1 e um campo obrigatório de rótulo "Nome do
    deck (até 60 caracteres)" com `maxlength="60"`; o de renomear já vem com o
    nome atual.
11. QUANDO a API aceitar a criação ENTÃO o sistema DEVE levar a
    `/app/baralhos/<id>` do deck novo, que nasce vazio e em edição, e avisar
    "Deck criado." (Req. 14.1).
12. QUANDO a API aceitar a renomeação ENTÃO o sistema DEVE levar à página do
    deck e avisar "Deck renomeado." (Req. 14.10).
13. SE a API recusar o nome com `validation_failed` ENTÃO a mensagem de
    `fields.name` DEVE aparecer junto do campo, ligada por `aria-describedby`,
    com `aria-invalid="true"`, foco no campo e o valor digitado mantido.
14. ENQUANTO um envio de formulário de deck estiver pendente, o botão de envio
    DEVE ficar desabilitado e novo envio DEVE ser ignorado (Req. 17.21).
15. A tela `/app/baralhos/<id>/excluir` DEVE ter o título de página "Excluir
    deck — Bindr", o cabeçalho "Excluir o deck “<nome>”?", o texto "O deck e as
    cartas dele somem. Sua coleção e sua wishlist não mudam.", o botão "Excluir
    deck" e o link "Cancelar" para a página do deck, e abri-la NÃO DEVE apagar
    nada.
16. QUANDO a API aceitar a exclusão ENTÃO o sistema DEVE levar a
    `/app/baralhos` e avisar "Deck “<nome>” excluído." (Req. 14.9).

**Página do deck**

17. A página `/app/baralhos/<id>` DEVE ter o título de página "<nome> — Bindr"
    e o nome do deck como cabeçalho de nível 1.
18. SE a API responder `404 not_found` a qualquer tela de um deck ENTÃO o
    sistema DEVE exibir, no lugar dela, o título de página "Deck não encontrado
    — Bindr", a mensagem da API e o link "Voltar aos baralhos".
19. ENQUANTO o deck for o deck em edição, a página DEVE exibir "Em edição";
    nos demais casos, DEVE exibir o botão "Editar este deck".
20. QUANDO a API aceitar "Editar este deck" ENTÃO o sistema DEVE exibir "Em
    edição" no lugar do botão e avisar "Agora as cartas vão para o deck
    “<nome>”.".
21. A página DEVE exibir o cabeçalho "Status: <rótulo>" e, quando o status não
    for `válido`, a lista dos motivos na ordem e com o texto que a API devolve
    (Req. 14.15).
22. Para cada aviso de regra própria do Leader devolvido pela API, a página
    DEVE exibir "Este Leader tem regra de montagem própria, não verificada" e o
    texto da regra numa citação (Req. 14.44).
23. A página DEVE exibir sempre "A lista de banidas não é verificada"
    (Req. 14.17).
24. A seção "Na sua pasta" DEVE exibir "Este deck ainda não tem cartas" quando
    o deck não tiver Leader nem entradas, "Você tem todas as cartas deste deck"
    quando o total que falta for zero, "Falta 1 cópia para montar este deck"
    quando for 1 e "Faltam N cópias para montar este deck" acima disso
    (Req. 14.22).
25. A seção "Leader" DEVE exibir, com Leader, "<nome> (<card_number>)" como
    link para `/app/cartas/<card_number>` sem recarga e, sem Leader, "Sem
    Leader".
26. A seção "Deck principal: N / 50" DEVE exibir as entradas na ordem da API,
    agrupadas sob cabeçalhos de nível 3 a cada troca de tipo ("Personagens",
    "Eventos", "Locais"; outro tipo com o valor da API e inicial maiúscula), e
    cada entrada com "N×", "<nome> (<card_number>)" como link para
    `/app/cartas/<card_number>` sem recarga e "custo N" quando o custo não for
    nulo (Req. 14.7).
27. O Leader e cada entrada DEVEM exibir "carta fora da fonte" quando a API os
    marcar como ausentes da fonte (Req. 14.19).
28. O Leader e cada entrada DEVEM exibir "pedida N, possuída N, falta N" com os
    números da API (Req. 14.21).
29. A página DEVE oferecer "Exportar lista", para `/decks/<id>.txt` com
    navegação de página inteira, e "Renomear", "Excluir" e "Voltar aos
    baralhos", estes três sem recarga (Req. 14.31).

**Importar**

30. A tela `/app/baralhos/importar` DEVE ter o título de página "Importar lista
    — Bindr", o cabeçalho "Importar lista", o texto "Cole a lista do OPTCG
    Simulator: uma carta por linha, como 4xOP01-016, com o Leader como 1x. A
    importação cria um deck novo e não altera nenhum deck que você já tem.", o
    campo opcional "Nome do deck (opcional; sem nome, o deck leva o nome do
    Leader)" com `maxlength="60"`, a área de texto obrigatória "Lista (até 200
    linhas e 10.000 caracteres)", o botão "Importar lista" e o link "Voltar aos
    baralhos".
31. QUANDO a API aceitar a importação ENTÃO o sistema DEVE levar à página do
    deck criado, que nasce em edição, e avisar "Deck importado." (Req. 14.24).
32. SE a API recusar a lista com `validation_failed` ENTÃO o sistema DEVE
    exibir, num resumo com `role="alert"` que recebe o foco, a `message` da API
    e cada mensagem de `fields.list` na ordem, ligar o resumo à área de texto
    por `aria-describedby` com `aria-invalid="true"` e manter nome e lista
    digitados; a mensagem de `fields.name` DEVE seguir o critério 13.

**Deck em edição no detalhe da carta**

33. ENQUANTO houver sessão e deck em edição, o detalhe
    `/app/cartas/<card_number>` DEVE exibir a seção "Deck em edição" com "As
    cartas vão para o deck <nome>", o nome como link para `/app/baralhos/<id>`
    sem recarga (Req. 14.3).
34. SE não houver sessão ou deck em edição, inclusive porque ele foi excluído,
    ENTÃO o detalhe NÃO DEVE exibir a seção "Deck em edição" (Req. 14.41).
35. Para carta que não é Leader, a seção DEVE exibir, numa região
    `aria-live="polite"`, "<N> cópia(s) de <nome> no deck" ("1 cópia", "0
    cópias", "N cópias") e o controle `−` `+` com alvos de 44px e os nomes
    acessíveis "Remover uma cópia de <nome> do deck <deck>" e "Adicionar uma
    cópia de <nome> ao deck <deck>" (Req. 14.3, 14.5).
36. Os toques no `−` e no `+` do deck DEVEM seguir as regras do stepper
    otimista da posse (Req. 19.27, 19.28, 19.30, 19.31, 19.32 e 19.34),
    aplicadas à quantidade da carta no deck em edição exibido.
37. ENQUANTO a quantidade exibida no deck for zero, o `−` DEVE ter
    `aria-disabled="true"`, continuar focável e, acionado, não enviar operação
    e anunciar "<card_number> não está no deck “<deck>”." na região viva do
    controle.
38. Para carta Leader, a seção DEVE exibir o botão "Usar como Leader", de nome
    acessível "Usar <nome> como Leader do deck <deck>", ou, quando ela já for o
    Leader, o botão "<nome> é o Leader deste deck" com `aria-disabled="true"`,
    focável e sem envio (Req. 14.4).
39. QUANDO a API aceitar "Usar como Leader" ENTÃO o sistema DEVE trocar o botão
    pelo de Leader atual e avisar "<card_number> é o Leader do deck “<deck>”.".

**Faltando para os baralhos (pasta)**

40. QUANDO `/app/pasta` abrir ENTÃO o sistema DEVE pedir o que falta para os
    decks do usuário e, com ao menos uma carta, exibir no grupo de ações
    secundárias da pasta, antes dos links, o bloco "Faltando para os baralhos",
    com cada carta na ordem da API: o nome como link para
    `/app/cartas/<card_number>` sem recarga, o `card_number` em estilo `code`,
    "falta 1" ou "faltam N" e "Em" seguido dos decks que a usam, cada um como
    link para `/app/baralhos/<id>` sem recarga, separados por ", "
    (Req. 14.33, 14.34).
41. QUANDO o usuário não tiver decks ou nada faltar ENTÃO a pasta DEVE omitir o
    bloco e o título (Req. 14.35).
42. SE a consulta do bloco falhar ENTÃO a pasta DEVE exibir, no lugar do bloco,
    a mensagem do erro e "Tentar novamente", sem afetar o resto da pasta.

**API de decks**

43. QUANDO `GET /api/decks` chegar ENTÃO o sistema DEVE responder `200` com os
    decks do usuário da sessão, ordenados por nome e id, cada um com `id`,
    `name`, `leader` (`{ card_number, name }` ou `null`), `main_total` e
    `status` (`valid`, `incomplete` ou `invalid`).
44. QUANDO `POST /api/decks` chegar com nome válido ENTÃO o sistema DEVE criar
    o deck vazio, torná-lo o deck em edição da sessão e responder `201` com o
    deck no formato do critério 47.
45. QUANDO `PATCH /api/decks/:id` chegar com nome válido ENTÃO o sistema DEVE
    mudar só o nome e responder `200` com o deck no formato do critério 47.
46. SE o nome faltar, ficar vazio depois de tirar os espaços das bordas ou
    passar de 60 caracteres ENTÃO a criação, a renomeação e a importação DEVEM
    responder `422 validation_failed` com `fields.name` igual a `["O nome não
    pode ficar vazio."]` ou `["O nome pode ter no máximo 60 caracteres."]`, sem
    gravar; na importação, o nome ausente só é recusado quando a lista não tem
    Leader (Req. 14.24).
47. QUANDO `GET /api/decks/:id` chegar ENTÃO o sistema DEVE responder `200` com
    `id`, `name`, `editing`, `status`, `reasons`, `warnings`, `main_total`,
    `missing_total`, `leader` e `entries`, em que `leader` (ou `null`) e cada
    item de `entries` trazem `card_number`, `name`, `card_type`, `cost`,
    `in_source`, `required`, `owned` e `missing`, e cada entrada também
    `quantity`, com `entries` na ordem do Req. 14.7 e tudo lido num retrato só
    do banco.
48. QUANDO `DELETE /api/decks/:id` chegar ENTÃO o sistema DEVE apagar o deck e
    as entradas dele, sem alterar coleção nem wishlist, e responder `200` com
    `{ "data": { "id", "name" } }`.
49. QUANDO `POST /api/decks/:id/select` chegar ENTÃO o sistema DEVE gravar o
    deck como o deck em edição da sessão do Rails, o mesmo que o Hotwire lê, e
    responder `200` com `{ "data": { "id", "name" } }`.
50. QUANDO `GET /api/cards/:card_number` chegar com sessão e deck em edição
    válido ENTÃO a carta DEVE trazer `editing_deck` com `id`, `name`,
    `quantity` (a quantidade da carta nesse deck, `0` sem entrada) e
    `is_leader` (se a carta é o Leader dele); sem sessão ou sem deck em edição,
    `editing_deck` DEVE ser `null`. Emenda aditiva do Req. 16.23.
51. QUANDO `POST /api/decks/:id/cards/:card_number/increment` chegar ENTÃO o
    sistema DEVE somar 1 à entrada da carta no deck, criando-a com 1 quando não
    existe, e responder `200` com `{ "data": { "card_number", "quantity" } }`.
    *(Chave das rotas: P12, decidida em AD-029.)*
52. QUANDO `POST /api/decks/:id/cards/:card_number/decrement` chegar ENTÃO o
    sistema DEVE subtrair 1 da entrada, apagá-la quando chegar a zero e
    responder `200` com a quantidade resultante; sem entrada, DEVE responder
    `200` com `quantity: 0` sem gravar (mesma regra do P10).
53. SE o incremento encontrar a entrada em 50 ENTÃO o sistema DEVE responder
    `422 validation_failed` com "O máximo é 50 cópias por carta no deck.", sem
    gravar (Req. 14.39).
54. SE o incremento apontar uma carta Leader ENTÃO o sistema DEVE responder
    `422 validation_failed` com "<card_number> é um Leader; use “Usar como
    Leader” em vez de somar cópias.", sem gravar.
55. QUANDO `PUT /api/decks/:id/leader` chegar com `card_number` de uma carta
    Leader ENTÃO o sistema DEVE gravar ou substituir o Leader, sem tocar as
    entradas, e responder `200` com `{ "data": { "leader_card_number" } }`;
    carta que não é Leader DEVE responder `422 validation_failed` com
    "<card_number> não é um Leader; use “+” para somar cópias ao deck.", sem
    gravar.
56. QUANDO incrementos e decrementos da mesma carta no mesmo deck chegarem ao
    mesmo tempo ENTÃO o sistema DEVE aplicar todos, sem perder operação nem
    passar de 50 nem de zero (Req. 14.38).
57. QUANDO `POST /api/decks/import` chegar com `name` e `list` ENTÃO o sistema
    DEVE aplicar o Req. 14.24–14.30 e, com a lista aceita, criar o deck,
    torná-lo o deck em edição e responder `201` com o deck no formato do
    critério 47.
58. SE a lista for recusada ENTÃO a importação DEVE responder `422
    validation_failed` com `message` "A lista não foi importada. Nenhum deck foi
    criado." e `fields.list` com cada recusa, na ordem do texto, como "Linha N:
    <motivo>" ou só o motivo quando vale para o texto inteiro, sem criar deck.
59. QUANDO `GET /api/decks/shortfall` chegar ENTÃO o sistema DEVE responder
    `200` só com as cartas que faltam para os decks do usuário, ordenadas por
    `card_number`, cada uma com `card_number`, `name`, `missing` e `decks`
    (`{ id, name }` dos decks que a usam, por id), pela regra do Req. 14.33.
60. Todo endpoint de deck DEVE exigir sessão (`401 unauthenticated`), toda
    mutação DEVE exigir CSRF (`422 invalid_csrf_token`), deck inexistente ou de
    outro usuário e carta inexistente DEVEM responder `404 not_found` sem
    gravar, e todo acesso DEVE partir de `Current.user.decks`: um `user_id` no
    corpo ou na query nunca muda o deck lido ou gravado (Req. 6.5, 14.36,
    14.37).
61. Os controllers e as rotas HTML DEVEM continuar inalterados: a suíte
    existente passa sem edição.

---

## Requisito 22 — Import e export da coleção na SPA

**User story:** Como colecionador, quero importar a minha coleção de um CSV e
baixá-la em CSV pela SPA, vendo antes o que vai mudar e depois o que mudou,
para migrar de uma planilha ou levar o meu dado embora sem as páginas Hotwire.

Requisito da troca de front (AD-023), escrito em 2026-10-10 sem o dono
presente. Recorte em `.specs/features/spa-portabilidade/spec.md` (SPOR-NN,
mesma numeração destes critérios). A régua é a paridade com `/collection/import`
e `/collection/export` do Hotwire (Req. 10, POR-01..13); o que for além dela
fica fora. Formato do arquivo, parser, resolvedor, staging (`collection_imports`,
AD-007), substituição (AD-006), teto de 10.000 linhas (AD-008) e gravação
continuam nos objetos do Req. 10 (`CollectionCsv::Parser`, `Resolver`, `Commit`,
`Export`); a SPA exibe o que a API devolve e não repete regra. É fatia vertical:
cria os endpoints de import sob `/api`, no padrão do Req. 16, e herda cliente,
sessão, casco, temas e mensagens do Req. 17 e a pasta do Req. 20, de onde se
chega às duas ações. A exportação continua o download do endpoint HTML, porque
todo endpoint de `/api` responde JSON (Req. 16.14).

A escolha marcada DECISÃO PENDENTE abaixo (P13) tem opção recomendada e está no
*Rastreamento de pendências*.

### Critérios de aceitação

**Envio do arquivo**

1. A SPA DEVE exibir o envio em `/app/pasta/importar`, com o título de página
   "Importar coleção — Bindr", o cabeçalho de nível 1 "Importar coleção" e o
   texto "Envie o arquivo CSV exportado da sua coleção. Você verá o que vai
   mudar antes de qualquer alteração ser gravada." (Req. 10.5).
2. A ação "Importar coleção" da pasta DEVE levar a `/app/pasta/importar` sem
   recarregar a página. Este critério substitui o destino Hotwire do Req. 20.25
   para essa ação.
3. SE a sessão estiver anônima quando `/app/pasta/importar` ou
   `/app/pasta/importar/<token>` abrir ENTÃO o sistema DEVE levar a
   `/app/entrar?return_to=<caminho atual>`, sem chamar a API da tela.
4. A tela DEVE ter o campo de arquivo obrigatório de rótulo "Arquivo CSV", com
   `accept="text/csv,.csv"`, e o botão "Pré-visualizar importação"; além do
   `required`, o cliente não valida tamanho, extensão nem conteúdo, que são
   regras da API.
5. QUANDO o usuário enviar o formulário ENTÃO o sistema DEVE mandar o arquivo
   por `POST /api/collection/imports`, em `multipart/form-data` no campo
   `file`, e o botão DEVE seguir o Req. 17.21 enquanto o envio estiver
   pendente.
6. QUANDO a API aceitar o arquivo ENTÃO o sistema DEVE levar a
   `/app/pasta/importar/<token>` sem recarregar a página.
7. SE a API recusar o arquivo com `422 validation_failed` ENTÃO o sistema DEVE
   exibir, num resumo com `role="alert"` que recebe o foco, a `message` e cada
   mensagem de `fields.file` na ordem, ligar o resumo ao campo por
   `aria-describedby` com `aria-invalid="true"` e manter o usuário na tela.
8. SE o envio falhar com outro erro ENTÃO o sistema DEVE exibir a mensagem do
   erro como veio (Req. 17.11); `401` e sessão trocada seguem o Req. 17.9 e
   17.10, sem reenvio em outra conta.

**Pré-visualização**

9. QUANDO `/app/pasta/importar/<token>` abrir ENTÃO o sistema DEVE pedir
   `GET /api/collection/imports/<token>` e exibir o título de página
   "Pré-visualização da importação — Bindr" e o cabeçalho de nível 1 "Confira o
   que vai mudar".
10. QUANDO essa consulta passar de 200 ms sem resposta ENTÃO a região do
    conteúdo DEVE ficar com `aria-busy="true"` e o texto "Carregando
    pré-visualização…".
11. SE a consulta responder `404` ENTÃO o sistema DEVE exibir a mensagem do
    erro e o link "Enviar um arquivo" para `/app/pasta/importar`, sem "Tentar
    novamente"; outro erro que não seja `401` DEVE exibir a mensagem e "Tentar
    novamente", que repete a consulta.
12. A pré-visualização DEVE exibir "Arquivo: <filename> — 1 linha analisada." ou
    "Arquivo: <filename> — N linhas analisadas." e o aviso "Nada foi gravado na
    sua coleção ainda. Sua coleção só muda quando você confirmar, no fim desta
    página.", com a primeira frase em destaque.
13. As linhas DEVEM aparecer em grupos, nesta ordem, cada um com cabeçalho de
    nível 2 "<título> (<quantidade>)" e a frase de apoio, e um grupo sem linhas
    não DEVE aparecer: `removes` "Remove da coleção" ("Estas cartas você possui
    hoje e o arquivo traz zero: a posse desaparece na confirmação."); `creates`
    "Passa a constar" ("Estas variantes ainda não estão na sua coleção e
    passarão a constar."); `updates` "Altera a quantidade" ("A quantidade do
    arquivo substitui a que está na sua coleção hoje."); `rejected` "Não será
    importada" ("Estas linhas do arquivo não serão aplicadas. O motivo de cada
    uma está abaixo."); `unchanged` "Já está assim" ("A quantidade do arquivo é
    a que você já tem: nada muda nestas linhas.").
14. Cada linha DEVE exibir o rótulo escrito da classificação ("Remove da
    coleção", "Cria", "Altera", "Recusada" ou "Sem alteração"), o
    `card_number`, o `variant_code` em estilo `code` e o `card_name`, com "—"
    no lugar de código ausente, e "Linha <line> do arquivo", na ordem da
    resposta dentro do grupo.
15. A linha recusada DEVE exibir a `message`; a linha `creates` DEVE exibir
    "Você não tem esta variante registrada; passará a ter nova quantidade
    <depois>." e as demais "De quantidade atual <antes> para nova quantidade
    <depois>.", com o antes e o depois em elementos próprios.
16. A classificação NÃO DEVE depender só de cor: o rótulo escrito e a estrutura
    de cabeçalhos bastam sem folha de estilo, e a distinção visual entre grupos
    usa forma ou peso além da cor (Req. 12.8).
17. `card_name`, `filename` e `message` DEVEM ser exibidos como texto, nunca
    interpretados como HTML: um `<script>` no nome da carta aparece escrito e
    não executa.
18. QUANDO houver linhas `removes` ENTÃO o sistema DEVE exibir, antes do botão
    de confirmar e no fluxo do documento, "Atenção: 1 carta que você possui
    hoje sai da sua coleção se você confirmar." ou "Atenção: N cartas que você
    possui hoje saem da sua coleção se você confirmar.", seguido de "Veja quais
    em “Remove da coleção”, no topo desta página.".
19. A pré-visualização DEVE terminar com o botão "Confirmar e gravar na minha
    coleção" e o texto "Se algo estiver errado, envie outro arquivo. Sair desta
    página sem confirmar deixa sua coleção exatamente como está.", com "envie
    outro arquivo" como link para `/app/pasta/importar` sem recarga.
20. Abrir, recarregar ou deixar a pré-visualização NÃO DEVE alterar a coleção
    (Req. 10.5).

**Confirmação e resumo**

21. QUANDO o usuário acionar "Confirmar e gravar na minha coleção" ENTÃO o
    sistema DEVE pedir `POST /api/collection/imports/<token>/confirm`, sem
    corpo, e o botão DEVE seguir o Req. 17.21 enquanto a confirmação estiver
    pendente.
22. QUANDO a confirmação responder `200` ENTÃO o sistema DEVE trocar a
    pré-visualização pelo resumo na mesma URL, com o título de página
    "Importação concluída — Bindr" e o cabeçalho de nível 1 "Importação
    concluída", que recebe o foco.
23. O resumo DEVE exibir "Arquivo: <filename> — sua coleção foi atualizada." e
    as três contagens do Req. 10.4, nesta ordem e cada número com seu rótulo em
    elemento próprio: "Importadas" (`created`, "Variantes que não estavam na sua
    coleção e passaram a estar."), "Atualizadas" (`updated`, "Variantes que já
    estavam na sua coleção e tiveram a quantidade substituída.") e "Recusadas"
    (quantidade de `rejected`, "Linhas do arquivo que não foram aplicadas."),
    inclusive com zero.
24. QUANDO `removed` for maior que zero ENTÃO o resumo DEVE exibir "1 dessas
    atualizações removeu a carta da sua coleção: o arquivo trazia zero para
    uma variante que você possuía." ou "N dessas atualizações removeram a carta
    da sua coleção: o arquivo trazia zero para N variantes que você possuía.".
25. QUANDO `unchanged` for maior que zero ENTÃO o resumo DEVE exibir "1 linha do
    arquivo já estava assim na sua coleção: nada mudou nelas." ou "N linhas do
    arquivo já estavam assim na sua coleção: nada mudou nelas.".
26. QUANDO houver recusas ENTÃO o resumo DEVE exibir "Confira estas linhas: 1
    linha do arquivo não foi aplicada. Sua coleção não foi alterada por ela."
    ou "Confira estas linhas: N linhas do arquivo não foram aplicadas. Sua
    coleção não foi alterada por elas." e, para cada recusa, `card_number`,
    `variant_code`, `card_name`, "Linha <line> do arquivo" e a `message`
    (Req. 10.4).
27. QUANDO houver falhas de gravação ENTÃO o resumo DEVE exibir, separado das
    recusas, "Atenção: 1 linha não pôde ser gravada por um problema ao salvar.
    As demais entraram normalmente. Envie o arquivo de novo com essa linha para
    tentar outra vez." ou a forma plural ("N linhas não puderam ser gravadas",
    "essas linhas"), e cada falha como "Linha <line> do arquivo —
    <card_number> <variant_code>".
28. SE não houver recusa nem falha ENTÃO o texto do resumo NÃO DEVE conter
    "rejeitada", "falha" nem "erro".
29. O resumo DEVE terminar com "Ver minha coleção", para `/app/pasta`, e
    "importar outro arquivo", para `/app/pasta/importar`, ambos sem recarga.
30. SE a confirmação responder `409 import_closed` ENTÃO o sistema DEVE manter
    a pré-visualização e exibir a mensagem da API com `role="alert"`.
31. SE a confirmação falhar sem resposta ou por tempo limite ENTÃO o sistema
    DEVE exibir "Não foi possível saber se a importação foi gravada. Confira a
    sua pasta antes de enviar o arquivo de novo.", com "Ver minha coleção" para
    `/app/pasta`, sem reenviar a confirmação. *(Resumo não persistido: DECISÃO
    PENDENTE P13.)*
32. O envio e a confirmação DEVEM ter tempo limite de 60 s; as demais chamadas
    mantêm os 15 s do Req. 17.12.

**Exportação e ida e volta**

33. A pasta DEVE continuar oferecendo "Baixar minha coleção (CSV)" como link de
    página inteira para `/collection/export` (Req. 20.25), e esta feature NÃO
    DEVE criar endpoint de exportação sob `/api`.
34. QUANDO o arquivo baixado por esse link for enviado sem edição pela SPA ENTÃO
    a pré-visualização DEVE ter só o grupo "Já está assim", e confirmar DEVE
    deixar a coleção idêntica à exportada (Req. 10.2, POR-11).

**Cliente HTTP**

35. O cliente HTTP do Req. 17.6 DEVE aceitar corpo `FormData`, enviado sem
    `Content-Type` próprio, com `X-CSRF-Token` e com a renovação e o reenvio
    único do Req. 17.10, e continuar sendo o único módulo que chama `fetch`.

**API do import**

36. QUANDO `POST /api/collection/imports` chegar com sessão, CSRF válido e
    arquivo aceito pelo parser ENTÃO o sistema DEVE criar a pré-visualização em
    `collection_imports`, dona do usuário da sessão, com o mesmo parser, o mesmo
    resolvedor e o mesmo nome de arquivo saneado do HTML, sem escrever em
    `collection_items`, e responder `201` com ela no formato do critério 38.
37. SE faltar o arquivo, o corpo declarar mais de 12 MB ou o parser recusar o
    arquivo ENTÃO o sistema DEVE responder `422 validation_failed` com `message`
    "O arquivo não foi importado. Sua coleção não foi alterada." e `fields.file`
    com a mensagem que o HTML exibe para o mesmo caso, sem criar
    pré-visualização.
38. QUANDO `GET /api/collection/imports/:token` chegar ENTÃO o sistema DEVE
    responder `200` com `{ data: { token, filename, rows } }`, `rows` na ordem
    do arquivo, cada uma com `line` (número da linha no arquivo, com o
    cabeçalho na linha 1), `classification` (`removes`, `creates`, `updates`,
    `rejected` ou `unchanged`), `card_number`, `variant_code`, `card_name` (o
    do arquivo), `quantity_before` (`null` sem registro na coleção, nunca `0`),
    `quantity_after` (`null` na recusada) e `message` (`null` fora da
    recusada), também depois do prazo de confirmação, como o HTML.
39. SE o token não existir ou for de outro usuário ENTÃO a leitura e a
    confirmação DEVEM responder o mesmo `404 not_found`, sem gravar.
40. QUANDO `POST /api/collection/imports/:token/confirm` chegar com sessão e
    CSRF válidos sobre pré-visualização pendente e no prazo ENTÃO o sistema
    DEVE gravar pelo mesmo `CollectionCsv::Commit` do HTML, só o que o staging
    guarda e sem ler outro parâmetro, e responder `200` com `{ data: {
    filename, created, updated, removed, unchanged, rejected, failures } }`, em
    que `updated` inclui as `removed`, `rejected` traz `line`, `card_number`,
    `variant_code`, `card_name` e `message` de cada recusa e `failures` traz
    `line`, `card_number` e `variant_code` de cada falha de gravação.
41. SE a pré-visualização já estiver confirmada ou vencida ENTÃO a confirmação
    DEVE responder `409 import_closed` com "Esta importação já foi confirmada
    ou expirou. Sua coleção não foi alterada; envie o arquivo de novo se quiser
    importar.", sem gravar.
42. QUANDO duas confirmações do mesmo token chegarem ao mesmo tempo ENTÃO só
    uma DEVE gravar e a outra DEVE responder `409 import_closed`.
43. Os três endpoints DEVEM exigir sessão (`401 unauthenticated`), as duas
    mutações DEVEM exigir CSRF (`422 invalid_csrf_token`), e todos DEVEM ler e
    gravar só registros do usuário da sessão: um `user_id` no corpo ou na query
    nunca muda o registro lido ou gravado (Req. 6.5).
44. O envio e a leitura da pré-visualização DEVEM sair de um número de
    consultas que não cresce com a quantidade de linhas do arquivo (Req. 11.1,
    POR-13).
45. Os controllers e as rotas HTML DEVEM continuar inalterados: a suíte
    existente passa sem edição.

**Tela**

46. As três telas DEVEM caber em 360px sem scroll horizontal, nos dois temas,
    com nome de carta e código longos quebrando linha, e os botões DEVEM ter
    alvo de no mínimo 44px (Req. 2.5).

---

## Requisito 23 — Troca do front: SPA na raiz e saída do Hotwire

**User story:** Como colecionador, quero usar o Bindr só pela SPA, no endereço
raiz, com os links que já compartilhei continuando a abrir a mesma tela; e como
dono, quero o Hotwire fora do código, para manter uma camada de apresentação só.

Requisito final da troca de front (AD-023), escrito em 2026-10-10 sem o dono
presente. Recorte em `.specs/features/spa-troca/spec.md` (STRO-NN, mesma
numeração destes critérios). Não cria tela: move a SPA de `/app` para a raiz,
redireciona as URLs antigas, remove controllers, views, helpers, importmap e CSS
do HTML e reorganiza a suíte. A régua é a checklist de paridade abaixo; o
Hotwire só sai quando cada linha dela estiver coberta por uma fatia SPA
encerrada e verificada.

As escolhas do P14 (rotas de arquivo nas URLs atuais) e do P15 (`301`) foram
decididas pelo dono em 2026-10-11 (AD-030); o `⚠️ VERIFICAR` do critério 27
segue no *Rastreamento de pendências* (P16).

**Checklist de paridade.** Cada tela Hotwire e a fatia SPA que a cobre:

| Tela Hotwire | URL Hotwire | Destino na SPA | Cobertura |
|---|---|---|---|
| Catálogo: grade, busca, filtros, posse na grade | `/`, `/catalog` | `/` | Req. 18 (`spa-catalogo`), com o SCAT-03 emendado para o destino do Req. 19.3 |
| Detalhe da carta: campos, variantes, posse, desejo, preço | `/cards/<card_number>` | `/cartas/<card_number>` | Req. 19 (`spa-carta`) |
| Controle do deck em edição no detalhe | `/cards/<card_number>` | `/cartas/<card_number>` | Req. 21 (`spa-decks`) |
| Entrar, criar conta, sair | `/session/new`, `/registration/new` | `/entrar`, `/criar-conta`, casco | Req. 17 (`spa-fundacao`, encerrada) |
| Minha pasta: indicadores, sets, valor estimado | `/progress` | `/pasta` | Req. 20 (`spa-pasta`) |
| Faltando para os decks, na pasta | `/progress` | `/pasta` | Req. 21 (`spa-decks`) |
| Lista de desejos | `/wishlist` | `/pasta/desejos` | Req. 20 (`spa-pasta`) |
| Import da coleção: envio, pré-visualização, resumo | `/collection/import`, `/collection/import/<token>` | `/pasta/importar`, `/pasta/importar/<token>` | Req. 22 (`spa-portabilidade`) |
| Export da coleção | `/collection/export` | rota de arquivo (P14) | Req. 22.33 |
| Decks: lista, criar, página, renomear, excluir, importar | `/decks`, `/decks/new`, `/decks/<id>`, `/decks/<id>/edit`, `/decks/<id>/delete`, `/decks/import` | `/baralhos`, `/baralhos/novo`, `/baralhos/<id>`, `/baralhos/<id>/renomear`, `/baralhos/<id>/excluir`, `/baralhos/importar` | Req. 21 (`spa-decks`) |
| Exportar lista do deck | `/decks/<id>.txt` | rota de arquivo (P14) | Req. 21.29 |
| Navegação, layout e mensagens (Req. 13, flash) | todas | casco e mensagens | Req. 17 (`spa-fundacao`) |

**Critérios superados.** Com a troca, deixam de valer: os critérios que mantêm
os controllers e as rotas HTML inalterados (Req. 16.17, 17.4, 19.49, 20.46,
21.61, 22.45); o destino Hotwire das entradas da navegação (Req. 17.26); a
frase do Req. 12.2 sobre as páginas Hotwire em tema único; e a cláusula "sem
JavaScript" dos Req. 9.7, 13.11, 13.30 e 13.40, cujo restante continua valendo
na SPA (estado na URL, sem recarregar a página). Toda menção a `/app/<caminho>`
nos Req. 17 a 22 passa a ler `/<caminho>`.

### Critérios de aceitação

**Paridade antes da remoção**

1. A troca DEVE começar só quando cada linha da checklist de paridade estiver
   coberta por uma feature encerrada e verificada (`validation.md` PASS).
2. O spec da `spa-catalogo` DEVE estar emendado antes da troca: o SCAT-03 leva o
   tile ao detalhe da SPA, como o Req. 19.3 e o SCAR-03 já determinam.
3. Nenhum link, botão ou navegação da SPA DEVE apontar para rota HTML removida;
   os únicos destinos fora da SPA são as rotas de arquivo (critérios 17 e 18).

**SPA na raiz**

4. QUANDO `docker compose up` terminar ENTÃO o sistema DEVE servir a SPA em `/`
   pelo Vite, encaminhando ao Rails só os caminhos do critério 8, sem comando
   adicional (Req. 11.6).
5. QUANDO o Rails de produção receber `GET` de caminho fora do critério 8 ENTÃO
   o sistema DEVE responder `200` com a página de entrada da SPA e
   `Cache-Control: no-cache`.
6. Os arquivos do build DEVEM sair sob `/_app/` pelo servidor de estáticos, com
   cache de longa duração; arquivo inexistente sob `/_app/` DEVE responder
   `404`.
7. A página de entrada NÃO DEVE ser servida pelo servidor de estáticos:
   `GET /200.html` DEVE responder como o critério 5, nunca com cache de longa
   duração.
8. Os caminhos do Rails DEVEM ser uma lista fechada: `/api/*`,
   `/card_images/*`, `/up`, `/_app/*`, os arquivos de `public/`, as rotas de
   arquivo dos critérios 17 e 18 e os redirecionamentos dos critérios 11 e 12.
   Rota nova do Rails fora de `/api` exige emendar esta lista.
9. As rotas da SPA DEVEM ficar na raiz, sem o prefixo `/app`: `/`, `/entrar`,
   `/criar-conta`, `/cartas/<card_number>`, `/pasta`, `/pasta/desejos`,
   `/pasta/importar`, `/pasta/importar/<token>`, `/baralhos`, `/baralhos/novo`,
   `/baralhos/importar`, `/baralhos/<id>`, `/baralhos/<id>/renomear` e
   `/baralhos/<id>/excluir`.
10. SE a SPA receber um caminho que não é rota dela ENTÃO o sistema DEVE exibir,
    dentro do casco, o cabeçalho de nível 1 "Página não encontrada", o título de
    página "Página não encontrada — Bindr" e o link "Ir para o catálogo" para
    `/`.

**URLs antigas (Req. 4.7, 13.40)**

11. QUANDO chegar `GET` numa URL Hotwire da checklist, salvo `/`, ENTÃO o sistema DEVE
    redirecionar para o destino da mesma linha na SPA, com `301` (P15) e a
    query string preservada sem alteração.
12. QUANDO chegar `GET /app` ou `GET /app/<caminho>` ENTÃO o sistema DEVE
    redirecionar para `/` ou `/<caminho>`, com `301` (P15) e a query
    preservada; arquivo sob `/app/_app/` DEVE responder `404`.
13. O redirecionamento NÃO DEVE exigir sessão nem consultar o banco: o destino
    sai só do caminho, e `card_number`, `id` ou `token` inexistente é resolvido
    pela tela da SPA.
14. O segmento dinâmico (`card_number`, `id`, `token`) DEVE chegar ao destino com
    a mesma codificação percentual da URL pedida.
15. SE chegar requisição que não seja `GET` ou `HEAD` a uma rota HTML removida
    ENTÃO o sistema DEVE responder `404` sem efeito, nunca a página de entrada
    nem `500`.

**Rotas de arquivo (P14)**

16. As rotas de arquivo DEVEM ficar fora de `/api`, que continua só JSON
    (Req. 16.14).
17. `GET /collection/export` DEVE continuar devolvendo o CSV do Req. 10.1 com o
    mesmo conteúdo, tipo, `Content-Disposition` e nome de arquivo de hoje.
18. `GET /decks/<id>.txt` DEVE continuar devolvendo a lista do Req. 14.31 com o
    mesmo conteúdo e tipo de hoje; deck de outra conta ou inexistente DEVE
    responder `404` (DCK-36).
19. SE uma rota de arquivo for pedida sem sessão ENTÃO o sistema DEVE
    redirecionar com `302` para `/entrar?return_to=<caminho com query,
    codificado>`.

**Sessão e retorno**

20. O destino pós-login DEVE ser o `return_to` decodificado quando ele começar
    por `/` e não tiver `//`, `\`, caractere de controle nem segmento `.` ou
    `..`; senão, `/`. Substitui o Req. 17.23.
21. SE o `return_to` for `/app` ou começar por `/app/` ENTÃO o sistema DEVE
    lê-lo sem o prefixo `/app` antes de aplicar o critério 20.
22. SE o destino pós-login for uma rota de arquivo ENTÃO a SPA DEVE navegar com
    página inteira; destino sob `/api/`, `/_app/` ou `/card_images/` DEVE virar
    `/`.
23. O deck em edição DEVE continuar em `session[:editing_deck_id]`, lido e
    gravado só pela API, revalidado contra `Current.user.decks` a cada leitura
    e limpo no login e no logout.
24. Sessões abertas antes da troca DEVEM continuar válidas: o mesmo cookie
    segue autenticado, sem novo login.

**Saída do Hotwire**

25. DEVEM sair do código os controllers HTML (`CatalogController`,
    `CollectionItemsController`, `WishlistItemsController`,
    `ProgressController`, `CollectionImportsController`, `DecksController`,
    `DeckEntriesController`, `DeckImportsController`, `SessionsController`,
    `RegistrationsController`), as views fora de `app/views/api/`, os helpers
    de view, `app/javascript/`, `config/importmap.rb`, `bin/importmap`,
    `app/assets/stylesheets/` e as rotas HTML, salvo o que as rotas de arquivo
    usam.
26. Concern e objeto usado pela API ou pelas rotas de arquivo DEVEM ficar,
    só com o que esses usam; nenhum redirecionamento para `new_session_path`
    nem leitura de `return_to_after_authenticating` permanece.
27. As gems `importmap-rails`, `turbo-rails`, `stimulus-rails` e `propshaft`
    DEVEM sair do `Gemfile`. `⚠️ VERIFICAR` que o Rails 8.0 sobe sem
    `propshaft` depois de retirar `config/initializers/assets.rb` e as
    referências a `config.assets` (P16).
28. DEVEM continuar sem mudança de comportamento: os endpoints de `/api`
    (Req. 16 e fatias), `/card_images/<variant_code>` (resposta, cache e
    erros), `/up`, a ingestão e as tarefas `ingestion:*`.
29. A troca NÃO DEVE ter migração nem alterar dado: catálogo, coleção,
    wishlist, decks e sessões ficam como estão.

**Suíte**

30. Teste cujo objeto é só markup, CSS, Turbo ou helper de view do HTML DEVE sair
    junto com o código que testa.
31. Teste HTML que prove garantia que continua valendo (isolamento entre
    usuários, Req. 6.5; corrida de posse e de deck; ida e volta do CSV;
    confirmação única do import; números da pasta e do que falta) DEVE ter
    equivalente sobre a API, o model ou o query object antes de sair, com o
    destino de cada arquivo removido registrado num inventário.
32. Os testes de model, query, service, lib, API e imagem DEVEM passar sem
    edição; o teste da entrega da SPA muda só para a raiz.
33. Cada redirecionamento dos critérios 11 e 12 DEVE ter teste do status, do
    `Location` com query e do `404` de método diferente de `GET`/`HEAD`.
34. O e2e DEVE rodar contra a raiz; teste que compara a SPA com página Hotwire
    DEVE passar a comparar com a resposta da API ou com o banco.
35. Ao fim, `bin/rails test`, `bin/rubocop`, `bin/brakeman`, os gates quick e
    e2e do front e `docker build -f Dockerfile .` DEVEM passar.

**Documentos**

36. Os critérios superados acima DEVEM receber nota de emenda apontando para
    este requisito.
37. O `CLAUDE.md` DEVE deixar de descrever o Hotwire como vigente e trazer as
    rotas e os comandos na raiz.

---

## Rastreamento de pendências

### Resolvidas

| # | Pendência | Decisão | Onde |
|---|---|---|---|
| P1 | Escolha e validação da fonte de dados do catálogo | (AD-001) | task 0.1, `.specs/STATE.md`, `docs/adr/001-fonte-de-dados-do-catalogo.md` |
| P2 | Confirmação dos campos, raridades, sets e attributes reais | (task 0.2) | `.context/tasks.md`, fixture validada |
| P3 | Definição de "set completo" (Req. 9) | (AD-003) | task 0.3, `.specs/STATE.md`, `docs/adr/002-stack-set-completo-e-imagens.md` |
| P4 | Escolha de stack | (AD-002) | task 0.3, `.specs/STATE.md`, `docs/adr/002-stack-set-completo-e-imagens.md` |
| P9 | Chave das rotas de posse e desejo da API | `card_number` + `variant_code` no caminho (AD-027, 2026-10-11) | Req. 19.42–19.47; `.specs/features/spa-carta/spec.md` |
| P10 | Decremento em zero na API | `200` com `owned_quantity: 0`, sem gravar (AD-027, 2026-10-11) | Req. 19.43; `.specs/features/spa-carta/spec.md` |
| P11 | Remoção de desejo na API | `DELETE /api/cards/:card_number/variants/:variant_code/wishlist`, `200` também sem desejo (AD-027, 2026-10-11) | Req. 20.43; `.specs/features/spa-pasta/spec.md` |
| P14 | Destino das rotas de arquivo `GET /collection/export` e `GET /decks/<id>.txt` depois da troca | Ficam nas URLs atuais, como rotas do Rails fora de `/api`, com sessão e `302` para `/entrar?return_to=` sem ela; o Req. 16.14 continua valendo (AD-030, 2026-10-11) | Req. 23.16–23.19, 23.22; `.specs/features/spa-troca/spec.md` |
| P15 | Status dos redirecionamentos das URLs Hotwire e de `/app` | `301` permanente; aceito o custo de que um rollback para a imagem com Hotwire encontra favoritos com o `301` em cache (AD-030, 2026-10-11) | Req. 23.11, 23.12; `.specs/features/spa-troca/spec.md` |

### Em aberto

| # | Pendência | Onde |
|---|---|---|
| P8 | Hexadecimais das seis cores do jogo (Req. 12.11) | Req. 12 (emenda de 2026-09-29); Req. 18.21 (chip de cor da SPA, neutro até a decisão) |
| P12 | Chave das rotas de deck da API | `id` do deck, exposto no payload, mais `card_number` no caminho (`POST /api/decks/:id/cards/:card_number/increment` e `/decrement`, `PUT /api/decks/:id/leader`): a ação vai para o deck exibido na tela (AD-029, 2026-10-11) | Req. 21.51–21.55; `.specs/features/spa-decks/spec.md` |
| P13 | DECISÃO PENDENTE — confirmação do import da coleção cuja resposta se perde (rede ou tempo limite): manter o resumo não persistido, como o HTML, e exibir "Não foi possível saber se a importação foi gravada. Confira a sua pasta antes de enviar o arquivo de novo." sem reenviar (recomendada; sem migração, e o `Commit` já impede gravar duas vezes) ou persistir o resultado do `Commit` em `collection_imports` (migração) e devolvê-lo na leitura da pré-visualização confirmada, para recuperar o resumo | Req. 22.31, 22.40; `.specs/features/spa-portabilidade/spec.md` |
| P16 | ⚠️ VERIFICAR — o Rails 8.0 sobe e passa a suíte sem a gem `propshaft`, depois de retirar `config/initializers/assets.rb` e as referências a `config.assets` | Req. 23.27; `.specs/features/spa-troca/spec.md` |
