require "test_helper"

# T16 (decks) — exportar a lista do deck em texto (DCK-31, DCK-36, DCK-37).
class DeckExportTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
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

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def create_card(number, card_type: "character", cost: nil)
    Card.create!(card_set: @set, card_number: number, name: "Carta #{number}", card_type: card_type,
                 colors: [ "Black" ], cost: cost)
  end

  def sign_in
    get "/api/session"
    post "/api/session", params: { email: @user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json",
                                    "X-CSRF-Token" => response.parsed_body.dig("data", "csrf_token") }
    assert_response :success
  end

  test "o .txt responde text/plain em utf-8 com o corpo de Deck::ListText.format, sem CR" do
    sign_in

    get deck_export_path(@deck)

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "utf-8", response.charset.downcase
    assert_equal Deck::ListText.format(@deck.reload), response.body
    assert_equal "1xDT16-001\n3xDT16-010\n4xDT16-011\n2xDT16-030", response.body
    assert_not_includes response.body, "\r"
  end

  test "o .txt é servido pelo DeckExportsController" do
    route = Rails.application.routes.recognize_path("/decks/#{@deck.id}.txt", method: :get)

    assert_equal "deck_exports", route[:controller]
    assert_equal "show", route[:action]
  end

  test "o .txt de deck de outro usuário dá 404" do
    alien = Deck.create!(user: @other, name: "Alheio", leader: @leader)
    sign_in

    get deck_export_path(alien)

    assert_response :not_found
  end

  test "o .txt de deck inexistente dá 404" do
    sign_in

    get "/decks/0.txt"

    assert_response :not_found
  end

  test "sem sessão, o .txt redireciona para o login" do
    get deck_export_path(@deck)

    assert_response :found
    assert_equal "#{request.base_url}/entrar?return_to=%2Fdecks%2F#{@deck.id}.txt", response.headers["Location"]
  end
end
