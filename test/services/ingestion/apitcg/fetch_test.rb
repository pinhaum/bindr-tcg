require "test_helper"

module Ingestion
  module Apitcg
    # SRC-01, SRC-03, SRC-04, SRC-05, SRC-32 e SRC-33, sem rede (Req. 11.5):
    # o cliente HTTP é um dublê que responde por URL e registra cada chamada.
    class FetchTest < ActiveSupport::TestCase
      CHAVE = "chave-de-teste".freeze
      BASE = "https://apitcg.test/api/one-piece".freeze
      AGORA = Time.utc(2026, 9, 30, 21, 5, 9)

      # Responde a cada URL com a fila de respostas configurada; a última se
      # repete. Uma resposta é `[status, corpo]` ou uma exceção a levantar.
      # `before_get` roda antes de cada resposta, para simular efeitos externos.
      class FakeHttp
        attr_reader :calls

        def initialize(routes, before_get: nil)
          @routes = routes.transform_values { |responses| Array(responses).dup }
          @before_get = before_get
          @calls = []
        end

        def get(url, headers:)
          @calls << { url: url, headers: headers }
          @before_get&.call(url)
          queue = @routes.fetch(url) { raise "URL inesperada: #{url}" }
          response = queue.size > 1 ? queue.shift : queue.first
          raise response if response.is_a?(Exception)

          response
        end
      end

      setup do
        @storage = Pathname(Dir.mktmpdir("apitcg-fetch-test"))
        @waits = []
      end

      teardown do
        FileUtils.remove_entry(@storage) if @storage.exist?
      end

      def fetch(http, api_key: CHAVE)
        config = SourceConfig.new(source: "apitcg", base_url: BASE, page_size: 2, timeout: 30, attempts: 3,
                                  api_key: api_key)
        Fetch.new(config: config, storage_dir: @storage, http: http,
                  clock: Struct.new(:now).new(AGORA), sleeper: ->(seconds) { @waits << seconds })
      end

      def page(number) = "#{BASE}/cards?page=#{number}&limit=2"

      def ok(data, total_pages: 3) = [ 200, JSON.generate("data" => data, "totalPages" => total_pages) ]

      def card(id) = { "_id" => id, "code" => "OP01-#{id}" }

      def snapshot_file = @storage.join("apitcg-20260930T210509Z.json")

      def three_pages
        {
          "#{BASE}/sets" => [ [ 200, JSON.generate("data" => [ { "_id" => "one-piece-op01" } ]) ] ],
          page(1) => [ ok([ card("1"), card("2") ]) ],
          page(2) => [ ok([ card("3"), card("4") ]) ],
          page(3) => [ ok([ card("5") ]) ]
        }
      end

      test "o snapshot tem fetched_at, os sets e a união das três páginas" do
        result = fetch(FakeHttp.new(three_pages)).call
        snapshot = JSON.parse(result.path.read)

        assert_equal AGORA.iso8601, snapshot["fetched_at"]
        assert_equal [ "one-piece-op01" ], snapshot["sets"].pluck("_id")
        assert_equal %w[1 2 3 4 5], snapshot["cards"].pluck("_id")
      end

      test "toda requisição leva o header x-api-key com a chave" do
        http = FakeHttp.new(three_pages)
        fetch(http).call

        assert_equal 4, http.calls.size
        http.calls.each { |call| assert_equal CHAVE, call[:headers]["x-api-key"], call[:url] }
      end

      test "o arquivo é apitcg-<UTC>.json, com sha256 e tamanho do conteúdo gravado" do
        result = fetch(FakeHttp.new(three_pages)).call

        assert_equal snapshot_file, result.path
        assert_equal Digest::SHA256.hexdigest(result.path.read), result.sha256
        assert_equal result.path.size, result.byte_size
        assert_equal [ snapshot_file ], @storage.children, "não pode sobrar o .part"
      end

      test "produto repetido entre páginas aparece uma vez (SRC-33)" do
        routes = three_pages.merge(page(2) => [ ok([ card("2"), card("3") ]) ])
        snapshot = JSON.parse(fetch(FakeHttp.new(routes)).call.path.read)

        assert_equal %w[1 2 3 5], snapshot["cards"].pluck("_id")
      end

      test "sem totalPages a paginação para na página vazia" do
        routes = {
          "#{BASE}/sets" => three_pages["#{BASE}/sets"],
          page(1) => [ ok([ card("1"), card("2") ], total_pages: nil) ],
          page(2) => [ ok([], total_pages: nil) ]
        }
        http = FakeHttp.new(routes)
        snapshot = JSON.parse(fetch(http).call.path.read)

        assert_equal %w[1 2], snapshot["cards"].pluck("_id")
        assert_equal 3, http.calls.size
      end

      # Um snapshot incompleto gravado como completo marcaria como ausente o
      # que faltou; toda parada antes do fim declarado é erro.
      test "página vazia antes de totalPages levanta SourceUnavailable sem arquivo" do
        routes = three_pages.merge(page(2) => [ ok([]) ])

        error = assert_raises(Fetch::SourceUnavailable) { fetch(FakeHttp.new(routes)).call }

        assert_match(/página 2 de 3 vazia/, error.message)
        assert_empty @storage.children
      end

      test "totalPages ilegível ou zero levanta SourceUnavailable sem arquivo" do
        [ "n/a", 0, -1 ].each do |invalido|
          routes = three_pages.merge(page(1) => [ ok([ card("1"), card("2") ], total_pages: invalido) ])

          assert_raises(Fetch::SourceUnavailable, "aceitou totalPages #{invalido.inspect}") do
            fetch(FakeHttp.new(routes)).call
          end
          assert_empty @storage.children
        end
      end

      test "sem totalPages uma página incompleta não encerra a busca" do
        routes = {
          "#{BASE}/sets" => three_pages["#{BASE}/sets"],
          page(1) => [ ok([ card("1") ], total_pages: nil) ],
          page(2) => [ ok([ card("2") ], total_pages: nil) ],
          page(3) => [ ok([], total_pages: nil) ]
        }
        snapshot = JSON.parse(fetch(FakeHttp.new(routes)).call.path.read)

        assert_equal %w[1 2], snapshot["cards"].pluck("_id")
      end

      test "a busca que passa do teto de páginas levanta SourceUnavailable sem arquivo" do
        sem_fim = Object.new
        sem_fim.define_singleton_method(:get) do |url, headers:|
          next [ 200, JSON.generate("data" => [ { "_id" => "set" } ]) ] if url.end_with?("/sets")

          number = url[/page=(\d+)/, 1]
          [ 200, JSON.generate("data" => [ { "_id" => "a#{number}" }, { "_id" => "b#{number}" } ]) ]
        end

        error = assert_raises(Fetch::SourceUnavailable) { fetch(sem_fim).call }

        assert_match(/#{Fetch::MAX_PAGES} páginas/, error.message)
        assert_empty @storage.children
      end

      test "catálogo sem cartas ou sem sets levanta SourceUnavailable sem arquivo" do
        sem_cartas = three_pages.merge(page(1) => [ ok([], total_pages: nil) ])
        sem_sets = three_pages.merge("#{BASE}/sets" => [ [ 200, JSON.generate("data" => []) ] ])

        [ sem_cartas, sem_sets ].each do |routes|
          assert_raises(Fetch::SourceUnavailable) { fetch(FakeHttp.new(routes)).call }
          assert_empty @storage.children
        end
      end

      test "produto sem _id ou que não é objeto levanta SourceUnavailable sem arquivo" do
        [ { "code" => "OP01-001" }, { "_id" => " " }, "OP01-001" ].each do |produto|
          routes = three_pages.merge(page(2) => [ ok([ card("3"), produto ]) ])

          assert_raises(Fetch::SourceUnavailable, "aceitou #{produto.inspect}") { fetch(FakeHttp.new(routes)).call }
          assert_empty @storage.children
        end
      end

      test "resposta malformada do HTTP é repetida como falha transitória" do
        routes = three_pages.merge(page(1) => [ Net::HTTPBadResponse.new("wrong status line"),
                                                ok([ card("1"), card("2") ]) ])
        snapshot = JSON.parse(fetch(FakeHttp.new(routes)).call.path.read)

        assert_equal [ 2 ], @waits
        assert_equal %w[1 2 3 4 5], snapshot["cards"].pluck("_id")
      end

      test "status fora de 2xx é repetido com esperas de 2s e 4s e recupera na terceira" do
        routes = three_pages.merge(page(2) => [ [ 503, "" ], [ 500, "" ], ok([ card("3"), card("4") ]) ])
        snapshot = JSON.parse(fetch(FakeHttp.new(routes)).call.path.read)

        assert_equal [ 2, 4 ], @waits
        assert_equal %w[1 2 3 4 5], snapshot["cards"].pluck("_id")
      end

      test "três timeouts levantam SourceUnavailable e nenhum arquivo é gravado (SRC-04)" do
        http = FakeHttp.new(three_pages.merge(page(2) => [ Net::ReadTimeout.new ]))

        error = assert_raises(Fetch::SourceUnavailable) { fetch(http).call }

        assert_match(/3 tentativas/, error.message)
        assert_equal 3, http.calls.count { |call| call[:url] == page(2) }
        assert_equal [ 2, 4 ], @waits
        assert_empty @storage.children, "não pode sobrar arquivo de uma busca que falhou"
      end

      test "três respostas não-2xx levantam SourceUnavailable sem arquivo gravado" do
        routes = three_pages.merge("#{BASE}/sets" => [ [ 500, "" ] ])

        error = assert_raises(Fetch::SourceUnavailable) { fetch(FakeHttp.new(routes)).call }

        assert_match(/500/, error.message)
        assert_empty @storage.children
      end

      test "401 levanta KeyRejected na primeira resposta, sem nova tentativa (SRC-32)" do
        http = FakeHttp.new(three_pages.merge("#{BASE}/sets" => [ [ 401, "" ] ]))

        error = assert_raises(Fetch::KeyRejected) { fetch(http).call }

        assert_equal "chave da apitcg recusada (401)", error.message
        assert_equal 1, http.calls.size
        assert_empty @waits
        assert_empty @storage.children
      end

      test "sem chave nenhuma requisição é feita (SRC-02)" do
        http = FakeHttp.new(three_pages)

        error = assert_raises(SourceConfig::MissingApiKey) { fetch(http, api_key: "").call }

        assert_equal "APITCG_API_KEY não configurada", error.message
        assert_empty http.calls
      end

      test "o valor da chave não aparece no arquivo gravado (SRC-05)" do
        result = fetch(FakeHttp.new(three_pages)).call

        refute_includes result.path.read, CHAVE
      end

      test "resposta que ecoa a chave descarta o snapshot (SRC-05)" do
        routes = three_pages.merge(page(3) => [ ok([ { "_id" => "5", "debug" => "x-api-key=#{CHAVE}" } ]) ])

        error = assert_raises(Fetch::SourceUnavailable) { fetch(FakeHttp.new(routes)).call }

        refute_includes error.message, CHAVE
        assert_empty @storage.children
      end

      test "o valor da chave não aparece na mensagem de nenhum erro (SRC-05)" do
        ecoa_a_chave = SocketError.new("falha ao conectar com x-api-key: #{CHAVE}")
        cenarios = [
          three_pages.merge("#{BASE}/sets" => [ ecoa_a_chave ]),
          three_pages.merge("#{BASE}/sets" => [ [ 401, "" ] ]),
          three_pages.merge(page(1) => [ [ 502, "" ] ])
        ]

        cenarios.each do |routes|
          error = assert_raises(Fetch::SourceUnavailable) { fetch(FakeHttp.new(routes)).call }
          refute_includes error.message, CHAVE
        end
      end

      test "arquivo com o mesmo nome já existente não é sobrescrito" do
        snapshot_file.write("snapshot anterior")
        http = FakeHttp.new(three_pages)

        assert_raises(Fetch::SnapshotExists) { fetch(http).call }

        assert_equal "snapshot anterior", snapshot_file.read
        assert_empty http.calls, "a busca não deve começar se o destino já existe"
      end

      test "snapshot criado por outra execução durante a busca não é sobrescrito" do
        concorrente = ->(url) { snapshot_file.write("outra execução") if url == page(3) }
        http = FakeHttp.new(three_pages, before_get: concorrente)

        assert_raises(Fetch::SnapshotExists) { fetch(http).call }

        assert_equal "outra execução", snapshot_file.read
        assert_equal [ snapshot_file ], @storage.children, "não pode sobrar o .part"
      end
    end
  end
end
