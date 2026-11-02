require "test_helper"

# SDEC-51..53: o SQL atômico de entrada de deck mora no model, para que o
# controller HTML e a API JSON compartilhem a mesma operação.
class DeckEntryAtomicTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "atomico-#{SecureRandom.hex(4)}@example.com", password: "senha-correta")
    @deck = Deck.create!(user: user, name: "Deck")
    set = CardSet.create!(code: "DA#{SecureRandom.hex(3)}", name: "Deck Atomic", kind: "booster")
    @card = Card.create!(card_set: set, card_number: "DA01-#{SecureRandom.hex(3)}", name: "Carta",
      card_type: "character", colors: [ "Black" ])
  end

  def quantity_of(card = @card)
    @deck.entries.where(card: card).pick(:quantity)
  end

  test "increment_for! sem entrada cria com quantidade 1 e devolve 1" do
    assert_equal 1, DeckEntry.increment_for!(@deck, @card)
    assert_equal 1, quantity_of
  end

  test "increment_for! soma uma cópia por chamada" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 3)

    assert_equal 4, DeckEntry.increment_for!(@deck, @card)
    assert_equal 4, quantity_of
  end

  test "increment_for! em 49 devolve 50" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 49)

    assert_equal 50, DeckEntry.increment_for!(@deck, @card)
  end

  test "increment_for! em 50 devolve nil e não grava" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 50)

    assert_nil DeckEntry.increment_for!(@deck, @card)
    assert_equal 50, quantity_of
  end

  test "decrement_for! com 2 cópias devolve 1 e mantém a entrada" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 2)

    assert_equal 1, DeckEntry.decrement_for!(@deck, @card)
    assert_equal 1, quantity_of
  end

  test "decrement_for! em 1 devolve 0 e apaga a linha" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 1)

    assert_equal 0, DeckEntry.decrement_for!(@deck, @card)
    assert_nil quantity_of
    assert_not @deck.entries.exists?(card: @card)
  end

  test "decrement_for! sem entrada devolve nil e não cria linha" do
    assert_nil DeckEntry.decrement_for!(@deck, @card)
    assert_not @deck.entries.exists?(card: @card)
  end

  test "as operações só afetam o deck e a carta recebidos" do
    other = Card.create!(card_set: @card.card_set, card_number: "DA01-#{SecureRandom.hex(3)}", name: "Outra",
      card_type: "character", colors: [ "Black" ])
    DeckEntry.create!(deck: @deck, card: other, quantity: 2)

    DeckEntry.increment_for!(@deck, @card)
    DeckEntry.decrement_for!(@deck, @card)

    assert_equal 2, quantity_of(other)
  end
end
