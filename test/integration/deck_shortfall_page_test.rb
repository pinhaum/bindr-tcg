require "test_helper"

# T10 (decks) — na página do deck, o que falta na pasta (DCK-21, DCK-22,
# DCK-23).
class DeckShortfallPageTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "deck-t10@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT10", name: "Decks T10", kind: "booster")
    @leader = Card.create!(card_set: @set, card_number: "DT10-001", name: "Leader", card_type: "leader",
                           colors: [ "Black" ])
    @leader_base = create_variant(@leader, "base")
    @card = Card.create!(card_set: @set, card_number: "DT10-002", name: "Carta", card_type: "character",
                         colors: [ "Black" ], cost: 1)
    @base = create_variant(@card, "base")
    @parallel = create_variant(@card, "parallel")
    mark_catalog_present!
  end

  def create_variant(card, art_kind)
    CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:#{card.card_number}-#{art_kind}",
                        art_kind: art_kind)
  end

  def create_deck(leader: nil, entries: {})
    Deck.create!(user: @user, name: "Deck", leader: leader).tap do |deck|
      entries.each { |card, quantity| deck.entries.create!(card: card, quantity: quantity) }
    end
  end

  def own(variant, quantity)
    CollectionItem.create!(user: @user, card_variant: variant, quantity: quantity)
  end

  def sign_in
    post session_path, params: { email: @user.email, password: PASSWORD }
  end

  def entry_text(card)
    css_select("section[aria-labelledby='deck-main-title'] li")
      .find { |li| li.text.include?(card.card_number) }.text.squish
  end

  def leader_text
    css_select("section[aria-labelledby='deck-leader-title'] p").first.text.squish
  end

  def total_text
    css_select("section[aria-labelledby='deck-shortfall-title'] p").first.text.strip
  end

  # Independent Test do P1 / DCK-20, DCK-21.
  test "2 da base e 1 da parallel com o deck pedindo 4 mostra pedida 4, possuída 3, falta 1" do
    own(@base, 2)
    own(@parallel, 1)
    deck = create_deck(entries: { @card => 4 })
    sign_in

    get deck_path(deck)

    assert_includes entry_text(@card), "pedida 4, possuída 3, falta 1"
  end

  # DCK-21 — o Leader também tem as três quantidades, pedindo 1.
  test "o Leader mostra pedida 1, possuída e falta" do
    deck = create_deck(leader: @leader)
    sign_in

    get deck_path(deck)

    assert_includes leader_text, "pedida 1, possuída 0, falta 1"
  end

  # DCK-22 — o total soma o Leader e as entradas.
  test "o total soma o que falta de todas as cartas, Leader incluído" do
    own(@base, 1)
    deck = create_deck(leader: @leader, entries: { @card => 4 })
    sign_in

    get deck_path(deck)

    assert_equal "Faltam 4 cópias para montar este deck", total_text
  end

  test "com total zero, a página diz que você tem todas as cartas" do
    own(@leader_base, 1)
    own(@base, 4)
    deck = create_deck(leader: @leader, entries: { @card => 4 })
    sign_in

    get deck_path(deck)

    assert_equal "Você tem todas as cartas deste deck", total_text
    assert_includes entry_text(@card), "pedida 4, possuída 4, falta 0"
  end

  # DCK-23 — sem sincronização gravada: a segunda leitura vê a coleção nova.
  test "incrementar a coleção entre duas leituras muda o que falta na segunda" do
    deck = create_deck(entries: { @card => 4 })
    sign_in

    get deck_path(deck)
    assert_includes entry_text(@card), "pedida 4, possuída 0, falta 4"
    assert_equal "Faltam 4 cópias para montar este deck", total_text

    post increment_collection_item_path(card_variant_id: @parallel.id)
    get deck_path(deck)

    assert_includes entry_text(@card), "pedida 4, possuída 1, falta 3"
    assert_equal "Faltam 3 cópias para montar este deck", total_text
  end
end
