require "test_helper"

# T10: HTML structure for detail layout — card-detail__data container (NAV-24, NAV-25)
class CardDetailLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(set_id: @set.id, card_number: "OP01-001", name: "Roronoa Zoro",
                         card_type: "character", colors: [ "Red" ], power: 5000,
                         effect_text: "Quando entra em jogo, este personagem ganha +1/+1.",
                         trigger_text: "Ao atacar, você pode sacrificar outro personagem.")
    CardVariant.create!(card: @card, set_id: @set.id, variant_code: "OP01-001",
                        rarity: "R", art_kind: "base")
    CardVariant.create!(card: @card, set_id: @set.id, variant_code: "OP01-001_p1",
                        rarity: "SEC", art_kind: "alternate_art")
  end

  test "detail page renders card-detail__data containing name and fields, with variants as sibling" do
    get card_path(@card.card_number)
    assert_response :success

    assert_select "main.card-detail" do
      # Link de voltar (primeiro filho)
      assert_select "p > a[href*='/catalog']"

      # Container de dados
      assert_select ".card-detail__data" do
        assert_select "h1.card-detail__name", text: @card.name
        assert_select ".card-detail__number", text: @card.card_number
        assert_select "dl.card-detail__fields"
        # effect e trigger estão dentro do container
        assert_select ".card-detail__effect"
        assert_select ".card-detail__trigger"
      end

      # Variants section, sibling of .card-detail__data
      assert_select ".card-detail__variants" do
        assert_select "li.variant", count: 2
      end
    end
  end

  test "card-detail__data is direct child of main, before variants" do
    get card_path(@card.card_number)

    assert_select "main.card-detail > .card-detail__data"
    assert_select "main.card-detail > .card-detail__variants"

    html = response.body
    data_pos = html.index('class="card-detail__data"')
    variants_pos = html.index('class="card-detail__variants"')

    assert_operator data_pos, :<, variants_pos,
                    ".card-detail__data must appear before .card-detail__variants"
  end
end
