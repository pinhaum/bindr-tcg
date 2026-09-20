# Quantidade possuída por variante, para a view, **sem uma consulta por tile**.
#
# O problema que este helper existe para resolver é N+1. A grade renderiza até
# 24 cartas por página e o detalhe lista todas as impressões de uma carta;
# perguntar a posse variante a variante (`CollectionItem.find_by(...)` dentro
# do loop) seria uma ida ao banco por controle renderizado. O controller
# carrega **um** hash `card_variant_id => quantity` antes de renderizar
# (`CatalogController#owned_quantities`) e este helper só o consulta.
#
# O default é zero, e não `nil`: "nunca teve" e "tem zero" são estados
# distintos no banco (a linha com `quantity = 0` existe e é o que o Req. 7.3
# manda preservar), mas para **exibir** os dois são a mesma coisa — o usuário
# não tem a carta. A distinção que importa é a do filtro, e ela vive nos
# scopes `owned`/`unowned` do model, não aqui.
#
# Anônimo cai no mesmo caminho: `@owned_quantities` é hash vazio e toda
# variante responde zero, sem consulta nenhuma e sem erro. O catálogo é
# público (Req. 6.3).
module CollectionHelper
  def owned_quantity(variant)
    return 0 if variant.nil?

    (@owned_quantities || {}).fetch(variant.id, 0)
  end
end
