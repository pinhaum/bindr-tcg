require "test_helper"

# T10: HTML structure for detail layout — card-detail__data container (NAV-24, NAV-25)
class CardDetailLayoutTest < ActionDispatch::IntegrationTest
  test "detail page renders card-detail__data containing name and fields, with variants as sibling" do
    card = Card.first
    skip "no cards in database" unless card

    get card_path(card.card_number)
    assert_response :success

    assert_select "main.card-detail" do
      # Link de voltar (primeiro filho)
      assert_select "p > a[href*='/catalog']"

      # Container de dados
      assert_select ".card-detail__data" do
        assert_select "h1.card-detail__name", text: card.name
        assert_select ".card-detail__number", text: card.card_number
        assert_select "dl.card-detail__fields"
      end

      # Variants section, sibling of .card-detail__data
      assert_select ".card-detail__variants"
    end
  end

  test "card-detail__data is direct child of main, before variants" do
    card = Card.first
    skip "no cards in database" unless card

    get card_path(card.card_number)

    assert_select "main.card-detail > .card-detail__data"
    assert_select "main.card-detail > .card-detail__variants"

    html = response.body
    data_pos = html.index('class="card-detail__data"')
    variants_pos = html.index('class="card-detail__variants"')

    assert_operator data_pos, :<, variants_pos,
                    ".card-detail__data must appear before .card-detail__variants"
  end
end
