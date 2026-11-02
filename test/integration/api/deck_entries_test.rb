require "test_helper"

# T6 (spa-decks) — somar, tirar e escolher o Leader do deck pela API (SDEC-51..55, SDEC-60).
class Api::DeckEntriesTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-api-de@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-de@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "AD06", name: "Api Entries", kind: "booster")
    @leader = Card.create!(card_set: @set, card_number: "AD06-001", name: "Leader", card_type: "leader", colors: [ "Black" ])
    @other_leader = Card.create!(card_set: @set, card_number: "AD06-003", name: "Outro Leader", card_type: "leader", colors: [ "Black" ])
    @card = Card.create!(card_set: @set, card_number: "AD06-002", name: "Carta", card_type: "character", colors: [ "Black" ])
    @deck = Deck.create!(user: @user, name: "Meu")
    sign_in
  end

  def sign_in(user = @user)
    get "/api/session"
    @token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => @token }
    @token = response.parsed_body.dig("data", "csrf_token") || @token
  end

  def send_json(verb, path, params = nil, token: @token)
    headers = { "Content-Type" => "application/json" }
    headers["X-CSRF-Token"] = token if token
    public_send(verb, path, params: params&.to_json, headers: headers)
  end

  def body = response.parsed_body

  def quantity_of(card, deck = @deck) = deck.entries.where(card: card).pick(:quantity)

  def increment(card_number = @card.card_number, deck: @deck, **opts)
    send_json :post, "/api/decks/#{deck.id}/cards/#{ERB::Util.url_encode(card_number)}/increment", **opts
  end

  def decrement(card_number = @card.card_number, deck: @deck, **opts)
    send_json :post, "/api/decks/#{deck.id}/cards/#{ERB::Util.url_encode(card_number)}/decrement", **opts
  end

  def set_leader(card_number, deck: @deck, **opts)
    send_json :put, "/api/decks/#{deck.id}/leader", { card_number: card_number }, **opts
  end

  test "increment cria com 1 e soma" do
    increment
    assert_response :ok
    assert_equal({ "card_number" => "AD06-002", "quantity" => 1 }, body["data"])

    increment
    assert_equal 2, body.dig("data", "quantity")
    assert_equal 2, quantity_of(@card)
  end

  test "increment em 50 é 422 com a frase do HTML e não grava" do
    @deck.entries.create!(card: @card, quantity: 50)

    increment

    assert_response :unprocessable_entity
    assert_equal "validation_failed", body.dig("error", "code")
    assert_equal "O máximo é 50 cópias por carta no deck.", body.dig("error", "message")
    assert_equal 50, quantity_of(@card)
  end

  test "increment de Leader é 422 e não grava" do
    increment(@leader.card_number)

    assert_response :unprocessable_entity
    assert_equal "AD06-001 é um Leader; use “Usar como Leader” em vez de somar cópias.", body.dig("error", "message")
    assert_equal 0, @deck.entries.count
  end

  test "decrement tira uma, apaga em 1 e sem entrada é 200 com zero sem gravar" do
    @deck.entries.create!(card: @card, quantity: 2)

    decrement
    assert_response :ok
    assert_equal({ "card_number" => "AD06-002", "quantity" => 1 }, body["data"])

    decrement
    assert_equal 0, body.dig("data", "quantity")
    assert_equal 0, @deck.entries.count

    decrement
    assert_response :ok
    assert_equal 0, body.dig("data", "quantity")
    assert_equal 0, @deck.entries.count
  end

  test "leader grava, troca sem tocar entradas e regravar é igual" do
    @deck.entries.create!(card: @card, quantity: 3)

    2.times do
      set_leader(@leader.card_number)
      assert_response :ok
      assert_equal({ "leader_card_number" => "AD06-001" }, body["data"])
    end
    assert_equal @leader.id, @deck.reload.leader_card_id

    set_leader(@other_leader.card_number)
    assert_equal "AD06-003", body.dig("data", "leader_card_number")
    assert_equal @other_leader.id, @deck.reload.leader_card_id
    assert_equal 3, quantity_of(@card)
  end

  test "leader com carta que não é Leader é 422 e não grava" do
    set_leader(@card.card_number)

    assert_response :unprocessable_entity
    assert_equal "AD06-002 não é um Leader; use “+” para somar cópias ao deck.", body.dig("error", "message")
    assert_nil @deck.reload.leader_card_id
  end

  test "leader com card_number ausente ou que não é String é 404" do
    [ nil, 12, [ "AD06-001" ], { "a" => 1 } ].each do |value|
      set_leader(value)
      assert_response :not_found, "valor #{value.inspect}"
    end
    send_json :put, "/api/decks/#{@deck.id}/leader", {}
    assert_response :not_found
    assert_nil @deck.reload.leader_card_id
  end

  test "card_number com hífen e ponto codificados no caminho funciona" do
    promo = Card.create!(card_set: @set, card_number: "P-117", name: "Promo", card_type: "character", colors: [ "Red" ])
    dotted = Card.create!(card_set: @set, card_number: "ST01.5-001", name: "Ponto", card_type: "character", colors: [ "Red" ])

    increment("P-117")
    assert_response :ok
    assert_equal "P-117", body.dig("data", "card_number")
    increment("ST01.5-001")
    assert_response :ok
    decrement("ST01.5-001")
    assert_equal 0, body.dig("data", "quantity")
    assert_equal 1, quantity_of(promo)
    assert_nil quantity_of(dotted)
  end

  test "carta inexistente é 404 nas três" do
    increment("ZZ99-999")
    assert_response :not_found
    decrement("ZZ99-999")
    assert_response :not_found
    set_leader("ZZ99-999")
    assert_response :not_found
    assert_equal 0, @deck.entries.count
  end

  test "deck alheio ou inexistente é 404 e não grava" do
    foreign = Deck.create!(user: @other, name: "Alheio")
    foreign.entries.create!(card: @card, quantity: 2)

    increment(deck: foreign)
    assert_response :not_found
    decrement(deck: foreign)
    assert_response :not_found
    set_leader(@leader.card_number, deck: foreign)
    assert_response :not_found
    assert_equal 2, quantity_of(@card, foreign)
    assert_nil foreign.reload.leader_card_id

    send_json :post, "/api/decks/0/cards/#{@card.card_number}/increment"
    assert_response :not_found
  end

  test "sem sessão é 401 e não grava" do
    delete "/api/session", headers: { "X-CSRF-Token" => @token }

    increment
    assert_response :unauthorized
    decrement
    assert_response :unauthorized
    set_leader(@leader.card_number)
    assert_response :unauthorized
    assert_equal 0, @deck.entries.count
    assert_nil @deck.reload.leader_card_id
  end

  test "sem token com a proteção ligada é 422 invalid_csrf_token e não grava" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    increment(token: nil)
    assert_equal "invalid_csrf_token", body.dig("error", "code")
    assert_response :unprocessable_entity
    decrement(token: nil)
    assert_response :unprocessable_entity
    set_leader(@leader.card_number, token: nil)
    assert_response :unprocessable_entity
    assert_equal 0, @deck.entries.count
    assert_nil @deck.reload.leader_card_id
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
