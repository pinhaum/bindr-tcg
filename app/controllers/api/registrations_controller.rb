class Api::RegistrationsController < Api::BaseController
  allow_unauthenticated_access only: :create

  def create
    user = User.new(registration_params)

    if save_unique(user)
      start_new_session_for(user)
      render "api/sessions/show", locals: { user: user, csrf_token: csrf_token }, status: :created
    else
      render_error(:unprocessable_entity, "validation_failed", "Dados inválidos.", user.errors.to_hash)
    end
  end

  private
    # A checagem de unicidade da validação perde a corrida contra o índice:
    # o banco recusa e o resultado tem de ser o mesmo da validação.
    def save_unique(user)
      user.save
    rescue ActiveRecord::RecordNotUnique
      user.errors.add(:email, :taken)
      false
    end

    # `params.expect` responderia 400 para `user` ausente ou não-hash; aqui isso
    # é um cadastro vazio e cai na validação, como no contrato de erro.
    def registration_params
      user = params[:user]
      return {} unless user.is_a?(ActionController::Parameters)

      user.permit(:email, :password, :password_confirmation)
    end
end
