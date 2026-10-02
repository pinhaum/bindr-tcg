# Uma linha do deck principal: `(deck, carta, quantidade)`. O Leader não entra
# aqui, ele mora em `decks.leader_card_id`.
#
# `UNIQUE (deck_id, card_id)` e `CHECK (quantity BETWEEN 1 AND 50)` são do
# banco (`test/models/deck_schema_test.rb`). As validações repetem o limite
# para que o erro chegue em português em vez de `StatementInvalid`.
class DeckEntry < ApplicationRecord
  QUANTITY_RANGE = 1..50

  belongs_to :deck, inverse_of: :entries
  belongs_to :card

  validates :quantity, numericality: { only_integer: true, in: QUANTITY_RANGE,
                                       message: "deve ficar entre #{QUANTITY_RANGE.min} e #{QUANTITY_RANGE.max}" }

  # Não vira CHECK porque o Postgres não faz CHECK entre tabelas, e um trigger
  # só para isso custaria mais que esta validação somada ao controller que
  # recusa Leader no incremento (design.md, Data Models).
  validate :card_must_not_be_a_leader

  private

  def card_must_not_be_a_leader
    return unless card&.card_type == "leader"

    errors.add(:card, "Leader não entra no deck principal; use-o como Leader do deck")
  end
end
