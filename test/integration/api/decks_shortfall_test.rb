require "test_helper"

# T9 (spa-decks) — o que falta para os decks na API (SDEC-59, SDEC-60).
class Api::DecksShortfallTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-api-short@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-short@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "AS09", name: "Api Shortfall", kind: "booster")
    @shared = card!("AS09-010", name: "Carta Disputada")
    @done = card!("AS09-011", name: "Carta Completa")
  end

  def card!(number, name:)
    Card.create!(card_set: @set, card_number: number, name: name, card_type: "character", colors: [ "Black" ]).tap do |card|
      CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:#{number}", art_kind: "base")
    end
  end

  def own(card, quantity, user: @user)
    CollectionItem.create!(user: user, card_variant: card.card_variants.first, quantity: quantity)
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

  test "sem sessão é 401 JSON" do
    get "/api/decks/shortfall"

    assert_response :unauthorized
    assert_equal "unauthenticated", body.dig("error", "code")
  end

  test "dois decks que dividem uma carta dão a mesma falta e os decks do bloco da pasta" do
    big = Deck.create!(user: @user, name: "Pede quatro")
    small = Deck.create!(user: @user, name: "Pede duas")
    big.entries.create!(card: @shared, quantity: 4)
    small.entries.create!(card: @shared, quantity: 2)
    big.entries.create!(card: @done, quantity: 1)
    own(@shared, 1)
    own(@done, 1)
    sign_in

    get "/api/decks/shortfall"

    assert_response :ok
    assert_equal [ { "card_number" => "AS09-010", "name" => "Carta Disputada", "missing" => 3,
                     "decks" => [ { "id" => big.id, "name" => "Pede quatro" },
                                  { "id" => small.id, "name" => "Pede duas" } ] } ], body["data"]
    expected = DeckShortfallQuery.new(@user).call.select { |row| row.missing.positive? }
    assert_equal expected.map { |row| [ row.card.card_number, row.missing ] },
                 body["data"].map { |row| [ row["card_number"], row["missing"] ] }
  end

  test "sem decks ou com tudo possuído devolve lista vazia" do
    sign_in
    get "/api/decks/shortfall"
    assert_equal [], body["data"]

    Deck.create!(user: @user, name: "Completo").entries.create!(card: @done, quantity: 2)
    own(@done, 2)
    get "/api/decks/shortfall"
    assert_equal [], body["data"]
  end

  test "decks de outro usuário nunca aparecem" do
    Deck.create!(user: @other, name: "Alheio").entries.create!(card: @shared, quantity: 3)
    mine = Deck.create!(user: @user, name: "Meu")
    mine.entries.create!(card: @shared, quantity: 1)
    sign_in

    get "/api/decks/shortfall"

    assert_equal [ [ { "id" => mine.id, "name" => "Meu" } ] ], body["data"].map { |row| row["decks"] }
    assert_equal [ 1 ], body["data"].map { |row| row["missing"] }
  end

  test "o número de consultas é o mesmo com 1 e com 3 decks" do
    first = Deck.create!(user: @user, name: "Um")
    first.entries.create!(card: @shared, quantity: 2)
    sign_in
    with_one = count_queries { get "/api/decks/shortfall" }

    2.times { |i| Deck.create!(user: @user, name: "Extra #{i}").entries.create!(card: @shared, quantity: 1) }
    with_three = count_queries { get "/api/decks/shortfall" }

    assert_equal with_one, with_three
  end

  test "com linhas são duas consultas de decks e sem linhas, uma a menos" do
    sign_in
    empty = count_queries { get "/api/decks/shortfall" }
    Deck.create!(user: @user, name: "Um").entries.create!(card: @shared, quantity: 2)
    filled = count_queries { get "/api/decks/shortfall" }

    assert_equal 1, filled - empty
  end
end
