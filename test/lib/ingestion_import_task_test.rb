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
    assert_includes out, "revisão: apitcg-subset.json sha256:"
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

  test "o rake não menciona mais REUSE_PAYLOAD" do
    refute_includes Rails.root.join("lib", "tasks", "ingestion.rake").read, "REUSE_PAYLOAD"
  end
end
