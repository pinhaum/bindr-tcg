require "test_helper"

# T4 (spa-decks) — criar e renomear deck pela API (SDEC-44..46, SDEC-60).
class Api::DecksWriteTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  EMPTY = [ "O nome não pode ficar vazio." ].freeze
  TOO_LONG = [ "O nome pode ter no máximo 60 caracteres." ].freeze

  setup do
    @user = User.create!(email: "nami-api-decks-w@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-decks-w@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "AW03", name: "Api Write", kind: "booster")
    @leader = Card.create!(card_set: @set, card_number: "AW03-001", name: "Leader", card_type: "leader", colors: [ "Black" ])
    @card = Card.create!(card_set: @set, card_number: "AW03-002", name: "Carta", card_type: "character", colors: [ "Black" ])
    sign_in
  end

  def sign_in(user = @user)
    get "/api/session"
    @token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => @token }
    @token = response.parsed_body.dig("data", "csrf_token") || @token
  end

  def send_json(verb, path, payload, token: @token)
    headers = { "Content-Type" => "application/json" }
    headers["X-CSRF-Token"] = token if token
    public_send(verb, path, params: payload.is_a?(String) ? payload : payload.to_json, headers: headers)
  end

  def body = response.parsed_body

  test "criar com nome válido é 201, deck vazio do usuário e em edição" do
    assert_difference -> { @user.decks.count }, 1 do
      send_json :post, "/api/decks", { name: "  Aggro Preto ", user_id: @other.id }
    end

    assert_response :created
    deck = @user.decks.last
    assert_equal "Aggro Preto", deck.name
    assert_equal 0, @other.decks.count
    assert_nil deck.leader
    assert_empty deck.entries
    assert_equal deck.id, body.dig("data", "id")
    assert_equal true, body.dig("data", "editing")
    assert_equal "Aggro Preto", body.dig("data", "name")
  end

  test "renomear muda só o nome e preserva Leader e entradas" do
    deck = Deck.create!(user: @user, name: "Velho", leader: @leader)
    deck.entries.create!(card: @card, quantity: 3)

    send_json :patch, "/api/decks/#{deck.id}", { name: "Novo", leader_card_id: nil }

    assert_response :ok
    assert_equal "Novo", body.dig("data", "name")
    assert_equal @leader.card_number, body.dig("data", "leader", "card_number")
    assert_equal 3, body.dig("data", "entries", 0, "quantity")
    deck.reload
    assert_equal @leader, deck.leader
    assert_equal 3, deck.entries.sum(:quantity)
  end

  test "nome vazio, ausente, não-texto ou só espaços é 422 e nada é gravado" do
    deck = Deck.create!(user: @user, name: "Fica")

    [ {}, { name: nil }, { name: 42 }, { name: [ "a" ] }, { name: "   " }, { name: "" } ].each do |payload|
      assert_no_difference -> { Deck.count } do
        send_json :post, "/api/decks", payload
      end
      assert_response :unprocessable_entity
      assert_equal "validation_failed", body.dig("error", "code")
      assert_equal EMPTY, body.dig("error", "fields", "name")

      send_json :patch, "/api/decks/#{deck.id}", payload
      assert_response :unprocessable_entity
      assert_equal EMPTY, body.dig("error", "fields", "name")
    end
    assert_equal "Fica", deck.reload.name
  end

  test "nome com 61 caracteres é recusado e com 60 é aceito" do
    deck = Deck.create!(user: @user, name: "Fica")

    assert_no_difference -> { Deck.count } do
      send_json :post, "/api/decks", { name: "a" * 61 }
    end
    assert_response :unprocessable_entity
    assert_equal TOO_LONG, body.dig("error", "fields", "name")

    send_json :patch, "/api/decks/#{deck.id}", { name: "a" * 61 }
    assert_response :unprocessable_entity
    assert_equal "Fica", deck.reload.name

    send_json :post, "/api/decks", { name: "a" * 60 }
    assert_response :created
  end

  test "sem token com a proteção ligada é 422 invalid_csrf_token" do
    deck = Deck.create!(user: @user, name: "Fica")
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    assert_no_difference -> { Deck.count } do
      send_json :post, "/api/decks", { name: "X" }, token: nil
    end
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", body.dig("error", "code")

    send_json :patch, "/api/decks/#{deck.id}", { name: "X" }, token: nil
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", body.dig("error", "code")
    assert_equal "Fica", deck.reload.name
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "renomear deck de outro usuário ou inexistente é 404" do
    foreign = Deck.create!(user: @other, name: "Alheio")

    send_json :patch, "/api/decks/#{foreign.id}", { name: "Meu" }
    assert_response :not_found
    assert_equal "Alheio", foreign.reload.name

    send_json :patch, "/api/decks/0", { name: "Meu" }
    assert_response :not_found
  end

  test "JSON malformado é 400 invalid_json" do
    send_json :post, "/api/decks", "{name:"

    assert_response :bad_request
    assert_equal "invalid_json", body.dig("error", "code")
  end

  test "sem sessão é 401" do
    delete "/api/session", headers: { "X-CSRF-Token" => @token }
    post "/api/decks", params: { name: "X" }.to_json, headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
  end
end
