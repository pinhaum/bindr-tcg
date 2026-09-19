# Uma impressão física específica: arte base, parallel, promo. Mesmo
# `card_number` da carta, mesmo efeito, objeto de coleção diferente.
# A coleção do usuário referencia variantes, nunca cartas.
class CardVariant < ApplicationRecord
  belongs_to :card
  belongs_to :card_set, foreign_key: :set_id, inverse_of: :card_variants

  validates :variant_code, presence: true, uniqueness: { scope: :card_id }
end
