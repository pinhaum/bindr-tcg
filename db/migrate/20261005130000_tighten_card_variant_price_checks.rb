# Achados da revisão de banco da `precos` (T1, T6), PRC-05 e AD-022.
#
# 1. A moeda é código ISO 4217. Sem formato, um "usd" ficaria fora da soma em
#    USD da pasta e também fora das "cópias sem preço", sumindo sem aviso.
# 2. `NaN >= 0` é verdadeiro no `numeric` do Postgres, e um NaN contaminaria a
#    soma do set inteiro.
class TightenCardVariantPriceChecks < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :card_variants, "price_currency ~ '^[A-Z]{3}$'",
                         name: "card_variants_price_currency_check"
    add_check_constraint :card_variants, "price_amount <> 'NaN'",
                         name: "card_variants_price_amount_not_nan_check"
  end
end
