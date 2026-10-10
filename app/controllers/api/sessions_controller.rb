class Api::SessionsController < Api::BaseController
  allow_unauthenticated_access only: %i[show create]

  def show
    render_session Current.user
  end

  def create
    user = User.authenticate_by(email: params[:email].to_s, password: params[:password].to_s)
    return render_error(:unauthorized, "invalid_credentials", "E-mail ou senha inválidos.") unless user

    start_new_session_for(user)
    render_session user
  end

  def destroy
    terminate_session
    render_session nil
  end

  private
    # O token é lido aqui, depois de `start_new_session_for`/`terminate_session`:
    # o `reset_session` deles invalida o anterior e este já é o novo.
    def render_session(user)
      render :show, locals: { user: user, csrf_token: csrf_token }
    end
end
