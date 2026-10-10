require "test_helper"

class Api::CardsTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  OBSERVED_AT = Time.utc(2026, 10, 1, 23, 16)

  setup do
    @user = User.create!(email: "nami-api-cards@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-cards@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "OP01-001", name: "Nami", card_type: "character",
                         colors: [ "Blue" ], cost: 0, power: 2000, counter: nil,
                         effect_text: "Efeito", traits: [ "Straw Hat Crew" ])
    @base = variant!("tcgplayer:1", price_amount: BigDecimal("1.7"))
    @alt = variant!("tcgplayer:2", art_kind: "alternate_art", price_amount: BigDecimal("0"))
    @unpriced = variant!("tcgplayer:3", art_kind: "parallel")
    mark_catalog_present!
  end

  def variant!(code, card: @card, last_seen_at: CATALOG_SEEN_AT, price_amount: nil, **attrs)
    price = price_amount && { price_amount: price_amount, price_currency: "USD", price_observed_at: OBSERVED_AT }
    CardVariant.create!(card: card, card_set: @set, variant_code: code, rarity: "R", art_kind: "base",
                        image_url: "https://cdn.example.com/#{code}.png", last_seen_at: last_seen_at,
                        **attrs, **price.to_h)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def fetch(number = "OP01-001", **params)
    get "/api/cards/#{number}", params: params
    response.parsed_body
  end

  def variant_json(body, code) = body.dig("data", "variants").find { |v| v["variant_code"] == code }

  test "devolve a carta com envelope data, campos aplicáveis e variantes ordenadas por código" do
    body = fetch

    assert_response :ok
    assert_equal "application/json", response.media_type
    card = body["data"]
    assert_equal({ "card_number" => "OP01-001", "name" => "Nami", "card_type" => "character",
                   "colors" => [ "Blue" ], "cost" => 0, "life" => nil, "power" => 2000, "counter" => nil,
                   "block_icon" => nil, "attributes" => [], "traits" => [ "Straw Hat Crew" ],
                   "effect_text" => "Efeito", "trigger_text" => nil,
                   "set" => { "code" => "OP01", "name" => "Romance Dawn" } },
                 card.except("variants", "featured_variant_code"))
    assert_equal %w[tcgplayer:1 tcgplayer:2 tcgplayer:3], card["variants"].pluck("variant_code")
  end

  test "carta e variante são objetos distintos: a variante não repete campos da carta" do
    variant = variant_json(fetch, "tcgplayer:1")

    assert_equal %w[art_kind illustrator image_url in_source owned_quantity price rarity set variant_code
                    wishlist_target],
                 variant.keys.sort
    assert_equal({ "code" => "OP01", "name" => "Romance Dawn" }, variant["set"])
  end

  test "preço: 1.70, 0.00 e null, com moeda e data ISO 8601 UTC" do
    body = fetch

    assert_equal({ "amount" => "1.70", "currency" => "USD", "observed_at" => "2026-10-01T23:16:00Z" },
                 variant_json(body, "tcgplayer:1")["price"])
    assert_equal "0.00", variant_json(body, "tcgplayer:2").dig("price", "amount")
    assert_nil variant_json(body, "tcgplayer:3")["price"]
  end

  test "image_url é o caminho do app, também com dois-pontos no código" do
    assert_equal "/card_images/tcgplayer:1", variant_json(fetch, "tcgplayer:1")["image_url"]
  end

  test "variante sem imagem na fonte sai com image_url null" do
    @unpriced.update!(image_url: nil)

    assert_nil variant_json(fetch, "tcgplayer:3")["image_url"]
  end

  test "anônimo vê owned_quantity e wishlist_target null" do
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 2)
    variant = variant_json(fetch, "tcgplayer:1")

    assert_nil variant["owned_quantity"]
    assert_nil variant["wishlist_target"]
  end

  test "dois usuários veem só a própria posse e wishlist" do
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 2)
    WishlistItem.create!(user: @user, card_variant: @alt, target_quantity: 3)
    CollectionItem.create!(user: @other, card_variant: @base, quantity: 7)

    sign_in(@user)
    body = fetch
    assert_equal 2, variant_json(body, "tcgplayer:1")["owned_quantity"]
    assert_equal 0, variant_json(body, "tcgplayer:2")["owned_quantity"]
    assert_equal 3, variant_json(body, "tcgplayer:2")["wishlist_target"]
    assert_nil variant_json(body, "tcgplayer:1")["wishlist_target"]

    sign_in(@other)
    body = fetch
    assert_equal 7, variant_json(body, "tcgplayer:1")["owned_quantity"]
    assert_nil variant_json(body, "tcgplayer:2")["wishlist_target"]
  end

  test "variante ausente da fonte só aparece, com in_source false, para quem a retém" do
    absent = variant!("tcgplayer:9", last_seen_at: CATALOG_SEEN_AT - 1.day)
    CollectionItem.create!(user: @user, card_variant: absent, quantity: 1)

    assert_not_includes fetch["data"]["variants"].pluck("variant_code"), "tcgplayer:9"

    sign_in(@other)
    assert_not_includes fetch["data"]["variants"].pluck("variant_code"), "tcgplayer:9"

    sign_in(@user)
    body = fetch
    assert_equal false, variant_json(body, "tcgplayer:9")["in_source"]
    assert_equal true, variant_json(body, "tcgplayer:1")["in_source"]
  end

  test "AC-23: variante ausente retida só pela wishlist aparece com in_source false só para o dono" do
    absent = variant!("tcgplayer:9", last_seen_at: CATALOG_SEEN_AT - 1.day)
    WishlistItem.create!(user: @user, card_variant: absent, target_quantity: 2)

    assert_not_includes fetch["data"]["variants"].pluck("variant_code"), "tcgplayer:9"

    sign_in(@other)
    assert_not_includes fetch["data"]["variants"].pluck("variant_code"), "tcgplayer:9"

    sign_in(@user)
    body = fetch
    assert_equal false, variant_json(body, "tcgplayer:9")["in_source"]
    assert_equal 2, variant_json(body, "tcgplayer:9")["wishlist_target"]
  end

  test "featured_variant_code segue o CNF-42" do
    assert_equal "tcgplayer:1", fetch["data"]["featured_variant_code"]
    assert_equal "tcgplayer:2", fetch(variant: "tcgplayer:2")["data"]["featured_variant_code"]
    assert_equal "tcgplayer:1", fetch(variant: "lixo")["data"]["featured_variant_code"]
  end

  test "variante pedida de outra carta cai no padrão" do
    other = Card.create!(card_set: @set, card_number: "OP01-002", name: "Zoro", card_type: "character")
    variant!("tcgplayer:20", card: other)
    mark_catalog_present!

    assert_equal "tcgplayer:1", fetch(variant: "tcgplayer:20")["data"]["featured_variant_code"]
  end

  test "carta inexistente é 404 not_found" do
    fetch("XX99-999")

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "carta com todas as variantes ocultas é 404 not_found" do
    CardVariant.where(card: @card).update_all(last_seen_at: CATALOG_SEEN_AT - 1.day)

    fetch

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "card_number com ponto responde JSON e não vira formato" do
    dotted = Card.create!(card_set: @set, card_number: "P.029", name: "Luffy", card_type: "leader")
    variant!("tcgplayer:30", card: dotted)
    mark_catalog_present!

    get "/api/cards/P.029"

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal "P.029", response.parsed_body.dig("data", "card_number")
  end

  test "o detalhe não consulta por variante" do
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get "/api/cards/OP01-001" }
    baseline = count

    10.times { |i| variant!("tcgplayer:4#{i}") }
    mark_catalog_present!
    count = 0
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get "/api/cards/OP01-001" }

    assert_equal baseline, count
  end
end
