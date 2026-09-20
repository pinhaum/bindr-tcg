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

    # `preload` e não `includes`: o `CatalogQuery` monta a página em Ruby (o
    # match exato é prependido a um array), então o que chega aqui é um Array
    # de `Card`, não uma relação. `preload` aceita o array e resolve as
    # variantes em **uma** consulta. Sem isto, o tile dispararia uma consulta
    # por carta só para descobrir quantas impressões ela tem.
    ActiveRecord::Associations::Preloader.new(
      records: @result.records, associations: :card_variants
    ).call

    @owned_quantities = owned_quantities(@result.records.flat_map(&:card_variants))
  end

  def show
    @card = Card.includes(card_variants: :card_set).find_by!(card_number: params[:id])
    @variants = @card.card_variants.sort_by { |variant| variant.variant_code }
    @owned_quantities = owned_quantities(@variants)
  end

  private
    # Um hash `card_variant_id => quantity` para as variantes desta página, em
    # **uma** consulta (Req. 5.3 / COL-18: o controle aparece por variante, na
    # grade e no detalhe — perguntar a posse variante a variante seria N+1).
    #
    # A consulta parte de `CollectionItem.for_user(Current.user)` e de mais
    # nada: o usuário vem da sessão, nunca do request (Req. 6.5). Para o
    # anônimo, `for_user(nil)` é `none` e o resultado é hash vazio — sem
    # consulta ao banco e sem ramo especial aqui.
    #
    # `authenticated?` **antes** de ler `Current.user`, e isso não é cerimônia.
    # Este controller declara `allow_unauthenticated_access`, que remove o
    # `before_action :require_authentication` — e era ele que resolvia a sessão
    # a partir do cookie assinado. Sem esta chamada, `Current.session` ainda é
    # `nil` aqui e **todo usuário autenticado veria quantidade zero**, porque a
    # sessão só seria resolvida mais tarde, quando a view chamasse
    # `authenticated?` para decidir se mostra os botões. O defeito é silencioso:
    # a página responde 200, os controles aparecem e a posse some.
    #
    # `resume_session` é idempotente (`Current.session ||= ...`), então a
    # chamada da view não repete a consulta.
    def owned_quantities(variants)
      authenticated?

      CollectionItem.for_user(Current.user)
                    .where(card_variant_id: variants.map(&:id))
                    .pluck(:card_variant_id, :quantity)
                    .to_h
    end
end
