require "test_helper"

# T7 (precos) — o valor estimado na pasta (PRC-11..PRC-15). Os números já estão
# provados por unidade em `collection_item_test.rb` (T6); aqui prova-se o que
# chega ao HTML e de quem é. A contagem de consultas (PRC-16) fica com o teste
# protegido `test/queries/set_progress_plan_test.rb`, que não muda (AD-021).
class ProgressValueTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @nami = User.create!(email: "nami-precos-t7@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-precos-t7@example.com", password: PASSWORD)
    @set_a = CardSet.create!(code: "PVA", name: "Set A", kind: "booster")
    @set_b = CardSet.create!(code: "PVB", name: "Set B", kind: "booster")
    @set_c = CardSet.create!(code: "PVC", name: "Set C", kind: "booster")
    @a1 = variant!(@set_a, "PVA-001", BigDecimal("1.7"))
    @a2 = variant!(@set_a, "PVA-002", nil)
    @b1 = variant!(@set_b, "PVB-001", BigDecimal("10"))
    variant!(@set_c, "PVC-001", BigDecimal("99"))
    mark_catalog_present!
  end

  def variant!(set, code, amount)
    card = Card.create!(card_set: set, card_number: code, name: "Carta #{code}",
                        card_type: "character", colors: [ "Red" ])
    price = amount ? { price_amount: amount, price_currency: "USD", price_observed_at: Time.utc(2026, 10, 1) } : {}
    CardVariant.create!(card: card, card_set: set, variant_code: "tcgplayer:#{code}", rarity: "C",
                        art_kind: "base", last_seen_at: CATALOG_SEEN_AT, **price)
  end

  def own!(user, variant, quantity) = CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)

  def sign_in(user) = post(session_path, params: { email: user.email, password: PASSWORD })

  def value_stat = css_select(".progress__stat--value").first

  def set_value(set) = css_select("#progress_set_#{set.code} .progress-set__value").first.text.strip

  def nami_spec_scenario
    own!(@nami, @a1, 3)
    own!(@nami, @b1, 1)
    own!(@nami, @a2, 2)
  end

  test "PRC-11: a pasta mostra o valor estimado com o rótulo" do
    nami_spec_scenario
    sign_in(@nami)

    get progress_path

    assert_response :success
    assert_equal "US$ 15,10", value_stat.at_css(".progress__stat-value").text.strip
    assert_equal "valor estimado", value_stat.at_css(".progress__stat-label").text.strip
  end

  test "PRC-12: mostra quantas cópias estão sem preço" do
    nami_spec_scenario
    sign_in(@nami)

    get progress_path

    assert_equal "2 cópias sem preço", value_stat.at_css(".progress__stat-note").text.strip
  end

  test "PRC-12: uma cópia sem preço fica no singular" do
    own!(@nami, @a2, 1)
    sign_in(@nami)

    get progress_path

    assert_equal "1 cópia sem preço", value_stat.at_css(".progress__stat-note").text.strip
  end

  test "PRC-13: cada set mostra o subtotal das variantes possuídas dele" do
    nami_spec_scenario
    sign_in(@nami)

    get progress_path

    assert_equal "US$ 5,10", set_value(@set_a)
    assert_equal "US$ 10,00", set_value(@set_b)
  end

  test "PRC-13: set sem cópia com preço mostra US$ 0,00" do
    nami_spec_scenario
    sign_in(@nami)

    get progress_path

    assert_equal "US$ 0,00", set_value(@set_c)
  end

  test "PRC-14: outro usuário logado vê só os próprios números" do
    nami_spec_scenario
    own!(@zoro, @b1, 4)
    sign_in(@zoro)

    get progress_path

    assert_equal "US$ 40,00", value_stat.at_css(".progress__stat-value").text.strip
    assert_equal "US$ 0,00", set_value(@set_a)
    assert_equal "US$ 40,00", set_value(@set_b)
    assert_empty value_stat.css(".progress__stat-note")
  end

  test "PRC-15: sem cópia com preço, o valor é US$ 0,00 e não há aviso de cópias sem preço" do
    sign_in(@nami)

    get progress_path

    assert_equal "US$ 0,00", value_stat.at_css(".progress__stat-value").text.strip
    assert_empty value_stat.css(".progress__stat-note")
    assert_not_includes response.body, "sem preço"
  end
end
