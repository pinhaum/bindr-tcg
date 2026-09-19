# A carta do jogo, identificada por `card_number` (design.md §3.1). É sobre ela
# que as regras e os textos falam. Uma impressão física é `CardVariant` — não
# colapsar as duas.
class Card < ApplicationRecord
  belongs_to :card_set, foreign_key: :set_id, inverse_of: :cards
  has_many :card_variants, dependent: :restrict_with_exception

  validates :card_number, presence: true, uniqueness: true
  validates :name, presence: true
end
