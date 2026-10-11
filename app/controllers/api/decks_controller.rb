# Leitura dos decks do usuário da sessão (SDEC-43, SDEC-47, SDEC-60). Sem
# `allow_unauthenticated_access`: o default do base exige sessão. O deck sai
# sempre de `Current.user.decks`, então o de outro usuário é `RecordNotFound`
# (404, igual ao id inexistente) e `user_id` do request nunca é lido.
class Api::DecksController < Api::BaseController
  include EditingDeck

  # Mesmo `includes` da lista HTML: o status de cada deck sai de `Deck#legality`
  # sobre entradas carregadas, em consultas fixas.
  def index
    @decks = Current.user.decks.includes(:leader, entries: :card).order(:name, :id)
  end

  def show
    detail = DeckDetail.new(user: Current.user, deck_id: params[:id]).call
    @deck = detail.deck
    @legality = detail.legality
    @absent_card_ids = detail.absent_card_ids
    @shortfall = detail.shortfall_by_card_id
    @editing = editing_deck&.id == @deck.id
  end
end
