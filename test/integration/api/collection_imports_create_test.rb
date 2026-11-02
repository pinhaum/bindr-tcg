require "test_helper"
require "stringio"

# POST /api/collection/imports (SPOR-36, SPOR-37, SPOR-43, SPOR-44): recebe o
# CSV, grava só a pré-visualização e nunca toca em `collection_items`.
class Api::CollectionImportsCreateTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  GENERAL = "O arquivo não foi importado. Sua coleção não foi alterada.".freeze
  HEADER = "card_number,variant_code,card_name,quantity\n".freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-api-import@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-import@example.com", password: PASSWORD)
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

  def own!(user, variant, quantity)
    CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
  end

  def fetch_token
    get "/api/session"
    response.parsed_body.dig("data", "csrf_token")
  end

  def sign_in(user = @user)
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => fetch_token }
    response.parsed_body.dig("data", "csrf_token")
  end

  def csv_file(content, name: "colecao.csv")
    Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: name)
  end

  def upload(content, token, name: "colecao.csv", extra: {}, query: "")
    post "/api/collection/imports#{query}",
         params: { file: csv_file(content, name: name) }.merge(extra),
         headers: { "X-CSRF-Token" => token }.compact
  end

  def assert_refused(fragment = nil)
    assert_response :unprocessable_entity
    assert_equal "application/json", response.media_type
    error = response.parsed_body["error"]
    assert_equal "validation_failed", error["code"]
    assert_equal GENERAL, error["message"]
    assert_includes error["fields"]["file"].first, fragment if fragment
  end

  test "envio aceito responde 201 com as cinco classificações na ordem do arquivo" do
    zera = variant!("OP01-001")
    cria = variant!("OP01-002")
    atualiza = variant!("OP01-003")
    igual = variant!("OP01-004")
    own!(@user, zera, 3)
    own!(@user, atualiza, 1)
    own!(@user, igual, 2)
    token = sign_in
    csv = HEADER + \
      "OP01-001,tcgplayer:OP01-001,Carta,0\n" \
      "OP01-002,tcgplayer:OP01-002,Carta,2\n" \
      "OP01-003,tcgplayer:OP01-003,Carta,5\n" \
      "OP01-999,tcgplayer:OP01-999,Fantasma,1\n" \
      "OP01-004,tcgplayer:OP01-004,Carta,2\n"

    assert_no_changes -> { CollectionItem.pluck(:id, :card_variant_id, :quantity).sort } do
      assert_difference -> { CollectionImport.for_user(@user).count }, 1 do
        upload(csv, token, name: "../minha coleção.csv")
      end
    end

    assert_response :created
    assert_equal "application/json", response.media_type
    data = response.parsed_body["data"]
    preview = CollectionImport.for_user(@user).last
    assert_equal preview.token, data["token"]
    assert_equal "minha_coleção.csv", data["filename"]
    rows = data["rows"]
    assert_equal %w[removes creates updates rejected unchanged], rows.map { |r| r["classification"] }
    assert_equal [ 2, 3, 4, 5, 6 ], rows.map { |r| r["line"] }
    assert_equal [ 3, nil, 1, nil, 2 ], rows.map { |r| r["quantity_before"] }
    assert_equal [ 0, 2, 5, nil, 2 ], rows.map { |r| r["quantity_after"] }
    assert_equal %w[OP01-001 OP01-002 OP01-003 OP01-999 OP01-004], rows.map { |r| r["card_number"] }
    assert_equal "tcgplayer:OP01-001", rows.first["variant_code"]
    assert_equal "Fantasma", rows[3]["card_name"]
    assert_equal [ nil, nil, nil, true, nil ], rows.map { |r| r["message"].present? || nil }
  end

  test "recusas do arquivo respondem 422 e não criam pré-visualização" do
    token = sign_in
    casos = {
      "vazio" => [ "", "O arquivo" ],
      "separador ;" => [ "card_number;variant_code;card_name;quantity\nOP01-001;x;y;1\n", nil ],
      "Latin-1" => [ "#{HEADER}OP01-001,tcgplayer:1,Ra\xE7a,1\n".b, nil ]
    }

    casos.each do |nome, (conteudo, _)|
      assert_no_difference -> { CollectionImport.count }, nome do
        upload(conteudo, token)
      end
      assert_refused
      assert_predicate response.parsed_body.dig("error", "fields", "file").first, :present?, nome
    end
  end

  test "sem arquivo, corpo JSON e arquivo como string recusam com a frase do HTML" do
    token = sign_in

    assert_no_difference -> { CollectionImport.count } do
      post "/api/collection/imports", headers: { "X-CSRF-Token" => token }
      assert_refused CollectionCsv::Upload::MISSING_FILE_MESSAGE

      post "/api/collection/imports", params: { file: "texto" }.to_json,
           headers: { "X-CSRF-Token" => token, "Content-Type" => "application/json" }
      assert_refused CollectionCsv::Upload::MISSING_FILE_MESSAGE

      post "/api/collection/imports", params: { file: "texto" }, headers: { "X-CSRF-Token" => token }
      assert_refused CollectionCsv::Upload::MISSING_FILE_MESSAGE
    end
  end

  test "Content-Length acima de 12 MB recusa com a frase de tamanho" do
    token = sign_in

    assert_no_difference -> { CollectionImport.count } do
      post "/api/collection/imports",
           params: { file: csv_file(HEADER) },
           headers: { "X-CSRF-Token" => token, "CONTENT_LENGTH" => (13 * 1024 * 1024).to_s }
    end
    assert_refused CollectionCsv::Upload::BODY_TOO_LARGE_MESSAGE
  end

  test "sem sessão responde 401 unauthenticated" do
    assert_no_difference -> { CollectionImport.count } do
      upload(HEADER, fetch_token)
    end

    assert_response :unauthorized
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
  end

  test "sem token CSRF responde 422 invalid_csrf_token" do
    sign_in

    assert_no_difference -> { CollectionImport.count } do
      upload(HEADER, nil)
    end

    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")
  end

  test "user_id no corpo ou na query é ignorado" do
    token = sign_in

    upload(HEADER, token, extra: { user_id: @other.id }, query: "?user_id=#{@other.id}")

    assert_response :created
    assert_equal 1, CollectionImport.for_user(@user).count
    assert_equal 0, CollectionImport.for_user(@other).count
  end

  test "o número de consultas é o mesmo com 2 e com 200 linhas" do
    token = sign_in
    pequeno = HEADER + (1..2).map { |i| "OP01-#{i},tcgplayer:#{i},X,1\n" }.join
    grande = HEADER + (1..200).map { |i| "OP01-#{i},tcgplayer:#{i},X,1\n" }.join

    (1..200).each { |i| variant!("OP01-#{i}", "tcgplayer:#{i}") }
    consultas_pequeno = count_queries { upload(pequeno, token) }
    assert_response :created
    consultas_grande = count_queries { upload(grande, token) }
    assert_response :created

    assert_equal consultas_pequeno, consultas_grande
  end

  private

    def count_queries(&block)
      contador = 0
      assinatura = lambda do |_name, _start, _finish, _id, payload|
        contador += 1 unless payload[:name] == "SCHEMA" || payload[:cached]
      end
      ActiveSupport::Notifications.subscribed(assinatura, "sql.active_record", &block)
      contador
    end
end
