require "test_helper"
require "rake"

# T13 (fonte-apitcg) — `ingestion:import SNAPSHOT=` (SRC-02, SRC-07): com
# snapshot roda sem chave; sem chave e sem snapshot aborta com a mensagem e
# código 1; arquivo inexistente também sai com 1. Nenhum teste faz rede.
class IngestionImportTaskTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join("spec", "fixtures", "apitcg-subset.json")

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ingestion:import")
    @original_env = ENV.to_h.slice("SNAPSHOT", "APITCG_API_KEY")
    ENV.delete("SNAPSHOT")
    ENV.delete("APITCG_API_KEY")
  end

  teardown do
    %w[SNAPSHOT APITCG_API_KEY].each { |name| ENV.delete(name) }
    @original_env.each { |name, value| ENV[name] = value }
  end

  # Cliente HTTP falso da busca real: responde sempre o mesmo, sem rede.
  class FailingHttp
    def initialize(response) = @response = response

    def get(_url, headers:)
      raise @response if @response.is_a?(Exception)

      @response
    end
  end

  CHAVE = "chave-de-teste".freeze

  # Roda a task em modo de busca, com a chave no ambiente e o cliente HTTP trocado.
  # `attempts: 1` evita o backoff real de 2s + 4s.
  def run_fetch_task(response)
    ENV["APITCG_API_KEY"] = CHAVE
    config = Ingestion::SourceConfig.new(source: "apitcg", base_url: "https://apitcg.test/api", page_size: 100,
                                         timeout: 30, attempts: 1, api_key: CHAVE)
    swap(Ingestion::SourceConfig, :load, ->(*) { config }) do
      swap(Ingestion::Apitcg::Fetch::NetHttpClient, :new, ->(**) { FailingHttp.new(response) }) { run_task }
    end
  end

  def swap(target, name, replacement)
    original = target.method(name)
    target.define_singleton_method(name) { |*args, **kwargs| replacement.call(*args, **kwargs) }
    yield
  ensure
    target.define_singleton_method(name, original)
  end

  # Devolve `[stdout, stderr, código de saída]`; sem `exit`, o código é 0.
  def run_task
    status = 0
    out, err = capture_io do
      Rake::Task["ingestion:import"].execute
    rescue SystemExit => e
      status = e.status
    end
    [ out, err, status ]
  end

  test "com SNAPSHOT e sem chave no ambiente: sucesso, código 0 e status succeeded" do
    ENV["SNAPSHOT"] = FIXTURE.to_s

    out, err, status = run_task

    assert_equal 0, status
    assert_empty err
    assert_includes out, "status: succeeded"
    assert_includes out, "revisão: apitcg-subset.json sha256:#{Digest::SHA256.file(FIXTURE).hexdigest}\n"
  end

  test "sem chave e sem SNAPSHOT: mensagem no stderr, código 1 e nenhum ImportRun" do
    out, err, status = run_task

    assert_equal 1, status
    assert_empty out
    assert_equal "APITCG_API_KEY não configurada\n", err
    assert_equal 0, ImportRun.count
  end

  test "SNAPSHOT inexistente: mensagem em português, código 1 e nenhum ImportRun" do
    ENV["SNAPSHOT"] = Rails.root.join("tmp", "nao-existe.json").to_s

    out, err, status = run_task

    assert_equal 1, status
    assert_empty out
    assert_match(/não foi possível ler o snapshot/, err)
    assert_equal 0, ImportRun.count
  end

  test "busca que falha: stdout com status failed, código 1 e a chave fora de stdout e stderr" do
    out, err, status = run_fetch_task(SocketError.new("falha ao conectar com x-api-key: #{CHAVE}"))

    assert_equal 1, status
    assert_includes out, "status: failed"
    assert_includes out, "criados: 0 | atualizados: 0 | falhados: 0"
    refute_includes out, CHAVE
    refute_includes err, CHAVE
    run = ImportRun.sole
    assert_equal "failed", run.status
    assert_includes run.error_log.sole["message"], "[FILTRADA]"
    refute_includes run.error_log.to_json, CHAVE
    assert_equal [ 0, 0, 0 ], [ Card.count, CardVariant.count, CardSet.count ]
  end

  test "401: stdout com status failed, código 1, mensagem da chave recusada no run e a chave fora da saída" do
    out, err, status = run_fetch_task([ 401, "" ])

    assert_equal 1, status
    assert_includes out, "status: failed"
    refute_includes out, CHAVE
    refute_includes err, CHAVE
    assert_equal "chave da apitcg recusada (401)", ImportRun.sole.error_log.sole["message"]
    assert_equal [ 0, 0, 0 ], [ Card.count, CardVariant.count, CardSet.count ]
  end

  test "o rake não menciona mais REUSE_PAYLOAD" do
    refute_includes Rails.root.join("lib", "tasks", "ingestion.rake").read, "REUSE_PAYLOAD"
  end
end
