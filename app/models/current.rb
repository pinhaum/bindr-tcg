# Portada do template `current.rb.tt` de railties-8.0.5.1 (o gerador inteiro
# não roda neste projeto — ver o comentário em `app/models/user.rb`).
#
# É daqui que sai o `Current.user` que o Req. 6.5 exige: toda consulta de
# coleção e wishlist parte da sessão resolvida pelo cookie assinado, nunca de
# um id vindo do request. `allow_nil: true` mantém `Current.user` como `nil`
# para o anônimo do catálogo público, em vez de levantar erro.
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
