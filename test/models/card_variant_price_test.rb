require "test_helper"

# T1 (precos) — PRC-05: o preço da variante é valor, moeda e data juntos, ou
# nada. A garantia é do banco, não do model: um preço sem data seria exibido
# como atual, e um sem moeda não teria como ser somado (AD-022).
class CardVariantPriceTest < ActiveSupport::TestCase
  setup do
    set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    card = Card.create!(set_id: set.id, card_number: "OP01-001", name: "Roronoa Zoro",
                        card_type: "leader", colors: [ "Red" ])
    @variant = CardVariant.create!(card: card, set_id: set.id, variant_code: "tcgplayer:1", art_kind: "base")
    @observed_at = Time.utc(2026, 10, 1, 23, 16)
  end

  def write_price!(amount:, currency:, observed_at:)
    @variant.update_columns(price_amount: amount, price_currency: currency, price_observed_at: observed_at)
  end

  test "sem preço, os três campos ficam nulos" do
    assert_nil @variant.reload.price_amount
    assert_nil @variant.price_currency
    assert_nil @variant.price_observed_at
  end

  test "valor, moeda e data juntos gravam" do
    write_price!(amount: BigDecimal("1.7"), currency: "USD", observed_at: @observed_at)

    @variant.reload
    assert_equal BigDecimal("1.70"), @variant.price_amount
    assert_equal "USD", @variant.price_currency
    assert_equal @observed_at, @variant.price_observed_at
  end

  test "preço zero grava e é distinto de sem preço" do
    write_price!(amount: 0, currency: "USD", observed_at: @observed_at)

    assert_equal BigDecimal("0"), @variant.reload.price_amount
  end

  test "valor sem moeda é recusado pelo banco" do
    assert_raises(ActiveRecord::StatementInvalid) do
      write_price!(amount: 1, currency: nil, observed_at: @observed_at)
    end
  end

  test "valor sem data é recusado pelo banco" do
    assert_raises(ActiveRecord::StatementInvalid) do
      write_price!(amount: 1, currency: "USD", observed_at: nil)
    end
  end

  test "moeda e data sem valor são recusadas pelo banco" do
    assert_raises(ActiveRecord::StatementInvalid) do
      write_price!(amount: nil, currency: "USD", observed_at: @observed_at)
    end
  end

  test "valor negativo é recusado pelo banco" do
    assert_raises(ActiveRecord::StatementInvalid) do
      write_price!(amount: -0.01, currency: "USD", observed_at: @observed_at)
    end
  end
end
