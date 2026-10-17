# Importar uma lista do OPTCG Simulator num deck novo pela API (SDEC-46,
# SDEC-57, SDEC-58, SDEC-60). Mesmas regras do `DeckImportsController` HTML:
# importar sempre cria, tudo ou nada, e o deck nasce em `Current.user.decks`
# (`user_id` do corpo nunca é lido). Só `name` e `list` entram, e só como
# `String`: outro tipo vale como ausente.
class Api::DeckImportsController < Api::BaseController
  include EditingDeck

  REFUSED = "A lista não foi importada. Nenhum deck foi criado.".freeze

  def create
    result = Deck::ListText.parse(text_param(:list))
    return render_list_errors(result.errors) if result.errors.any?

    deck = Current.user.decks.new(name: text_param(:name).presence || result.leader&.name.to_s, leader: result.leader)
    result.entries.each { |card, quantity| deck.entries.build(card: card, quantity: quantity) }
    return render_name_errors(deck) unless deck.save

    start_editing(deck)
    detail = DeckDetail.new(user: Current.user, deck_id: deck.id).call
    @deck = detail.deck
    @legality = detail.legality
    @absent_card_ids = detail.absent_card_ids
    @shortfall = detail.shortfall_by_card_id
    @editing = true
    render "api/decks/show", status: :created
  end

  private
    def text_param(key)
      params[key].is_a?(String) ? params[key] : ""
    end

    def render_list_errors(errors)
      lines = errors.map { |error| error[:line] ? "Linha #{error[:line]}: #{error[:message]}" : error[:message] }
      render_error(:unprocessable_entity, "validation_failed", REFUSED, list: lines)
    end

    def render_name_errors(deck)
      messages = deck.errors[:name].map { |message| "O nome #{message}." }
      render_error(:unprocessable_entity, "validation_failed", "Dados inválidos.", name: messages)
    end
end
