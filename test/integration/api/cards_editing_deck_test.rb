require "test_helper"

# T10 (spa-decks) — deck em edição no detalhe da carta pela API (SDEC-50).
class Api::CardsEditingDeckTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-api-ced@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "AD10", name: "Api Editing", kind: "booster")
    @leader = Card.create!(card_set: @set, card_number: "AD10-001", name: "Leader", card_type: "leader", colors: [ "Black" ])
    @card = Card.create!(card_set: @set, card_number: "AD10-002", name: "Carta", card_type: "character", colors: [ "Black" ])
    @deck = Deck.create!(user: @user, name: "Meu", leader: @leader)
    sign_in
  end

  def sign_in(user = @user)
    get "/api/session"
    @token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => @token }
    @token = response.parsed_body.dig("data", "csrf_token") || @token
  end

  def send_json(verb, path)
    public_send(verb, path, headers: { "Content-Type" => "application/json", "X-CSRF-Token" => @token })
  end

  def editing_deck_of(card)
    get "/api/cards/#{card.card_number}"
    response.parsed_body.dig("data", "editing_deck")
  end

  test "sem sessão é null" do
    reset!
    assert_nil editing_deck_of(@card)
    assert_response :ok
  end

  test "com sessão e sem deck em edição é null" do
    assert_nil editing_deck_of(@card)
  end

  test "com deck em edição traz quantidade 0 sem entrada e N com entrada" do
    send_json :post, "/api/decks/#{@deck.id}/select"
    assert_equal({ "id" => @deck.id, "name" => "Meu", "quantity" => 0, "is_leader" => false }, editing_deck_of(@card))

    @deck.entries.create!(card: @card, quantity: 3)
    assert_equal 3, editing_deck_of(@card)["quantity"]
  end

  test "is_leader é verdadeiro só para o Leader do deck" do
    send_json :post, "/api/decks/#{@deck.id}/select"
    assert_equal true, editing_deck_of(@leader)["is_leader"]
    assert_equal false, editing_deck_of(@card)["is_leader"]
  end

  test "depois de excluir o deck pela API volta a null" do
    send_json :post, "/api/decks/#{@deck.id}/select"
    send_json :delete, "/api/decks/#{@deck.id}"
    assert_nil editing_deck_of(@card)
  end

  test "depois de excluir o deck por fora da sessão volta a null" do
    send_json :post, "/api/decks/#{@deck.id}/select"
    @deck.destroy!
    assert_nil editing_deck_of(@card)
  end

  test "consultas a mais com deck em edição são em número fixo" do
    send_json :post, "/api/decks/#{@deck.id}/select"
    counter = ->(*, payload) { @count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    measure = lambda do
      @count = 0
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get "/api/cards/#{@card.card_number}" }
      @count
    end
    without_entry = measure.call

    @deck.entries.create!(card: @card, quantity: 2)
    assert_equal without_entry, measure.call
  end
end
