require "test_helper"

class Api::ContractTest < ActionDispatch::IntegrationTest
  OLD_BROWSER = "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/50.0.2661.102 Safari/537.36"

  setup do
    @forgery = ActionController::Base.allow_forgery_protection
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
  end

  test "caminho inexistente sob /api responde 404 not_found em JSON para GET, POST e DELETE" do
    %i[get post delete].each do |verb|
      public_send(verb, "/api/nao-existe")

      assert_response :not_found, verb
      assert_equal "application/json", response.media_type, verb
      assert_equal({ "error" => { "code" => "not_found", "message" => "Não encontrado.", "fields" => {} } },
                   response.parsed_body, verb)
    end
  end

  test "POST em caminho inexistente sem token CSRF e com a proteção ligada continua 404" do
    ActionController::Base.allow_forgery_protection = true

    post "/api/nao-existe"

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "caminho aninhado inexistente também cai no catch-all" do
    get "/api/cards/OP01-001/nada/mais"

    assert_response :not_found
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "Accept text/html não muda o formato" do
    get "/api/nao-existe", headers: { "Accept" => "text/html" }

    assert_response :not_found
    assert_equal "application/json", response.media_type
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "caminho com extensão .html continua JSON" do
    get "/api/nao-existe.html"

    assert_response :not_found
    assert_equal "application/json", response.media_type
    assert_equal "not_found", response.parsed_body.dig("error", "code")
  end

  test "navegador antigo recebe 406 unsupported_browser em JSON" do
    get "/api/nao-existe", headers: { "User-Agent" => OLD_BROWSER }

    assert_response :not_acceptable
    assert_equal "application/json", response.media_type
    assert_equal "unsupported_browser", response.parsed_body.dig("error", "code")
    assert_equal({}, response.parsed_body.dig("error", "fields"))
    assert_kind_of String, response.parsed_body.dig("error", "message")
  end

  test "as rotas HTML não são afetadas pelo escopo /api" do
    get "/up"

    assert_response :success
    assert_equal "text/html", response.media_type
  end

  test "exceção inesperada responde 500 internal_error genérico e é logada" do
    log = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)
    begin
      with_failing_show(RuntimeError.new("segredo-interno")) { get "/api/qualquer" }
    ensure
      Rails.logger = original_logger
    end

    assert_response :internal_server_error
    assert_equal "internal_error", response.parsed_body.dig("error", "code")
    assert_equal "Erro inesperado. Tente novamente.", response.parsed_body.dig("error", "message")
    assert_no_match(/RuntimeError|segredo-interno|\.rb/, response.body)
    assert_match(/RuntimeError: segredo-interno/, log.string)
  end

  test "parâmetro obrigatório ausente responde 400 bad_request e não 500" do
    with_failing_show(ActionController::ParameterMissing.new(:user)) { get "/api/qualquer" }

    assert_response :bad_request
    assert_equal "bad_request", response.parsed_body.dig("error", "code")
    assert_no_match(/user/, response.body)
  end

  test "formato desconhecido responde 406 e não 500" do
    with_failing_show(ActionController::UnknownFormat.new) { get "/api/qualquer" }

    assert_response :not_acceptable
    assert_equal "not_acceptable", response.parsed_body.dig("error", "code")
  end

  private
    def with_failing_show(error)
      original = Api::NotFoundController.instance_method(:show)
      Api::NotFoundController.send(:define_method, :show) { raise error }
      yield
    ensure
      Api::NotFoundController.send(:define_method, :show, original)
    end
end
