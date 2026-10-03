require "test_helper"

# T18 (decks) — "Faltando para os baralhos" na pasta (DCK-33, DCK-34, DCK-35).
class DeckFolderShortfallTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  TITLE = "Faltando para os baralhos".freeze

  setup do
    @user = User.create!(email: "deck-t18@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT18", name: "Decks T18", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "DT18-010", name: "Carta Disputada", card_type: "character",
                         colors: [ "Black" ])
    @variant = CardVariant.create!(card: @card, card_set: @set, variant_code: "tcgplayer:DT18-010", art_kind: "base")
  end

  def sign_in
    post session_path, params: { email: @user.email, password: PASSWORD }
  end

  def own(quantity)
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: quantity)
  end

  def block
    css_select("section[aria-labelledby='deck-folder-shortfall-title']").first
  end

  test "dois decks pedindo 4 e 2 da mesma carta, com 1 possuída, mostram faltam 3 e links para os dois" do
    big = Deck.create!(user: @user, name: "Pede quatro")
    small = Deck.create!(user: @user, name: "Pede duas")
    big.entries.create!(card: @card, quantity: 4)
    small.entries.create!(card: @card, quantity: 2)
    own(1)
    sign_in

    get progress_path

    assert_response :success
    assert block, "a pasta deveria ter o bloco do que falta"
    assert_equal TITLE, block.at_css("h2").text.strip
    items = block.css("li")
    assert_equal 1, items.size
    assert_includes items.first.text.squish, "Carta Disputada DT18-010 faltam 3"
    assert_equal [ [ deck_path(big), "Pede quatro" ], [ deck_path(small), "Pede duas" ] ].sort,
                 items.first.css("a[href^='/decks/']").map { |a| [ a["href"], a.text ] }.sort
  end

  test "sem decks, a pasta não tem o bloco nem o título" do
    sign_in

    get progress_path

    assert_response :success
    assert_nil block
    assert_not_includes response.body, TITLE
  end

  test "com tudo possuído, a pasta não tem o bloco nem o título" do
    deck = Deck.create!(user: @user, name: "Completo")
    deck.entries.create!(card: @card, quantity: 4)
    own(4)
    sign_in

    get progress_path

    assert_response :success
    assert_nil block
    assert_not_includes response.body, TITLE
  end
end
