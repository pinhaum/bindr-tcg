require "test_helper"
require "tmpdir"

class SpaTest < ActionDispatch::IntegrationTest
  FIXTURE_BODY = "<!doctype html><html><body>spa-shell</body></html>".freeze

  setup do
    @original_entry_path = Rails.configuration.x.spa_entry_path
    @tmpdir = Dir.mktmpdir("spa-test")
    @entry_path = Pathname(@tmpdir).join("200.html")
    File.write(@entry_path, FIXTURE_BODY)
    Rails.configuration.x.spa_entry_path = @entry_path
  end

  teardown do
    Rails.configuration.x.spa_entry_path = @original_entry_path
    FileUtils.remove_entry(@tmpdir)
  end

  test "serves the entry page on /app, a client route and a deep path with a query" do
    [ "/app", "/app/entrar", "/app/qualquer/coisa?x=1" ].each do |path|
      get path

      assert_response :success, path
      assert_equal FIXTURE_BODY, response.body, path
      assert_equal "text/html", response.media_type, path
      assert_includes response.headers["Cache-Control"], "no-cache", path
    end
  end

  test "does not redirect to login without a session" do
    get "/app/colecao"

    assert_response :success
  end

  test "build assets that do not exist answer 404 instead of the entry page" do
    get "/app/_app/immutable/velho.js"

    assert_response :not_found
    assert_not_equal FIXTURE_BODY, response.body
  end

  test "answers 404 when the entry file is missing" do
    File.delete(@entry_path)

    get "/app/entrar"

    assert_response :not_found
  end

  test "serves the entry page on the root fallback with a query and /200.html" do
    [ "/pasta/desejos", "/qualquer/coisa?x=1", "/200.html" ].each do |path|
      get path

      assert_response :success, path
      assert_equal FIXTURE_BODY, response.body, path
      assert_equal "text/html", response.media_type, path
      assert_includes response.headers["Cache-Control"], "no-cache", path
    end
  end

  test "root build assets that do not exist answer 404 instead of the entry page" do
    [ "/_app/immutable/inexistente.js", "/app/_app/immutable/x.js" ].each do |path|
      get path

      assert_response :not_found, path
      assert_not_equal FIXTURE_BODY, response.body, path
    end
  end

  test "non-GET methods on an unknown path answer 404" do
    post "/qualquer"

    assert_response :not_found
    assert_not_equal FIXTURE_BODY, response.body
  end
end
