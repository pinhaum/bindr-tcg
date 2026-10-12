# As URLs antigas (Hotwire e `/app/...`) levam `301` à rota equivalente da SPA
# na raiz (STRO-11, STRO-12). Nada aqui lê sessão nem banco (STRO-13): o destino
# sai só do caminho, e id, `card_number` ou token inexistente vira o 404 da tela
# da SPA, que consulta com a sessão.
#
# Direto de `ActionController::Base`, como o `SpaController`: sem `Authentication`
# e sem `allow_browser`. Só rotas `GET` apontam para cá; os outros métodos não têm
# rota e caem no 404 do Rails (STRO-15).
#
# `redirect_to` com string iniciada por `/` só prefixa protocolo e host, sem
# `URI.parse`, então a codificação do segmento e da query passa byte a byte
# (STRO-14).
#
# O caminho vem de `original_fullpath`: o roteador colapsa `//` em `/` antes da
# action, e `/app//evil.com` chegaria aqui como `/app/evil.com` em vez de ser
# recusado pelo `LegacyPath`.
class LegacyRedirectsController < ActionController::Base
  def show
    path = request.original_fullpath.partition("?").first
    destination = LegacyPath.destination(path, request.query_string)

    if destination
      redirect_to destination, status: :moved_permanently
    else
      head :not_found
    end
  end
end
