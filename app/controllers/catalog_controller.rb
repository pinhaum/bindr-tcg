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
  include EditingDeck

  allow_unauthenticated_access

  def index
    # O usuário do filtro de posse (Req. 7.6 / COL-11) vai por argumento
    # próprio, separado de `params`: o query object não tem caminho de `params`
    # para o usuário, então `?owned=owned&user_id=7` não lê a coleção de
    # ninguém. `authenticated?` antes, pelo mesmo motivo de
    # `VariantHoldings` — `allow_unauthenticated_access` não resolve a sessão,
    # e sem esta chamada `Current.user` seria `nil` aqui e o filtro sairia
    # silenciosamente ignorado para quem está autenticado.
    authenticated?

    @query = CatalogQuery.new(params, Current.user)
    @result = @query.call
    @filter_options = CatalogQuery.filter_options

    # Só as variantes presentes na fonte (SRC-16); o `preload` fica no `Card`.
    Card.preload_present_variants(@result.records)

    @owned_quantities = VariantHoldings.new(Current.user, @result.records.flat_map(&:card_variants)).owned_quantities
  end

  # SRC-16/SRC-17 — as regras do detalhe vivem em `CardDetail`. Carta cujas
  # variantes ficaram todas ocultas é 404 (`RecordNotFound`).
  #
  # `authenticated?` uma vez, no topo: `allow_unauthenticated_access` não
  # resolve a sessão, e sem isto `Current.user` seria `nil` e o usuário
  # autenticado veria posse zero e "Quero esta" em tudo, com a página em 200.
  def show
    authenticated?

    detail = CardDetail.new(card_number: params[:id], user: Current.user, requested_variant: params[:variant]).call
    @card = detail.card
    @variants = detail.variants
    @absent_variant_ids = detail.absent_variant_ids
    @hero = detail.featured_variant
    @owned_quantities = detail.holdings.owned_quantities
    @wishlist_targets = detail.holdings.wishlist_targets
    @editing_deck_quantity = editing_deck_quantity
  end

  private
    # DCK-03 — a quantidade desta carta no deck em edição, numa consulta, ou
    # `nil` sem deck em edição. `editing_deck` chama `authenticated?` antes de
    # ler `Current.user` (ver o concern): este controller é público, e sem isso
    # o controle de deck sumiria calado para quem está logado.
    def editing_deck_quantity
      return unless editing_deck

      editing_deck.entries.where(card_id: @card.id).pick(:quantity).to_i
    end
end
