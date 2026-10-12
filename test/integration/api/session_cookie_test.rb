require "test_helper"
require "stringio"

# T1 (spa-troca) — garantias de cookie e de troca de sessão pela API (STRO-23, STRO-24, STRO-31).
class Api::SessionCookieTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  HEADER = "card_number,variant_code,card_name,quantity\n".freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-api-cookie@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-cookie@example.com", password: PASSWORD)
    ImportRun.create!(source: "apitcg", source_revision: "cookie.json", status: "succeeded",
                      started_at: 1.hour.ago)
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "OP01-001", name: "Carta", card_type: "leader",
                         colors: [ "Blue" ], cost: 0, power: 2000, effect_text: "Efeito")
    @variant = CardVariant.create!(card: @card, card_set: @set, variant_code: "tcgplayer:123", rarity: "R",
                                   art_kind: "base", image_url: "https://cdn.example.com/123.png",
                                   last_seen_at: Time.current)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def json_headers(token = nil)
    { "Content-Type" => "application/json", "X-CSRF-Token" => token }.compact
  end

  def fetch_token
    get "/api/session"
    response.parsed_body.dig("data", "csrf_token")
  end

  def sign_in(user = @user, email: user.email)
    post "/api/session", params: { email: email, password: PASSWORD }.to_json,
                         headers: json_headers(fetch_token)
    response.parsed_body.dig("data", "csrf_token")
  end

  def sign_out(token)
    delete "/api/session", headers: json_headers(token)
    response.parsed_body.dig("data", "csrf_token")
  end

  def increment(token)
    post "/api/cards/OP01-001/variants/#{ERB::Util.url_encode(@variant.variant_code)}/increment",
         headers: json_headers(token)
  end

  def quantity_of(user)
    CollectionItem.find_by(user: user, card_variant: @variant)&.quantity
  end

  def assert_unauthenticated
    assert_response :unauthorized
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
  end

  test "session_id em params não autentica" do
    sign_in
    session_id = Session.find_by!(user: @user).id
    reset!

    get "/api/progress", params: { session_id: session_id }

    assert_unauthenticated
  end

  test "cookie session_id não assinado não autentica" do
    sign_in
    session_id = Session.find_by!(user: @user).id
    reset!
    cookies[:session_id] = session_id.to_s

    get "/api/progress"

    assert_unauthenticated
  end

  test "cookie de sessão destruída não autentica" do
    token = sign_in
    get "/api/progress"
    assert_response :ok
    signed_value = cookies[:session_id]

    sign_out(token)
    cookies[:session_id] = signed_value
    get "/api/progress"

    assert_unauthenticated
  end

  test "login de B no cookie jar de A grava para B, deixa A intacta e o progresso reflete B" do
    token = sign_in(@user)
    increment(token)
    assert_equal 1, quantity_of(@user)

    token = sign_in(@other)
    increment(token)

    assert_response :ok
    assert_equal 1, quantity_of(@user)
    assert_equal 1, quantity_of(@other)

    get "/api/progress"
    assert_response :ok
    assert_equal 1, response.parsed_body.dig("data", "summary", "total_copies")

    CollectionItem.where(user: @other).delete_all
    get "/api/progress"
    assert_equal 0, response.parsed_body.dig("data", "summary", "total_copies")
  end

  test "header X-User-Id com id alheio é ignorado no progresso" do
    CollectionItem.create!(user: @other, card_variant: @variant, quantity: 4)
    sign_in(@user)

    get "/api/progress", headers: { "X-User-Id" => @other.id.to_s }

    assert_response :ok
    assert_equal 0, response.parsed_body.dig("data", "summary", "total_copies")
  end

  test "header X-User-Id com id alheio é ignorado no envio do import e a pré-visualização é do dono da sessão" do
    CollectionItem.create!(user: @other, card_variant: @variant, quantity: 4)
    token = sign_in(@user)
    csv = HEADER + "OP01-001,tcgplayer:123,Carta,2\n"

    post "/api/collection/imports",
         params: { file: Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv",
                                                       original_filename: "colecao.csv") },
         headers: { "X-CSRF-Token" => token, "X-User-Id" => @other.id.to_s }

    assert_response :created
    assert_nil response.parsed_body.dig("data", "rows", 0, "quantity_before")
    assert_equal 4, quantity_of(@other)
    assert_nil quantity_of(@user)
  end

  test "login com o e-mail em outra caixa é aceito" do
    post "/api/session", params: { email: @user.email.upcase, password: PASSWORD }.to_json,
                         headers: json_headers(fetch_token)

    assert_response :ok
    assert_equal @user.email, response.parsed_body.dig("data", "user", "email")
  end

  test "deck em edição não sobrevive a logout e login, na mesma conta nem em outra" do
    deck = Deck.create!(user: @user, name: "Meu", leader: @card)
    token = sign_in(@user)
    post "/api/decks/#{deck.id}/select", headers: json_headers(token)
    assert_response :ok
    get "/api/cards/OP01-001"
    assert_equal deck.id, response.parsed_body.dig("data", "editing_deck", "id")

    sign_out(token)
    get "/api/cards/OP01-001"
    assert_nil response.parsed_body.dig("data", "editing_deck")

    sign_in(@user)
    get "/api/cards/OP01-001"
    assert_nil response.parsed_body.dig("data", "editing_deck")

    token = sign_in(@user)
    post "/api/decks/#{deck.id}/select", headers: json_headers(token)
    sign_out(token)
    sign_in(@other)
    get "/api/cards/OP01-001"
    assert_response :ok
    assert_nil response.parsed_body.dig("data", "editing_deck")
  end
end
