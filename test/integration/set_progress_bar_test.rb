require "test_helper"

# T37 — Barra do set provada por valor (NAV-38).
#
# Testa que a barra <progress> renderiza com value e max corretos, correspondendo
# aos números da contagem "possuídos / denominador" da mesma linha, e que a barra
# não aparece em set sem total base conhecido (base_set_size: nil).
#
# fonte-apitcg (Req. 9.1 emendado): `value` é o número de cartas distintas
# possuídas e `max` é `base_set_size`, os dois números do percentual. Mata M13
# (barra renderizada sem total conhecido).
class SetProgressBarTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "set-progress-bar-t37@example.com", password: PASSWORD)

    # Set com base_set_size conhecido
    @set_with_base = CardSet.create!(code: "OP01", name: "Romance Dawn",
                                     kind: "booster",
                                     base_set_size: 5, total_set_size: 7)

    # Set sem base_set_size (nil)
    @set_without_base = CardSet.create!(code: "OP02", name: "Kingdoms",
                                        kind: "booster",
                                        base_set_size: nil, total_set_size: 10)

    # Variantes do set com base: 5 variantes base + 2 parallels = 7 total
    @v1 = create_variant(@set_with_base, "001", "base")
    @v2 = create_variant(@set_with_base, "002", "base")
    @v3 = create_variant(@set_with_base, "003", "base")
    @v4 = create_variant(@set_with_base, "004", "base")
    @v5 = create_variant(@set_with_base, "005", "base")
    @v6 = create_variant(@set_with_base, "006", "parallel")
    @v7 = create_variant(@set_with_base, "007", "parallel")

    # Variantes do set sem base: 10 variantes total
    (1..10).each { |i| create_variant(@set_without_base, "%03d" % i, "base") }
    @w1 = @set_without_base.cards.first.card_variants.first

    # Posse do usuário: tem 3 cópias de @v1, 2 de @v2, 1 de @w1
    # Set OP01: possuídas = 2 (v1 com qty 3, v2 com qty 2), total = 7
    # Set OP02: possuídas = 1 (w1 com qty 1), total = 10
    CollectionItem.create!(user: @user, card_variant: @v1, quantity: 3)
    CollectionItem.create!(user: @user, card_variant: @v2, quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @w1, quantity: 1)
    mark_catalog_present!
  end

  def create_variant(set, suffix, art_kind)
    card = Card.create!(card_set: set, card_number: "#{set.code}-#{suffix}",
                        name: "Card #{suffix}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: card, card_set: set, variant_code: suffix,
                        rarity: "C", art_kind: art_kind)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # --- NAV-38: barra com value = possuídas, max = total ---

  test "set com base_set_size conhecido renderiza a barra" do
    sign_in(@user)
    get progress_path

    assert_select ".progress-set__bar",
      fail_message: "barra deve ser renderizada para set com base_set_size conhecido"
  end

  test "barra tem value igual aos números possuídos e max igual ao denominador" do
    sign_in(@user)
    get progress_path

    # Set OP01: 2 números possuídos, base_set_size = 5 (7 impressões)
    bars = css_select(".progress-set__bar")
    assert bars.present?, "deve haver barra de progresso"

    # Pega a primeira barra (OP01)
    bar = bars.first
    assert_equal "2", bar["value"],
      "barra deve ter value = 2 (números possuídos de OP01)"
    assert_equal "5", bar["max"],
      "barra deve ter max = 5 (base_set_size de OP01, não as 7 impressões)"
  end

  test "barra value e max coincidem com a contagem textual da mesma linha" do
    sign_in(@user)
    get progress_path

    # Procura o li de OP01
    op01_li = css_select("li#progress_set_OP01").first
    assert op01_li, "não encontrou o li do set OP01"

    # Extrai "de" contagem: "2 de 7 variantes"
    owned_span = op01_li.css(".progress-set__owned").text.to_i
    total_span = op01_li.css(".progress-set__total").text.to_i

    # Pega a barra
    bar = op01_li.css(".progress-set__bar").first
    assert bar, "não encontrou barra no li"

    assert_equal owned_span, bar["value"].to_i,
      "value da barra (#{bar["value"]}) deve coincidir com .progress-set__owned (#{owned_span})"
    assert_equal total_span, bar["max"].to_i,
      "max da barra (#{bar["max"]}) deve coincidir com .progress-set__total (#{total_span})"
  end

  # --- T23 / SRC-26: o texto não passa do denominador ---

  test "set com mais números possuídos que o denominador mostra 7 / 7 · 100% e 7 de 7" do
    legado = CardSet.create!(code: "OP09", name: "Legado", kind: "booster", base_set_size: 7, total_set_size: 9)
    variantes = (1..8).map { |i| create_variant(legado, "%03d" % i, "base") }
    # Uma reimpressão de outro número tira o set do ramo "set inteiro" (SRC-24).
    reimpressa = Card.create!(card_set: legado, card_number: "ST01-001", name: "Reimpressa",
                              card_type: "character", colors: [ "Red" ])
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: reimpressa, card_set: legado, variant_code: "r1",
                        rarity: "C", art_kind: "base")
    variantes.each { |v| CollectionItem.create!(user: @user, card_variant: v, quantity: 1) }
    sign_in(@user)

    get progress_path

    li = css_select("li#progress_set_OP09").first
    assert li, "não encontrou o li do set OP09"
    assert_equal "7 / 7 · 100%", li.css(".progress-set__owned-line").text.squish
    assert_equal "7 de 7 do set base", li.css(".progress-set__percent-basis").text.squish
    assert_equal [ "7", "7" ], [ li.css(".progress-set__bar").first["value"], li.css(".progress-set__bar").first["max"] ]
  end

  # --- NAV-38: barra não renderizada sem base_set_size ---

  test "set sem base_set_size não renderiza barra de progresso" do
    sign_in(@user)
    get progress_path

    # OP02 não tem base_set_size
    op02_li = css_select("li#progress_set_OP02").first
    assert op02_li, "não encontrou o li do set OP02"

    bar = op02_li.css(".progress-set__bar")
    assert bar.empty?,
      "barra não deve ser renderizada para set sem base_set_size"
  end

  test "set sem base_set_size exibe mensagem de percentual indisponível" do
    sign_in(@user)
    get progress_path

    op02_li = css_select("li#progress_set_OP02").first
    assert op02_li, "não encontrou o li do set OP02"

    percent_text = op02_li.css(".progress-set__percent").text
    assert percent_text.include?("Percentual indisponível"),
      "deve exibir 'Percentual indisponível' para set sem base_set_size"
  end

  test "contagem textual continua para set sem base_set_size" do
    sign_in(@user)
    get progress_path

    op02_li = css_select("li#progress_set_OP02").first

    # A posse continua presente mesmo sem barra; sem denominador conhecido, a
    # linha não inventa um total (PRG-10).
    owned = op02_li.css(".progress-set__owned").text.to_i

    assert_equal 1, owned, "OP02 deve ter 1 número possuído"
    assert_empty op02_li.css(".progress-set__total"), "sem base_set_size não há denominador a exibir"
  end
end
