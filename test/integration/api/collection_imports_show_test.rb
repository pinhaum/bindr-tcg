require "test_helper"
require "stringio"

# GET /api/collection/imports/:token (SPOR-38, SPOR-39, SPOR-43, SPOR-44): relê
# a pré-visualização gravada pelo envio, sem prazo e sem tocar em `collection_items`.
class Api::CollectionImportsShowTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  HEADER = "card_number,variant_code,card_name,quantity\n".freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-api-show@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-show@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def variant!(number, code = "tcgplayer:#{number}")
    card = Card.find_by(card_number: number) ||
      Card.create!(card_set: @set, card_number: number, name: "Carta #{number}", card_type: "character",
                   colors: [ "Blue" ], cost: 0, power: 2000, effect_text: "Efeito")
    CardVariant.create!(card: card, card_set: @set, variant_code: code, rarity: "R", art_kind: "base",
                        image_url: "https://cdn.example.com/#{code}.png", last_seen_at: Time.current)
  end

  def csrf
    get "/api/session"
    response.parsed_body.dig("data", "csrf_token")
  end

  def sign_in(user = @user)
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => csrf }
    response.parsed_body.dig("data", "csrf_token")
  end

  def upload(content)
    token = sign_in
    file = Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "colecao.csv")
    post "/api/collection/imports", params: { file: file }, headers: { "X-CSRF-Token" => token }
    assert_response :created
    response.parsed_body.dig("data", "token")
  end

  def assert_not_found
    assert_response :not_found
    assert_equal "application/json", response.media_type
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "devolve o mesmo data do 201 e continua 200 com o staging vencido" do
    variant!("OP01-001")
    variant!("OP01-002")
    CollectionItem.create!(user: @user, card_variant: variant!("OP01-003"), quantity: 1)
    csv = HEADER + "OP01-001,tcgplayer:OP01-001,Carta,2\nOP01-003,tcgplayer:OP01-003,Carta,0\nOP01-999,x,Y,1\n"
    token = upload(csv)
    criado = response.parsed_body["data"]

    assert_no_changes -> { CollectionItem.pluck(:id, :quantity).sort } do
      get "/api/collection/imports/#{token}"
      assert_response :ok
      assert_equal "application/json", response.media_type
      assert_equal criado, response.parsed_body["data"]

      travel 3.hours do
        get "/api/collection/imports/#{token}"
        assert_response :ok
        assert_equal criado, response.parsed_body["data"]
      end
    end
  end

  test "token de outro usuário, inexistente e malformado dão o mesmo 404" do
    token = upload(HEADER + "OP01-001,x,Y,1\n")
    sign_in(@other)

    get "/api/collection/imports/#{token}"
    assert_not_found
    corpo = response.parsed_body

    get "/api/collection/imports/inexistente"
    assert_not_found
    assert_equal corpo, response.parsed_body

    get "/api/collection/imports/%2F..%2Fx"
    assert_not_found
    assert_equal corpo, response.parsed_body
  end

  test "sem sessão responde 401 e user_id alheio é ignorado" do
    token = upload(HEADER + "OP01-001,x,Y,1\n")
    delete "/api/session", headers: { "X-CSRF-Token" => csrf_after_login }

    get "/api/collection/imports/#{token}"
    assert_response :unauthorized
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")

    sign_in(@other)
    get "/api/collection/imports/#{token}?user_id=#{@user.id}"
    assert_not_found
  end

  test "o número de consultas é o mesmo com 2 e com 200 linhas" do
    (1..200).each { |i| variant!("OP01-#{i}", "tcgplayer:#{i}") }
    pequeno = upload(HEADER + (1..2).map { |i| "OP01-#{i},tcgplayer:#{i},X,1\n" }.join)
    grande = upload(HEADER + (1..200).map { |i| "OP01-#{i},tcgplayer:#{i},X,1\n" }.join)

    consultas_pequeno = count_queries { get "/api/collection/imports/#{pequeno}" }
    assert_response :ok
    consultas_grande = count_queries { get "/api/collection/imports/#{grande}" }
    assert_response :ok

    assert_equal consultas_pequeno, consultas_grande
  end

  private

    def csrf_after_login
      get "/api/session"
      response.parsed_body.dig("data", "csrf_token")
    end

    def count_queries(&block)
      contador = 0
      assinatura = lambda do |_name, _start, _finish, _id, payload|
        contador += 1 unless payload[:name] == "SCHEMA"
      end
      ActiveSupport::Notifications.subscribed(assinatura, "sql.active_record", &block)
      contador
    end
end
