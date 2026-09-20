Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # A carta é identificada pelo `card_number` na URL, não pelo id: é o
  # identificador que o usuário conhece e o que torna a URL compartilhável.
  # O ponto em códigos como `P-029` exigiria `format: false`; os códigos reais
  # do catálogo não têm ponto, mas a constraint fixa isso.
  get "cards/:id" => "catalog#show", as: :card, constraints: { id: /[^\/]+/ }
  get "catalog" => "catalog#index", as: :catalog

  # Só a rota, na T3: o concern `Authentication` redireciona o anônimo para
  # `new_session_path`, e um helper inexistente seria `NameError` em tempo de
  # requisição em vez de redirect. O `SessionsController` que a atende é a T4 —
  # esta declaração é o contrato entre as duas tasks, e a T4 não precisa mexer
  # em rota.
  resource :session, only: %i[new create destroy]

  root "catalog#index"
end
