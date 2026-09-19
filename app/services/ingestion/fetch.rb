require "net/http"

module Ingestion
  # Estágio 1 de 3 (design.md §5.1). É a única parte que toca a rede.
  #
  # Duas garantias, nesta ordem:
  #
  # - O payload bruto é gravado em disco **antes** de qualquer processamento.
  #   É o que permite reprocessar sem rede e o que transforma o payload em
  #   fixture de teste (Req. 11.5).
  # - Se a fonte estiver indisponível, o processo aborta aqui, antes de
  #   qualquer escrita no banco (Req. 1.8). Este estágio não conhece o banco:
  #   ele não tem como deixar o catálogo meio sobrescrito.
  class Fetch
    class SourceUnavailable < StandardError; end

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 120

    Result = Struct.new(:path, :revision, :url, :byte_size, keyword_init: true)

    # Cliente HTTP real. Devolve `[status, corpo]` para que o estágio não
    # precise conhecer a hierarquia de respostas do Net::HTTP.
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

    # `http` é injetável para que o teste exercite o comportamento deste
    # estágio sem tocar a rede (Req. 11.5). O default é o cliente real.
    def initialize(config: SourceConfig.load,
                   storage_dir: Rails.root.join("storage", "ingestion"),
                   http: NetHttpClient.new)
      @config = config
      @storage_dir = Pathname(storage_dir)
      @http = http
    end

    def call
      body = download
      Result.new(path: persist(body), revision: @config.revision, url: @config.url, byte_size: body.bytesize)
    end

    # Reprocessamento sem rede: o payload de uma execução anterior serve de
    # entrada direta para o Normalize.
    def cached_payload_path
      candidate = payload_path
      candidate.exist? ? candidate : nil
    end

    private

    def payload_path
      @storage_dir.join("#{@config.source}-#{@config.revision}.json")
    end

    def download
      status, body = @http.get(@config.url)

      unless status == 200
        raise SourceUnavailable, "fonte respondeu #{status} para #{@config.url}"
      end

      body
    rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError, SocketError, OpenSSL::SSL::SSLError => e
      # Falha de rede não pode virar catálogo vazio: só se distingue de uma
      # resposta legítima se for propagada (Req. 1.8).
      raise SourceUnavailable, "fonte indisponível (#{e.class}): #{e.message}"
    end

    # Grava por arquivo temporário e renomeia: uma interrupção no meio da
    # escrita deixaria um payload truncado que o Normalize leria como fonte
    # válida. O rename é atômico no mesmo sistema de arquivos.
    def persist(body)
      @storage_dir.mkpath
      destination = payload_path
      temporary = destination.sub_ext(".json.part")
      temporary.binwrite(body)
      File.rename(temporary, destination)
      destination
    end
  end
end
