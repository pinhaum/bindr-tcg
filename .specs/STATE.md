# STATE

## Decisions

### AD-001
- **Decision**: O catálogo é carregado de `hugoprudente/optcgjson` (`output/*.json`), fixado em revisão imutável, e não da apitcg.com nem da dotgg.gg.
- **Reason**: É a única das três fontes que preserva a distinção entre carta e impressão física. Ela fornece `id` estável por variante (`OP01-001_p1`), o que elimina a necessidade de derivar `variant_code` por hash — a parte que o design apontava como a mais frágil do projeto.
- **Trade-off**: Abre mão de preços (que apitcg tem e optcgjson não) e depende de um scraper de mantenedor único, sem licença declarada. Mitigado pelo estágio Fetch salvar o payload bruto em disco: o catálogo é reconstruível sem rede, e trocar de fonte significa reescrever só o Normalize.
- **Scope**: Todo o subsistema de ingestão; modelo de `cards` e `card_variants`; Fase 3 (preços) precisará de outra fonte.
- **Date**: 2026-09-19
- **Status**: active

### AD-002
- **Decision**: Stack Rails 8 + Hotwire + PostgreSQL.
- **Reason**: PostgreSQL é requisito de design, não preferência — `pg_trgm`, `unaccent` e GIN sobre arrays sustentam os Req. 3 e 4 inteiros. Hotwire cobre o incremento/decremento sem recarregar página (Req. 7.2) sem introduzir uma SPA.
- **Trade-off**: Descartado Next.js + Prisma, apesar de haver cinco apps Next no workspace; Prisma tem atrito com arrays Postgres + GIN e com `pg_trgm`, o que jogaria boa parte das consultas para SQL cru.
- **Scope**: Todo o projeto.
- **Date**: 2026-09-19
- **Status**: active

### AD-003
- **Decision**: "Set completo" usa `baseSetSize` (variantes base) como denominador; parallels contam em métrica separada, nunca somados ao percentual.
- **Reason**: Sob a leitura "todas as impressões", sets dominados por parallels travam perto de zero permanentemente — em `LimitedProductCard`, 171 de 192 registros são parallels. O percentual deixaria de responder a pergunta que o Req. 9 existe para responder.
- **Trade-off**: Quem persegue completar todas as impressões não vê isso no número principal; fica na métrica secundária.
- **Scope**: Req. 9 (progresso por set).
- **Date**: 2026-09-19
- **Status**: active

### AD-004
- **Decision**: Imagens por hotlink de `imageUrl` (onepiece-cardgame.com), sem cache local na Fase 1.
- **Reason**: Coerente com `product.md` §5.1, que prefere referenciar a redistribuir arte. Custo zero de storage e invalidação, nenhum dos quais é requisito hoje.
- **Trade-off**: Se a Bandai bloquear hotlink, a grade fica sem arte. O placeholder do Req. 2.2 deixa de ser detalhe de robustez e passa a ser a mitigação desta decisão. Nenhum dado de usuário depende de imagem.
- **Scope**: Grade do catálogo e detalhe da carta.
- **Date**: 2026-09-19
- **Status**: active

### AD-005
- **Decision**: Os documentos de especificação continuam em `.context/` (`product.md`, `requirements.md`, `design.md`, `tasks.md`); `.specs/` guarda o recorte por feature, o log de decisões e os artefatos de verificação.
- **Reason**: `.context/` é a fonte de verdade histórica do projeto e tem convenções próprias (`⚠️ VERIFICAR`, `DECISÃO PENDENTE`, P1–P7) referenciadas pelo `CLAUDE.md`. Reescrevê-lo criaria duas fontes de verdade para os mesmos requisitos.
- **Trade-off**: Exige manter a rastreabilidade entre os dois diretórios — os IDs `CAT-NN` em `.specs/` apontam para os requisitos numerados de `.context/requirements.md`.
- **Scope**: Método de trabalho de todas as features.
- **Date**: 2026-09-19
- **Status**: active

## Handoff

> **Começando uma sessão nova?** Leia **`.specs/HANDOFF-colecao.md`** primeiro:
> estado, decisões, armadilhas de ambiente e método para a feature `colecao`.
> O `HANDOFF-fase-4.md` continua válido como histórico do fim do `catalogo`.

- **Feature**: colecao (`.specs/features/colecao/`) — `catalogo` encerrada
- **Phase / Task**: Feature `colecao`, **Fase 3 em execução** — **T11 fechada**
  (total de cópias da coleção, exibido na grade e atualizado por Turbo Stream;
  **sem migração**). Fase 2 (posse) encerrada com T5–T8.
  Restam T12–T13: wishlist.
  Feature `catalogo` ENCERRADA: 14 de 14 tasks, os dois lotes verificados (B1 e
  B2, ambos PASS, autor ≠ verificador). Os achados dos Verifiers e da revisão
  de a11y foram corrigidos e commitados.
