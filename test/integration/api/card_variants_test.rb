require "test_helper"

class Api::CardVariantsTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  NOT_FOUND = { "error" => { "code" => "not_found", "message" => "Não encontrado.", "fields" => {} } }.freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-api-variants@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-variants@example.com", password: PASSWORD)
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

  def operate(operation, number, code, token, **options)
    post "/api/cards/#{number}/variants/#{ERB::Util.url_encode(code)}/#{operation}",
         headers: json_headers(token), **options
  end

  def quantity_of(user, variant)
    CollectionItem.find_by(user: user, card_variant: variant)&.quantity
  end

  test "increment sem registro cria a posse com 1 e o segundo soma para 2" do
    token = sign_in

    assert_difference -> { CollectionItem.count }, 1 do
      operate(:increment, "OP01-001", "tcgplayer:123", token)
    end
    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal({ "data" => { "variant_code" => "tcgplayer:123", "owned_quantity" => 1 } },
                 response.parsed_body)

    assert_no_difference -> { CollectionItem.count } do
      operate(:increment, "OP01-001", "tcgplayer:123", token)
    end
    assert_response :ok
    assert_equal 2, response.parsed_body.dig("data", "owned_quantity")
    assert_equal 2, quantity_of(@user, @variant)
  end

  test "decrement com 2 devolve 1 e grava" do
    token = sign_in
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 2)

    operate(:decrement, "OP01-001", "tcgplayer:123", token)

    assert_response :ok
    assert_equal({ "data" => { "variant_code" => "tcgplayer:123", "owned_quantity" => 1 } },
                 response.parsed_body)
    assert_equal 1, quantity_of(@user, @variant)
  end

  test "decrement com quantidade 0 devolve 0 e não altera o registro" do
    token = sign_in
    item = CollectionItem.create!(user: @user, card_variant: @variant, quantity: 0)

    operate(:decrement, "OP01-001", "tcgplayer:123", token)

    assert_response :ok
    assert_equal 0, response.parsed_body.dig("data", "owned_quantity")
    assert_equal 0, item.reload.quantity
  end

  test "decrement sem registro devolve 0 e não cria registro" do
    token = sign_in

    assert_no_difference -> { CollectionItem.count } do
      operate(:decrement, "OP01-001", "tcgplayer:123", token)
    end
    assert_response :ok
    assert_equal({ "data" => { "variant_code" => "tcgplayer:123", "owned_quantity" => 0 } },
                 response.parsed_body)
  end

  test "variant_code com dois pontos codificado e card_number com ponto são resolvidos" do
    token = sign_in

    operate(:increment, "P.029", "tcgplayer:456", token)

    assert_response :ok
    assert_equal "tcgplayer:456", response.parsed_body.dig("data", "variant_code")
    assert_equal 1, quantity_of(@user, @promo_variant)
  end

  test "carta inexistente responde 404 not_found sem gravar" do
    token = sign_in

    %i[increment decrement].each do |operation|
      assert_no_difference -> { CollectionItem.count } do
        operate(operation, "OP99-999", "tcgplayer:123", token)
      end
      assert_response :not_found
      assert_equal "application/json", response.media_type
      assert_equal NOT_FOUND, response.parsed_body
    end
  end

  test "variant_code de outra carta responde 404 not_found sem gravar" do
    token = sign_in

    %i[increment decrement].each do |operation|
      assert_no_difference -> { CollectionItem.count } do
        operate(operation, "OP01-001", "tcgplayer:456", token)
      end
      assert_response :not_found
      assert_equal NOT_FOUND, response.parsed_body
    end
  end

  test "sem sessão responde 401 unauthenticated sem gravar" do
    token = fetch_token

    %i[increment decrement].each do |operation|
      assert_no_difference -> { CollectionItem.count } do
        operate(operation, "OP01-001", "tcgplayer:123", token)
      end
      assert_response :unauthorized
      assert_equal "application/json", response.media_type
      assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
    end
  end

  test "sem X-CSRF-Token responde 422 invalid_csrf_token sem gravar" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 1)

    %i[increment decrement].each do |operation|
      operate(operation, "OP01-001", "tcgplayer:123", nil)
      assert_response :unprocessable_entity
      assert_equal "application/json", response.media_type
      assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")
    end
    assert_equal 1, quantity_of(@user, @variant)
  end

  test "user_id alheio no corpo e na query é ignorado" do
    token = sign_in

    post "/api/cards/OP01-001/variants/tcgplayer%3A123/increment?user_id=#{@other.id}",
         params: { user_id: @other.id }.to_json, headers: json_headers(token)

    assert_response :ok
    assert_equal 1, quantity_of(@user, @variant)
    assert_nil quantity_of(@other, @variant)
  end

  test "não altera a posse de outro usuário" do
    CollectionItem.create!(user: @other, card_variant: @variant, quantity: 5)
    token = sign_in

    operate(:decrement, "OP01-001", "tcgplayer:123", token)

    assert_response :ok
    assert_equal 0, response.parsed_body.dig("data", "owned_quantity")
    assert_equal 5, quantity_of(@other, @variant)
  end

  test "nenhuma resposta dos endpoints é redirect nem HTML" do
    token = sign_in

    [ [ :increment, "OP01-001", "tcgplayer:123" ], [ :decrement, "OP01-001", "tcgplayer:123" ],
      [ :increment, "OP99-999", "tcgplayer:123" ] ].each do |operation, number, code|
      operate(operation, number, code, token)
      assert_not_includes 300..399, response.status
      assert_equal "application/json", response.media_type
    end
  end
end
