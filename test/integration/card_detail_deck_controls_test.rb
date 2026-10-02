require "test_helper"

# T15 (decks) — o controle de deck no detalhe da carta (DCK-03, DCK-04,
# DCK-41). O detalhe é público: sem sessão ou sem deck em edição, ele responde
# 200 sem controle de deck.
class CardDetailDeckControlsTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "deck-t15@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT15", name: "Decks T15", kind: "booster")
    @card = create_card("DT15-010", "Carta Comum", "character")
    @leader = create_card("DT15-001", "Leader Preto", "leader")
    mark_catalog_present!
  end

  def create_card(number, name, card_type)
    Card.create!(card_set: @set, card_number: number, name: name, card_type: card_type,
                 colors: [ "Black" ]).tap do |card|
      CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:#{number}", art_kind: "base")
    end
  end

  def sign_in
    post session_path, params: { email: @user.email, password: PASSWORD }
  end

  # Cria pelo formulário, que já deixa o deck em edição (T12).
  def create_editing_deck(name = "Em edição")
    post decks_path, params: { deck: { name: name } }
    Deck.order(:id).last
  end

  def controls_for(card)
    css_select("##{ActionView::RecordIdentifier.dom_id(card, :deck_entry)}").first
  end

  test "com deck em edição, a carta comum mostra o controle com a quantidade 0 sem entrada e o nome do deck" do
    sign_in
    deck = create_editing_deck("Luffy Preto")

    get card_path("DT15-010")

    assert_response :success
    controls = controls_for(@card)
    assert controls, "o detalhe deveria ter o controle de deck"
    assert_includes controls.text.squish, "0 cópias de Carta Comum no deck"
    assert_equal "Luffy Preto", controls.at_css("a[href='#{deck_path(deck)}']")&.text
    assert controls.at_css("form[action='#{increment_deck_card_path(deck, @card)}'] " \
                           "button[aria-label='Adicionar uma cópia de Carta Comum ao deck Luffy Preto']")
    assert controls.at_css("form[action='#{decrement_deck_card_path(deck, @card)}'] " \
                           "button[aria-label='Remover uma cópia de Carta Comum do deck Luffy Preto']")
  end

  test "com entrada no deck em edição, o controle mostra a quantidade atual" do
    sign_in
    deck = create_editing_deck
    deck.entries.create!(card: @card, quantity: 3)

    get card_path("DT15-010")

    assert_includes controls_for(@card).text.squish, "3 cópias de Carta Comum no deck"
  end

  test "com deck em edição, a carta Leader mostra Usar como Leader no lugar do − N +" do
    sign_in
    deck = create_editing_deck

    get card_path("DT15-001")

    controls = controls_for(@leader)
    assert controls.at_css("form[action='#{deck_leader_path(deck)}'] button", text: "Usar como Leader")
    assert_equal @leader.id.to_s, controls.at_css("form[action='#{deck_leader_path(deck)}'] input[name='card_id']")["value"]
    assert_nil controls.at_css("form[action='#{increment_deck_card_path(deck, @leader)}']")
    assert_nil controls.at_css("form[action='#{decrement_deck_card_path(deck, @leader)}']")
  end

  # T24 (achados M4 e M5) — o controle tem título próprio, e só a frase da
  # quantidade fica na região viva.
  test "com deck em edição, o controle fica numa section com h2 Deck em edição e uma só região viva" do
    sign_in
    create_editing_deck

    get card_path("DT15-010")

    section = css_select("section[aria-labelledby='deck-controls-title']").first
    assert section, "o controle de deck deveria estar numa section rotulada"
    assert_equal "Deck em edição", section.at_css("h2#deck-controls-title")&.text&.strip
    controls = section.at_css("##{ActionView::RecordIdentifier.dom_id(@card, :deck_entry)}")
    assert controls, "o controle deveria estar dentro da section"
    assert_nil controls["aria-live"]
    regions = controls.css("[aria-live]")
    assert_equal 1, regions.size
    assert_equal "0 cópias de Carta Comum no deck", regions.first.text.squish
    assert_empty regions.first.css("button, a")
  end

  test "sem sessão, o detalhe responde 200 sem controle de deck" do
    get card_path("DT15-010")

    assert_response :success
    assert_nil controls_for(@card)
  end

  test "com sessão e sem deck em edição, o detalhe responde 200 sem controle de deck" do
    Deck.create!(user: @user, name: "Não escolhido")
    sign_in

    get card_path("DT15-010")

    assert_response :success
    assert_nil controls_for(@card)
  end

  # DCK-41 — o deck em edição excluído some do detalhe.
  test "com o deck em edição excluído, o detalhe responde 200 sem controle de deck" do
    sign_in
    deck = create_editing_deck
    delete deck_path(deck)

    get card_path("DT15-010")

    assert_response :success
    assert_nil controls_for(@card)
  end
end
