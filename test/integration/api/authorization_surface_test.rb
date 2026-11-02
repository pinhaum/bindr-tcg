require "test_helper"
require "stringio"

# T7 (spa-troca) — a superfície de autorização da API não nomeia usuário (STRO-31):
# progresso, desejos e import partem sempre da sessão, e o token do import não se adivinha.
class Api::AuthorizationSurfaceTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  HEADER = "card_number,variant_code,card_name,quantity\n".freeze
  SCOPES = %w[/api/progress /api/wishlist /api/collection/imports].freeze
  USER_SEGMENT = /\A:(user|user_id|email|account|account_id|owner|owner_id)\z/

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: "nami-api-surface@example.com", password: PASSWORD)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def scoped_paths
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
      path if SCOPES.any? { |scope| path == scope || path.start_with?("#{scope}/") }
    end
  end

  def fetch_token
    get "/api/session"
    response.parsed_body.dig("data", "csrf_token")
  end

  def sign_in
    post "/api/session", params: { email: @user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => fetch_token }
    response.parsed_body.dig("data", "csrf_token")
  end

  def upload_token(csrf)
    file = Rack::Test::UploadedFile.new(StringIO.new(HEADER), "text/csv", original_filename: "colecao.csv")
    post "/api/collection/imports", params: { file: file }, headers: { "X-CSRF-Token" => csrf }
    assert_response :created
    response.parsed_body.dig("data", "token")
  end

  test "as rotas de progresso, desejos e import existem para cada escopo" do
    paths = scoped_paths

    SCOPES.each do |scope|
      assert paths.any? { |path| path.start_with?(scope) }, "nenhuma rota sob #{scope}"
    end
    assert_includes paths, "/api/collection/imports/:token/confirm"
  end

  test "nenhuma rota de progresso, desejos ou import tem segmento de usuário" do
    offenders = scoped_paths.select do |path|
      path.split("/").any? { |segment| segment.match?(USER_SEGMENT) }
    end

    assert_empty offenders, "rotas com segmento de usuário: #{offenders.join(', ')}"
  end

  test "o único segmento dinâmico das rotas de import é o token" do
    dynamic = scoped_paths.flat_map { |path| path.scan(/:\w+/) }.uniq

    assert_equal [ ":token" ], dynamic
  end

  test "o token do import tem ao menos 32 bytes urlsafe" do
    token = upload_token(sign_in)

    assert_match(/\A[A-Za-z0-9_-]+\z/, token)
    assert_operator Base64.urlsafe_decode64(token).bytesize, :>=, 32
  end

  test "dois uploads seguidos não dão tokens sequenciais nem o id do registro" do
    csrf = sign_in
    first = upload_token(csrf)
    second = upload_token(csrf)

    assert_not_equal first, second
    assert_not_equal first.succ, second
    assert_no_match(/\A\d+\z/, first)
    assert_no_match(/\A\d+\z/, second)
    ids = CollectionImport.for_user(@user).order(:id).pluck(:id).map(&:to_s)
    assert_empty ids & [ first, second ]
    assert_operator Base64.urlsafe_decode64(first).bytes.zip(Base64.urlsafe_decode64(second).bytes).count { |a, b| a != b }, :>, 1
  end
end
