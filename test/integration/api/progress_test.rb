require "test_helper"

class Api::ProgressTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nami-api-progress@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-progress@example.com", password: PASSWORD)
    @seq = 0
    ImportRun.create!(source: "apitcg", source_revision: "progress.json", status: "succeeded",
                      started_at: 1.hour.ago)
  end

  def set!(code, base_set_size: nil)
    CardSet.create!(code: code, name: "Set #{code}", kind: "booster", base_set_size: base_set_size)
  end

  def variant!(set, art_kind: "base", price: nil, currency: "USD")
    @seq += 1
    card = Card.create!(card_set: set, card_number: "#{set.code}-#{format('%03d', @seq)}", name: "Carta #{@seq}",
                        card_type: "character", colors: [ "Blue" ], cost: 0, power: 2000, effect_text: "Efeito")
    attrs = { card: card, card_set: set, variant_code: "tcgplayer:#{@seq}", rarity: "R", art_kind: art_kind,
              image_url: "https://cdn.example.com/#{@seq}.png", last_seen_at: Time.current }
    attrs.merge!(price_amount: price, price_currency: currency, price_observed_at: Time.current) if price
    CardVariant.create!(attrs)
  end

  def own!(user, variant, quantity = 1)
    CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
  end

  def sign_in(user = @user)
    get "/api/session"
    token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
  end

  def progress(query = "")
    get "/api/progress#{query}"
    assert_response :ok
    assert_equal "application/json", response.media_type
    response.parsed_body.fetch("data")
  end

  def money(value)
    { "amount" => format("%.2f", value), "currency" => "USD" }
  end

  test "cada usuário recebe o resumo e as linhas de SetProgressQuery e collection_stats_for" do
    op01 = set!("OP01", base_set_size: 4)
    op02 = set!("OP02", base_set_size: 3)
    a1 = variant!(op01, price: "2.50")
    a2 = variant!(op01, art_kind: "parallel", price: "10.00")
    variant!(op01)
    b1 = variant!(op02)
    own!(@user, a1, 2)
    own!(@user, a2)
    own!(@other, b1, 3)

    [ @user, @other ].each do |user|
      reset!
      sign_in(user)
      data = progress
      stats = CollectionItem.collection_stats_for(user)
      rows = SetProgressQuery.new(user).call

      assert_equal({ "total_copies" => stats[:total_copies], "distinct_variants" => stats[:distinct_variants],
                     "estimated_value" => money(stats[:estimated_value]),
                     "unpriced_copies" => stats[:unpriced_copies] }, data["summary"])
      assert_equal rows.map(&:set_code), data["sets"].map { |s| s["code"] }
      rows.zip(data["sets"]).each do |row, set|
        assert_equal row.set_name, set["name"]
        assert_equal row.displayed_owned_numbers, set["owned_numbers"]
        assert_equal row.base_size, set["base_size"]
        assert_equal row.parallel_owned_variants, set["parallel_owned"]
        assert_equal row.parallel_variants, set["parallel_total"]
        assert_equal money(stats[:value_by_set_id].fetch(row.set_id, 0)), set["value"]
      end
    end
  end

  test "sem cópia com preço o valor do set é 0.00" do
    op01 = set!("OP01", base_set_size: 2)
    own!(@user, variant!(op01))
    sign_in

    data = progress

    assert_equal money(0), data["sets"].first["value"]
    assert_equal money(0), data["summary"]["estimated_value"]
    assert_equal 1, data["summary"]["unpriced_copies"]
  end

  test "preço em moeda diferente de USD fica fora do valor" do
    op01 = set!("OP01", base_set_size: 2)
    own!(@user, variant!(op01, price: "9.99", currency: "EUR"))
    own!(@user, variant!(op01, price: "1.00"))
    sign_in

    data = progress

    assert_equal money(1), data["summary"]["estimated_value"]
    assert_equal money(1), data["sets"].first["value"]
  end

  test "order ausente, desconhecido, vazio ou em lista vira recent" do
    sign_in
    [ "", "?order=xyz", "?order=", "?order[]=code" ].each do |query|
      assert_equal "recent", progress(query)["order"], query
    end
  end

  test "order=code devolve a ordem por código" do
    zed = set!("OP09", base_set_size: 1)
    abc = set!("OP01", base_set_size: 1)
    own!(@user, variant!(abc))
    travel_to 1.minute.from_now
    own!(@user, variant!(zed))
    sign_in

    assert_equal %w[OP09 OP01], progress("?order=recent")["sets"].map { |s| s["code"] }
    data = progress("?order=code")
    travel_back

    assert_equal "code", data["order"]
    assert_equal %w[OP01 OP09], data["sets"].map { |s| s["code"] }
  end

  test "base_size nulo ou zero sai null e sem percentual" do
    own!(@user, variant!(set!("OP01", base_set_size: nil)))
    own!(@user, variant!(set!("OP02", base_set_size: 0)))
    sign_in

    progress("?order=code")["sets"].each do |set|
      assert_nil set["base_size"]
      assert_nil set["completion_percent"]
      assert_equal 1, set["owned_numbers"]
    end
  end

  test "posse acima do base_size é limitada ao base_size com 100%" do
    op01 = set!("OP01", base_set_size: 1)
    own!(@user, variant!(op01))
    own!(@user, variant!(op01))
    sign_in

    set = progress["sets"].first

    assert_equal 1, set["base_size"]
    assert_equal 1, set["owned_numbers"]
    assert_equal 100, set["completion_percent"]
  end

  test "percentual arredonda meio para cima como a página HTML" do
    op01 = set!("OP01", base_set_size: 8)
    variants = Array.new(8) { variant!(op01) }
    sign_in

    own!(@user, variants.first)
    assert_equal 13, progress["sets"].first["completion_percent"]

    variants[1..6].each { |v| own!(@user, v) }
    assert_equal 88, progress["sets"].first["completion_percent"]
  end

  test "o número de consultas não cresce com sets nem com itens" do
    sign_in
    small = set!("OP01", base_set_size: 2)
    own!(@user, variant!(small))
    progress
    baseline = count_queries { progress }

    18.times { |i| variant!(set!("OP#{format('%02d', i + 2)}", base_set_size: 2)) }
    9.times { own!(@user, variant!(small, price: "1.00")) }

    assert_equal baseline, count_queries { progress }
  end

  test "sem sessão responde 401 unauthenticated em JSON" do
    get "/api/progress"

    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
  end

  test "user_id de outro usuário na query é ignorado" do
    op01 = set!("OP01", base_set_size: 2)
    own!(@other, variant!(op01))
    sign_in

    data = progress("?user_id=#{@other.id}")

    assert_equal 0, data["summary"]["total_copies"]
    assert_equal 0, data["sets"].first["owned_numbers"]
  end

  private
    def count_queries(&)
      count = 0
      counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
      count
    end
end
