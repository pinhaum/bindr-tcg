# Quantas cópias de uma **variante** o usuário possui. Referencia variante, e
# não carta: a arte base e a alternativa são objetos de coleção distintos
# (design.md §3.1).
class CollectionItem < ApplicationRecord
  belongs_to :user
  belongs_to :card_variant

  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :card_variant_id, uniqueness: { scope: :user_id }
end
