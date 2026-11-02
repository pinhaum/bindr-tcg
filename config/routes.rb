Rails.application.routes.draw do
  # Fronteira fechada do Rails (STRO-08): `/up`, as imagens, as duas rotas de
  # arquivo, as URLs antigas, a `/api` e, por último, a entrada da SPA. Rota nova
  # de primeiro nível exige emenda do STRO-08 antes, para não engolir a SPA.

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Imagens das cartas, servidas pela aplicação em vez de hotlink (AD-012).
  # O `variant_code` é validado no controller antes de qualquer consulta.
  # Nenhum parâmetro do request entra na URL de saída — ela vem do banco.
  get "card_images/:variant_code" => "card_images#show", as: :card_image, format: false,
      constraints: { variant_code: /[^\/]+/ }

  # Downloads (STRO-16..19): URLs fixas fora de `/api`, com sessão exigida. O
  # arquivo é sempre o do usuário da sessão; nenhum identificador de usuário cabe
  # nestas URLs (Req. 6.5). `decks/:id.txt` vem antes de `decks/:id` das URLs
  # antigas, que o engoliria.
  get "collection/export" => "collection_exports#show", as: :collection_export
  get "decks/:id.txt" => "deck_exports#show", as: :deck_export, format: false

  # URLs antigas (STRO-11, STRO-12): só `GET`, destino calculado do caminho. Os
  # outros métodos não têm rota e dão 404 (STRO-15). `decks/new` e
  # `decks/import` vêm antes de `decks/:id`.
  %w[catalog cards/:id session/new registration/new progress wishlist
     collection/import collection/import/:token decks decks/new decks/import
     decks/:id decks/:id/edit decks/:id/delete].each do |path|
    get path => "legacy_redirects#show", format: false, constraints: { id: /[^\/]+/, token: /[^\/]+/ }
  end
  get "app(/*path)" => "legacy_redirects#show", format: false,
      constraints: ->(request) { !request.path.start_with?("/app/_app/") }

  # API JSON. `format: false` tira a extensão do caminho (`.html` cai no
  # catch-all) e o default fixa `params[:format]`, que vence o `Accept`. Rotas
  # novas da API entram acima do catch-all, que tem de ser a última.
  scope "api", module: :api, defaults: { format: :json }, format: false do
    resource :session, only: %i[show create destroy], as: :api_session
    resource :registration, only: :create, as: :api_registration

    # O ponto em `P.029` não pode virar formato: `format: false` do scope tira a
    # extensão e a constraint deixa o segmento casar tudo até a próxima barra.
    # `catalog/filters` (T11) entra logo abaixo, antes de qualquer rota com `:id`.
    get "catalog" => "catalog#index", as: :api_catalog
    get "catalog/filters" => "catalog#filters", as: :api_catalog_filters

    get "progress" => "progress#show", as: :api_progress
    get "wishlist" => "wishlist#index", as: :api_wishlist

    # Antes de `resources :decks`: depois dele, `import` e `shortfall` casariam
    # com `decks#show`.
    get "decks/shortfall" => "decks#shortfall", as: :api_decks_shortfall
    post "decks/import" => "deck_imports#create", as: :api_deck_imports

    # `as:` evita colidir com os nomes `decks` e `deck` das rotas HTML.
    resources :decks, only: %i[index show create update destroy], as: :api_decks do
      member { post :select }
    end

    # Entradas do deck (SDEC-51..55): o deck vai no caminho e a carta por
    # `card_number`; o Leader leva a carta no corpo.
    post "decks/:id/cards/:card_number/increment" => "deck_entries#increment",
         as: :api_increment_deck_card, constraints: { card_number: /[^\/]+/ }
    post "decks/:id/cards/:card_number/decrement" => "deck_entries#decrement",
         as: :api_decrement_deck_card, constraints: { card_number: /[^\/]+/ }
    put "decks/:id/leader" => "deck_entries#leader", as: :api_deck_leader

    get "cards/:card_number" => "cards#show", as: :api_card, constraints: { card_number: /[^\/]+/ }

    # Posse por variante (SCAR-42, SCAR-43). O `variant_code` tem `:` e chega
    # codificado (`tcgplayer%3A123`); a constraint aceita tudo até a próxima barra.
    post "cards/:card_number/variants/:variant_code/increment" => "card_variants#increment",
         as: :api_increment_card_variant,
         constraints: { card_number: /[^\/]+/, variant_code: /[^\/]+/ }
    post "cards/:card_number/variants/:variant_code/decrement" => "card_variants#decrement",
         as: :api_decrement_card_variant,
         constraints: { card_number: /[^\/]+/, variant_code: /[^\/]+/ }
    put "cards/:card_number/variants/:variant_code/wishlist" => "card_variants#wishlist",
        as: :api_wishlist_card_variant,
        constraints: { card_number: /[^\/]+/, variant_code: /[^\/]+/ }
    delete "cards/:card_number/variants/:variant_code/wishlist" => "card_variants#unwish",
           constraints: { card_number: /[^\/]+/, variant_code: /[^\/]+/ }

    post "collection/imports" => "collection_imports#create", as: :api_collection_imports
    get "collection/imports/:token" => "collection_imports#show", as: :api_collection_import,
        constraints: { token: /[^\/]+/ }
    post "collection/imports/:token/confirm" => "collection_imports#confirm",
         as: :confirm_api_collection_import, constraints: { token: /[^\/]+/ }

    # `*path` não casa `/api` nem `/api/`; sem esta linha eles cairiam na SPA.
    match "/", to: "not_found#show", via: :all
    match "*path", to: "not_found#show", via: :all
  end

  # Entrada da SPA na raiz (STRO-05) e fallback: qualquer `GET` fora das rotas
  # acima recebe `spa/200.html`, e os outros métodos caem no 404 do Rails. Tem de
  # ser a última rota. Os arquivos do build (`/_app/`, `/app/_app/`) nunca
  # devolvem a entrada.
  root "spa#show"
  get "*path", to: "spa#show", format: false,
      constraints: ->(request) { !request.path.start_with?("/_app/", "/app/_app/") }
end
