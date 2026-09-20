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

  root "catalog#index"
end
