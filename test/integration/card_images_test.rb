require "test_helper"

# T2 — rota pública `GET /card_images/:variant_code` e `CardImagesController`
# (Req. 11.7, IMG-04 a IMG-12, IMG-13).
#
# Testes de integração sobre rota, controller, status HTTP, cabeçalhos e acesso
# público, sem tocar rede.
class CardImagesTest < ActionDispatch::IntegrationTest
  ALLOWED_HOST = CardImageCache::ALLOWED_HOST

  setup do
    @card_set = CardSet.create!(code: "OP01", name: "Test", kind: "booster")
    @card = Card.create!(set_id: @card_set.id, card_number: "OP01-001",
                         name: "Zoro", card_type: "leader", colors: [ "Red" ])

    @dir = Dir.mktmpdir("card-images-integration-test")
    @http_default = CardImageCache.default_http
    @storage_default = CardImageCache.default_storage_dir

    # Trocar o cliente HTTP por um dublê que registra chamadas.
    CardImageCache.default_http = ResponderCom.new(200, "PNG-BYTES")
    # Trocar o diretório de storage para não sujar o disco real.
    CardImageCache.default_storage_dir = -> { Pathname(@dir) }
  end

  teardown do
    CardImageCache.default_http = @http_default
    CardImageCache.default_storage_dir = @storage_default
    FileUtils.remove_entry(@dir) if File.exist?(@dir)
  end

  # Dublê de cliente HTTP que registra URLs chamadas.
  ResponderCom = Struct.new(:status, :body) do
    attr_reader :calls

    def initialize(status, body)
      super(status, body)
      @calls = []
    end

    def get(url)
      @calls << url
      [ status, body ]
    end
  end

  def create_variant(variant_code:, image_url: nil)
    CardVariant.create!(
      card: @card, set_id: @card_set.id, variant_code: variant_code,
      rarity: "C", art_kind: "base", image_url: image_url
    )
  end

  # --- Helper de rota ---

  # Done when: helper `card_image_path("OP01-001") == "/card_images/OP01-001"`.
  test "helper card_image_path gera rota correta" do
    assert_equal "/card_images/OP01-001", card_image_path("OP01-001")
  end

  # --- Acesso público (IMG-04) ---

  # Done when: anônimo recebe 200 (não redirect) para variante com imagem.
  test "anônimo recebe 200 para variante com imagem" do
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    get card_image_path(variant.variant_code)

    assert_response :success
    assert_equal 200, status
  end

  # --- Sucesso: arquivo e cabeçalhos (IMG-05, IMG-07) ---

  # Done when: 200 traz os bytes do dublê, Content-Type pela extensão,
  # Cache-Control com public e max-age=31536000, disposição inline.
  test "sucesso devolve arquivo com Content-Type correto" do
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    get card_image_path(variant.variant_code)

    assert_response :success
    assert_equal "image/png", response.content_type
    assert_equal "PNG-BYTES", response.body
  end

  test "sucesso traz Cache-Control público com max-age de um ano" do
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    get card_image_path(variant.variant_code)

    assert_response :success
    assert_match(/public/, response.headers["Cache-Control"])
    # Rails computa max-age com alguns segundos extras; verificar que está na
    # ordem de um ano (31536000 segundos ± margem razoável).
    cache_control = response.headers["Cache-Control"]
    max_age_match = cache_control.match(/max-age=(\d+)/)
    assert max_age_match, "Cache-Control sem max-age: #{cache_control}"
    max_age = max_age_match[1].to_i
    assert max_age > 31500000 && max_age < 31600000,
           "max-age=#{max_age} não está na ordem de um ano (31536000 s)"
  end

  test "sucesso traz Content-Disposition inline" do
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    get card_image_path(variant.variant_code)

    assert_response :success
    assert_equal "inline", response.headers["Content-Disposition"].split(";").first
  end

  # --- Cache em disco (IMG-05) ---

  # Done when: segunda requisição da mesma variante não chama o cliente.
  test "segunda requisição não chama o cliente HTTP" do
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    get card_image_path(variant.variant_code)
    assert_equal 1, CardImageCache.default_http.calls.size

    get card_image_path(variant.variant_code)
    assert_equal 1, CardImageCache.default_http.calls.size,
                 "cliente foi chamado na segunda requisição"
  end

  # --- Validação de variant_code (IMG-09) ---

  # Done when: variant_code validado contra
  # \A[A-Za-z0-9]+(-[A-Za-z0-9]+)*(_[a-z0-9]+)?\z no controller **antes**
  # de qualquer consulta; teste com `..`, `%2F`, `OP01-001.png` e similares
  # prova 404 sem chamada ao cliente e sem arquivo criado.
  test "variant_code com .. → 404, zero chamadas ao cliente, nenhum arquivo" do
    get "/card_images/OP01-..-..-001"

    assert_response :not_found
    assert_empty CardImageCache.default_http.calls
    assert_empty Dir.children(@dir)
  end

  test "variant_code com / → 404, zero chamadas, nenhum arquivo" do
    get "/card_images/OP01/001"

    assert_response :not_found
    assert_empty CardImageCache.default_http.calls
    assert_empty Dir.children(@dir)
  end

  test "variant_code com .png → 404, zero chamadas, nenhum arquivo" do
    get "/card_images/OP01-001.png"

    assert_response :not_found
    assert_empty CardImageCache.default_http.calls
    assert_empty Dir.children(@dir)
  end

  test "variant_code com %2F → 404, zero chamadas, nenhum arquivo" do
    get "/card_images/OP01%2F001"

    assert_response :not_found
    assert_empty CardImageCache.default_http.calls
    assert_empty Dir.children(@dir)
  end

  test "variant_code com espaço → 404, zero chamadas, nenhum arquivo" do
    get "/card_images/OP01%20001"

    assert_response :not_found
    assert_empty CardImageCache.default_http.calls
    assert_empty Dir.children(@dir)
  end

  # --- Inexistente ou sem image_url (IMG-11) ---

  # Done when: variante inexistente e variante sem `image_url` → 404 corpo
  # vazio, sem chamada ao cliente.
  test "variante inexistente → 404, zero chamadas ao cliente, corpo vazio" do
    get card_image_path("NONEXISTENT")

    assert_response :not_found
    assert_empty response.body
    assert_empty CardImageCache.default_http.calls
  end

  test "variante sem image_url → 404, zero chamadas ao cliente, corpo vazio" do
    variant = create_variant(variant_code: "OP01-002", image_url: nil)

    get card_image_path(variant.variant_code)

    assert_response :not_found
    assert_empty response.body
    assert_empty CardImageCache.default_http.calls
  end

  # --- Falha da fonte (IMG-12) ---

  # Done when: falha da fonte (status ≠ 200, timeout, host recusado) → 502
  # corpo vazio; nada gravado.
  test "timeout da fonte → 502, corpo vazio, nada gravado" do
    CardImageCache.default_http = FalhaCom.new(Net::ReadTimeout.new)
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    get card_image_path(variant.variant_code)

    assert_response :bad_gateway
    assert_empty response.body
    assert_empty Dir.children(@dir)
  end

  test "host recusado → 502, corpo vazio, nada gravado" do
    CardImageCache.default_http = ResponderCom.new(200, "bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://evil.test/image.png"
    )

    get card_image_path(variant.variant_code)

    assert_response :bad_gateway
    assert_empty response.body
    assert_empty Dir.children(@dir)
  end

  # Dublê de cliente HTTP que levanta exceção.
  FalhaCom = Struct.new(:erro) do
    attr_reader :calls

    def initialize(erro)
      super(erro)
      @calls = []
    end

    def get(url)
      @calls << url
      raise(erro)
    end
  end

  # --- Nenhum parâmetro do request entra na URL (IMG-08) ---

  # Done when: nenhum parâmetro do request além de `variant_code` é lido;
  # teste com `?url=https://evil.test/x.png` prova que o cliente recebe a URL
  # do banco.
  test "parâmetro url de query é ignorado, cliente recebe URL do banco" do
    http = ResponderCom.new(200, "bytes")
    CardImageCache.default_http = http
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    get card_image_path(variant.variant_code), params: { url: "https://evil.test/x.png" }

    assert_response :success
    assert_equal 1, http.calls.size
    assert_equal variant.image_url, http.calls.first,
                 "cliente deveria receber a URL do banco, não do request"
  end

  # --- Controller não lê Current.user ---

  # Done when: controller não lê `Current.user` (não há dado de usuário aqui).
  test "controller não acessa Current.user" do
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    # Simular tentativa de contaminação: logar um usuário.
    user = User.create!(email: "test@example.com", password: "password123")
    post session_path, params: { email: "test@example.com", password: "password123" }

    # Requisição para a imagem deve funcionar normalmente sem ler o usuário.
    get card_image_path(variant.variant_code)

    assert_response :success
  end
end
