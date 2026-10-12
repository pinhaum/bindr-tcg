require "test_helper"

# T5 (spa-decks) — excluir e escolher o deck em edição pela API (SDEC-48, SDEC-49, SDEC-60).
class Api::DecksDestroySelectTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-api-decks-ds@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-decks-ds@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "AD05", name: "Api Destroy", kind: "booster")
    @leader = Card.create!(card_set: @set, card_number: "AD05-001", name: "Leader", card_type: "leader", colors: [ "Black" ])
    @card = Card.create!(card_set: @set, card_number: "AD05-002", name: "Carta", card_type: "character", colors: [ "Black" ])
    @variant = CardVariant.create!(last_seen_at: Time.current, card: @card, card_set: @set, variant_code: "tcgplayer:ad05002", rarity: "C", art_kind: "base")
    sign_in
  end

  def sign_in(user = @user)
    get "/api/session"
    @token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => @token }
    @token = response.parsed_body.dig("data", "csrf_token") || @token
  end

  def send_json(verb, path, token: @token)
    headers = { "Content-Type" => "application/json" }
    headers["X-CSRF-Token"] = token if token
    public_send(verb, path, headers: headers)
  end

  def body = response.parsed_body

  test "excluir apaga deck e entradas, mantém coleção e wishlist, e nenhum deck fica em edição" do
    deck = Deck.create!(user: @user, name: "Some", leader: @leader)
    deck.entries.create!(card: @card, quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 3)
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 4)
    send_json :post, "/api/decks/#{deck.id}/select"

    assert_difference -> { Deck.count } => -1, -> { DeckEntry.count } => -1 do
      send_json :delete, "/api/decks/#{deck.id}"
    end

    assert_response :ok
    assert_equal({ "id" => deck.id, "name" => "Some" }, body["data"])
    assert_equal 1, @user.collection_items.count
    assert_equal 1, @user.wishlist_items.count
  end

  test "select grava o deck em edição e repetir não muda nada" do
    deck = Deck.create!(user: @user, name: "Escolhido")

    2.times do
      send_json :post, "/api/decks/#{deck.id}/select"
      assert_response :ok
      assert_equal({ "id" => deck.id, "name" => "Escolhido" }, body["data"])
    end
  end

  test "sem sessão é 401 nos dois" do
    deck = Deck.create!(user: @user, name: "Fica")
    delete "/api/session", headers: { "X-CSRF-Token" => @token }

    send_json :post, "/api/decks/#{deck.id}/select"
    assert_response :unauthorized
    send_json :delete, "/api/decks/#{deck.id}"
    assert_response :unauthorized
    assert Deck.exists?(deck.id)
  end

  test "sem token com a proteção ligada é 422 invalid_csrf_token e nada muda" do
    deck = Deck.create!(user: @user, name: "Fica")
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    send_json :delete, "/api/decks/#{deck.id}", token: nil
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", body.dig("error", "code")
    assert Deck.exists?(deck.id)

    send_json :post, "/api/decks/#{deck.id}/select", token: nil
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", body.dig("error", "code")
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "deck alheio ou inexistente é 404 nos dois, sem gravar" do
    foreign = Deck.create!(user: @other, name: "Alheio")

    send_json :delete, "/api/decks/#{foreign.id}"
    assert_response :not_found
    assert Deck.exists?(foreign.id)

    send_json :post, "/api/decks/#{foreign.id}/select"
    assert_response :not_found

    send_json :delete, "/api/decks/0"
    assert_response :not_found
  end
end
