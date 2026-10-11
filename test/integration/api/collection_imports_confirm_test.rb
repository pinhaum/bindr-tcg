require "test_helper"
require "stringio"

# POST /api/collection/imports/:token/confirm (SPOR-39..43, SPOR-45): a única
# escrita da API de import. Tudo é delegado a `CollectionCsv::Commit`.
class Api::CollectionImportsConfirmTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  HEADER = "card_number,variant_code,card_name,quantity\n".freeze
  MENSAGEM_409 = "Esta importação já foi confirmada ou expirou. " \
    "Sua coleção não foi alterada; envie o arquivo de novo se quiser importar.".freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-api-confirm@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-confirm@example.com", password: PASSWORD)
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

  def upload(content, token: sign_in)
    file = Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "colecao.csv")
    post "/api/collection/imports", params: { file: file }, headers: { "X-CSRF-Token" => token }
    assert_response :created
    response.parsed_body.dig("data", "token")
  end

  def confirm(token, csrf_token, **options)
    post "/api/collection/imports/#{token}/confirm", headers: { "X-CSRF-Token" => csrf_token }, **options
  end

  def snapshot
    CollectionItem.order(:id).pluck(:user_id, :card_variant_id, :quantity)
  end

  def assert_not_found
    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  def seed_collection(user)
    @a = variant!("OP01-001")
    @b = variant!("OP01-002")
    @c = variant!("OP01-003") unless CardVariant.exists?(variant_code: "tcgplayer:OP01-003")
    @c ||= CardVariant.find_by!(variant_code: "tcgplayer:OP01-003")
    CollectionItem.create!(user: user, card_variant: @b, quantity: 4)
    CollectionItem.create!(user: user, card_variant: @c, quantity: 1)
  end

  CSV_MISTO = HEADER +
    "OP01-001,tcgplayer:OP01-001,Carta,2\n" \
    "OP01-002,tcgplayer:OP01-002,Carta,4\n" \
    "OP01-003,tcgplayer:OP01-003,Carta,0\n" \
    "OP01-999,x,Desconhecida,1\n"

  test "200 traz o resumo e grava a coleção" do
    seed_collection(@user)
    token = upload(CSV_MISTO)

    confirm(token, csrf_after_login)

    assert_response :ok
    assert_equal "application/json", response.media_type
    data = response.parsed_body["data"]
    assert_equal "colecao.csv", data["filename"]
    assert_equal 1, data["created"]
    assert_equal 1, data["updated"]
    assert_equal 1, data["removed"]
    assert_equal 1, data["unchanged"]
    assert_equal 1, data["rejected"].size
    assert_equal({ "line" => 5, "card_number" => "OP01-999", "variant_code" => "x", "card_name" => "Desconhecida" },
                 data["rejected"].first.slice("line", "card_number", "variant_code", "card_name"))
    assert data["rejected"].first["message"].present?
    assert_equal [], data["failures"]
    assert_equal 2, CollectionItem.find_by(user: @user, card_variant: @a).quantity
    assert_equal 0, CollectionItem.find_by(user: @user, card_variant: @c).quantity
  end

  test "updated inclui removed e o resultado é igual ao da confirmação HTML" do
    seed_collection(@user)
    seed_collection_for_other = CollectionItem.create!(user: @other, card_variant: @b, quantity: 4)
    CollectionItem.create!(user: @other, card_variant: @c, quantity: 1)
    seed_collection_for_other
    csv = CSV_MISTO

    token = upload(csv)
    confirm(token, csrf_after_login)
    assert_response :ok
    assert_operator response.parsed_body.dig("data", "updated"), :>=, response.parsed_body.dig("data", "removed")

    delete "/api/session", headers: { "X-CSRF-Token" => csrf_after_login }
    ActionController::Base.allow_forgery_protection = false
    post session_path, params: { email: @other.email, password: PASSWORD }
    post collection_imports_path, params: { arquivo: Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "colecao.csv") }
    html_token = CollectionImport.order(:id).last.token
    post confirm_collection_import_path(html_token)
    assert_response :ok

    mine = CollectionItem.where(user: @user).order(:card_variant_id).pluck(:card_variant_id, :quantity)
    theirs = CollectionItem.where(user: @other).order(:card_variant_id).pluck(:card_variant_id, :quantity)
    assert_equal mine, theirs
  end

  test "file e linhas no corpo da confirmação são ignorados" do
    seed_collection(@user)
    token = upload(CSV_MISTO)
    esperado = nil
    esperado = CollectionItem.where(user: @user).count

    file = Rack::Test::UploadedFile.new(StringIO.new(HEADER + "OP01-001,tcgplayer:OP01-001,X,99\n"), "text/csv",
                                        original_filename: "outro.csv")
    confirm(token, csrf_after_login, params: { file: file, linhas: [ { card_number: "OP01-001", quantidade: 99 } ] })

    assert_response :ok
    assert_equal "colecao.csv", response.parsed_body.dig("data", "filename")
    assert_equal 2, CollectionItem.find_by(user: @user, card_variant: @a).quantity
    assert_equal esperado + 1, CollectionItem.where(user: @user).count
  end

  test "o resumo traz o que o Commit gravou quando a coleção mudou depois da leitura" do
    seed_collection(@user)
    token = upload(CSV_MISTO)
    token_csrf = csrf_after_login
    post "/api/cards/OP01-002/variants/tcgplayer:OP01-002/increment", headers: { "X-CSRF-Token" => token_csrf }
    assert_response :ok
    token_csrf = response.parsed_body.dig("data", "csrf_token") || csrf_after_login

    confirm(token, token_csrf)

    assert_response :ok
    data = response.parsed_body["data"]
    assert_equal 1, data["created"]
    assert_equal 1, data["removed"]
    assert_equal 4, CollectionItem.find_by(user: @user, card_variant: @b).quantity
  end

  test "falha forçada no upsert aparece em failures com line, card_number e variant_code" do
    seed_collection(@user)
    token = upload(CSV_MISTO)
    original = CollectionCsv::Commit.instance_method(:upsert)
    alvo = @a.id
    CollectionCsv::Commit.define_method(:upsert) do |linha|
      raise "bug" if linha.card_variant_id == alvo
      original.bind_call(self, linha)
    end

    begin
      confirm(token, csrf_after_login)
    ensure
      CollectionCsv::Commit.define_method(:upsert, original)
    end

    assert_response :ok
    assert_equal [ { "line" => 2, "card_number" => "OP01-001", "variant_code" => "tcgplayer:OP01-001" } ],
                 response.parsed_body.dig("data", "failures")
    assert_nil CollectionItem.find_by(user: @user, card_variant: @a)
  end

  test "segunda confirmação responde 409 import_closed e não altera a coleção" do
    seed_collection(@user)
    token = upload(CSV_MISTO)
    confirm(token, csrf_after_login)
    assert_response :ok

    assert_no_changes -> { snapshot } do
      confirm(token, csrf_after_login)
    end
    assert_response :conflict
    assert_equal "import_closed", response.parsed_body.dig("error", "code")
    assert_equal MENSAGEM_409, response.parsed_body.dig("error", "message")
  end

  test "staging vencido responde 409 e não altera a coleção" do
    seed_collection(@user)
    token = upload(CSV_MISTO)

    CollectionImport.find_by!(user: @user).update_column(:expires_at, 1.second.ago)

    assert_no_changes -> { snapshot } do
      confirm(token, csrf_after_login)
    end
    assert_response :conflict
    assert_equal "import_closed", response.parsed_body.dig("error", "code")
  end

  test "token alheio e inexistente dão o mesmo 404 sem gravar" do
    seed_collection(@user)
    token = upload(CSV_MISTO)
    sign_in(@other)

    assert_no_changes -> { snapshot } do
      confirm(token, csrf_after_login)
      assert_not_found
      corpo = response.parsed_body
      confirm("inexistente", csrf_after_login)
      assert_not_found
      assert_equal corpo, response.parsed_body
    end
    assert_equal "pendente", CollectionImport.find_by!(user: @user).status
  end

  test "sem sessão 401 e sem CSRF 422 invalid_csrf_token" do
    seed_collection(@user)
    token = upload(CSV_MISTO)
    sessao = csrf_after_login

    assert_no_changes -> { snapshot } do
      post "/api/collection/imports/#{token}/confirm"
      assert_response :unprocessable_entity
      assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")

      delete "/api/session", headers: { "X-CSRF-Token" => sessao }
      post "/api/collection/imports/#{token}/confirm", headers: { "X-CSRF-Token" => csrf }
      assert_response :unauthorized
      assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
    end
  end

  private

    def csrf_after_login
      get "/api/session"
      response.parsed_body.dig("data", "csrf_token")
    end
end
