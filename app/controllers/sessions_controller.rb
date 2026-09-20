# Entrar e sair. Portado à mão do template `sessions_controller.rb.tt` de
# railties-8.0.5.1, com três mudanças deliberadas em relação ao original.
#
# 1. **`email`, não `email_address`.** A coluna deste projeto é `email`
#    (migração `20260919120200`, índice `index_users_on_lower_email`).
#    `authenticate_by` particiona os argumentos por `has_attribute?`
#    (`activerecord-8.0.5.1/lib/active_record/secure_password.rb:41`), então o
#    nome da coluna não precisa de adaptação nenhuma.
#
# 2. **Sem `rate_limit`.** O template traz
#    `rate_limit to: 10, within: 3.minutes`, e a T4 exige decidir em vez de
#    copiar. Ele depende de um cache store compartilhado, que este projeto não
#    tem: em teste o store é `:null_store` (`config/environments/test.rb:23`),
#    que não conta nada — um teste do limite passaria sem exercitar coisa
#    alguma; em produção `config.cache_store` está **comentado**
#    (`config/environments/production.rb:50`) e o default é `:file_store` em
#    `tmp/cache/`, que é por container e evapora no recreate. Com mais de um
#    container, cada um contaria seu próprio limite. Incluir a linha daria a
#    aparência de proteção contra força bruta sem a proteção — e sem teste que
#    denuncie a diferença. Entra junto com um cache store real (Redis ou
#    `solid_cache`), que é mudança de infraestrutura, não desta task.
#
# 3. **Mensagens em português** (Req. 6.6), e a de credencial errada é a mesma
#    para e-mail inexistente e senha errada: distinguir as duas transformaria o
#    formulário em oráculo de quais e-mails têm conta.
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
  end

  def create
    if (user = User.authenticate_by(params.permit(:email, :password)))
      start_new_session_for(user)
      # `after_authentication_url` devolve a página que o anônimo tentou abrir
      # antes de ser barrado pelo concern, ou a raiz. É o que fecha o Req. 6.4:
      # ser barrado não pode custar o destino ao usuário.
      redirect_to after_authentication_url
    else
      # `unprocessable_entity` e não redirect: o formulário é reapresentado com
      # o que foi digitado, e o Turbo só troca o corpo da página num 4xx.
      flash.now[:alert] = "E-mail ou senha inválidos."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: "Sessão encerrada."
  end
end
