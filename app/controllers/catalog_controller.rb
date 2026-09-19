# Grade do catálogo (Req. 2). O controller não conhece filtro nenhum: ele
# repassa os parâmetros crus ao `CatalogQuery`, que é o único lugar que traduz
# URL em consulta (design.md §4.2). Acrescentar um filtro novo não deve tocar
# este arquivo.
#
# Catálogo é público; qualquer mutação exigirá sessão (Fase 4).
class CatalogController < ApplicationController
  def index
    @query = CatalogQuery.new(params)
    @result = @query.call
  end

  def show
    @card = Card.includes(card_variants: :card_set).find_by!(card_number: params[:id])
    @variants = @card.card_variants.sort_by { |variant| variant.variant_code }
  end
end
