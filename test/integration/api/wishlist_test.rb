require "test_helper"

class Api::WishlistTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-api-wishlist@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-wishlist@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster", base_set_size: 2)
    @seq = 0
    ImportRun.create!(source: "apitcg", source_revision: "wishlist.json", status: "succeeded",
                      started_at: 1.hour.ago)
  end

  def variant!
    @seq += 1
    card = Card.create!(card_set: @set, card_number: "OP01-#{format('%03d', @seq)}", name: "Carta #{@seq}",
                        card_type: "character", colors: [ "Blue" ], cost: 0, power: 2000, effect_text: "Efeito")
    CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:#{@seq}", rarity: "R",
                        art_kind: "base", image_url: "https://cdn.example.com/#{@seq}.png",
                        last_seen_at: Time.current)
  end

  def want!(user, variant, target, created_at: Time.current)
    WishlistItem.create!(user: user, card_variant: variant, target_quantity: target, created_at: created_at)
  end

  def own!(user, variant, quantity)
    CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
  end

  def sign_in(user = @user)
    get "/api/session"
    token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
  end

  def wishlist(query = "")
    get "/api/wishlist#{query}"
    assert_response :ok
    assert_equal "application/json", response.media_type
    response.parsed_body.fetch("data")
  end

  test "lista os desejos na ordem de criação e id com atendido e não atendido" do
    exceeded, met, missing = variant!, variant!, variant!
    want!(@user, missing, 2, created_at: 3.hours.ago)
    want!(@user, exceeded, 2, created_at: 2.hours.ago)
    want!(@user, met, 2, created_at: 1.hour.ago)
    own!(@user, exceeded, 3)
    own!(@user, met, 2)
    sign_in

    assert_equal [
      { "card_number" => missing.card.card_number, "card_name" => missing.card.name,
        "variant_code" => missing.variant_code, "target_quantity" => 2, "owned_quantity" => 0,
        "fulfilled" => false },
      { "card_number" => exceeded.card.card_number, "card_name" => exceeded.card.name,
        "variant_code" => exceeded.variant_code, "target_quantity" => 2, "owned_quantity" => 3,
        "fulfilled" => true },
      { "card_number" => met.card.card_number, "card_name" => met.card.name,
        "variant_code" => met.variant_code, "target_quantity" => 2, "owned_quantity" => 2,
        "fulfilled" => true }
    ], wishlist
  end

  test "lista vazia devolve data vazio" do
    sign_in

    assert_equal [], wishlist
  end

  test "posse e desejos de outro usuário não vazam e user_id na query é ignorado" do
    shared = variant!
    other_only = variant!
    want!(@user, shared, 2)
    want!(@other, shared, 1)
    want!(@other, other_only, 1)
    own!(@other, shared, 5)
    sign_in

    data = wishlist("?user_id=#{@other.id}")

    assert_equal [ shared.variant_code ], data.map { |row| row["variant_code"] }
    assert_equal 0, data.first["owned_quantity"]
    assert_equal false, data.first["fulfilled"]
  end

  test "o número de consultas não depende da quantidade de itens" do
    want!(@user, variant!, 1)
    sign_in
    baseline = count_queries { wishlist }

    9.times { want!(@user, variant!, 2) }

    assert_equal baseline, count_queries { wishlist }
  end

  test "sem sessão responde 401 unauthenticated em JSON" do
    get "/api/wishlist"

    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
  end

  private
    def count_queries(&)
      count = 0
      counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
      count
    end
end
