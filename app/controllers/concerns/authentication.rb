# Portado à mão do template `authentication.rb.tt` de railties-8.0.5.1. O
# gerador `bin/rails generate authentication` não roda neste projeto: ele
# sobrescreveria `app/models/user.rb` e apagaria em silêncio o
# `dependent: :restrict_with_exception` que protege a coleção (ver o comentário
# no model).
#
# O concern inverte o default do app: incluído em `ApplicationController`, ele
# torna **exigir sessão** a regra e liberar o acesso a exceção declarada. É o
# que satisfaz o Req. 6.4 por construção — uma action nova nasce protegida, e
# esquecer de protegê-la é impossível; o que se pode esquecer é liberá-la, e
# isso aparece como 302 no teste, não como vazamento.
#
# O catálogo é a exceção (Req. 6.3) e a declara com `allow_unauthenticated_access`.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    # A sessão vem **sempre** do cookie assinado, nunca de `params`. Um id de
    # sessão aceito do request seria personificação direta; o cookie assinado
    # é verificado com `secret_key_base` e não é forjável pelo cliente.
    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    # Só os downloads (`/collection/export`, `/decks/<id>.txt`) chegam aqui; a
    # tela de entrada é da SPA e leva o destino em `return_to` (STRO-19). O
    # caminho vai codificado por inteiro (`/` vira `%2F`), query inclusive.
    def request_authentication
      redirect_to "/entrar?return_to=#{ERB::Util.url_encode(request.fullpath)}"
    end

    # Duas propriedades do cookie são herdadas do template e ficam registradas
    # aqui porque este arquivo fixa a política de sessão do app inteiro
    # (revisão de segurança da T3):
    #
    # 1. **`secure` não é explícito.** Em produção ele é aplicado pelo
    #    middleware, porque `config.force_ssl = true`
    #    (`config/environments/production.rb:31`) — a garantia é indireta, não
    #    local. Fixá-la aqui exigiria `secure: Rails.env.production?`, já que
    #    desenvolvimento e teste rodam em HTTP; é decisão de política de cookie,
    #    não desta task, e está registrada como dívida em `STATE.md`.
    # 2. **`permanent` dá validade de 20 anos ao cookie**, sem expiração por
    #    inatividade. A revogação existe e é do servidor: `terminate_session`
    #    apaga o registro, e um cookie órfão deixa de resolver sessão nenhuma.
    #
    # `reset_session` ao autenticar troca o id da sessão do Rails (fixação) e
    # descarta o que ela carregava antes. Ao sair, o mesmo reset impede que o
    # próximo login no navegador herde a sessão da conta anterior.
    def start_new_session_for(user)
      reset_session

      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
      reset_session
    end
end
