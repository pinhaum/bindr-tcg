require "test_helper"

# T4 (precos) — o formato do preço e do rótulo da cotação (PRC-08, PRC-11,
# PRC-15). O app não tem locale pt-BR; os separadores são fixados aqui.
class PricesHelperTest < ActionView::TestCase
  test "valor em dólar com milhar em ponto e centavos em vírgula" do
    assert_equal "US$ 1.234,56", format_price(BigDecimal("1234.56"), "USD")
  end

  test "valor com uma casa decimal ganha a segunda" do
    assert_equal "US$ 1,70", format_price(BigDecimal("1.7"), "USD")
  end

  test "zero é US$ 0,00" do
    assert_equal "US$ 0,00", format_price(0, "USD")
  end

  test "moeda sem símbolo conhecido usa o código ISO" do
    assert_equal "BRL 12,00", format_price(BigDecimal("12"), "BRL")
  end

  test "o rótulo traz fonte, campo e a data no horário de Brasília" do
    variant = CardVariant.new(price_amount: 1, price_currency: "USD",
                              price_observed_at: Time.utc(2026, 10, 6, 1, 30))

    assert_equal "TCGplayer · market · 05/10/2026", price_label(variant)
  end
end
