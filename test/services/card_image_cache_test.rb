require "test_helper"

# T1 — cache de imagens em disco sob demanda, com validação de SSRF e path
# traversal. O serviço não faz requisição de saída nem toca disco além do
# permitido (Req. 11.7, 11.5).
class CardImageCacheTest < ActiveSupport::TestCase
  ALLOWED_HOST = CardImageCache::ALLOWED_HOST

  setup do
    @card_set = CardSet.create!(code: "OP01", name: "Test", kind: "booster")
    @card = Card.create!(set_id: @card_set.id, card_number: "OP01-001",
                         name: "Zoro", card_type: "leader", colors: [ "Red" ])
    @storage = Pathname(Dir.mktmpdir("card-image-cache-test"))
    @http_default = CardImageCache.default_http
  end

  teardown do
    CardImageCache.default_http = @http_default
    FileUtils.remove_entry(@storage) if @storage.exist?
  end

  # Dublês de cliente HTTP para não tocar rede (Req. 11.5). Registram URLs
  # chamadas para que o teste prove que nenhuma chamada foi feita quando
  # esperado.
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

  def cache(storage: @storage, http: nil)
    CardImageCache.new(storage_dir: storage, http: http)
  end

  def create_variant(variant_code:, image_url: nil)
    CardVariant.create!(
      card: @card, set_id: @card_set.id, variant_code: variant_code,
      rarity: "C", art_kind: "base", image_url: image_url
    )
  end

  # --- Host, esquema e porta ---

  # Done when: host permitido é constante, esquema https, porta 443; URL
  # malformada, outro host, outro esquema ou outra porta falham **sem** chamar
  # o cliente HTTP.
  test "host alheio → Unavailable, zero chamadas ao cliente" do
    http = ResponderCom.new(200, "png-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://evil.test/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_match(/host/, erro.message)
    assert_empty http.calls
  end

  test "http em vez de https → Unavailable, zero chamadas ao cliente" do
    http = ResponderCom.new(200, "png-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "http://#{ALLOWED_HOST}/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_match(/esquema|https/, erro.message)
    assert_empty http.calls
  end

  test "porta 8443 em vez de 443 → Unavailable, zero chamadas ao cliente" do
    http = ResponderCom.new(200, "png-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}:8443/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_match(/porta/, erro.message)
    assert_empty http.calls
  end

  test "URL malformada → Unavailable, zero chamadas ao cliente" do
    http = ResponderCom.new(200, "png-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "not a url at all"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_empty http.calls
  end

  # --- Extensão ---

  # Done when: extensão vem do caminho de `image_url` e só .png, .jpg, .jpeg,
  # .webp são aceitas; outra extensão falha sem chamar o cliente.
  test "extensão .png aceita" do
    http = ResponderCom.new(200, "png-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    result = cache(http: http).fetch(variant)

    assert_equal ".png", File.extname(result.path)
    assert_equal "image/png", result.content_type
  end

  test "extensão .jpg aceita" do
    http = ResponderCom.new(200, "jpg-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.jpg"
    )

    result = cache(http: http).fetch(variant)

    assert_equal ".jpg", File.extname(result.path)
    assert_equal "image/jpeg", result.content_type
  end

  test "extensão .jpeg aceita" do
    http = ResponderCom.new(200, "jpeg-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.jpeg"
    )

    result = cache(http: http).fetch(variant)

    assert_equal ".jpeg", File.extname(result.path)
    assert_equal "image/jpeg", result.content_type
  end

  test "extensão .webp aceita" do
    http = ResponderCom.new(200, "webp-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.webp"
    )

    result = cache(http: http).fetch(variant)

    assert_equal ".webp", File.extname(result.path)
    assert_equal "image/webp", result.content_type
  end

  test "extensão .svg → Unavailable, zero chamadas ao cliente" do
    http = ResponderCom.new(200, "svg-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.svg"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_match(/extensão/, erro.message)
    assert_empty http.calls
  end

  test "URL sem extensão → Unavailable, zero chamadas ao cliente" do
    http = ResponderCom.new(200, "bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_empty http.calls
  end

  # --- Variante nil ou sem image_url ---

  # Done when: variante sem `image_url` falha sem chamar o cliente.
  test "variante nil → NotFound, zero chamadas ao cliente" do
    http = ResponderCom.new(200, "bytes")

    erro = assert_raises(CardImageCache::NotFound) do
      cache(http: http).fetch(nil)
    end

    assert_empty http.calls
  end

  test "variante sem image_url → NotFound, zero chamadas ao cliente" do
    http = ResponderCom.new(200, "bytes")
    variant = create_variant(variant_code: "OP01-001", image_url: nil)

    erro = assert_raises(CardImageCache::NotFound) do
      cache(http: http).fetch(variant)
    end

    assert_empty http.calls
  end

  # --- Sucesso: gravação atômica ---

  # Done when: sucesso grava <dir>/<variant_code>.<ext> via temporário único
  # no mesmo diretório + rename; teste prova que os bytes gravados são os do
  # dublê.
  test "sucesso grava arquivo com nome correto via temporário + rename" do
    body = "PNG-bytes-here"
    http = ResponderCom.new(200, body)
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    result = cache(http: http).fetch(variant)

    assert_equal "OP01-001.png", result.path.basename.to_s
    assert_equal body, result.path.read
    # Nenhum arquivo temporário sobrou.
    assert_empty @storage.children.select { |f| f.to_s.end_with?(".part") }
  end

  test "sucesso com .jpg grava extensão correta" do
    body = "JPG-bytes"
    http = ResponderCom.new(200, body)
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.jpg"
    )

    result = cache(http: http).fetch(variant)

    assert_equal "OP01-001.jpg", result.path.basename.to_s
    assert_equal body, result.path.read
  end

  # --- Cache em memória/disco ---

  # Done when: arquivo já em disco é devolvido sem chamar o cliente.
  test "segunda requisição da mesma variante não chama o cliente" do
    http1 = ResponderCom.new(200, "first-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    result1 = cache(http: http1).fetch(variant)
    assert_equal 1, http1.calls.size

    # Segunda chamada com cliente diferente: não deve chamar.
    http2 = ResponderCom.new(200, "second-bytes")
    result2 = cache(http: http2).fetch(variant)

    assert_equal 0, http2.calls.size, "cliente foi chamado na segunda requisição"
    assert_equal result1.path, result2.path
    assert_equal "first-bytes", result2.path.read, "bytes da segunda resposta não foram gravados"
  end

  # --- Falha: sem cache ---

  # Done when: falha não deixa arquivo final nem temporário no diretório; a
  # chamada seguinte chama o cliente de novo.
  test "status 404 → Unavailable, nenhum arquivo deixado" do
    http = ResponderCom.new(404, "")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_empty @storage.children
  end

  test "status 302 (redirect) → Unavailable, nenhum arquivo deixado" do
    http = ResponderCom.new(302, "")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_empty @storage.children
  end

  test "corpo vazio (status 200) → Unavailable, nenhum arquivo deixado" do
    http = ResponderCom.new(200, "")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_empty @storage.children
  end

  test "Net::ReadTimeout → Unavailable, nenhum arquivo deixado, próxima tentativa chama cliente" do
    http1 = FalhaCom.new(Net::ReadTimeout.new)
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http1).fetch(variant)
    end

    assert_empty @storage.children

    # Próxima requisição chama o cliente de novo.
    http2 = ResponderCom.new(200, "bytes-ok")
    result = cache(http: http2).fetch(variant)

    assert_equal 1, http2.calls.size
    assert_equal "bytes-ok", result.path.read
  end

  # --- variant_code validação ---

  # Done when: variant_code validado contra
  # \A[A-Za-z0-9]+(-[A-Za-z0-9]+)*(_[a-z0-9]+)?\z no serviço (antes de virar
  # nome de arquivo); inválido → NotFound.
  test "variant_code com .. → NotFound, zero chamadas" do
    http = ResponderCom.new(200, "bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )
    # Simular um variant_code inválido manuseando o modelo (isso nunca
    # aconteceria em produção porque a validação está no banco, mas o teste
    # precisa exercitar o serviço).
    variant.update_column(:variant_code, "OP01-..-..-001")

    erro = assert_raises(CardImageCache::NotFound) do
      cache(http: http).fetch(variant)
    end

    assert_empty http.calls
  end

  test "variant_code com / → NotFound, zero chamadas" do
    http = ResponderCom.new(200, "bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )
    variant.update_column(:variant_code, "OP01/001")

    erro = assert_raises(CardImageCache::NotFound) do
      cache(http: http).fetch(variant)
    end

    assert_empty http.calls
  end

  test "variant_code com espaço → NotFound, zero chamadas" do
    http = ResponderCom.new(200, "bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )
    variant.update_column(:variant_code, "OP01 001")

    erro = assert_raises(CardImageCache::NotFound) do
      cache(http: http).fetch(variant)
    end

    assert_empty http.calls
  end

  # --- Path traversal ---

  # Done when: por defesa, valide também o variant_code no serviço contra o
  # padrão esperado e confira que o caminho final expandido fica dentro de
  # storage_dir.
  test "caminho final fica dentro de storage_dir" do
    http = ResponderCom.new(200, "bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    result = cache(http: http).fetch(variant)

    expanded = result.path.expand_path
    expanded_storage = @storage.expand_path
    assert expanded.to_s.start_with?(expanded_storage.to_s + "/"),
           "arquivo gravado fora de storage_dir: #{expanded}"
  end

  # --- Formato de Result ---

  test "result contém path, content_type e ambos têm tipo correto" do
    http = ResponderCom.new(200, "png-bytes")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    result = cache(http: http).fetch(variant)

    assert_kind_of Pathname, result.path
    assert_equal "image/png", result.content_type
  end

  # --- Redirect não é seguido ---

  # Done when: cliente próprio com timeouts curtos (ordem de segundos), sem
  # seguir redirect; status ≠ 200 (inclusive 301/302) e corpo vazio são falha.
  test "301 redirect → Unavailable, zero chamadas subsequentes" do
    http = ResponderCom.new(301, "")
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_empty @storage.children
  end

  # --- Exceções de rede ---

  # Done when: erro de rede e timeout viram falha tipada, nunca exceção crua.
  test "SystemCallError → Unavailable" do
    http = FalhaCom.new(SystemCallError.new("erro do sistema"))
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end

    assert_empty @storage.children
  end

  test "Net::OpenTimeout → Unavailable" do
    http = FalhaCom.new(Net::OpenTimeout.new)
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    erro = assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end
  end

  test "IOError → Unavailable" do
    http = FalhaCom.new(IOError.new("I/O error"))
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end
  end

  test "SocketError → Unavailable" do
    http = FalhaCom.new(SocketError.new("Socket error"))
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end
  end

  test "OpenSSL::SSL::SSLError → Unavailable" do
    http = FalhaCom.new(OpenSSL::SSL::SSLError.new("SSL error"))
    variant = create_variant(
      variant_code: "OP01-001",
      image_url: "https://#{ALLOWED_HOST}/image.png"
    )

    assert_raises(CardImageCache::Unavailable) do
      cache(http: http).fetch(variant)
    end
  end
end
