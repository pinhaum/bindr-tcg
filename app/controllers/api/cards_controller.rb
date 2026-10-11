class Api::CardsController < Api::BaseController
  include EditingDeck

  allow_unauthenticated_access

  def show
    @detail = CardDetail.new(card_number: params[:card_number], user: Current.user,
                             requested_variant: params[:variant]).call
    @editing_deck_payload = editing_deck_payload(@detail.card)
  end

  private
    def editing_deck_payload(card)
      return unless editing_deck

      { id: editing_deck.id, name: editing_deck.name,
        quantity: editing_deck.entries.where(card_id: card.id).pick(:quantity).to_i,
        is_leader: editing_deck.leader_card_id == card.id }
    end
end
