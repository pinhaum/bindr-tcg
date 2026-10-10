require "test_helper"

class Api::CatalogTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-api-catalog@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-catalog@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @blue = card!("OP01-001", "Nami", "Blue")
    @red = card!("OP01-002", "Luffy", "Red")
    @green = card!("OP01-003", "Zoro", "Green")
    @blue_b = variant!(@blue, "tcgplayer:12")
    @blue_a = variant!(@blue, "tcgplayer:11")
    @red_v = variant!(@red, "tcgplayer:21")
    @green_v = variant!(@green, "tcgplayer:31")
    mark_catalog_present!
  end

  def card!(number, name, color)
    Card.create!(card_set: @set, card_number: number, name: name, card_type: "character", colors: [ color ],
                 cost: 1, power: 1000)
  end

  def variant!(card, code, **attrs)
    CardVariant.create!(card: card, card_set: @set, variant_code: code, rarity: "R", art_kind: "base",
                        image_url: "https://cdn.example.com/#{code}.png", **attrs)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def fetch(**params)
    get "/api/catalog", params: params
    response.parsed_body
  end

  def numbers(body) = body["data"].pluck("card_number")

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  test "API-18: mesma lista e ordem do CatalogQuery para um filtro de cor, com meta" do
    params = { colors: [ "Blue", "Red" ] }
    expected = CatalogQuery.new(params).call
    body = fetch(**params)

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal expected.records.map(&:card_number), numbers(body)
    assert_equal %w[OP01-001 OP01-002], numbers(body)
    assert_equal({ "page" => 1, "per_page" => 25, "total_count" => 2, "total_pages" => 1,
                   "active_filters" => expected.active_filters.deep_stringify_keys.as_json },
                 body["meta"])
  end

  test "API-18: paginação reflete page, per_page e total_pages" do
    body = fetch(per_page: 2, page: 2)

    assert_equal %w[OP01-003], numbers(body)
    assert_equal({ "page" => 2, "per_page" => 2, "total_count" => 3, "total_pages" => 2 },
                 body["meta"].except("active_filters"))
  end

  test "API-19: parâmetro desconhecido e valor inválido são ignorados com 200" do
    body = fetch(banana: "x", owned: "talvez", page: "abc", per_page: "-3")

    assert_response :ok
    assert_equal 1, body["meta"]["page"]
    assert_equal 25, body["meta"]["per_page"]
    assert_equal 3, body["meta"]["total_count"]
  end

  test "edge: per_page acima do teto reflete o máximo em meta.per_page" do
    assert_equal CatalogQuery::MAX_PER_PAGE, fetch(per_page: 500)["meta"]["per_page"]
  end

  test "API-20: owned=owned filtra pela coleção da sessão" do
    CollectionItem.create!(user: @user, card_variant: @red_v, quantity: 2)
    CollectionItem.create!(user: @other, card_variant: @green_v, quantity: 1)
    sign_in @user

    body = fetch(owned: "owned")

    assert_equal %w[OP01-002], numbers(body)
    assert_equal 2, body["data"].first["variants"].first["owned_quantity"]
  end

  test "API-20: owned=missing filtra pelo que o usuário da sessão não tem" do
    CollectionItem.create!(user: @user, card_variant: @red_v, quantity: 1)
    sign_in @user

    assert_equal %w[OP01-001 OP01-003], numbers(fetch(owned: "missing"))
  end

  test "API-20: sem sessão, owned é ignorado e a posse sai null" do
    CollectionItem.create!(user: @user, card_variant: @red_v, quantity: 2)

    body = fetch(owned: "owned")

    assert_response :ok
    assert_equal %w[OP01-001 OP01-002 OP01-003], numbers(body)
    assert_nil body["data"].flat_map { |c| c["variants"] }.first["owned_quantity"]
  end

  test "API-20: user_id nos parâmetros não muda a coleção lida" do
    CollectionItem.create!(user: @other, card_variant: @green_v, quantity: 1)
    sign_in @user

    assert_empty numbers(fetch(owned: "owned", user_id: @other.id))

    delete session_path
    assert_equal %w[OP01-001 OP01-002 OP01-003], numbers(fetch(owned: "owned", user_id: @other.id))
  end

  test "API-21: variante ausente da fonte fica fora de variants e as presentes saem por variant_code" do
    ghost = variant!(@blue, "tcgplayer:10", last_seen_at: CATALOG_SEEN_AT - 1.day)

    blue = fetch["data"].find { |c| c["card_number"] == "OP01-001" }

    assert_equal %w[tcgplayer:11 tcgplayer:12], blue["variants"].pluck("variant_code")
    assert_not_includes blue["variants"].pluck("variant_code"), ghost.variant_code
  end

  test "API-26: a lista é pública e o anônimo recebe JSON" do
    get "/api/catalog"

    assert_response :ok
    assert_equal "application/json", response.media_type
  end

  test "o número de consultas não cresce com o número de cartas" do
    sign_in @user
    CollectionItem.create!(user: @user, card_variant: @red_v, quantity: 1)
    get "/api/catalog"
    with_three = count_queries { get "/api/catalog" }

    4.upto(9) do |n|
      card = card!("OP01-00#{n}", "Carta #{n}", "Blue")
      variant!(card, "tcgplayer:#{n}0")
      variant!(card, "tcgplayer:#{n}1")
    end
    mark_catalog_present!
    with_nine = count_queries { get "/api/catalog" }

    assert_equal 9, response.parsed_body["data"].size
    assert_equal with_three, with_nine
  end
end
