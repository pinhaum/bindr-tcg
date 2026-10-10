class Api::RegistrationsController < Api::BaseController
  allow_unauthenticated_access only: :create

  def create
    user = User.new(registration_params)

    if user.save
      start_new_session_for(user)
      render "api/sessions/show", locals: { user: user, csrf_token: csrf_token }, status: :created
    else
      render_error(:unprocessable_entity, "validation_failed", "Dados inválidos.", user.errors.to_hash)
    end
  end

  private
    # `params.expect` responderia 400 para `user` ausente ou não-hash; aqui isso
    # é um cadastro vazio e cai na validação, como no contrato de erro.
    def registration_params
      user = params[:user]
      return {} unless user.is_a?(ActionController::Parameters)

      user.permit(:email, :password, :password_confirmation)
    end
end
