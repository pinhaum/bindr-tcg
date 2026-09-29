require "test_helper"

# T6 (conformidade) — CNF-16, CNF-36, CNF-37: selo de quantidade sobre a
# imagem principal, legenda do ilustrador, e placeholder na mesma medida da
# imagem quando a carta não tem `image_url`.
class CardDetailImageTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-t6@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OPt6", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "OP01-t6", name: "Nami",
      card_type: "character", colors: [ "Blue" ], cost: 1, power: 1000)
    @variant = CardVariant.create!(card: @card, card_set: @set, variant_code: "OP01-t6",
      rarity: "R", art_kind: "base", illustrator: "Eiichiro Oda",
      image_url: "https://example.test/OP01-t6.png")
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # --- CNF-16: selo de quantidade sobre a imagem principal ---

  test "com sessão e cópias da primeira variante, o selo mostra a quantidade sobre a imagem" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 2)

    get card_path(@card.card_number)
    assert_response :success

    assert_select ".card-detail__thumb .card-detail__badge", text: "2"
    assert_select ".card-detail__expand .card-detail__badge", text: "2"
    assert_select ".card-detail__badge[role=img][aria-label=?]", "2 cópias", count: 2
  end

  test "sem cópias, nenhum selo aparece sobre a imagem" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 0)

    get card_path(@card.card_number)
    assert_response :success

    assert_select ".card-detail__badge", count: 0
  end

  test "anônimo nunca vê selo sobre a imagem, mesmo que outro usuário possua a variante" do
    other = User.create!(email: "outro-t6@example.com", password: PASSWORD)
    CollectionItem.create!(user: other, card_variant: @variant, quantity: 5)

    get card_path(@card.card_number)
    assert_response :success

    assert_select ".card-detail__badge", count: 0
  end

  test "carta com duas variantes mostra o selo da primeira variante (1 cópia), não a soma (1+3=4)" do
    sign_in
    second = CardVariant.create!(card: @card, card_set: @set, variant_code: "OP01-t6_p1",
      rarity: "SR", art_kind: "parallel", illustrator: "Oda",
      image_url: "https://example.test/OP01-t6_p1.png")
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 1)
    CollectionItem.create!(user: @user, card_variant: second, quantity: 3)

    get card_path(@card.card_number)
    assert_response :success

    assert_select ".card-detail__thumb .card-detail__badge", text: "1"
    assert_select ".card-detail__expand .card-detail__badge", text: "1"
    assert_select ".card-detail__badge[role=img][aria-label=?]", "1 cópia", count: 2
  end

  # --- CNF-16 / CNF-37: legenda do ilustrador ---

  test "variante com ilustrador mostra a legenda abaixo da imagem" do
    get card_path(@card.card_number)
    assert_response :success

    assert_select ".card-detail__illustrator", text: "Ilustração: Eiichiro Oda"
  end

  test "variante sem ilustrador omite a legenda" do
    @variant.update!(illustrator: nil)

    get card_path(@card.card_number)
    assert_response :success

    assert_select ".card-detail__illustrator", count: 0
  end

  # --- CNF-36: placeholder na mesma medida quando não há imagem ---

  test "sem image_url, a miniatura e a imagem maior mostram o placeholder, sem <img>" do
    @variant.update!(image_url: nil)

    get card_path(@card.card_number)
    assert_response :success

    assert_select ".card-detail__thumb .card-detail__placeholder"
    assert_select ".card-detail__thumb img", count: 0
    assert_select ".card-detail__expand .card-detail__placeholder"
    assert_select ".card-detail__expand img", count: 0
  end
end
