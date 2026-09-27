require "test_helper"

# T37 — Barra do set provada por valor (NAV-38).
#
# Testa que a barra <progress> renderiza com value e max corretos, correspondendo
# aos números da contagem "possuídas / total" da mesma linha, e que a barra não
# aparece em set sem total base conhecido (base_set_size: nil).
#
# Mata os mutantes M12 (`max` trocado por `base_size`) e M13 (barra renderizada
# sem total conhecido).
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
  end

  def create_variant(set, suffix, art_kind)
    card = Card.create!(card_set: set, card_number: "#{set.code}-#{suffix}",
                        name: "Card #{suffix}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: suffix,
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

  test "barra tem value igual às variantes possuídas e max igual ao total" do
    sign_in(@user)
    get progress_path

    # Set OP01: possuídas = 2, total = 7
    bars = css_select(".progress-set__bar")
    assert bars.present?, "deve haver barra de progresso"

    # Pega a primeira barra (OP01)
    bar = bars.first
    assert_equal "2", bar["value"],
      "barra deve ter value = 2 (variantes possuídas de OP01)"
    assert_equal "7", bar["max"],
      "barra deve ter max = 7 (total de variantes de OP01)"
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

    # A contagem "1 de 10 variantes" deve estar presente mesmo sem barra
    owned = op02_li.css(".progress-set__owned").text.to_i
    total = op02_li.css(".progress-set__total").text.to_i

    assert_equal 1, owned, "OP02 deve ter 1 variante possuída"
    assert_equal 10, total, "OP02 deve ter 10 variantes totais"
  end
end
