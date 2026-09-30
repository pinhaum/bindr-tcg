require "test_helper"

# T6 (conformidade) — CNF-14: miniatura ao lado do título abaixo de 1024px,
# imagem maior dentro de um `<details>` que expande no lugar, sem JavaScript.
class CardDetailHeroImageTest < ActionDispatch::IntegrationTest
  setup do
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(set_id: @set.id, card_number: "OP01-001", name: "Roronoa Zoro",
                         card_type: "character", colors: [ "Red" ], power: 5000)
    # O detalhe lista as variantes por variant_code: "OP01-001" vem antes de "OP01-001_p1".
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: @card, set_id: @set.id, variant_code: "OP01-001_p1",
                        rarity: "SEC", art_kind: "alternate_art",
                        image_url: "https://example.com/OP01-001_p1.png")
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: @card, set_id: @set.id, variant_code: "OP01-001",
                        rarity: "R", art_kind: "base",
                        image_url: "https://example.com/OP01-001.png")
    mark_catalog_present!
  end

  test "a miniatura da primeira variante listada fica ao lado do título, com alt que nomeia carta e variante" do
    get card_path(@card.card_number)
    assert_response :success

    assert_select ".card-detail__head" do
      assert_select ".card-detail__thumb img.card-detail__image", count: 1 do |img|
        assert_equal card_image_path("OP01-001"), img.first["src"]
        assert_equal "Roronoa Zoro OP01-001", img.first["alt"]
      end
      assert_select "h1.card-detail__name", text: "Roronoa Zoro"
    end

    head_pos = response.body.index('class="card-detail__head"')
    data_pos = response.body.index('class="card-detail__data"')
    assert_operator head_pos, :<, data_pos, "a miniatura e o título precisam vir antes dos dados"
  end

  test "a imagem maior fica dentro de um <details> que expande no lugar, sem script novo" do
    get card_path(@card.card_number)
    assert_response :success

    scripts_before = response.body.scan(/<script\b/).size

    assert_select "details.card-detail__expand" do
      assert_select "summary"
      assert_select ".card-detail__media img.card-detail__image", count: 1 do |img|
        assert_equal card_image_path("OP01-001"), img.first["src"]
      end
    end

    # A página já tem os <script> do importmap/Turbo (layout padrão); o
    # `<details>` não pode acrescentar nenhum novo para expandir a imagem.
    assert_equal scripts_before, response.body.scan(/<script\b/).size,
                "nenhum <script> novo deveria ser necessário para expandir a imagem"
  end

  test "o placeholder com nome e card_number fica no HTML junto da miniatura e da imagem maior" do
    get card_path(@card.card_number)

    assert_select ".card-detail__thumb .card-detail__placeholder[aria-hidden=true]" do
      assert_select "span", text: "Roronoa Zoro"
      assert_select "span", text: "OP01-001"
    end

    assert_select ".card-detail__expand .card-detail__placeholder[aria-hidden=true]" do
      assert_select "span", text: "Roronoa Zoro"
      assert_select "span", text: "OP01-001"
    end
  end

  test "variante sem image_url mostra só o placeholder na miniatura e na imagem maior" do
    CardVariant.where(card: @card).update_all(image_url: nil)

    get card_path(@card.card_number)
    assert_response :success
    assert_select ".card-detail__thumb .card-detail__placeholder"
    assert_select ".card-detail__thumb img", count: 0
    assert_select ".card-detail__expand .card-detail__placeholder"
    assert_select ".card-detail__expand img", count: 0
  end

  test "carta sem variante abre o detalhe sem miniatura nem <details>" do
    CardVariant.where(card: @card).delete_all

    get card_path(@card.card_number)
    assert_response :success
    assert_select ".card-detail__head", count: 0
    assert_select ".card-detail__expand", count: 0
    assert_select "h1.card-detail__name", text: "Roronoa Zoro"
  end
end
