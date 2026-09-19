# SPEC_DEVIATION: design.md §3.2 chama a entidade de `Set`.
# Reason: `Set` é classe da stdlib do Ruby e está sempre carregada; um model
# com esse nome não é resolvido pelo autoload e quebra na primeira referência
# (verificado). A tabela continua `sets`; só o nome da classe muda.
class CardSet < ApplicationRecord
  self.table_name = "sets"

  has_many :cards, foreign_key: :set_id, inverse_of: :card_set,
                   dependent: :restrict_with_exception
  has_many :card_variants, foreign_key: :set_id, inverse_of: :card_set,
                           dependent: :restrict_with_exception

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
