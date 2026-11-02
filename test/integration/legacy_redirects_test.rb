require "test_helper"

# T18 (spa-troca) — as URLs do Hotwire e as de `/app` redirecionam `301` para a
# SPA na raiz (STRO-11, STRO-12), sem sessão nem banco (STRO-13), com a
# codificação do segmento e a query intactas (STRO-14); os outros métodos em rota
# removida dão `404` sem gravar (STRO-15, STRO-33).
class LegacyRedirectsTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  # Por linha da checklist de paridade do spec: origem → destino, com a query crua.
  REDIRECTS = {
    "/app" => "/",
    "/app/pasta?order=code" => "/pasta?order=code",
    "/app/200.html" => "/200.html",
    "/app/cartas/P-029" => "/cartas/P-029",
    "/app/entrar?return_to=%2Fapp%2Fpasta" => "/entrar?return_to=%2Fapp%2Fpasta",
    "/app/pasta/importar/abc123" => "/pasta/importar/abc123",
    "/catalog" => "/",
    "/catalog?colors[]=Red&colors[]=Green&sort=name" => "/?colors[]=Red&colors[]=Green&sort=name",
    "/cards/P.029" => "/cartas/P.029",
    "/cards/OP01-001?variant=tcgplayer%3A123" => "/cartas/OP01-001?variant=tcgplayer%3A123",
    "/cards/a%3Ab" => "/cartas/a%3Ab",
    "/session/new" => "/entrar",
    "/registration/new" => "/criar-conta",
    "/progress" => "/pasta",
    "/progress?order=code" => "/pasta?order=code",
    "/wishlist" => "/pasta/desejos",
    "/collection/import" => "/pasta/importar",
    "/collection/import/abc123" => "/pasta/importar/abc123",
    "/decks" => "/baralhos",
    "/decks/new" => "/baralhos/novo",
    "/decks/import" => "/baralhos/importar",
    "/decks/7" => "/baralhos/7",
    "/decks/7/edit" => "/baralhos/7/renomear",
    "/decks/7/delete" => "/baralhos/7/excluir",
    "/app/%2F%2Fevil.com" => "/%2F%2Fevil.com"
  }.freeze

  setup do
    @user = User.create!(email: "legado-t18@example.com", password: PASSWORD)
    @other = User.create!(email: "legado-t18-outro@example.com", password: PASSWORD)
    set = CardSet.create!(code: "LT18", name: "Legado T18", kind: "booster", base_set_size: 1, total_set_size: 1)
    card = Card.create!(card_set: set, card_number: "LT18-001", name: "Carta legada", card_type: "leader",
                        colors: [ "Red" ])
    @variant = CardVariant.create!(card: card, card_set: set, variant_code: "lt18-1", rarity: "L", art_kind: "base")
    @alien_deck = Deck.create!(user: @other, name: "Alheio", leader: card)
    @own_deck = Deck.create!(user: @user, name: "Meu", leader: card)
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 2)
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 3)
  end

  def sign_in(user)
    get "/api/session"
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json",
                                    "X-CSRF-Token" => response.parsed_body.dig("data", "csrf_token") }
    assert_response :success
  end

  def count_queries
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end

  def assert_moved_to(expected, origin)
    assert_response :moved_permanently, origin
    assert_equal "#{request.base_url}#{expected}", response.headers["Location"], origin
  end

  REDIRECTS.each do |origin, expected|
    test "GET #{origin} redireciona 301 para #{expected}" do
      get origin

      assert_moved_to expected, origin
    end

    test "HEAD #{origin} responde igual ao GET" do
      head origin

      assert_moved_to expected, origin
      assert_empty response.body
    end
  end

  test "o redirecionamento não consulta o banco, com ou sem sessão" do
    REDIRECTS.each_key do |origin|
      assert_equal 0, count_queries { get origin }, "anônimo #{origin}"
    end

    sign_in(@user)
    REDIRECTS.each_key do |origin|
      assert_equal 0, count_queries { get origin }, "com sessão #{origin}"
    end
  end

  test "deck de outro usuário redireciona sem consultar e sem revelar se existe" do
    sign_in(@user)

    [ @alien_deck.id, 0 ].each do |id|
      queries = count_queries { get "/decks/#{id}" }

      assert_equal 0, queries
      assert_moved_to "/baralhos/#{id}", "/decks/#{id}"
    end
  end

  test "/app//evil.com não redireciona para outro host" do
    get "/app//evil.com"

    assert_response :not_found
    assert_nil response.headers["Location"]
  end

  test "barra invertida e controle codificados ficam como caminho local" do
    { "/app/%5Cevil.com" => "/%5Cevil.com", "/app/%09/evil" => "/%09/evil" }.each do |origin, expected|
      get origin

      assert_moved_to expected, origin
    end
  end

  # O cliente de integração recusa URI não ASCII; o servidor real a aceita, então
  # o pedido vai direto ao Rack com o byte cru na query ou no caminho.
  def raw_env(path, query = "")
    full = query.empty? ? path : "#{path}?#{query}"
    Rack::MockRequest.env_for("/").merge!(
      "PATH_INFO" => path.b, "QUERY_STRING" => query.b, "REQUEST_URI" => full.b, "ORIGINAL_FULLPATH" => full.b
    )
  end

  # Pela pilha completa, o parser de parâmetros do Rack já recusa o byte inválido
  # com `400` antes do controller; o que importa é nunca chegar a `500`.
  test "bytes inválidos em UTF-8 na query ou no caminho nunca dão 500 pela pilha completa" do
    [ [ "/catalog", "x=\xFF" ], [ "/cards/\xFF", "" ], [ "/app/\xFF", "" ], [ "/app//\xFF", "" ] ].each do |path, query|
      status, = Rails.application.call(raw_env(path, query))

      assert_includes [ 301, 400, 404 ], status, "#{path}?#{query}"
    end
  end

  # O controller sozinho prova a garantia: sem o tratamento, `partition`,
  # `match?` ou `redirect_to` levantariam `ArgumentError`.
  test "o controller com bytes inválidos no caminho dá 404, sem Location" do
    [ "/cards/\xFF", "/app/\xFF", "/app//\xFF", "/catalog/\xFF" ].each do |path|
      status, headers, = LegacyRedirectsController.action(:show).call(raw_env(path))

      assert_equal 404, status, path
      assert_nil headers["Location"], path
    end
  end

  test "anônimo em /collection/export com CRLF e // na query leva return_to codificado" do
    get "/collection/export?x=%0D%0A//y"

    assert_response :found
    location = response.headers["Location"]
    assert_equal "#{request.base_url}/entrar?return_to=%2Fcollection%2Fexport%3Fx%3D%250D%250A%2F%2Fy", location
    assert_no_match(/[\r\n]/, location)
    assert_no_match(%r{//y}, location.delete_prefix(request.base_url))
  end

  test "/app/_app/x.js é 404, não redirecionamento" do
    get "/app/_app/x.js"

    assert_response :not_found
    assert_nil response.headers["Location"]
  end

  test "método diferente de GET em rota removida dá 404 e não grava nada" do
    sign_in(@user)
    tables = [ CollectionItem, WishlistItem, Deck, Session ]
    before = tables.to_h { |model| [ model, model.order(:id).pluck(:id, :updated_at) ] }
    before_quantity = CollectionItem.sole.quantity
    before_deck_name = @own_deck.reload.name

    post "/collection_items/#{@variant.id}/increment"
    assert_response :not_found
    post "/collection_items/#{@variant.id}/decrement"
    assert_response :not_found
    delete "/wishlist/#{WishlistItem.sole.id}"
    assert_response :not_found
    delete "/session"
    assert_response :not_found
    patch "/decks/#{@own_deck.id}", params: { deck: { name: "Trocado" } }
    assert_response :not_found
    delete "/decks/#{@own_deck.id}"
    assert_response :not_found
    post "/decks/#{@own_deck.id}/select"
    assert_response :not_found
    post "/decks", params: { deck: { name: "Novo" } }
    assert_response :not_found
    post "/registration", params: { user: { email: "novo-t18@example.com", password: PASSWORD } }
    assert_response :not_found

    tables.each do |model|
      assert_equal before.fetch(model), model.order(:id).pluck(:id, :updated_at), model.name
    end
    assert_equal before_quantity, CollectionItem.sole.quantity
    assert_equal before_deck_name, @own_deck.reload.name
    assert_not User.exists?(email: "novo-t18@example.com")
  end

  # STRO-24: o cookie que o HTML gravava é o mesmo que a API lê.
  test "sessão aberta antes do corte é lida pelo mesmo cookie em GET /api/session" do
    session = @user.sessions.create!(user_agent: "navegador antigo", ip_address: "127.0.0.1")
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.signed[:session_id] = session.id
    cookies[:session_id] = jar[:session_id]

    get "/api/session"

    assert_response :success
    assert_equal @user.email, response.parsed_body.dig("data", "user", "email")
  end
end
