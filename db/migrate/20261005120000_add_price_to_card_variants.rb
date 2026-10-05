# Preço atual da variante, conforme `.specs/features/precos/design.md` (Data
# Models). PRC-05, AD-022.
#
# Só o preço atual: cada import sobrescreve (decisão do dono em 2026-10-05).
# `numeric(10,2)` porque a apitcg entrega no máximo duas casas e o maior valor
# medido no snapshot de 2026-10-01 foi 13000.
class AddPriceToCardVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :card_variants, :price_amount, :decimal, precision: 10, scale: 2
    # ISO 4217. A moeda fica no registro para BRL entrar sem migrar dado (AD-022).
    add_column :card_variants, :price_currency, :text
    # O `started_at` do import que leu o preço; a fonte não traz data do preço.
    add_column :card_variants, :price_observed_at, :datetime

    # Tudo ou nada: um preço sem data seria exibido como atual, e um sem moeda
    # não teria como ser somado.
    add_check_constraint :card_variants,
                         "(price_amount IS NULL) = (price_currency IS NULL) " \
                         "AND (price_amount IS NULL) = (price_observed_at IS NULL)",
                         name: "card_variants_price_complete_check"
    add_check_constraint :card_variants, "price_amount >= 0", name: "card_variants_price_amount_check"
  end
end
