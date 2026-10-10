# Catch-all do escopo `/api`. Não muda estado, então dispensa CSRF; sem isso
# um `POST` desconhecido daria 422 antes do 404.
class Api::NotFoundController < Api::BaseController
  allow_unauthenticated_access
  skip_forgery_protection

  def show
    render_error(:not_found, "not_found", "Não encontrado.")
  end
end
