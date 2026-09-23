# Criar conta (Req. 6.1). Não vem do gerador do Rails, que só entrega entrar,
# sair e reset de senha — o cadastro é requisito daqui.
#
# Ao contrário do `SessionsController`, este formulário **precisa** dizer que o
# e-mail já está em uso: sem isso o usuário não tem como saber por que a conta
# não foi criada. Não é o mesmo vazamento da tela de entrar — quem tenta se
# cadastrar já está afirmando o endereço, e recusar em silêncio trocaria uma
# fuga de informação pequena por um formulário quebrado.
class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      # Cadastrar já autentica: exigir que o usuário digite de novo o que acabou
      # de escolher não protege nada.
      start_new_session_for(@user)
      redirect_to after_authentication_url, notice: "Conta criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    # `form_with model: @user` aninha os campos em `user[...]`. Ler os
    # parâmetros de topo aqui descarta tudo em silêncio e o cadastro recusa um
    # formulário preenchido como se estivesse em branco.
    def registration_params
      params.expect(user: %i[email password password_confirmation])
    end
end
