require "test_helper"

# T16 (decks) — exportar a lista do deck em texto (DCK-31, DCK-36, DCK-37).
class DeckExportTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "deck-t16@example.com", password: PASSWORD)
    @other = User.create!(email: "deck-t16-outro@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT16", name: "Decks T16", kind: "booster")
    @leader = create_card("DT16-001", card_type: "leader")
    @event = create_card("DT16-030", card_type: "event", cost: 1)
    @cheap = create_card("DT16-010", cost: 1)
    @pricey = create_card("DT16-011", cost: 5)
    @deck = Deck.create!(user: @user, name: "Exportado", leader: @leader)
    { @event => 2, @pricey => 4, @cheap => 3 }.each { |card, quantity| @deck.entries.create!(card: card, quantity: quantity) }
  end

  def create_card(number, card_type: "character", cost: nil)
    Card.create!(card_set: @set, card_number: number, name: "Carta #{number}", card_type: card_type,
                 colors: [ "Black" ], cost: cost)
  end

  def sign_in
    post session_path, params: { email: @user.email, password: PASSWORD }
  end

  test "o .txt responde text/plain em utf-8 com o corpo de Deck::ListText.format, sem CR" do
    sign_in

    get deck_path(@deck, format: :txt)

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "utf-8", response.charset.downcase
    assert_equal Deck::ListText.format(@deck.reload), response.body
    assert_equal "1xDT16-001\n3xDT16-010\n4xDT16-011\n2xDT16-030", response.body
    assert_not_includes response.body, "\r"
  end

  test "a página do deck tem o link Exportar lista para o .txt" do
    sign_in

    get deck_path(@deck)

    assert_select "a[href='#{deck_path(@deck, format: :txt)}']", text: "Exportar lista"
  end

  test "o .txt de deck de outro usuário dá 404" do
    alien = Deck.create!(user: @other, name: "Alheio", leader: @leader)
    sign_in

    get deck_path(alien, format: :txt)

    assert_response :not_found
  end

  test "sem sessão, o .txt redireciona para o login" do
    get deck_path(@deck, format: :txt)

    assert_redirected_to new_session_path
  end
end
