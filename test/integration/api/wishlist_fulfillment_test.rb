require "test_helper"

# Atendimento da lista de desejos pela API (STRO-31): "atendido" é derivado da
# posse na consulta, nunca gravado, e é por variante.
class Api::WishlistFulfillmentTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-api-fulfillment@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster", base_set_size: 2)
    ImportRun.create!(source: "apitcg", source_revision: "fulfillment.json", status: "succeeded",
                      started_at: 1.hour.ago)
    @card = Card.create!(card_set: @set, card_number: "OP01-001", name: "Monkey D. Luffy",
                         card_type: "character", colors: [ "Red" ], cost: 3, power: 5000, effect_text: "Efeito")
    @base = variant!("tcgplayer:1", "base")
    @parallel = variant!("tcgplayer:2", "parallel")
  end

  def variant!(code, art_kind)
    CardVariant.create!(card: @card, card_set: @set, variant_code: code, rarity: "R", art_kind: art_kind,
                        image_url: "https://cdn.example.com/#{code}.png", last_seen_at: Time.current)
  end

  def sign_in
    get "/api/session"
    token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: @user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
    response.parsed_body.dig("data", "csrf_token")
  end

  def rows
    get "/api/wishlist"
    assert_response :ok
    response.parsed_body.fetch("data")
  end

  def row_for(variant)
    rows.find { |row| row["variant_code"] == variant.variant_code }
  end

  test "alvo 2 com posse 1 não está atendido" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 1)
    sign_in

    row = row_for(@base)

    assert_equal 1, row["owned_quantity"]
    assert_equal false, row["fulfilled"]
  end

  test "posse registrada em zero não atende o desejo" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 1)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 0)
    sign_in

    row = row_for(@base)

    assert_equal 0, row["owned_quantity"]
    assert_equal false, row["fulfilled"]
  end

  test "sem registro de posse o desejo continua listado como não atendido" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    sign_in

    row = row_for(@base)

    assert_equal 0, row["owned_quantity"]
    assert_equal false, row["fulfilled"]
  end

  test "posse de outra variante da mesma carta não atende o desejo" do
    WishlistItem.create!(user: @user, card_variant: @parallel, target_quantity: 1)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 4)
    sign_in

    row = row_for(@parallel)

    assert_equal 0, row["owned_quantity"]
    assert_equal false, row["fulfilled"]
  end

  test "mudar a posse muda o atendimento sem escrita em wishlist_items" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 1)
    token = sign_in
    assert_equal false, row_for(@base)["fulfilled"]

    assert_no_changes -> { WishlistItem.pluck(:id, :target_quantity, :updated_at) } do
      post "/api/cards/#{@card.card_number}/variants/#{ERB::Util.url_encode(@base.variant_code)}/increment",
           headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
      assert_response :ok
    end

    row = row_for(@base)
    assert_equal 2, row["owned_quantity"]
    assert_equal true, row["fulfilled"]
  end

  test "variante que saiu da fonte continua listada" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    @base.update!(last_seen_at: 3.months.ago)
    @parallel.update!(last_seen_at: Time.current)
    sign_in

    data = rows

    assert_equal [ @base.variant_code ], data.map { |row| row["variant_code"] }
    assert CardVariant.exists?(@base.id)
  end
end
