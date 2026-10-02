require "test_helper"

# T3 (decks) — o model `DeckEntry`. O limite de quantidade também é do banco
# (`deck_schema_test.rb`); aqui a afirmação é que o model o diz em português.
class DeckEntryTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "entrada-#{SecureRandom.hex(4)}@example.com", password: "senha-correta")
    @deck = Deck.create!(user: user, name: "Deck")
    @set = CardSet.create!(code: "DE#{SecureRandom.hex(3)}", name: "Deck Entry", kind: "booster")
  end

  def create_card(card_type: "character")
    Card.create!(card_set: @set, card_number: "DE01-#{SecureRandom.hex(3)}", name: "Carta",
      card_type: card_type, colors: [ "Black" ])
  end

  # Done when / DCK-39: quantidade de 1 a 50.
  test "quantidade 0 e 51 são inválidas com mensagem em português" do
    card = create_card

    [ 0, 51 ].each do |quantity|
      entry = DeckEntry.new(deck: @deck, card: card, quantity: quantity)

      assert_not entry.valid?, "quantidade #{quantity} deveria ser inválida"
      assert_equal [ "deve ficar entre 1 e 50" ], entry.errors[:quantity]
    end
  end

  test "quantidades 1 e 50 são válidas" do
    card = create_card

    assert DeckEntry.new(deck: @deck, card: card, quantity: 1).valid?
    assert DeckEntry.new(deck: @deck, card: card, quantity: 50).valid?
  end

  # Done when: entrada com carta Leader é inválida.
  test "entrada com carta Leader é inválida" do
    entry = DeckEntry.new(deck: @deck, card: create_card(card_type: "leader"), quantity: 1)

    assert_not entry.valid?
    assert_equal [ "Leader não entra no deck principal; use-o como Leader do deck" ], entry.errors[:card]
  end
end
