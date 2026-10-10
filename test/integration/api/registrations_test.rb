require "test_helper"

class Api::RegistrationsTest < ActionDispatch::IntegrationTest
  VALID = { email: "robin@example.com", password: "poneglyph-1", password_confirmation: "poneglyph-1" }.freeze

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  def fetch_token
    get "/api/session"
    response.parsed_body.dig("data", "csrf_token")
  end

  def register(user, token = fetch_token)
    post "/api/registration", params: { user: user }.to_json,
         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }.compact
  end

  def assert_rejected(fields)
    assert_response :unprocessable_entity
    assert_equal "validation_failed", response.parsed_body.dig("error", "code")
    assert_equal fields, response.parsed_body.dig("error", "fields")
  end

  test "cadastro válido cria User e Session e devolve token novo" do
    old_token = fetch_token

    assert_difference [ -> { User.count }, -> { Session.count } ], 1 do
      register(VALID, old_token)
    end

    assert_response :created
    assert_equal VALID[:email], response.parsed_body.dig("data", "user", "email")
    assert_predicate response.parsed_body.dig("data", "csrf_token"), :present?
    assert_not_equal old_token, response.parsed_body.dig("data", "csrf_token")

    get "/api/session"
    assert_equal VALID[:email], response.parsed_body.dig("data", "user", "email")
  end

  test "o token devolvido é aceito e o anterior recusado" do
    old_token = fetch_token
    register(VALID, old_token)
    new_token = response.parsed_body.dig("data", "csrf_token")

    delete "/api/session", headers: { "X-CSRF-Token" => old_token }
    assert_response :unprocessable_entity

    delete "/api/session", headers: { "X-CSRF-Token" => new_token }
    assert_response :ok
  end

  test "e-mail vazio" do
    assert_no_difference [ -> { User.count }, -> { Session.count } ] do
      register(VALID.merge(email: ""))
    end

    assert_rejected("email" => [ "não pode ficar em branco" ])
  end

  test "e-mail já usado com outra caixa" do
    User.create!(email: "robin@example.com", password: "poneglyph-1", password_confirmation: "poneglyph-1")

    assert_no_difference [ -> { User.count }, -> { Session.count } ] do
      register(VALID.merge(email: "ROBIN@Example.com"))
    end

    assert_rejected("email" => [ "já está em uso" ])
  end

  test "senha curta" do
    assert_no_difference [ -> { User.count }, -> { Session.count } ] do
      register(VALID.merge(password: "curta", password_confirmation: "curta"))
    end

    assert_rejected("password" => [ "é muito curto (mínimo: 8 caracteres)" ])
  end

  test "confirmação diferente" do
    assert_no_difference [ -> { User.count }, -> { Session.count } ] do
      register(VALID.merge(password_confirmation: "outra-senha-1"))
    end

    assert_rejected("password_confirmation" => [ "não é igual a Senha" ])
  end

  test "sem user ou com user não-hash é 422 validation_failed" do
    token = fetch_token

    [ {}, { user: "robin" }, { user: [ "x" ] } ].each do |body|
      assert_no_difference [ -> { User.count }, -> { Session.count } ] do
        post "/api/registration", params: body.to_json,
             headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
      end

      assert_response :unprocessable_entity
      assert_equal "validation_failed", response.parsed_body.dig("error", "code")
    end
  end

  test "sem token CSRF é 422 invalid_csrf_token e não cria nada" do
    assert_no_difference [ -> { User.count }, -> { Session.count } ] do
      post "/api/registration", params: { user: VALID }.to_json,
           headers: { "Content-Type" => "application/json" }
    end

    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", response.parsed_body.dig("error", "code")
  end
end
