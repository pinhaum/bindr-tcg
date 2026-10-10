require "test_helper"

class Api::SessionsTest < ActionDispatch::IntegrationTest
  CREDENTIALS = { email: "nami@example.com", password: "log-pose-77" }.freeze
  INVALID_BODY = { "error" => { "code" => "invalid_credentials", "message" => "E-mail ou senha inválidos.",
                                "fields" => {} } }.freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @user = User.create!(email: CREDENTIALS[:email], password: CREDENTIALS[:password],
                         password_confirmation: CREDENTIALS[:password])
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def json_headers(token = nil)
    { "Content-Type" => "application/json", "X-CSRF-Token" => token }.compact
  end

  def fetch_token
    get "/api/session"
    response.parsed_body.dig("data", "csrf_token")
  end

  def login(token = fetch_token, credentials = CREDENTIALS)
    post "/api/session", params: credentials.to_json, headers: json_headers(token)
  end

  def session_cookie_header
    Array(response.headers["Set-Cookie"]).join("\n")[/^session_id=.*$/i]
  end

  test "GET anônimo devolve user nil e um csrf_token" do
    get "/api/session"

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_nil response.parsed_body.dig("data", "user")
    assert_predicate response.parsed_body.dig("data", "csrf_token"), :present?
  end

  test "GET autenticado devolve o e-mail da sessão e um csrf_token" do
    login

    get "/api/session"

    assert_response :ok
    assert_equal CREDENTIALS[:email], response.parsed_body.dig("data", "user", "email")
    assert_predicate response.parsed_body.dig("data", "csrf_token"), :present?
  end

  test "login cria a Session, grava o cookie httponly samesite lax e devolve token novo" do
    old_token = fetch_token

    assert_difference -> { Session.count }, 1 do
      login(old_token)
    end

    assert_response :ok
    assert_equal CREDENTIALS[:email], response.parsed_body.dig("data", "user", "email")
    assert_not_equal old_token, response.parsed_body.dig("data", "csrf_token")
    assert_match(/httponly/i, session_cookie_header)
    assert_match(/samesite=lax/i, session_cookie_header)
  end

  test "credencial inválida responde 401 com o mesmo corpo, sem Session nem cookie" do
    token = fetch_token
    bodies = [ { email: "ninguem@example.com", password: "log-pose-77" },
               { email: CREDENTIALS[:email], password: "senha-errada-1" } ].map do |credentials|
      assert_no_difference -> { Session.count } do
        login(token, credentials)
      end
      assert_response :unauthorized
      assert_nil session_cookie_header
      response.parsed_body
    end

    assert_equal INVALID_BODY, bodies.first
    assert_equal bodies.first, bodies.last
  end

  test "campo ausente no login é 401 invalid_credentials" do
    token = fetch_token

    [ { email: CREDENTIALS[:email] }, { password: CREDENTIALS[:password] }, {} ].each do |credentials|
      login(token, credentials)

      assert_response :unauthorized
      assert_equal INVALID_BODY, response.parsed_body
    end
  end

  test "logout apaga a Session, remove o cookie e devolve user nil com token novo" do
    login
    token = fetch_token

    assert_difference -> { Session.count }, -1 do
      delete "/api/session", headers: json_headers(token)
    end

    assert_response :ok
    assert_nil response.parsed_body.dig("data", "user")
    assert_not_equal token, response.parsed_body.dig("data", "csrf_token")
    assert_match(/session_id=;/, session_cookie_header)
  end

  test "DELETE anônimo é 401 unauthenticated sem gravar return_to_after_authenticating" do
    token = fetch_token

    delete "/api/session", headers: json_headers(token)

    assert_response :unauthorized
    assert_equal "unauthenticated", response.parsed_body.dig("error", "code")
    assert_equal "Faça login para continuar.", response.parsed_body.dig("error", "message")

    login(fetch_token)
    assert_nil session[:return_to_after_authenticating]
  end

  test "mutação sem token é 422 invalid_csrf_token e não executa" do
    assert_no_difference -> { Session.count } do
      post "/api/session", params: CREDENTIALS.to_json, headers: json_headers
    end

    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")
    assert_nil session_cookie_header

    login
    assert_no_difference -> { Session.count } do
      delete "/api/session", headers: json_headers
    end
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")
  end

  test "token anterior é recusado e o novo aceito depois do login" do
    old_token = fetch_token
    login(old_token)
    new_token = response.parsed_body.dig("data", "csrf_token")

    delete "/api/session", headers: json_headers(old_token)
    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")

    delete "/api/session", headers: json_headers(new_token)
    assert_response :ok
  end

  test "token anterior é recusado e o novo aceito depois do logout" do
    login
    old_token = fetch_token
    delete "/api/session", headers: json_headers(old_token)
    new_token = response.parsed_body.dig("data", "csrf_token")

    post "/api/session", params: CREDENTIALS.to_json, headers: json_headers(old_token)
    assert_response :unprocessable_entity

    post "/api/session", params: CREDENTIALS.to_json, headers: json_headers(new_token)
    assert_response :ok
  end

  test "corpo JSON malformado é 400 invalid_json" do
    post "/api/session", params: "{nao-e-json", headers: json_headers(fetch_token)

    assert_response :bad_request
    assert_equal({ "error" => { "code" => "invalid_json", "message" => "Requisição inválida.", "fields" => {} } },
                 response.parsed_body)
  end

  test "login de quem já está logado troca a sessão" do
    login
    first_id = Session.find_by!(user: @user).id
    other = User.create!(email: "zoro@example.com", password: "santoryu-99", password_confirmation: "santoryu-99")

    login(fetch_token, { email: "zoro@example.com", password: "santoryu-99" })

    assert_response :ok
    assert_equal "zoro@example.com", response.parsed_body.dig("data", "user", "email")
    assert_equal other.id, Session.order(:created_at).last.user_id
    get "/api/session"
    assert_equal "zoro@example.com", response.parsed_body.dig("data", "user", "email")
    assert_not_equal first_id, Session.order(:created_at).last.id
  end

  test "fluxo: GET, login, GET autenticado, logout, GET anônimo" do
    token = fetch_token
    assert_nil response.parsed_body.dig("data", "user")

    login(token)
    assert_response :ok
    token = response.parsed_body.dig("data", "csrf_token")

    get "/api/session"
    assert_equal CREDENTIALS[:email], response.parsed_body.dig("data", "user", "email")

    delete "/api/session", headers: json_headers(token)
    assert_response :ok

    get "/api/session"
    assert_nil response.parsed_body.dig("data", "user")
  end
end
