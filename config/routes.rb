Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

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

  root "catalog#index"
end
