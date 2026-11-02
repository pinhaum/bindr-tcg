# Somar, tirar e escolher o Leader do deck (SDEC-51..55, SDEC-60). Mesmas
# regras e frases do `DeckEntriesController` HTML; o SQL atômico é de
# `DeckEntry.increment_for!`/`decrement_for!`. Sem `allow_unauthenticated_access`:
# o default do base exige sessão. O deck sai sempre de `Current.user.decks`.
#
# Regra de jogo nunca recusa gravação (DCK-18); recusa só a forma do modelo:
# Leader não é entrada e nenhuma entrada passa de 50.
class Api::DeckEntriesController < Api::BaseController
  before_action :set_deck, :set_card

  # Deck excluído entre o `find` e o `INSERT`: mesmo 404 do deck inexistente.
  rescue_from ActiveRecord::InvalidForeignKey do
    render_error(:not_found, "not_found", "Não encontrado.")
  end

  def increment
    return refuse("#{@card.card_number} é um Leader; use “Usar como Leader” em vez de somar cópias.") if leader_card?

    @quantity = DeckEntry.increment_for!(@deck, @card)
    return refuse("O máximo é #{DeckEntry::MAX_QUANTITY} cópias por carta no deck.") if @quantity.nil?

    render :quantity
  end

  # `nil` = sem entrada: `200` com zero, sem gravar (SDEC-52).
  def decrement
    @quantity = DeckEntry.decrement_for!(@deck, @card).to_i
    render :quantity
  end

  def leader
    return refuse("#{@card.card_number} não é um Leader; use “+” para somar cópias ao deck.") unless leader_card?

    @deck.update!(leader: @card)
  end

  private
    def set_deck
      @deck = Current.user.decks.find(params[:id])
    end

    # No Leader a carta vem do corpo; ausente ou que não é `String` é 404.
    def set_card
      card_number = params[:card_number]
      raise ActiveRecord::RecordNotFound, "card_number precisa ser um texto" unless card_number.is_a?(String)

      @card = Card.find_by!(card_number: card_number)
    end

    def leader_card?
      @card.card_type == "leader"
    end

    def refuse(message)
      render_error(:unprocessable_entity, "validation_failed", message)
    end
end
