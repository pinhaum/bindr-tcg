require "test_helper"

# T29 — imagem maior no topo do detalhe da carta (NAV-48, Req. 5.1, Req. 2.3).
class CardDetailHeroImageTest < ActionDispatch::IntegrationTest
  setup do
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(set_id: @set.id, card_number: "OP01-001", name: "Roronoa Zoro",
                         card_type: "character", colors: [ "Red" ], power: 5000)
    # O detalhe lista as variantes por variant_code: "OP01-001" vem antes de "OP01-001_p1".
    CardVariant.create!(card: @card, set_id: @set.id, variant_code: "OP01-001_p1",
                        rarity: "SEC", art_kind: "alternate_art",
                        image_url: "https://example.com/OP01-001_p1.png")
    CardVariant.create!(card: @card, set_id: @set.id, variant_code: "OP01-001",
                        rarity: "R", art_kind: "base",
                        image_url: "https://example.com/OP01-001.png")
  end

  test "a imagem da primeira variante listada vem antes dos dados, com alt que nomeia carta e variante" do
    get card_path(@card.card_number)
    assert_response :success

    assert_select "main.card-detail > .card-detail__media img.card-detail__image", count: 1 do |img|
      assert_equal card_image_path("OP01-001"), img.first["src"]
      assert_equal "Roronoa Zoro OP01-001", img.first["alt"]
    end

    media_pos = response.body.index('class="card-detail__media"')
    data_pos = response.body.index('class="card-detail__data"')
    assert_operator media_pos, :<, data_pos, "a imagem maior precisa vir antes dos dados"
  end

  test "o placeholder com nome e card_number fica no HTML junto da imagem, para quando ela falhar sem JS" do
    get card_path(@card.card_number)

    assert_select ".card-detail__media .card-detail__placeholder[aria-hidden=true]" do
      assert_select "span", text: "Roronoa Zoro"
      assert_select "span", text: "OP01-001"
    end
  end

  test "variante sem image_url mostra só o placeholder" do
    CardVariant.where(card: @card).update_all(image_url: nil)

    get card_path(@card.card_number)
    assert_response :success
    assert_select ".card-detail__media .card-detail__placeholder"
    assert_select ".card-detail__media img", count: 0
  end

  test "carta sem variante abre o detalhe sem o elemento da imagem" do
    CardVariant.where(card: @card).delete_all

    get card_path(@card.card_number)
    assert_response :success
    assert_select ".card-detail__media", count: 0
    assert_select "h1.card-detail__name", text: "Roronoa Zoro"
  end
end
