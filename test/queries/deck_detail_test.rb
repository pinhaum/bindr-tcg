require "test_helper"

# T2 (spa-decks) — `DeckDetail`: a leitura da página do deck, num retrato só
# (SDEC-47).
class DeckDetailTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "detalhe@example.com", password: "senha-correta")
    @other = User.create!(email: "outro@example.com", password: "senha-correta")
    @set = CardSet.create!(code: "DD01", name: "Detail", kind: "booster")
    @leader = create_card("DD01-001", card_type: "leader")
    @present = create_card("DD01-002")
    @absent = create_card("DD01-003")
    @variant = CardVariant.create!(card: @present, card_set: @set, variant_code: "tcgplayer:dd-1", art_kind: "base")
    CardVariant.create!(card: @leader, card_set: @set, variant_code: "tcgplayer:dd-0", art_kind: "base")
    mark_catalog_present!
    CardVariant.create!(card: @absent, card_set: @set, variant_code: "tcgplayer:dd-2", art_kind: "base")
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 1)
    @deck = Deck.create!(user: @user, name: "Deck", leader: @leader)
    @deck.entries.create!(card: @present, quantity: 3)
    @deck.entries.create!(card: @absent, quantity: 2)
  end

  def create_card(number, card_type: "character")
    Card.create!(card_set: @set, card_number: number, name: "Carta #{number}", card_type: card_type,
                 colors: [ "Black" ])
  end

  test "devolve deck, status, cartas fora da fonte e falta por carta" do
    result = DeckDetail.new(user: @user, deck_id: @deck.id).call

    assert_equal @deck, result.deck
    assert_equal @deck.legality, result.legality
    assert_equal [ @absent.id ].to_set, result.absent_card_ids
    row = result.shortfall_by_card_id.fetch(@present.id)
    assert_equal [ 3, 1, 2 ], [ row.required, row.owned, row.missing ]
    assert_equal [ 2, 0, 2 ], result.shortfall_by_card_id.fetch(@absent.id).then { |r| [ r.required, r.owned, r.missing ] }
  end

  test "deck de outro usuário e id inexistente levantam RecordNotFound" do
    assert_raises(ActiveRecord::RecordNotFound) { DeckDetail.new(user: @other, deck_id: @deck.id).call }
    assert_raises(ActiveRecord::RecordNotFound) { DeckDetail.new(user: @user, deck_id: 0).call }
  end

  test "dentro de transação aberta não pede REPEATABLE READ" do
    assert Deck.connection.transaction_open?
    assert_nothing_raised { DeckDetail.new(user: @user, deck_id: @deck.id).call }
  end
end
