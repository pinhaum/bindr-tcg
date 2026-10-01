require "net/http"
require "digest"
require "securerandom"

module Ingestion
  module Apitcg
    # Estágio de busca da apitcg (design.md, `Ingestion::Apitcg::Fetch`). É a
    # única parte da ingestão que toca a rede.
    #
    # Grava o snapshot inteiro em disco antes de qualquer normalização
    # (SRC-03), e uma busca incompleta não grava nada: o snapshot é escrito
    # num `.part` e só ganha o nome final depois de todas as páginas
    # recebidas. Uma falha aqui acontece antes de qualquer escrita no banco
    # (SRC-04).
    #
    # A chave vai só no header `x-api-key`. Nunca entra em URL, no corpo
    # gravado nem em mensagem de erro (SRC-05): o arquivo gravado contém só os
    # corpos das respostas.
    #
    # Formato confirmado na T10 (2026-10-01): `/api/one-piece/sets` devolve
    # `{success, data: [...]}`; as cartas vêm de `/api/products?tcg=one-piece&
    # type=card&page=N&limit=N` (não existe `/cards`), que devolve
    # `{success, data: [...], total}` com `total` em produtos, não em páginas.
    class Fetch
      class SourceUnavailable < StandardError; end
      class KeyRejected < SourceUnavailable; end
      class SnapshotExists < StandardError; end

      Result = Struct.new(:path, :sha256, :byte_size, keyword_init: true)

      # Esperas antes da 2ª e da 3ª tentativa.
      BACKOFF_SECONDS = [ 2, 4 ].freeze

      TCG = "one-piece".freeze

      # Teto de páginas de cartas. A medição de 2026-09-29 deu ~73 páginas
      # de 100; o teto só existe para que uma API que ignore `page` e não
      # mande `total` não prenda a busca num laço sem fim.
      MAX_PAGES = 500

      TRANSIENT_ERRORS = [
        Timeout::Error, SystemCallError, IOError, SocketError, OpenSSL::SSL::SSLError,
        Net::HTTPBadResponse, Net::ProtocolError, JSON::ParserError
      ].freeze

      # Cliente HTTP real. Devolve `[status, corpo]` para que o estágio não
      # precise conhecer a hierarquia de respostas do Net::HTTP.
      class NetHttpClient
        def initialize(timeout:)
          @timeout = timeout
        end

        def get(url, headers:)
          uri = URI.parse(url)
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                     open_timeout: @timeout, read_timeout: @timeout) do |http|
            request = Net::HTTP::Get.new(uri)
            headers.each { |name, value| request[name] = value }
            http.request(request)
          end
          [ response.code.to_i, response.body ]
        end
      end

      def initialize(config: SourceConfig.load,
                     storage_dir: Rails.root.join("storage", "ingestion"),
                     http: nil,
                     clock: Time,
                     sleeper: ->(seconds) { sleep(seconds) })
        @config = config
        @storage_dir = Pathname(storage_dir)
        @http = http || NetHttpClient.new(timeout: config.timeout)
        @clock = clock
        @sleeper = sleeper
      end

      def call
        # Antes da primeira requisição: sem chave, nada sai para a rede (SRC-02).
        @headers = { "x-api-key" => @config.api_key, "Accept" => "application/json" }
        destination = snapshot_path
        refuse_overwrite!(destination)

        body = JSON.generate("fetched_at" => @clock.now.utc.iso8601, "sets" => fetch_sets, "cards" => fetch_cards)
        # Uma resposta que ecoe a chave não pode ir para o disco (SRC-05).
        raise SourceUnavailable, "resposta da apitcg contém a chave; snapshot descartado" if body.include?(@config.api_key)

        persist(destination, body)
        Result.new(path: destination, sha256: Digest::SHA256.hexdigest(body), byte_size: body.bytesize)
      end

      # Os headers, com a chave, ficam em ivar; o `inspect` padrão os imprimiria
      # (SRC-05).
      def inspect = "#<#{self.class.name} config=#{@config.inspect}>"

      private

      def snapshot_path
        @storage_dir.join("apitcg-#{@clock.now.utc.strftime('%Y%m%dT%H%M%SZ')}.json")
      end

      def fetch_sets
        sets = records(get_json("#{@config.base_url}/#{TCG}/sets"))
        raise SourceUnavailable, "apitcg respondeu sem nenhum set" if sets.empty?

        sets
      end

      # Páginas em sequência, sem paralelismo, por causa do limite de
      # requisições da API. A mesma `_id` em duas páginas fica uma vez só, na
      # primeira em que apareceu (SRC-33).
      #
      # Um snapshot incompleto é pior que nenhum: gravado como run
      # `succeeded`, ele marcaria como ausente tudo o que faltou. Por isso
      # toda forma de parar cedo que não seja o fim declarado é erro: página
      # vazia antes do fim declarado, `total` ilegível e o teto de páginas.
      # Sem `total`, o fim é a primeira página vazia.
      def fetch_cards
        cards = {}

        (1..MAX_PAGES).each do |page|
          payload = get_json("#{@config.base_url}/products?tcg=#{TCG}&type=card&page=#{page}&limit=#{@config.page_size}")
          batch = records(payload)
          total_pages = total_pages(payload)

          if batch.empty?
            raise SourceUnavailable, "apitcg respondeu a página #{page} de #{total_pages} vazia" if total_pages
            raise SourceUnavailable, "apitcg respondeu sem nenhuma carta" if cards.empty?

            return cards.values
          end

          batch.each { |card| cards[product_id(card)] ||= card }
          return cards.values if total_pages && page >= total_pages
        end

        raise SourceUnavailable, "apitcg passou de #{MAX_PAGES} páginas de cartas sem terminar"
      end

      def records(payload)
        list = payload.is_a?(Hash) ? payload["data"] : payload
        return list if list.is_a?(Array)

        raise SourceUnavailable, "apitcg respondeu sem lista de registros"
      end

      # A API informa `total` em produtos; o número de páginas sai dele.
      def total_pages(payload)
        return nil unless payload.is_a?(Hash) && !payload["total"].nil?

        total = Integer(payload["total"], exception: false)
        raise SourceUnavailable, "apitcg respondeu total inválido" unless total&.positive?

        (total.to_f / @config.page_size).ceil
      end

      # Sem `_id`, dois produtos colapsariam numa só chave e um sumiria.
      def product_id(card)
        id = card["_id"].to_s if card.is_a?(Hash)
        raise SourceUnavailable, "apitcg respondeu produto sem _id" if id.blank?

        id
      end

      # Timeout, erro de rede, corpo ilegível e status fora de 2xx contam como
      # falha e são repetidos até `attempts` tentativas (SRC-04). O 401 não se
      # repete: a chave não vai passar a valer na tentativa seguinte (SRC-32).
      def get_json(url)
        attempt = 1

        begin
          status, body = @http.get(url, headers: @headers)
          raise KeyRejected, "chave da apitcg recusada (401)" if status == 401
          raise SourceUnavailable, "status #{status}" unless (200..299).cover?(status)

          JSON.parse(body.to_s)
        rescue KeyRejected
          raise
        rescue SourceUnavailable, *TRANSIENT_ERRORS => e
          if attempt < @config.attempts
            @sleeper.call(BACKOFF_SECONDS.fetch(attempt - 1, BACKOFF_SECONDS.last))
            attempt += 1
            retry
          end

          raise SourceUnavailable,
                "apitcg indisponível após #{attempt} tentativas em #{url} (#{failure_reason(e)})"
        end
      end

      # A mensagem do erro de rede vem de bibliotecas de terceiros. A chave
      # não é interpolada nela, mas a filtragem garante isso mesmo que alguma
      # passe a ecoar o request.
      def failure_reason(error)
        reason = error.is_a?(SourceUnavailable) ? error.message : "#{error.class}: #{error.message}"
        reason.gsub(@config.api_key, "[FILTRADA]")
      end

      def refuse_overwrite!(destination)
        return unless destination.exist?

        raise SnapshotExists, "snapshot #{destination.basename} já existe; não será sobrescrito"
      end

      # `link` falha se o destino já existir, ao contrário de `rename`: o
      # snapshot de outra execução no mesmo segundo nunca é sobrescrito. O
      # `.part` tem nome único e é criado com `EXCL | NOFOLLOW`, para que duas
      # execuções não compartilhem o temporário nem a escrita siga um symlink.
      def persist(destination, body)
        @storage_dir.mkpath
        temporary = destination.sub_ext(".json.#{SecureRandom.hex(4)}.part")
        File.open(temporary, File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW, 0o600) do |file|
          file.binmode
          file.write(body)
        end
        File.link(temporary, destination)
      rescue Errno::EEXIST
        raise SnapshotExists, "snapshot #{destination.basename} já existe; não será sobrescrito"
      ensure
        temporary.delete if temporary&.exist?
      end
    end
  end
end
