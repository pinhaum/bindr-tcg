require "test_helper"

class Api::CardVariantsUnwishTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  NOT_FOUND = { "error" => { "code" => "not_found", "message" => "Não encontrado.", "fields" => {} } }.freeze
  REMOVED = { "data" => { "variant_code" => "tcgplayer:123", "wishlist_target" => nil } }.freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-api-unwish@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-unwish@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = card!("OP01-001")
    @promo = card!("P.029")
    @variant = variant!(@card, "tcgplayer:123")
    @promo_variant = variant!(@promo, "tcgplayer:456")
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def card!(number)
    Card.create!(card_set: @set, card_number: number, name: "Carta #{number}", card_type: "character",
                 colors: [ "Blue" ], cost: 0, power: 2000, effect_text: "Efeito")
  end

  def variant!(card, code)
    CardVariant.create!(card: card, card_set: @set, variant_code: code, rarity: "R", art_kind: "base",
                        image_url: "https://cdn.example.com/#{code}.png", last_seen_at: Time.current)
  end

  def json_headers(token = nil)
    { "Content-Type" => "application/json", "X-CSRF-Token" => token }.compact
  end

  def fetch_token
    get "/api/session"
    response.parsed_body.dig("data", "csrf_token")
  end

  def sign_in(user = @user)
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: json_headers(fetch_token)
    response.parsed_body.dig("data", "csrf_token")
  end

  def unwish(number, code, token, body: nil, query: "")
    delete "/api/cards/#{number}/variants/#{ERB::Util.url_encode(code)}/wishlist#{query}",
           params: body, headers: json_headers(token)
  end

  def target_of(user, variant)
    WishlistItem.find_by(user: user, card_variant: variant)&.target_quantity
  end

  test "com desejo responde 200 com o corpo exato e apaga o registro" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    assert_difference -> { WishlistItem.count }, -1 do
      unwish("OP01-001", "tcgplayer:123", token)
    end
    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal REMOVED, response.parsed_body
    assert_nil target_of(@user, @variant)
  end

  test "sem desejo responde o mesmo 200 sem apagar nada" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @promo_variant, target_quantity: 1)

    assert_no_difference -> { WishlistItem.count } do
      unwish("OP01-001", "tcgplayer:123", token)
    end
    assert_response :ok
    assert_equal REMOVED, response.parsed_body
  end

  test "repetir a remoção continua respondendo 200" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    2.times do
      unwish("OP01-001", "tcgplayer:123", token)
      assert_response :ok
      assert_equal REMOVED, response.parsed_body
    end
  end

  test "o desejo de outro usuário na mesma variante continua gravado" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)
    WishlistItem.create!(user: @other, card_variant: @variant, target_quantity: 4)

    unwish("OP01-001", "tcgplayer:123", token)

    assert_response :ok
    assert_nil target_of(@user, @variant)
    assert_equal 4, target_of(@other, @variant)
  end

  test "user_id alheio no corpo e na query é ignorado" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)
    WishlistItem.create!(user: @other, card_variant: @variant, target_quantity: 4)

    unwish("OP01-001", "tcgplayer:123", token,
           body: { user_id: @other.id }.to_json, query: "?user_id=#{@other.id}")

    assert_response :ok
    assert_nil target_of(@user, @variant)
    assert_equal 4, target_of(@other, @variant)
  end

  test "não apaga o desejo do usuário em outra variante" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)
    WishlistItem.create!(user: @user, card_variant: @promo_variant, target_quantity: 3)

    unwish("OP01-001", "tcgplayer:123", token)

    assert_equal 3, target_of(@user, @promo_variant)
  end

  test "variant_code com dois pontos codificado e card_number com ponto são resolvidos" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @promo_variant, target_quantity: 1)

    unwish("P.029", "tcgplayer:456", token)

    assert_response :ok
    assert_equal({ "data" => { "variant_code" => "tcgplayer:456", "wishlist_target" => nil } },
                 response.parsed_body)
    assert_nil target_of(@user, @promo_variant)
  end

  test "carta inexistente responde 404 not_found sem apagar" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    assert_no_difference -> { WishlistItem.count } do
      unwish("OP99-999", "tcgplayer:123", token)
    end
    assert_response :not_found
    assert_equal NOT_FOUND, response.parsed_body
  end

  test "variant_code de outra carta responde 404 not_found sem apagar" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @promo_variant, target_quantity: 2)

    assert_no_difference -> { WishlistItem.count } do
      unwish("OP01-001", "tcgplayer:456", token)
    end
    assert_response :not_found
    assert_equal NOT_FOUND, response.parsed_body
  end

  test "sem sessão responde 401 unauthenticated sem apagar" do
    token = fetch_token
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    assert_no_difference -> { WishlistItem.count } do
      unwish("OP01-001", "tcgplayer:123", token)
    end
    assert_response :unauthorized
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
  end

  test "sem X-CSRF-Token responde 422 invalid_csrf_token sem apagar" do
    sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    assert_no_difference -> { WishlistItem.count } do
      unwish("OP01-001", "tcgplayer:123", nil)
    end
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")
  end

  test "corpo JSON malformado responde 400 invalid_json sem apagar" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    assert_no_difference -> { WishlistItem.count } do
      unwish("OP01-001", "tcgplayer:123", token, body: "{user_id: ")
    end
    assert_response :bad_request
    assert_equal "invalid_json", response.parsed_body.dig("error", "code")
  end

  test "nenhuma resposta do endpoint é redirect nem HTML" do
    token = sign_in

    [ [ "OP01-001", "tcgplayer:123", nil ],
      [ "OP99-999", "tcgplayer:123", nil ],
      [ "OP01-001", "tcgplayer:123", "{user_id: " ] ].each do |number, code, body|
      unwish(number, code, token, body: body)
      assert_not response.redirect?, "#{number} #{body}"
      assert_equal "application/json", response.media_type
    end
  end
end
