require "test_helper"

class Api::EndToEndTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-e2e@example.com", password: PASSWORD, password_confirmation: PASSWORD)
    set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @owned_card = card!(set, "OP01-001", "Nami")
    @other_card = card!(set, "OP01-002", "Luffy")
    @owned_variant = variant!(@owned_card, "tcgplayer:11")
    variant!(@other_card, "tcgplayer:21")
    CollectionItem.create!(user: @user, card_variant: @owned_variant, quantity: 3)
    mark_catalog_present!
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def card!(set, number, name)
    Card.create!(card_set: set, card_number: number, name: name, card_type: "character", colors: [ "Blue" ],
                 cost: 1, power: 1000)
  end

  def variant!(card, code)
    CardVariant.create!(card: card, card_set: card.card_set, variant_code: code, rarity: "R", art_kind: "base",
                        image_url: "https://cdn.example.com/#{code}.png")
  end

  def json_headers(token = nil)
    { "Content-Type" => "application/json", "X-CSRF-Token" => token }.compact
  end

  def assert_json_only(label = nil)
    assert_not response.redirect?, "#{label}: redirect para #{response.location}"
    assert_equal "application/json", response.media_type, label
    JSON.parse(response.body)
  end

  test "ponta a ponta: sessão anônima, login, catálogo da coleção e logout, só JSON e token a cada passo" do
    get "/api/session"
    assert_response :ok
    assert_json_only("GET /api/session")
    assert_nil response.parsed_body.dig("data", "user")
    anonymous_token = response.parsed_body.dig("data", "csrf_token")
    assert_predicate anonymous_token, :present?

    post "/api/session", params: { email: @user.email, password: PASSWORD }.to_json,
                         headers: json_headers(anonymous_token)
    assert_response :ok
    assert_json_only("POST /api/session")
    assert_equal @user.email, response.parsed_body.dig("data", "user", "email")
    session_token = response.parsed_body.dig("data", "csrf_token")
    assert_predicate session_token, :present?
    assert_not_equal anonymous_token, session_token

    get "/api/catalog", params: { owned: "owned" }
    assert_response :ok
    assert_json_only("GET /api/catalog")
    assert_equal %w[OP01-001], response.parsed_body["data"].pluck("card_number")
    assert_equal 3, response.parsed_body["data"].first["variants"].first["owned_quantity"]

    delete "/api/session", headers: json_headers(session_token)
    assert_response :ok
    assert_json_only("DELETE /api/session")
    assert_nil response.parsed_body.dig("data", "user")
    assert_predicate response.parsed_body.dig("data", "csrf_token"), :present?
    assert_equal 0, Session.where(user: @user).count

    get "/api/catalog", params: { owned: "owned" }
    assert_response :ok
    assert_equal 2, response.parsed_body["data"].size
  end

  test "API-17: nenhuma resposta sob /api, de sucesso ou de erro, é HTML ou redirect" do
    get "/api/session"
    token = response.parsed_body.dig("data", "csrf_token")
    login = { email: @user.email, password: PASSWORD }.to_json

    requests = [
      [ :get, "/api/session" ],
      [ :get, "/api/catalog" ],
      [ :get, "/api/catalog", { owned: "owned", per_page: "abc", zzz: "1" } ],
      [ :get, "/api/catalog/filters" ],
      [ :get, "/api/cards/OP01-001" ],
      [ :get, "/api/cards/OP01-001", { variant: "tcgplayer:11" } ],
      [ :get, "/api/cards/NAO-EXISTE" ],
      [ :get, "/api/nao-existe" ],
      [ :get, "/api/cards/OP01-001.html" ],
      [ :post, "/api/nao-existe", nil, json_headers ],
      [ :delete, "/api/session", nil, json_headers(token) ],
      [ :post, "/api/session", login, json_headers ],
      [ :post, "/api/session", "{malformado", json_headers(token) ],
      [ :post, "/api/session", { email: @user.email, password: "errada" }.to_json, json_headers(token) ],
      [ :post, "/api/registration", { user: { email: "" } }.to_json, json_headers(token) ],
      [ :post, "/api/registration", {}.to_json, json_headers(token) ]
    ]

    requests.each do |verb, path, params, headers|
      public_send(verb, path, params: params, headers: headers || {})
      assert_json_only("#{verb.to_s.upcase} #{path}")
    end

    get "/api/session", headers: { "Accept" => "text/html" }
    assert_json_only("GET /api/session com Accept text/html")
  end
end
