# Dono do contrato de acesso e de erro de toda a `/api`: sempre JSON, nunca
# redirect nem HTML. Irmão de `ApplicationController`, não filho — herdar
# traria o `allow_browser` do HTML como segundo `before_action`.
class Api::BaseController < ActionController::Base
  include Authentication

  # Resolve a sessão em toda action, inclusive nas públicas: sem isso,
  # `Current.user` fica nil num endpoint público e a posse some com 200.
  before_action :resume_session
  around_action :use_api_locale

  allow_browser versions: :modern, block: -> {
    render_error(:not_acceptable, "unsupported_browser",
                 "Navegador não suportado. Atualize para uma versão recente.")
  }

  # A de menor precedência vem primeiro: o Rails procura do último handler
  # declarado para o primeiro.
  rescue_from StandardError do |error|
    Rails.error.report(error, handled: true, severity: :error)
    Rails.logger.error("[api] #{error.class}: #{error.message}\n#{error.backtrace&.first(5)&.join("\n")}")
    render_error(:internal_server_error, "internal_error", "Erro inesperado. Tente novamente.")
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    render_error(:unprocessable_entity, "invalid_csrf_token", "Token de segurança inválido.")
  end
  rescue_from ActiveRecord::RecordNotFound do
    render_error(:not_found, "not_found", "Não encontrado.")
  end
  rescue_from ActionController::ParameterMissing do
    render_error(:bad_request, "bad_request", "Requisição inválida.")
  end
  rescue_from ActionController::UnknownFormat do
    render_error(:not_acceptable, "not_acceptable", "Formato não suportado.")
  end
  rescue_from ActionDispatch::Http::Parameters::ParseError do
    render_error(:bad_request, "invalid_json", "Requisição inválida.")
  end

  private
    def render_error(status, code, message, fields = {})
      render json: { error: { code: code, message: message, fields: fields } }, status: status
    end

    def use_api_locale(&)
      I18n.with_locale(:"pt-BR", &)
    end

    # Sem `session[:return_to_after_authenticating]` nem redirect: a SPA
    # decide para onde ir depois do login.
    def request_authentication
      render_error(:unauthorized, "unauthenticated", "Faça login para continuar.")
    end

    def csrf_token
      form_authenticity_token
    end
end
