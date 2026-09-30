# Uma impressão física específica: arte base, parallel, promo. Mesmo
# `card_number` da carta, mesmo efeito, objeto de coleção diferente.
# A coleção do usuário referencia variantes, nunca cartas.
class CardVariant < ApplicationRecord
  belongs_to :card
  belongs_to :card_set, foreign_key: :set_id, inverse_of: :card_variants

  validates :variant_code, presence: true, uniqueness: { scope: :card_id }

  # "Presente na fonte" (SRC-16): vista pela última ingestão `succeeded`. O
  # Upsert grava em `last_seen_at` o `started_at` do run que viu a variante.
  # Sem run `succeeded`, a subconsulta dá NULL e nada é presente.
  scope :present, lambda {
    where("card_variants.last_seen_at >= (SELECT max(started_at) FROM import_runs WHERE status = 'succeeded')")
  }
end
