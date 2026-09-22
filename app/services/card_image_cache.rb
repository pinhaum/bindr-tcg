require "net/http"

# T1 — cache de imagens em disco sob demanda, com validação de SSRF e path
# traversal. Baixa a arte da fonte uma vez, grava atomicamente em disco e
# serve das requisições seguintes, ou falha de forma tipada e não cacheia.
#
# **Invariantes de segurança (AD-012):**
# - A URL de saída sempre vem de `card_variants.image_url`, nunca do request.
# - Host, esquema e porta são validados contra `ALLOWED_HOST` e https:443.
# - `variant_code` é validado contra o padrão esperado antes de virar nome de
#   arquivo, prevenindo path traversal.
# - Extensão está em lista fechada (`.png`, `.jpg`, `.jpeg`, `.webp`),
#   prevenindo SSRF via sufixo arbitrário.
# - Escrita atômica (temporário + rename) previne arquivo pela metade em
#   concorrência.
# - Falha não deixa arquivo em disco; a próxima requisição tenta de novo.
#
# **Timeouts curtos:** o fetch acontece dentro de uma requisição do navegador.
# Não segue redirect (status 301/302 é falha).
class CardImageCache
  class NotFound < StandardError; end
  class Unavailable < StandardError; end

  ALLOWED_HOST = "asia-en.onepiece-cardgame.com".freeze
  VARIANT_CODE_PATTERN = /\A[A-Za-z0-9]+(-[A-Za-z0-9]+)*(_[a-z0-9]+)?\z/.freeze
  ALLOWED_EXTENSIONS = %w[.png .jpg .jpeg .webp].freeze

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  Result = Struct.new(:path, :content_type, keyword_init: true)

  # Cliente HTTP real. Devolve `[status, corpo]` para que o serviço não
  # precise conhecer a hierarquia de respostas do Net::HTTP. Não segue
  # redirect (Net::HTTP não segue por padrão; status de redirect é falha).
  class NetHttpClient
    def get(url)
      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(uri))
      end
      [ response.code.to_i, response.body ]
    end
  end

  # `http` é injetável para que o teste não toque rede. O default é o cliente
  # real. Trocável em teste via `CardImageCache.default_http =`.
  class_attribute :default_http, default: NetHttpClient.new

  def initialize(storage_dir: Rails.root.join("storage", "card_images"), http: nil)
    @storage_dir = Pathname(storage_dir)
    @http = http || self.class.default_http
  end

  def fetch(variant)
    raise NotFound, "variante não existe" if variant.nil?
    raise NotFound, "variante sem imagem" if variant.image_url.blank?

    validate_variant_code(variant.variant_code)
    url = variant.image_url
    validate_url(url)

    final_path = final_path_for(variant.variant_code, url)

    # Se o arquivo já existe, devolve sem chamar o cliente.
    return Result.new(path: final_path, content_type: content_type_for(final_path)) if final_path.exist?

    # Busca e grava.
    fetch_and_store(url, final_path)
  rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError, SocketError, OpenSSL::SSL::SSLError => e
    raise Unavailable, "erro ao buscar ou gravar: #{e.class} - #{e.message}"
  end

  private

  def validate_variant_code(variant_code)
    unless variant_code.match?(VARIANT_CODE_PATTERN)
      raise NotFound, "variant_code inválido: não casou o padrão esperado"
    end

    # Por defesa: o caminho final precisa ficar dentro de storage_dir.
    # (Impossível em produção porque variant_code vem do banco, mas o teste
    # pode tentar truques.)
    final_path = @storage_dir.join("#{variant_code}.png")
    expanded_final = final_path.expand_path
    expanded_storage = @storage_dir.expand_path

    unless expanded_final.to_s.start_with?(expanded_storage.to_s + "/")
      raise NotFound, "caminho do arquivo sairia de storage_dir"
    end
  end

  def validate_url(url)
    uri = begin
      URI.parse(url)
    rescue URI::InvalidURIError
      raise NotFound, "URL malformada"
    end

    if uri.scheme != "https"
      raise NotFound, "esquema deve ser https"
    end

    if uri.host != ALLOWED_HOST
      raise NotFound, "host não permitido"
    end

    if uri.port && uri.port != 443
      raise NotFound, "porta deve ser 443"
    end

    ext = File.extname(uri.path).downcase
    if ext.blank? || !ALLOWED_EXTENSIONS.include?(ext)
      raise Unavailable, "extensão #{ext.inspect} não permitida"
    end
  end

  def final_path_for(variant_code, url)
    ext = File.extname(url).downcase
    @storage_dir.join("#{variant_code}#{ext}")
  end

  def content_type_for(path)
    ext = File.extname(path).downcase
    case ext
    when ".png"
      "image/png"
    when ".jpg", ".jpeg"
      "image/jpeg"
    when ".webp"
      "image/webp"
    else
      "application/octet-stream"
    end
  end

  def fetch_and_store(url, final_path)
    status, body = @http.get(url)

    unless status == 200
      raise Unavailable, "fonte respondeu status #{status}"
    end

    if body.blank?
      raise Unavailable, "fonte retornou corpo vazio"
    end

    persist(body, final_path)
  end

  # Grava por arquivo temporário e renomeia. Uma interrupção no meio da
  # escrita deixaria um arquivo truncado que o controller leria como sucesso.
  # O rename é atômico no mesmo sistema de arquivos. Em qualquer exceção,
  # apaga o temporário para que não sobre arquivo parcial.
  def persist(body, final_path)
    @storage_dir.mkpath
    temporary = final_path.sub_ext("#{final_path.extname}.#{SecureRandom.hex(8)}.part")

    begin
      temporary.binwrite(body)
      File.rename(temporary, final_path)
    ensure
      File.delete(temporary) if temporary.exist?
    end

    Result.new(path: final_path, content_type: content_type_for(final_path))
  end
end
