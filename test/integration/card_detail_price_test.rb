require "test_helper"

# T5 (precos) — o preço de cada variante no detalhe da carta (PRC-08, PRC-09,
# PRC-10).
class CardDetailPriceTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  OBSERVED_AT = Time.utc(2026, 10, 1, 23, 16)

  setup do
    @set = CardSet.create!(code: "OPpr", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "OP01-pr1", name: "Nami",
                         card_type: "character", colors: [ "Blue" ], cost: 1, power: 2000)
    @priced = variant!("tcgplayer:1", price: BigDecimal("1.7"))
    @unpriced = variant!("tcgplayer:2")
    mark_catalog_present!
  end

  def variant!(code, price: nil, last_seen_at: CATALOG_SEEN_AT)
    attrs = price ? { price_amount: price, price_currency: "USD", price_observed_at: OBSERVED_AT } : {}
    CardVariant.create!(last_seen_at: last_seen_at, card: @card, card_set: @set, variant_code: code,
                        rarity: "R", art_kind: "base", **attrs)
  end

  def variant_item(variant) = css_select(".variant").find { |li| li.at_css(".variant__code")&.text&.strip == variant.variant_code }

  def price_text(variant) = variant_item(variant).at_css(".variant__price").text.squish

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  test "PRC-08 e PRC-10: sem sessão, a variante com preço mostra valor, fonte e data" do
    get card_path(@card.card_number)

    assert_response :success
    assert_equal "US$ 1,70 TCGplayer · market · 01/10/2026", price_text(@priced)
  end

  test "PRC-08: o preço tem o rótulo Preço para leitor de tela" do
    get card_path(@card.card_number)

    dt = variant_item(@priced).at_css(".variant__price").parent.at_css("dt")
    assert_equal "Preço", dt.text.strip
  end

  test "PRC-09: a variante sem preço mostra Sem preço" do
    get card_path(@card.card_number)

    assert_equal "Sem preço", price_text(@unpriced)
  end

  test "PRC-08: preço zero aparece como US$ 0,00, não como Sem preço" do
    @unpriced.update!(price_amount: 0, price_currency: "USD", price_observed_at: OBSERVED_AT)

    get card_path(@card.card_number)

    assert_equal "US$ 0,00 TCGplayer · market · 01/10/2026", price_text(@unpriced)
  end

  test "PRC-04 e PRC-08: a variante fora da fonte mostra ao dono o último preço e a data dele" do
    user = User.create!(email: "precos-t5@example.com", password: PASSWORD)
    antiga = variant!("tcgplayer:3", price: BigDecimal("12.5"), last_seen_at: CATALOG_SEEN_AT - 30.days)
    antiga.update_columns(price_observed_at: Time.utc(2026, 8, 12, 15))
    CollectionItem.create!(user: user, card_variant: antiga, quantity: 1)
    post session_path, params: { email: user.email, password: PASSWORD }

    get card_path(@card.card_number)

    assert_equal "US$ 12,50 TCGplayer · market · 12/08/2026", price_text(antiga)
  end

  test "PRC-10: o preço não acrescenta consulta por variante" do
    get card_path(@card.card_number)
    with_two = count_queries { get card_path(@card.card_number) }

    3.upto(6) { |n| variant!("tcgplayer:#{n}", price: BigDecimal(n)) }
    mark_catalog_present!
    with_six = count_queries { get card_path(@card.card_number) }

    assert_equal with_two, with_six
  end
end
