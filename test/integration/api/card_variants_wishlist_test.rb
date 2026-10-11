require "test_helper"

class Api::CardVariantsWishlistTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  NOT_FOUND = { "error" => { "code" => "not_found", "message" => "Não encontrado.", "fields" => {} } }.freeze
  INVALID_TARGET = {
    "error" => {
      "code" => "validation_failed",
      "message" => "Dados inválidos.",
      "fields" => { "target_quantity" => [ "Informe um número inteiro maior ou igual a 1." ] }
    }
  }.freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-api-wishlist@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-wishlist@example.com", password: PASSWORD)
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

  def wish(number, code, token, body: nil, query: "")
    put "/api/cards/#{number}/variants/#{ERB::Util.url_encode(code)}/wishlist#{query}",
        params: body, headers: json_headers(token)
  end

  def target_of(user, variant)
    WishlistItem.find_by(user: user, card_variant: variant)&.target_quantity
  end

  test "PUT com 2 sem desejo cria e responde 200 com o alvo" do
    token = sign_in

    assert_difference -> { WishlistItem.count }, 1 do
      wish("OP01-001", "tcgplayer:123", token, body: { target_quantity: 2 }.to_json)
    end
    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal({ "data" => { "variant_code" => "tcgplayer:123", "wishlist_target" => 2 } },
                 response.parsed_body)
    assert_equal 2, target_of(@user, @variant)
  end

  test "PUT com 3 atualiza o mesmo registro" do
    token = sign_in
    item = WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    assert_no_difference -> { WishlistItem.count } do
      wish("OP01-001", "tcgplayer:123", token, body: { target_quantity: 3 }.to_json)
    end
    assert_response :ok
    assert_equal 3, response.parsed_body.dig("data", "wishlist_target")
    assert_equal 3, item.reload.target_quantity
  end

  test "PUT com o mesmo alvo responde igual sem duplicar" do
    token = sign_in
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

    assert_no_difference -> { WishlistItem.count } do
      wish("OP01-001", "tcgplayer:123", token, body: { target_quantity: 2 }.to_json)
    end
    assert_response :ok
    assert_equal({ "data" => { "variant_code" => "tcgplayer:123", "wishlist_target" => 2 } },
                 response.parsed_body)
  end

  test "string só de dígitos é aceita como inteiro" do
    token = sign_in

    wish("OP01-001", "tcgplayer:123", token, body: { target_quantity: "3" }.to_json)

    assert_response :ok
    assert_equal 3, response.parsed_body.dig("data", "wishlist_target")
    assert_equal 3, target_of(@user, @variant)
  end

  [ 0, -1, 1.5, 2_147_483_648, "2147483648", "abc", "", "0", "1.5", "-2", " 2", nil, true, [ 2 ], { "a" => 1 } ].each do |value|
    test "target_quantity #{value.inspect} responde 422 validation_failed sem gravar" do
      token = sign_in
      WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 2)

      assert_no_difference -> { WishlistItem.count } do
        wish("OP01-001", "tcgplayer:123", token, body: { target_quantity: value }.to_json)
      end
      assert_response :unprocessable_entity
      assert_equal INVALID_TARGET, response.parsed_body
      assert_equal 2, target_of(@user, @variant)
    end
  end

  test "target_quantity ausente responde 422 validation_failed sem gravar" do
    token = sign_in

    assert_no_difference -> { WishlistItem.count } do
      wish("OP01-001", "tcgplayer:123", token, body: {}.to_json)
    end
    assert_response :unprocessable_entity
    assert_equal INVALID_TARGET, response.parsed_body
  end

  test "sem corpo responde 422 validation_failed sem gravar" do
    token = sign_in

    assert_no_difference -> { WishlistItem.count } do
      wish("OP01-001", "tcgplayer:123", token)
    end
    assert_response :unprocessable_entity
    assert_equal INVALID_TARGET, response.parsed_body
  end

  test "corpo JSON malformado responde 400 invalid_json sem gravar" do
    token = sign_in

    assert_no_difference -> { WishlistItem.count } do
      wish("OP01-001", "tcgplayer:123", token, body: "{target_quantity: ")
    end
    assert_response :bad_request
    assert_equal "invalid_json", response.parsed_body.dig("error", "code")
  end

  test "variant_code com dois pontos codificado e card_number com ponto são resolvidos" do
    token = sign_in

    wish("P.029", "tcgplayer:456", token, body: { target_quantity: 1 }.to_json)

    assert_response :ok
    assert_equal 1, target_of(@user, @promo_variant)
  end

  test "carta inexistente responde 404 not_found sem gravar" do
    token = sign_in

    assert_no_difference -> { WishlistItem.count } do
      wish("OP99-999", "tcgplayer:123", token, body: { target_quantity: 2 }.to_json)
    end
    assert_response :not_found
    assert_equal NOT_FOUND, response.parsed_body
  end

  test "variant_code de outra carta responde 404 not_found sem gravar" do
    token = sign_in

    assert_no_difference -> { WishlistItem.count } do
      wish("OP01-001", "tcgplayer:456", token, body: { target_quantity: 2 }.to_json)
    end
    assert_response :not_found
    assert_equal NOT_FOUND, response.parsed_body
  end

  test "sem sessão responde 401 unauthenticated sem gravar" do
    token = fetch_token

    assert_no_difference -> { WishlistItem.count } do
      wish("OP01-001", "tcgplayer:123", token, body: { target_quantity: 2 }.to_json)
    end
    assert_response :unauthorized
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
  end

  test "sem X-CSRF-Token responde 422 invalid_csrf_token sem gravar" do
    sign_in

    assert_no_difference -> { WishlistItem.count } do
      wish("OP01-001", "tcgplayer:123", nil, body: { target_quantity: 2 }.to_json)
    end
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")
  end

  test "user_id alheio no corpo e na query é ignorado" do
    token = sign_in

    wish("OP01-001", "tcgplayer:123", token,
         body: { target_quantity: 2, user_id: @other.id }.to_json, query: "?user_id=#{@other.id}")

    assert_response :ok
    assert_equal 2, target_of(@user, @variant)
    assert_nil target_of(@other, @variant)
  end

  test "não altera o desejo de outro usuário" do
    token = sign_in
    WishlistItem.create!(user: @other, card_variant: @variant, target_quantity: 4)

    wish("OP01-001", "tcgplayer:123", token, body: { target_quantity: 2 }.to_json)

    assert_equal 4, target_of(@other, @variant)
    assert_equal 2, target_of(@user, @variant)
  end

  test "nenhuma resposta do endpoint é redirect nem HTML" do
    token = sign_in

    [
      [ "OP01-001", "tcgplayer:123", { target_quantity: 2 }.to_json ],
      [ "OP01-001", "tcgplayer:123", { target_quantity: 0 }.to_json ],
      [ "OP99-999", "tcgplayer:123", { target_quantity: 2 }.to_json ],
      [ "OP01-001", "tcgplayer:123", "{target_quantity: " ]
    ].each do |number, code, body|
      wish(number, code, token, body: body)
      assert_not response.redirect?, "#{number} #{body}"
      assert_equal "application/json", response.media_type
    end
  end

  test "RecordNotUnique na primeira tentativa repete e grava o alvo" do
    token = sign_in
    original = WishlistItem.method(:find_or_initialize_by)
    calls = 0
    WishlistItem.define_singleton_method(:find_or_initialize_by) do |*args, **kwargs|
      calls += 1
      item = original.call(*args, **kwargs)
      item.define_singleton_method(:save!) { |*| raise ActiveRecord::RecordNotUnique, "duplicate" } if calls == 1
      item
    end

    begin
      wish("OP01-001", "tcgplayer:123", token, body: { target_quantity: 2 }.to_json)
    ensure
      WishlistItem.singleton_class.remove_method(:find_or_initialize_by)
    end

    assert_response :ok
    assert_equal 2, calls
    assert_equal 2, response.parsed_body.dig("data", "wishlist_target")
    assert_equal 2, target_of(@user, @variant)
  end
end
