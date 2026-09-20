# Progresso de conclusão por set (Req. 9 / PRG-08, PRG-09).
#
# **Nenhuma declaração de acesso público, e isso é a decisão desta task.** O
# default de `ApplicationController` exige sessão em toda action (Req. 6.4), e
# é ele que atende PRG-09: o anônimo é redirecionado para a autenticação
# **antes** de a action rodar, então nenhum número chega ao corpo da resposta.
#
# Diferente do catálogo, a página não tem conteúdo público: sem usuário todo
# numerador é zero e a página inteira vira uma lista de zeros — um 200 sem
# informação, indistinguível de "não comecei nenhum set".
#
# Exigir sessão também fecha, por construção, a armadilha que apareceu cinco
# vezes na feature `colecao`: em controller público `allow_unauthenticated_access`
# remove o `before_action :require_authentication`, que era quem chamava
# `resume_session` — e ler `Current.user` sem antes chamar `authenticated?`
# responde **200 com tudo zerado, em silêncio**. Aqui o filtro resolve a sessão
# antes da action, e o defeito não tem como existir. Por isso
# `allow_unauthenticated_access` não deve ser acrescentado a este controller, e
# `authenticated?` não precisa ser chamado por reflexo como no
# `CatalogController#owned_quantities`.
class ProgressController < ApplicationController
  # `SetProgressQuery.new(Current.user)` é o único ponto de entrada, e ele
  # aceita o **objeto** `User` — nunca um id. A barreira é de tipo e mora em
  # `CollectionItem.for_user`, que levanta `ArgumentError` para qualquer outra
  # coisa. Consequência: `?user_id=7` não tem por onde entrar na consulta, e o
  # Req. 6.5 fica satisfeito por construção em vez de por verificação.
  #
  # A action não lê `params` em lugar nenhum: não há filtro, paginação nem
  # recorte a receber do request. A página inteira é uma consulta só, montada a
  # partir de quem está na sessão.
  def index
    @rows = SetProgressQuery.new(Current.user).call
  end
end
