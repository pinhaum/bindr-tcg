# Grade do catálogo (Req. 2). O controller não conhece filtro nenhum: ele
# repassa os parâmetros crus ao `CatalogQuery`, que é o único lugar que traduz
# URL em consulta (design.md §4.2). Acrescentar um filtro novo não deve tocar
# este arquivo.
#
# Catálogo é público (Req. 6.3), e é a única exceção ao default de
# `ApplicationController`, que exige sessão em toda action. A liberação é
# declarada aqui, na classe, e não por rota: um filtro novo ou uma action nova
# deste controller herdam o acesso público sem precisar lembrar de nada. Toda
# mutação continua exigindo sessão porque vive em outro controller.
class CatalogController < ApplicationController
  allow_unauthenticated_access

  def index
    @query = CatalogQuery.new(params)
    @result = @query.call
  end

  def show
    @card = Card.includes(card_variants: :card_set).find_by!(card_number: params[:id])
    @variants = @card.card_variants.sort_by { |variant| variant.variant_code }
  end
end
