require "test_helper"

module Ingestion
  # T13 (fonte-apitcg) — SRC-02, SRC-04, SRC-06, SRC-07, SRC-08, SRC-32: o
  # reprocessamento de snapshot não toca rede nem chave, e a falha da busca
  # vira um `ImportRun` `failed` sem escrita no catálogo. HTTP sempre falso.
  class RunTest < ActiveSupport::TestCase
    CHAVE = "chave-de-teste".freeze
    BASE = "https://apitcg.test/api".freeze
    FIXTURE = Rails.root.join("spec", "fixtures", "apitcg-subset.json")

    # Falha se for chamado: prova que o caminho com snapshot não usa a rede.
    class ForbiddenHttp
      attr_reader :calls

      def initialize = @calls = 0

      def get(_url, headers:)
        @calls += 1
        raise "o cliente HTTP não podia ser chamado"
      end
    end

    # Responde por URL; a última resposta de cada fila se repete.
    class FakeHttp
      attr_reader :calls

      def initialize(routes)
        @routes = routes
        @calls = []
      end

      def get(url, headers:)
        @calls << url
        @routes.fetch(url) { raise "URL inesperada: #{url}" }
      end
    end

    setup do
      @storage = Pathname(Dir.mktmpdir("apitcg-run-test"))
      @waits = []
    end

    teardown do
      FileUtils.remove_entry(@storage) if @storage.exist?
    end

    def config(api_key: CHAVE)
      SourceConfig.new(source: "apitcg", base_url: BASE, page_size: 1000, timeout: 30, attempts: 3,
                       api_key: api_key)
    end

    def fetch_with(http, cfg)
      Apitcg::Fetch.new(config: cfg, storage_dir: @storage, http: http,
                        clock: Struct.new(:now).new(Time.utc(2026, 10, 1, 12)),
                        sleeper: ->(seconds) { @waits << seconds })
    end

    def catalog_counts = [ Card.count, CardVariant.count, CardSet.count ]

    def snapshot_routes
      snapshot = JSON.parse(FIXTURE.read)
      {
        "#{BASE}/one-piece/sets" => [ 200, JSON.generate("data" => snapshot["sets"]) ],
        "#{BASE}/products?tcg=one-piece&type=card&page=1&limit=1000" =>
          [ 200, JSON.generate("data" => snapshot["cards"], "total" => snapshot["cards"].size) ]
      }
    end

    test "com snapshot roda sem chave e sem tocar o cliente HTTP, e grava a revisão com o SHA-256" do
      http = ForbiddenHttp.new
      run = Run.call(snapshot: FIXTURE.to_s, config: config(api_key: nil), fetch: fetch_with(http, config))

      assert_equal "succeeded", run.status
      assert_equal 0, http.calls
      assert_equal "apitcg-subset.json sha256:#{Digest::SHA256.file(FIXTURE).hexdigest}", run.source_revision
      assert_operator Card.count, :>, 0
    end

    test "o mesmo snapshot duas vezes deixa as contagens do catálogo idênticas" do
      Run.call(snapshot: FIXTURE.to_s, config: config(api_key: nil))
      first = catalog_counts

      second_run = Run.call(snapshot: FIXTURE.to_s, config: config(api_key: nil))

      assert_equal "succeeded", second_run.status
      assert_equal first, catalog_counts
      assert_equal 0, second_run.created_count
    end

    test "com snapshot o Fetch nem chega a ser construído" do
      fetch = Apitcg::Fetch
      fetch.singleton_class.alias_method(:new_original, :new)
      fetch.define_singleton_method(:new) { |**| raise "o Fetch não podia ser construído" }

      run = Run.call(snapshot: FIXTURE.to_s, config: config(api_key: nil))

      assert_equal "succeeded", run.status
    ensure
      fetch.singleton_class.alias_method(:new, :new_original)
      fetch.singleton_class.remove_method(:new_original)
    end

    test "snapshot inexistente levanta erro em português antes de criar ImportRun" do
      error = assert_raises(Run::SnapshotUnreadable) do
        Run.call(snapshot: @storage.join("nao-existe.json").to_s, config: config(api_key: nil))
      end

      assert_match(/não foi possível ler o snapshot/, error.message)
      assert_equal 0, ImportRun.count
    end

    test "snapshot que não é JSON levanta erro em português antes de criar ImportRun" do
      path = @storage.join("quebrado.json")
      path.write("{ isso não é json")

      error = assert_raises(Run::SnapshotUnreadable) { Run.call(snapshot: path.to_s, config: config(api_key: nil)) }

      assert_match(/não é um JSON válido/, error.message)
      assert_equal 0, ImportRun.count
    end

    test "busca com as 3 tentativas esgotadas gera run failed sem escrita no catálogo" do
      http = FakeHttp.new("#{BASE}/one-piece/sets" => [ 500, "erro" ])
      before = catalog_counts

      run = Run.call(config: config, fetch: fetch_with(http, config))

      assert_equal "failed", run.status
      assert_equal "(busca não concluída)", run.source_revision
      assert_equal "apitcg", run.source
      assert_equal 3, http.calls.size
      assert_equal 0, run.failed_count
      assert_not_nil run.finished_at
      entry = run.error_log.sole
      assert_equal "fetch", entry["identifier"]
      assert_equal "Ingestion::Apitcg::Fetch::SourceUnavailable", entry["error"]
      assert_match(/após 3 tentativas/, entry["message"])
      assert_equal before, catalog_counts
    end

    test "401 gera run failed com a mensagem da chave recusada, sem repetir" do
      http = FakeHttp.new("#{BASE}/one-piece/sets" => [ 401, "" ])
      before = catalog_counts

      run = Run.call(config: config, fetch: fetch_with(http, config))

      assert_equal "failed", run.status
      assert_equal 1, http.calls.size
      assert_equal "Ingestion::Apitcg::Fetch::KeyRejected", run.error_log.sole["error"]
      assert_equal "chave da apitcg recusada (401)", run.error_log.sole["message"]
      assert_equal before, catalog_counts
    end

    test "a chave nunca entra no error_log, mesmo se a mensagem do erro a contiver" do
      leaky = Class.new do
        def call = raise(Apitcg::Fetch::SourceUnavailable, "falhou com #{CHAVE} no meio")
      end

      run = Run.call(config: config, fetch: leaky.new)

      assert_equal "falhou com [FILTRADA] no meio", run.error_log.sole["message"]
      refute_includes run.error_log.to_json, CHAVE
    end

    test "snapshot já existente na busca gera run failed" do
      Run.call(config: config, fetch: fetch_with(FakeHttp.new(snapshot_routes), config))
      http = FakeHttp.new(snapshot_routes)

      run = Run.call(config: config, fetch: fetch_with(http, config))

      assert_equal "failed", run.status
      assert_equal "Ingestion::Apitcg::Fetch::SnapshotExists", run.error_log.sole["error"]
    end

    test "sem chave e sem snapshot levanta MissingApiKey sem ImportRun nem rede" do
      http = ForbiddenHttp.new
      cfg = config(api_key: nil)

      error = assert_raises(SourceConfig::MissingApiKey) { Run.call(config: cfg, fetch: fetch_with(http, cfg)) }

      assert_match(/APITCG_API_KEY não configurada/, error.message)
      assert_equal 0, ImportRun.count
      assert_equal 0, http.calls
    end

    test "a chave é exigida antes de o Fetch ser chamado" do
      fetch = Object.new
      fetch.define_singleton_method(:call) { flunk "o Fetch não podia ser chamado sem chave" }

      assert_raises(SourceConfig::MissingApiKey) { Run.call(config: config(api_key: nil), fetch: fetch) }
      assert_equal 0, ImportRun.count
    end

    test "busca bem-sucedida pelo Fetch processa o snapshot gravado e termina succeeded" do
      http = FakeHttp.new(snapshot_routes)

      run = Run.call(config: config, fetch: fetch_with(http, config))

      assert_equal "succeeded", run.status
      assert_equal 2, http.calls.size
      saved = @storage.glob("apitcg-*.json").sole
      assert_match(/\A#{Regexp.escape(saved.basename.to_s)} sha256:\h{64}\z/, run.source_revision)
      assert_operator Card.count, :>, 0
    end
  end
end
