Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Imagens das cartas, servidas pela aplicação em vez de hotlink (AD-012).
  # O `variant_code` é validado no controller antes de qualquer consulta.
  # Nenhum parâmetro do request entra na URL de saída — ela vem do banco.
  get "card_images/:variant_code" => "card_images#show", as: :card_image, format: false,
      constraints: { variant_code: /[^\/]+/ }

  # A carta é identificada pelo `card_number` na URL, não pelo id: é o
  # identificador que o usuário conhece e o que torna a URL compartilhável.
  # O ponto em códigos como `P-029` exigiria `format: false`; os códigos reais
  # do catálogo não têm ponto, mas a constraint fixa isso.
  get "cards/:id" => "catalog#show", as: :card, constraints: { id: /[^\/]+/ }
  get "catalog" => "catalog#index", as: :catalog

  # Declarada na T3, antes do controller existir: o concern redireciona o
  # anônimo para `new_session_path`, e um helper inexistente seria `NameError`
  # em tempo de requisição em vez de redirect. A T4 preencheu o controller.
  resource :session, only: %i[new create destroy]

  # Singular como a sessão: não há o que listar nem id a exibir — o usuário cria
  # a própria conta e pronto.
  resource :registration, only: %i[new create]

  # Posse por variante (Req. 7.2). A chave da URL é a **variante**, não o id do
  # registro de coleção: o botão sai da grade do catálogo, onde o registro
  # normalmente ainda não existe. O usuário nunca aparece aqui — vem de
  # `Current.user` (Req. 6.5).
  #
  # `POST` e não `PATCH` porque a operação cria o registro quando ele falta; e
  # duas rotas distintas em vez de uma com `?operation=` porque incremento e
  # decremento são verbos diferentes, cada um com o seu statement.
  post "collection_items/:card_variant_id/increment" => "collection_items#increment",
       as: :increment_collection_item
  post "collection_items/:card_variant_id/decrement" => "collection_items#decrement",
       as: :decrement_collection_item

  # Wishlist (Req. 8). Ao contrário da posse, aqui **existe id de item na URL**:
  # remover parte da própria lista, onde o item existe por definição. É o que
  # torna real o 404 por id alheio do critério 4 da história de isolamento — a
  # T7 registrou `SPEC_DEVIATION` por não ter, no desenho da posse, nenhuma URL
  # onde um id coubesse.
  #
  # `path: "wishlist"` porque é o nome que o usuário lê na barra de endereço;
  # os helpers continuam `wishlist_items_path`, alinhados ao model e ao
  # controller. `create` continua recebendo `card_variant_id` no corpo: o
  # usuário nunca aparece na URL, vem de `Current.user` (Req. 6.5).
  resources :wishlist_items, only: %i[index create destroy], path: "wishlist"

  # Progresso por set (Req. 9). Rota singular e sem id: a página é sempre a do
  # usuário da sessão, e não há coleção de "progressos" a listar nem recorte a
  # endereçar. **Nenhum identificador de usuário cabe nesta URL** — quem
  # calcula é `Current.user`, e é isso que torna `?user_id=` inócuo por desenho
  # e não por checagem (Req. 6.5).
  #
  # `get` puro em vez de `resource`: só existe leitura, e `resource :progress`
  # geraria `new`/`edit`/`create` que nunca serão escritos.
  get "progress" => "progress#index", as: :progress

  # Export da coleção em CSV (Req. 10 / POR-03). Mesmo desenho do progresso e
  # pela mesma razão: rota singular, sem id, porque o arquivo é sempre o do
  # usuário da sessão. **Nenhum identificador de usuário cabe nesta URL** — quem
  # serializa é `Current.user`, e é isso que torna `?user_id=` inócuo por
  # desenho e não por checagem (Req. 6.5).
  #
  # `get` puro em vez de `resources`: o export é uma leitura só, e
  # `resources :collection_exports` geraria `show` com `:id` — exatamente o
  # segmento que não pode existir aqui.
  get "collection/export" => "collection_exports#show", as: :collection_export

  # Import da coleção em CSV (Req. 10 / POR-07, POR-12). **Nenhum identificador
  # de usuário cabe nestas URLs**, pela mesma razão do export e do progresso: o
  # dono da pré-visualização é sempre `Current.user`, e é isso que torna
  # `?user_id=` inócuo por desenho e não por checagem (Req. 6.5).
  #
  # O único segmento dinâmico é o **token** da pré-visualização — 32 bytes
  # urlsafe gerados pela T11 —, e ele não identifica usuário nenhum: é um
  # segredo por upload, resolvido sempre dentro do escopo do dono por
  # `CollectionImport.find_by_token_for`. Um id sequencial aqui deixaria a
  # pré-visualização alheia a uma tentativa de distância; o token deixa a URL
  # endereçável (é para ela que o upload redireciona) sem deixá-la adivinhável.
  #
  # `get`/`post` explícitos em vez de `resources`: o recurso não tem `edit`,
  # `update` nem `destroy`, e `resources` geraria `:id` — exatamente o segmento
  # que não pode existir. A confirmação (T14) entra aqui como uma rota própria,
  # também chaveada pelo token.
  # Os três nomes são declarados à mão, e nenhum deles pode ser omitido: sem
  # `as:` no `post`, o Rails deriva `collection_import` do caminho e ele colide
  # com o nome do `show` — `ArgumentError` na carga das rotas, que aparece como
  # `root_url` indefinido em todo teste que faz login, bem longe da causa.
  get "collection/import" => "collection_imports#new", as: :new_collection_import
  post "collection/import" => "collection_imports#create", as: :collection_imports
  get "collection/import/:token" => "collection_imports#show", as: :collection_import

  # A confirmação (T14) — a **única escrita** da feature. `post` e não `get`
  # porque ela altera estado, e a tela da T13 chega aqui por `form_with`: um
  # `get` deixaria a gravação a um prefetch ou a um histórico de navegador de
  # distância, sobre o único dado insubstituível do sistema.
  #
  # Chaveada pelo mesmo token do `show`, e por nada mais: a rota **não aceita
  # arquivo nem identificador de usuário**. O que é gravado vem do staging que
  # a tela mostrou (Req. 10.5), e o dono é sempre `Current.user`.
  post "collection/import/:token/confirm" => "collection_imports#confirm",
       as: :confirm_collection_import

  root "catalog#index"
end
