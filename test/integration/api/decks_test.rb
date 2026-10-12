require "test_helper"

# T3 (spa-decks) — leitura da API de decks (SDEC-43, SDEC-47, SDEC-60).
class Api::DecksTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  RAYLEIGH_RULE = "Under the rules of this game, you cannot include cards with a cost of 5 or more in your deck.".freeze

  setup do
    @user = User.create!(email: "nami-api-decks@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-decks@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "AD03", name: "Api Decks", kind: "booster")
    @leader = card!("AD03-001", name: "Leader Preto", card_type: "leader")
  end

  def card!(number, name: "Carta #{number}", card_type: "character", cost: nil, colors: [ "Black" ], effect_text: nil,
            present: true)
    Card.create!(card_set: @set, card_number: number, name: name, card_type: card_type, cost: cost,
                 colors: colors, effect_text: effect_text).tap do |card|
      CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:#{number}", art_kind: "base",
                          last_seen_at: present ? nil : CATALOG_SEEN_AT - 1.day)
    end
  end

  def deck!(name: "Deck", user: @user, leader: nil, entries: {})
    mark_catalog_present!
    Deck.create!(user: user, name: name, leader: leader).tap do |deck|
      entries.each { |card, quantity| deck.entries.create!(card: card, quantity: quantity) }
    end
  end

  def sign_in(user = @user)
    get "/api/session"
    token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
  end

  def body = response.parsed_body

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  test "index sem sessão é 401 JSON" do
    get "/api/decks"

    assert_response :unauthorized
    assert_equal "unauthenticated", body.dig("error", "code")
  end

  test "index lista os decks do usuário por nome e id, sem os de outro usuário" do
    deck!(name: "Zebra")
    leader_deck = deck!(name: "Alfa", leader: @leader, entries: { card!("AD03-002", cost: 1) => 3 })
    deck!(name: "Alheio", user: @other)
    sign_in

    get "/api/decks"

    assert_response :success
    assert_equal %w[Alfa Zebra], body["data"].map { |d| d["name"] }
    alfa, zebra = body["data"]
    assert_equal({ "id" => leader_deck.id, "name" => "Alfa", "leader" => { "card_number" => "AD03-001", "name" => "Leader Preto" },
                   "main_total" => 3, "status" => "incomplete" }, alfa)
    assert_nil zebra["leader"]
    assert_equal 0, zebra["main_total"]
  end

  test "index traz o status e ignora user_id da query" do
    deck!(name: "Um", leader: @leader)
    deck!(name: "Alheio", user: @other)
    sign_in

    get "/api/decks", params: { user_id: @other.id }
    assert_equal [ "Um" ], body["data"].map { |d| d["name"] }
    assert_equal [ "incomplete" ], body["data"].map { |d| d["status"] }
  end

  test "index faz as mesmas consultas com 1 e com 3 decks" do
    deck!(name: "A", leader: @leader, entries: { card!("AD03-002", cost: 1) => 2 })
    sign_in
    one = count_queries { get "/api/decks" }

    deck!(name: "B", leader: @leader, entries: { card!("AD03-003", cost: 1) => 2 })
    deck!(name: "C", leader: @leader, entries: { card!("AD03-004", cost: 1) => 2 })
    three = count_queries { get "/api/decks" }

    assert_equal one, three
  end

  test "show de deck vazio traz todos os campos do SDEC-47" do
    deck = deck!(name: "Vazio")
    sign_in

    get "/api/decks/#{deck.id}"

    assert_response :success
    data = body["data"]
    assert_equal deck.id, data["id"]
    assert_equal "Vazio", data["name"]
    assert_equal false, data["editing"]
    assert_equal "incomplete", data["status"]
    assert_equal [ "O deck não tem Leader", "Faltam 50 cartas para 50" ], data["reasons"]
    assert_empty data["warnings"]
    assert_equal 0, data["main_total"]
    assert_equal 0, data["missing_total"]
    assert_nil data["leader"]
    assert_equal [], data["entries"]
  end

  test "show de deck incompleto traz Leader, entradas ordenadas e faltas" do
    char = card!("AD03-003", name: "Char", cost: 2)
    cheap = card!("AD03-002", name: "Barata", cost: 1)
    event = card!("AD03-004", name: "Evento", card_type: "event")
    gone = card!("AD03-005", name: "Fora", cost: 3, present: false)
    deck = deck!(leader: @leader, entries: { char => 4, cheap => 2, event => 1, gone => 1 })
    CollectionItem.create!(user: @user, card_variant: CardVariant.find_by!(card: cheap), quantity: 1)
    sign_in

    get "/api/decks/#{deck.id}"

    data = body["data"]
    assert_equal deck.ordered_entries.map { |e| e.card.card_number }, data["entries"].map { |e| e["card_number"] }
    assert_equal({ "card_number" => "AD03-002", "name" => "Barata", "card_type" => "character", "cost" => 1,
                   "in_source" => true, "required" => 2, "owned" => 1, "missing" => 1, "quantity" => 2 },
                 data["entries"].first)
    ev = data["entries"].find { |e| e["card_number"] == "AD03-004" }
    assert_nil ev["cost"]
    assert_equal "event", ev["card_type"]
    assert_equal false, data["entries"].find { |e| e["card_number"] == "AD03-005" }["in_source"]
    assert_equal({ "card_number" => "AD03-001", "name" => "Leader Preto", "card_type" => "leader", "cost" => nil,
                   "in_source" => true, "required" => 1, "owned" => 0, "missing" => 1 }, data["leader"])
    assert_equal 8, data["main_total"]
    assert_equal 1 + 4 + 1 + 1 + 1, data["missing_total"]
    assert_equal "incomplete", data["status"]
    assert_equal [ "Faltam 42 cartas para 50" ], data["reasons"]
  end

  test "show de deck inválido por cor traz os motivos" do
    red = card!("AD03-002", name: "Vermelha", colors: [ "Red" ], cost: 1)
    deck = deck!(leader: @leader, entries: { red => 4 })
    sign_in

    get "/api/decks/#{deck.id}"

    data = body["data"]
    assert_equal "invalid", data["status"]
    assert(data["reasons"].any? { |r| r.include?("AD03-002") && r.include?("vermelha") })
  end

  test "show de Leader com regra própria traz o aviso sem mudar o status" do
    rayleigh = card!("AD03-009", name: "Rayleigh", card_type: "leader", effect_text: RAYLEIGH_RULE)
    deck = deck!(leader: rayleigh)
    sign_in

    get "/api/decks/#{deck.id}"

    assert_equal "incomplete", body.dig("data", "status")
    assert_equal [ rayleigh.own_deck_rule ], body.dig("data", "warnings")
    assert_equal [ RAYLEIGH_RULE ], body.dig("data", "warnings")
  end

  test "editing é verdadeiro só para o deck da sessão" do
    editing = deck!(name: "Editando")
    other = deck!(name: "Outro")
    sign_in
    post "/decks/#{editing.id}/select"

    get "/api/decks/#{editing.id}"
    assert_equal true, body.dig("data", "editing")
    get "/api/decks/#{other.id}"
    assert_equal false, body.dig("data", "editing")
  end

  test "show sem sessão é 401, deck alheio e inexistente são 404 not_found" do
    alheio = deck!(user: @other)
    mine = deck!

    get "/api/decks/#{mine.id}"
    assert_response :unauthorized

    sign_in
    [ alheio.id, 0 ].each do |id|
      get "/api/decks/#{id}", params: { user_id: @other.id }
      assert_response :not_found
      assert_equal "not_found", body.dig("error", "code")
      assert_equal "application/json", response.media_type
    end
  end
end