- **Completed**: `catalogo` inteira (14 tasks). `colecao`: T1, T2, T3, T4, T5,
  T6, T7, T8, T9, T10, **T11**. `colecao` Fase 1 (T1–T4) e **Fase 2 (T5–T8)** encerradas;
  `.context/tasks.md` §4.1, §4.2, §4.3 e **§4.4** fechados. A §4.2 cobria T5+T6+T7 e
  fechou na T7. A **§4.3 cobria T6+T8 e fechou na T8**, conferida bullet a
  bullet: "incremento e decremento em ação única, sem formulário" e "sem
  recarregar a página inteira" — a primeira metade é T6 (um `POST` por
  operação, sem `new`/`edit`) e a segunda é T8 (Turbo Stream que troca só o
  contêiner da variante); "quantidade zero equivale a não possuída" — T5, com
  os scopes `owned`/`unowned` e teste em `collection_item_test.rb`; "disponível
  tanto na grade quanto no detalhe, sempre por variante" — T8.
  A **§4.4 fechou na T11**, conferida bullet a bullet: ela cobre T9+T10+T11 e
  tem dois bullets. "Filtro *somente as que eu tenho* / *somente as que eu não
  tenho*, integrado ao query object da task 3.1" é a **T9** (parâmetro `owned`
  dentro do `CatalogQuery`, que é o query object da 3.1, com o usuário injetado
  pelo chamador) somada à **T10** (plano de execução medido, sem full table
  scan na tabela de coleção). "Total de cartas possuídas contando cópias" é a
  **T11** (`sum(:quantity)`, não `count`). **A §4.5 continua aberta**: wishlist
  (T12–T13).
  Detalhe do `catalogo`: 0.1, 0.2, 0.3, 1.1 (T1), 1.2 (T2), 2.1–2.7 (T3–T9),
  3.1 (T10), 3.2 (T11), 3.3 (T12), 3.4 (T13), 3.5 (T14). Verifier B1 + B2 PASS
  em `.specs/features/catalogo/validation.md` (B1 linhas 1–414, B2 a partir da
  419).
- **In-progress** (file:line): nenhum
- **Next step**: **Executar T12** de `.specs/features/colecao/tasks.md`
  (migração e model de `wishlist_items`, com as mesmas garantias de banco da
  coleção — `UNIQUE (user_id, card_variant_id)`, `CHECK (target_quantity >= 1)`
  e FK `restrict`). É a primeira task da feature que **cria migração**, então
  `schema_format = :sql` exige `db:migrate` para regenerar `db/structure.sql`.
  A decisão central segue de pé: **não rodar
  `bin/rails generate authentication`**.
- **O que a T11 entregou, e o que a T12/T13 herdam dela.** O total de cópias é
  `CollectionItem.total_copies_for(user)` — `for_user(user).owned.sum(:quantity)`
  —, no **model** e não no controller, porque tem dois chamadores: a grade do
  catálogo (`CatalogController#owned_total`, exibido pelo partial
  `catalog/_owned_total`) e o `turbo_stream` da posse, que o re-renderiza a
  cada "+1"/"−1". A wishlist vai querer um agregado parecido ("quantos itens
  atendidos"), e o lugar dele é o mesmo: model, com um chamador de view e um de
  Stream.
  - **`sum(:quantity)`, nunca `count`.** Cópias, não variantes distintas — esta
    última é a métrica do **Req. 9** (progresso por set), com denominador
    decidido em AD-003. O teste só discrimina os dois porque as quantidades
    semeadas são **diferentes de 1**; com uma cópia por variante os dois
    agregados dão o mesmo número. Vale para qualquer contagem futura.
  - **O scope `owned` é aritmeticamente redundante na soma e fica assim
    mesmo.** Removê-lo não matou teste nenhum (uma linha com zero soma zero).
    Ele é a definição de "possuída" do Req. 7.3 e é o que segura o número se
    alguém trocar a agregação. Não "limpar".
  - **O `authenticated?` dentro de `#owned_total` é redundante hoje e não deve
    ser removido.** `#index` já chama no topo desde a T9 e `#owned_quantities`
    chama de novo, então a mutação que o remove **sobrevive**. Removidas as
    três, porém, o resultado é "Sua coleção: 0 cópias" para usuário autenticado
    com a página em 200 — o defeito silencioso do
    `allow_unauthenticated_access` pela quarta vez na feature — e 7 testes
    morrem. A redundância existe para que uma reordenação futura de `#index`
    não reintroduza o defeito.
  - **O `turbo_stream` da posse agora tem QUATRO alvos**, não três: o contêiner
    da variante, `flash_notice`, `flash_alert` e **`catalog_owned_total`**. O
    quarto veio de um achado HIGH da revisão de a11y (SC 4.1.3): sem ele, um
    "+1" deixaria o total do topo no valor do carregamento enquanto a contagem
    da variante logo abaixo já mostraria o novo. Um `update` cujo alvo não está
    no DOM — o detalhe da carta não exibe o total — é **descartado em silêncio**
    pelo Turbo, então não há ramo condicional. Se a T13 acrescentar região de
    wishlist atualizável, é este o padrão.
  - **O total NÃO é região viva, e isso é decisão com teste.** Nada de
    `aria-live` nem `role="status"` nele: quem dispara a operação já recebe o
    anúncio específico da região viva da variante, e uma segunda região faria
    cada "+1" produzir duas falas. Mesmo raciocínio que separou `role="status"`
    de `role="alert"` no flash da T8. Acrescentar `aria-live` mata um teste.
  - **A correção proposta pelo revisor de a11y foi recusada em favor de uma
    melhor.** Ele sugeria qualificar o texto para "Sua coleção ao carregar esta
    página", isto é, descrever o defeito na cópia em vez de corrigi-lo — o
    usuário leria uma ressalva em toda visita para cobrir um caso que dura um
    clique. O alvo de Stream resolve a causa. Registro aqui porque o padrão
    vale para as próximas revisões: aceitar o **achado** não obriga a aceitar a
    **correção** proposta.
- **O que a T10 mediu, e por que não há índice novo.** A T10 fechou **sem
  migração**: o índice candidato que a T9 registrou — parcial,
  `collection_items (user_id, card_variant_id) WHERE quantity >= 1` — foi
  criado no banco de teste, medido com `EXPLAIN (ANALYZE, BUFFERS)` e
  **reprovado**. O planejador não o escolheu em cenário nenhum: continuou
  entrando por `index_collection_items_on_user_id` com `Filter: (quantity >=
  1)`, ao mesmo custo de **19.29**. Com usuário pesado (15.000 itens, 12.857
  possuídos) o custo total foi **2397.84 com** o índice contra **2404.20 sem**
  — 0,27%, sem troca de plano e com execução ligeiramente pior. A hipótese da
  T9 valia como descrição (a checagem de `quantity` é mesmo filtro de heap) e
  não como problema: o recorte por usuário já reduz o conjunto a centenas de
  linhas. **Não reabrir sem um padrão de acesso novo que a medição não cobriu.**
- **`collection_items` tem um piso de acesso indexado que o teste de plano não
  consegue derrubar, e isso está documentado de propósito.** Sensor da T10:
  derrubados os dois índices não-únicos, as asserções de plano **continuam
  verdes**, porque o planejador cai no índice do `UNIQUE (user_id,
  card_variant_id)`. Aquele índice é inseparável da unicidade criada em
  `20260919120200`. Por isso a existência dos índices é asserida em **teste
  separado**, e o cabeçalho de `test/queries/catalog_owned_plan_test.rb`
  explica isso — não é descuido, é propriedade do schema. O que as asserções de
  plano pegam é **forma de consulta não indexável**: a mutação `(user_id + 0)`
  produziu `Seq Scan on collection_items` a custo 6846 contra 19.29 e matou
  dois testes.
- **O planejador troca de índice conforme a seletividade do recorte de cartas,
  e a T11 herda esse fato se for medir plano.** Cor pouco seletiva (`Red`,
  19.960 de 20.000) → entra por `index_collection_items_on_user_id`, hash join,
  custo 2398. Cor muito seletiva (`Yellow`, 40) → **inverte o join**, dirige por
  `cards` e sonda `collection_items` por
  `index_collection_items_on_card_variant_id`, custo **1339** — mais barato.
  Asserção de plano que trava um nome de índice reprova o plano **melhor**;
  a da T10 aceita os três índices da tabela.
- **O que a T10 precisa saber sobre a forma da consulta que a T9 escreveu.** O
  filtro vive em `CatalogQuery#apply_ownership_filter` e a subconsulta em
  `#owned_variants_exists`. O SQL gerado, medido:

  ```sql
  -- owned
  SELECT cards.* FROM cards WHERE EXISTS (
    SELECT 1 FROM card_variants
    WHERE card_variants.card_id = cards.id
      AND card_variants.id IN (
        SELECT collection_items.card_variant_id FROM collection_items
        WHERE collection_items.user_id = $1 AND collection_items.quantity >= 1))
  -- missing: o mesmo, sob NOT (EXISTS (...)), combinado por AND com os demais filtros
  ```

  - **É semi-join duplo** (`cards` → `card_variants` → `collection_items`), e o
    `ecc:database-reviewer` mediu que o planejador **achata** tanto o `EXISTS`
    quanto o `IN` em semi/anti-join. **Reescrever o `IN` interno como `JOIN` não
    muda o plano** — não gastar a T10 tentando isso; o que pode mudar o plano é
    índice.
  - **O índice candidato já está identificado e deliberadamente NÃO foi criado
    na T9**: parcial,
    `collection_items (user_id, card_variant_id) WHERE quantity >= 1`. O
    `UNIQUE (user_id, card_variant_id)` existente localiza o usuário mas não
    filtra `quantity`, então a checagem de `quantity >= 1` volta à heap; o
    parcial permitiria Index Only Scan. **Medir antes de criar**: a tabela pode
    ser pequena o bastante para o Seq Scan ser a escolha certa, que é o cuidado
    de seletividade realista que o próprio "Done when" da T10 exige (o mesmo
    erro que a T4 do `catalogo` evitou semeando 20k cartas).
  - `index_card_variants_on_card_id` já existe e cobre o lado correlacionado;
    `card_variants.id` é PK. O revisor não pediu índice nenhum nessas duas.
  - A correlação usa `Card.arel_table[:id]`, **não** a tabela do escopo
    recebido — foi um achado HIGH do revisor, corrigido na T9. Não reverter para
    `scope.arel_table`: um alias no escopo faria a correlação apontar para a
    coluna errada sem erro de sintaxe.
  - **Se a T10 criar migração**, ela é aditiva e `schema_format = :sql` exige
    `db:migrate` para regenerar `db/structure.sql`.
- **A semântica de `owned`/`missing` é de partição, e a T11 herda isso.**
  `owned` = a carta tem ao menos uma variante possuída; `missing` = não tem
  nenhuma. `owned ∪ missing == all`, sem sobreposição, com teste que asserta a
  complementaridade. Isso **não** é "falta alguma variante" — sob aquela leitura
  os dois filtros se sobreporiam em 40,1% do catálogo (as cartas com mais de uma
  variante, medidas na T8). Completude por impressão é o **Req. 9**, com métrica
  própria e denominador de AD-003; não resolver aquilo aqui.
- **O usuário entra no `CatalogQuery` como segundo argumento POSICIONAL**
  (`CatalogQuery.new(params, Current.user)`), não nomeado, e a escolha não é
  estética: com `user:` nomeado, `CatalogQuery.new(colors: [ "Green" ])` — a
  forma dos 54 chamadores existentes — vira lista de keywords e a suíte estoura
  com `ArgumentError: unknown keyword: :colors`. Medido. Não trocar por keyword
  sem converter todos os chamadores.
- **`CatalogController#index` chama `authenticated?` antes de montar o query
  object**, pelo mesmo motivo de `#owned_quantities`: `allow_unauthenticated_access`
  não resolve a sessão, e sem a chamada o filtro sai **silenciosamente ignorado**
  para o usuário autenticado (200, catálogo inteiro, nenhum erro). Terceira vez
  que essa armadilha aparece na feature.
- **O que a T9 e a T11 precisam saber sobre a contagem de posse que a T8
  introduziu.** O `CatalogController` agora carrega, antes de renderizar, um
  hash `@owned_quantities` no formato `card_variant_id => quantity`, montado
  por `owned_quantities(variants)` — um `pluck` de conjunto sobre
  `CollectionItem.for_user(Current.user)`, uma consulta só, nas duas actions. O
  helper `owned_quantity(variant)` (`app/helpers/collection_helper.rb`) é o
  único ponto de leitura na view e devolve **zero** por default, inclusive para
  o anônimo (`for_user(nil)` é `none`).
  - **A T11 (total de cópias) não deve somar esse hash.** Ele cobre só as
    variantes da página corrente; o total do Req. 7.7 é sobre a coleção
    inteira e pede o seu próprio `sum(:quantity)` sobre
    `CollectionItem.for_user(Current.user).owned`.
  - **A T9 não precisa do hash e não deve passar por ele.** O filtro `owned`
    é consulta, não exibição: ele entra no `CatalogQuery` com o usuário
    **injetado pelo chamador**, e a semântica "zero é linha existente" já está
    nos scopes `owned`/`unowned` do model. O hash é camada de view.
  - **`allow_unauthenticated_access` NÃO resolve a sessão.** Ele remove o
    `before_action :require_authentication`, que era quem chamava
    `resume_session` — em um controller público, `Current.user` é `nil` na
    action até alguém chamar `authenticated?`. A T8 tropeçou nisso: o defeito
    é **silencioso** (200, controles na tela, posse zerada para quem está
    autenticado). `CatalogController#owned_quantities` chama `authenticated?`
    antes de ler `Current.user` por esse motivo. **Qualquer leitura de dado do
    usuário dentro de um controller público precisa fazer o mesmo.**
- **A T8 não desfez nada da T6 nem da T7, e o aviso continua valendo para a
  Fase 3.** O `ON CONFLICT` do incremento e o `UPDATE ... WHERE quantity > 0`
  do decremento estão **idênticos**; o usuário continua saindo de
  `Current.user` e o `WHERE user_id = $1` continua nos dois statements. O que a
  T8 mudou foi a **renderização da resposta**: `respond_to` com `format.html`
  (o `redirect_back` da T6, que é o caminho sem JavaScript) **primeiro** e
  `format.turbo_stream` depois.
- **O caminho sem JavaScript é requisito, não cortesia, e tem teste.** Os Edge
  Cases da spec exigem que incremento e decremento continuem funcionando por
  submissão normal. `button_to` gera `<form method="post">` de verdade com
  token CSRF; nada no controle depende de JS. Removido o `format.html`, cinco
  testes morrem — três deles da própria T6. **Não trocar `respond_to` por
  resposta única de Stream.**
- **`turbo_stream.update`, nunca `replace`, nos controles de posse e no flash.**
  `update` troca os filhos e preserva o elemento; `replace` troca o nó. Como a
  região `aria-live`/`role` mora no elemento alvo, `replace` a recriaria a cada
  operação — e uma região viva recém-inserida no DOM **não anuncia**. A
  mudança de quantidade passaria em silêncio para quem usa leitor de tela. Dois
  testes morrem se trocar.
- **Importmap instalado na T8, com Turbo e sem Stimulus.** `config/importmap.rb`
  pina `application` e `@hotwired/turbo-rails` → `turbo.js`, servido pelo
  Propshaft a partir da própria gem (sem download, sem `vendor/javascript` a
  versionar). `app/javascript/application.js` importa o Turbo e nada mais.
  **Stimulus não foi pinado de propósito**: não há nenhum controller Stimulus
  no projeto, e pinar o que não se usa carregaria JS em toda página para nada.
  O `javascript_importmap_tags` está no layout. O placeholder de imagem do
  catálogo **continua em CSS** e não deve ser trocado por JS agora que o
  importmap existe.
- **A rota por id de `collection_item` foi decidida na T7: não existe, e não
  vai existir na Fase 2.** As duas rotas continuam sendo
  `POST /collection_items/:card_variant_id/increment` e `.../decrement`: a
  chave é a **variante**, porque o botão "+1" sai da grade do catálogo, onde o
  registro de coleção normalmente ainda não existe. O critério da T7 "id de item
  de outro usuário devolve 404" pressupunha um desenho REST por id que a T6 não
  adotou; **decisão do orquestrador na T7: não acrescentar a rota**, porque o
  requisito de origem (Req. 6.5, *"Um usuário NUNCA DEVE conseguir ler ou
  alterar a coleção de outro usuário"*) não menciona 404 nem id, e é satisfeito
  **por construção** — não há id de item em URL nenhuma. Registrado como
  `SPEC_DEVIATION` no cabeçalho de
  `test/integration/collection_authorization_test.rb` e provado por teste: uma
  rota de `collection_items` com qualquer segmento que não seja
  `card_variant_id` quebra a suíte.
  - **A T13 herdou esse critério e precisa entregá-lo de verdade.** A wishlist
    tem remoção por item, logo id na URL: o "404 sem revelar existência" para
    item de outro usuário é teste real lá, e o "Done when" da T13 já o pede.
    O terreno está pronto — `for_user(Current.user)` é o único caminho de
    leitura, e uma busca por id dentro dele cai em `RecordNotFound` → 404 por
    construção, sem checagem de dono espalhada. **Não usar `find_by` + `if
    nil`**: isso devolveria 200 ou 403 e revelaria a existência.
- **A T7 não encontrou nenhum defeito de autorização, e o sensor explica por
  quê.** Três mutações confirmaram que o isolamento está onde parece estar:
  `Current.user.id` → `params[:user_id] || Current.user.id` mata 4 testes
  (inclusive um decremento cruzado real, 5 → 4); remover `WHERE user_id = $1`
  do decremento mata 2; acrescentar rota por id mata 1. **A T8 não pode
  desfazer nenhuma das duas cláusulas** ao trocar a resposta por Turbo Stream:
  o que muda é a renderização, não a origem do usuário nem o escopo do
  `WHERE`.
- **A T6 resolveu a corrida no banco, e a T8 não pode desfazer isso.** O
  incremento é `INSERT ... ON CONFLICT (user_id, card_variant_id) DO UPDATE SET
  quantity = collection_items.quantity + 1`; o decremento é
  `UPDATE ... WHERE ... AND quantity > 0`. Ler em Ruby e escrever depois
  (`item.update!(quantity: item.quantity + 1)`) perde uma das duas abas — é o
  *lost update* que o `ecc:database-reviewer` apontou na T5 como problema da
  camada de aplicação. Se a T8 reescrever a action para renderizar Turbo
  Stream, **manter os dois statements**: o que muda é a resposta, não a
  escrita.
- **O `redirect_back` da T6 não é provisório.** A T8 acrescenta Turbo Stream
  por cima, mas o redirect continua sendo o caminho sem JavaScript que os Edge
  Cases da spec exigem continuar funcionando — `respond_to` com `format.html`
  preservado, não substituído.
- **A T5 não precisou de migração, e a T6 também não deve precisar.** As três
  garantias de `collection_items` (`UNIQUE (user_id, card_variant_id)`,
  `CHECK (quantity >= 0)` e as duas FKs `restrict`) nasceram na migração
  `20260919120200`, na Fase 2 do `catalogo`. A T5 as **provou** contra o banco
  em `test/models/collection_item_test.rb`; não as criou. O piso de zero do
  Req. 7.4 já é do schema — o decremento da T6 não é a única coisa que o
  segura, e o teste do `UPDATE ... SET quantity = quantity - 1` direto está lá
  justamente para provar isso.
- **Zero é linha existente, não ausência de linha.** `CollectionItem.owned`
  filtra `quantity > 0`; `unowned` filtra `quantity = 0`. A T9 (filtro `owned`
  no `CatalogQuery`) herda essa semântica: "nunca teve" e "não tem mais"
  precisam continuar distinguíveis, senão o Req. 7.6 fica furado.
- **`rate_limit` é dívida aberta, não esquecimento.** A T4 decidiu **não**
  incluir a linha do template: sem cache store compartilhado ela não limita
  nada (teste é `:null_store`; produção cai em `:file_store` por container) e
  daria aparência de proteção contra força bruta. O login está **sem limite de
  tentativas** hoje. Reabrir junto com Redis ou `solid_cache` — é mudança de
  infraestrutura, com teste que exercite o limite de verdade. Justificativa
  completa no comentário de `app/controllers/sessions_controller.rb`. A
  revisão de segurança apontou que omitir o limite **e** o piso de senha
  deixaria o espaço de força bruta no menor denominador; o piso
  (`minimum: 8`) entrou na T4 por isso, e é a metade que não depende de
  infraestrutura.
- **As sondas de teste continuam de pé depois da T6, e continuam necessárias.**
  Tanto `authentication_test.rb` quanto `sessions_test.rb` definem um
  controller-sonda anônimo com rota desenhada no `setup`. A T6 entregou o
  `CollectionItemsController` e **não removeu nenhuma das duas**: elas cobrem o
  concern em si — o default herdado por uma action que não declara nada — e
  continuam sendo o único teste disso. O `CollectionItemsController` é um
  consumidor desse default, não um substituto do teste dele.
- **A sonda de teste da T3 não é código de produção.** Quando a T3 rodou não
  havia nenhuma action protegida no app, então
  `test/integration/authentication_test.rb` define um controller anônimo com
  rota desenhada no `setup`. Quando a T6 entregar o
  `CollectionItemsController`, a sonda continua válida como teste do concern em
  si — não removê-la achando que virou redundante: ela é o único teste que
  cobre o default herdado por uma action que **não declara nada**.
- **Achado da T1, já resolvido na própria T1**: `authenticate_by` resolve o
  usuário com `find_by(email:)`, que é **sensível à caixa**. O índice
  `index_users_on_lower_email` impede que duas grafias coexistam, mas não faz a
  busca casar — quem se cadastrasse como `sanji@` não entraria digitando
  `SANJI@`. Resolvido com `normalizes :email` no `User`, que normaliza tanto a
  escrita quanto o argumento nomeado das consultas
  (`activerecord-8.0.5.1/lib/active_record/normalization.rb:33`). A **T4** não
  precisa mais tratar caixa de e-mail.
- **Dívida registrada na revisão de segurança da T3** (`ecc:security-reviewer`,
  sem achado bloqueante): o cookie de sessão não declara `secure: true` no hash
  de opções de `start_new_session_for`. Em produção o middleware o marca, porque
  `config.force_ssl = true` — a garantia é **indireta**: um staging que não
  herde `production.rb`, ou o dia em que `force_ssl` for desligado, tira o
  `secure` sem que nenhum teste acuse. Fixar exige `secure: Rails.env.production?`
  (desenvolvimento e teste rodam em HTTP), que é decisão de política de cookie e
  não cabia na task que porta o concern. Ambos os pontos estão comentados em
  `app/controllers/concerns/authentication.rb`.
- **Blockers**: none
- **Uncommitted files**: none
- **Branch**: main

### Dívida conhecida ao fim da feature `catalogo`

Nada aqui bloqueia a Fase 4; são pontos que a próxima sessão herda com os olhos abertos.

- **CI verde no primeiro run real** (`35475280590`, 2026-09-19), remoto em `github.com/pinhaum/bindr-tcg`. O run expôs que o pin da major não pegava o `pg_dump` (era 16.15 com `psql` 17.11, porque o runner traz um client 16 e o `update-alternatives` só reassume o `psql`); corrigido pondo `/usr/lib/postgresql/17/bin` na frente do PATH, com step que falha o job se a major regredir. Confirmado 17.11 nos dois binários no run `35475533719`.
- **T12/T14 não têm cobertura de navegador.** Viraram teste de integração porque não há chromedriver no container (`SPEC_DEVIATION` registrado em cada uma). O 360px do Req. 2.5 foi verificado à mão em Chromium; uma regressão de layout passaria no CI. Decidir se vale chromedriver no `Dockerfile.dev`.
- ~~**Importmap não instalado.**~~ **RESOLVIDO na T8 da `colecao`**, que era onde esta dívida vencia. `bin/rails importmap:install` rodou, `config/importmap.rb` pina Turbo (e **não** Stimulus, que continua sem uso) e o layout carrega `javascript_importmap_tags`. O placeholder de imagem **continua em CSS**, de propósito: ele não precisa de JS e não deve passar a precisar só porque agora existe pipeline.
- **Três melhorias de a11y não bloqueantes**, da revisão do `ecc:a11y-architect`: `lang="en"` no conteúdo em inglês (nome, `effect_text`, `trigger_text`), `min-height/min-width: 24px` explícitos nos alvos de toque (SC 2.5.8) e reforço do indicador de foco (SC 2.4.11). **Os 24px e o indicador de foco valem para o código novo desde a T4, e a T8 nasceu com os dois** (`.ownership__button`, `.ownership__sign-in`, `.card-tile__variants-link`); continuam pendentes nos componentes **antigos** — chips de filtro e paginação. O `lang="en"` continua inteiramente aberto, e a T8 o propagou para um lugar novo: os `aria-label` dos botões de posse citam `card.name`, que é conteúdo em inglês dentro de frase em português.
- **Dívida nova da T8, duas, nenhuma bloqueante.** (1) **Plural em português é feito à mão**: o inflector do Rails é inglês e `"cópia".pluralize(2)` devolve `"cópia"` — o partial de posse resolve com um ternário, e a saída correta depende de ninguém trocá-lo por `pluralize`. Um `Inflector` em português resolveria para o app inteiro e é mudança de configuração global. (2) **Contraste do indicador de foco não verificado**: o `outline` usa `currentcolor` e o projeto **não declara nenhuma paleta** — as cores são as do navegador. O `ecc:a11y-architect` levantou como LOW não confirmado (SC 1.4.11) e não havia o que corrigir sem antes haver paleta. Reabrir junto com a primeira decisão de cor do projeto.
- **Flakiness observada uma vez:** `guarantees_test.rb` falhou uma vez em ~20 execuções por contenção entre os 4 workers paralelos (`last_seen_at` do presente menor que o do ausente). Se voltar, congelar o relógio — `Upsert` já aceita `clock:` — e **não** afrouxar a asserção.

### Contexto que não está nos documentos

- **Docker em WSL:** `~/.docker/config.json` tem `"credsStore": "desktop.exe"`, que não existe no PATH. Qualquer `docker compose` que precise puxar imagem falha com `docker-credential-desktop.exe: executable file not found`. Contorno documentado no README: `DOCKER_CONFIG` apontando para um config `{}` vazio. **Não editar o config global do usuário.**
- **`tmp/pids/server.pid` órfão impede o app de subir.** Se o container morre sem limpar o pid, `docker compose up app` reinicia e sai com `A server is already running (pid: 1)`. O serviço fica fora do ar sem erro óbvio. Correção: `rm -f tmp/pids/server.pid` e subir de novo. Aconteceu ao rodar smoke test na verificação do B2.
- **A rota do catálogo é `/catalog`, não `/cards`.** `/cards/:id` é a página de detalhe da carta. `root` aponta para `catalog#index`.
- **`RAILS_ENV` posicional NÃO é lido pelo `bin/rails`.** `bin/rails db:drop db:create RAILS_ENV=test` atinge o banco de **desenvolvimento** e apaga o catálogo da T9 — aconteceu na verificação do B1. Use `env RAILS_ENV=test bin/rails ...` (variável antes do comando) ou `bin/rails db:test:prepare`. Recuperação, sem rede: `REUSE_PAYLOAD=1 bin/rails ingestion:import`, a partir do payload fixado em `storage/ingestion/`.
- **O volume nomeado `bundle` sombreia as gems da imagem.** Mudar o `Gemfile` e reconstruir a imagem **não basta**: é preciso `docker compose run --rm --no-deps app bundle install` para a gem entrar no volume, senão o container sobe com `Bundler::GemNotFound`.
- **App renomeado à mão:** o projeto foi gerado fora do repo e nasceu como `railsgen`; o módulo é `Bindr` em `config/application.rb`. Se algo referenciar `railsgen`, é resíduo.
- **`--skip-solid` foi deliberado**, justificado em `.context/design.md` §2.
- **O gerador de autenticação NÃO foi executado.** A T8 criou `users` e `collection_items` mínimos (migração `20260919120200`) porque a invariante do Req. 1.7 não é demonstrável sem coleção. O fluxo de sessão/login continua sendo Fase 4 e deve usar o gerador, que criará `Session` e provavelmente vai querer ajustar `users`.
- `config/database.yml` lê tudo do ambiente; `POSTGRES_TEST_DB` é variável própria.
- Ao concluir qualquer task, marcar o checkbox **nos dois** planos e commitar junto com o código.
- `python3 spec/verify_fixture.py` roda offline e continua passando (12 verificações).
- Não adicionar linhas de atribuição em mensagens de commit.

### Decisões técnicas da Fase 2 que valem para a Fase 3

- **`schema_format = :sql`** (`db/structure.sql`, `db/schema.rb` removido). O índice trigram do nome depende da função `immutable_unaccent`, e o formato Ruby não representa funções — um banco criado a partir de `schema.rb` falhava ao recriar o índice. Migração nova exige `db:migrate` para regenerar `structure.sql`.
- **`unaccent` é STABLE**, nas duas assinaturas (medido no PostgreSQL 17.11). Não entra em índice de expressão nem em coluna gerada. Usar sempre o wrapper `immutable_unaccent(text)`, que a migração `20260919120100` cria. A busca por nome da **T11** depende disso.
- **`json` pinada em `~> 2.7`.** A 3.x removeu o argumento `quirks_mode` que o ActiveSupport 8.0.5.1 ainda passa; com ela **toda** escrita em coluna `jsonb` levanta `ArgumentError`. Soltar o pin só quando o Rails parar de passar esse argumento.
- **Nomes que divergem de `design.md` §3.2**, ambos por colisão com o Ruby/Rails e marcados com `SPEC_DEVIATION` no código: a coluna `attributes` virou **`attributes_list`** (`attributes` é método do Active Record) e o model `Set` virou **`CardSet`** (a tabela continua `sets`; `Set` é classe da stdlib).
- **Teste de plano de execução precisa de seletividade realista.** O teste da T4 semeia 20k cartas com cor e custo raros: com filtro pouco seletivo o planejador escolhe Seq Scan *com razão*, e o teste não distinguiria índice ausente de índice ignorado por custo. A T13 (latência) herda esse cuidado.
- **`Dockerfile.dev` instala `postgresql-client-17` do PGDG**, porque o `pg_dump` 15 do bookworm recusa dumpar um servidor 17 e quebraria `db:schema:dump`.

### Decisões técnicas da Fase 3 que valem para as próximas

- **O limiar do trigram exige transação explícita.** `set_config(..., true)` é
  `SET LOCAL`: vale até o fim da transação corrente. Fora de uma, cada
  statement é a sua própria e o limiar já reverteu quando a consulta roda — a
  busca por typo devolve **zero** em produção enquanto a suíte passa, porque o
  Rails envolve todo teste numa transação. `CatalogQuery#call` abre transação
  quando há termo de busca. O teste que pega isso é o único da suíte com
  `use_transactional_tests = false`; não remover.
- **`word_similarity` (`<%`), não `similarity` (`%`), limiar 0.5.** O par
  default do `pg_trgm` não atende o Req. 3.3: a similaridade da string inteira
  é diluída por partes do nome que o termo não tem. Medido em `design.md`
  §4.1.3.
- **Ramificações de busca se unem por `UNION`, não por `OR`.** Uma ramificação
  inindexável num `OR` derruba o plano indexado do predicado inteiro. Em
  `design.md` §4.1.2.
- **Match exato compara a coluna crua** (`card_number = ?`) com o termo já em
  maiúsculas pelo Ruby. `upper(card_number) = upper(?)` descarta o índice
  único — defeito só de latência, que nenhum teste funcional pega. Há teste de
  plano de execução para ele.
- **O placeholder de imagem não usa JavaScript.** O projeto não tem pipeline
  de JS: `app/javascript` e `config/importmap.rb` não existem, e
  `stimulus-rails` está no Gemfile sem nunca ter sido instalado. O placeholder
  é resolvido por camada de CSS (sempre renderizado, embaixo da imagem). Se a
  Fase 4 precisar de Hotwire para o incremento sem recarregar (Req. 7.2), o
  importmap precisa ser instalado então — não está feito.
- **Não há navegador no container**, logo não há system test. T12 e T14 estão
  marcadas `Tests: e2e` no plano e foram entregues como teste de integração
  sobre HTML renderizado, com `SPEC_DEVIATION` registrado em cada uma. Os
  360px e o lazy loading foram verificados à mão em Chromium do Playwright, no
  host. Fechar essa lacuna é mudança de `Dockerfile.dev`.
- **Migração nova na Fase 3:** `20260919120300_add_card_number_trigram_index`.
  É **aditiva** — só cria índice GIN trigram em `cards.card_number`, não toca
  tabela, coluna nem constraint do schema verificado na Fase 2.
- **Benchmark de latência é rake, não teste:**
  `bin/rails catalog:benchmark` (`lib/tasks/benchmark.rake`).

### Pendência aberta para o orquestrador

- **CI (`.github/workflows/ci.yml`) não foi alterado, por instrução.** Mas a T4 mudou o caminho do `db:prepare`: com `schema_format = :sql`, `bin/rails db:prepare` carrega `db/structure.sql` via `psql`, que precisa estar no runner **e** ser compatível com o Postgres 17 do serviço. O `ubuntu-latest` traz cliente PostgreSQL, mas a versão não está fixada. **Conferir antes de confiar no verde do CI.**
