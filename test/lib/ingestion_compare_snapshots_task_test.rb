require "test_helper"
require "rake"
require "tmpdir"

# T15 (fonte-apitcg) — `ingestion:compare_snapshots` (SRC-31): task que chama
# `CompareSnapshots`, imprime comuns e mudados, uma linha por mudança com `_id` e
# os dois ids, e sai com código 1 com mensagem em português quando faltam A ou B
# ou o arquivo não existe/é ilegível.
class IngestionCompareSnapshotsTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ingestion:compare_snapshots")
  end

  test "com A= e B=, imprime comuns e mudados, e sai com código 0" do
    with_snapshots(
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } },
        { "_id" => "prod-002", "markets" => { "tcgplayer" => { "id" => "456" } } }
      ],
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "999" } } },
        { "_id" => "prod-002", "markets" => { "tcgplayer" => { "id" => "456" } } }
      ]
    ) do |a_path, b_path|
      out, err, status = run_task(a_path, b_path)

      assert_equal 0, status
      assert_empty err
      lines = out.lines.map(&:chomp)
      assert_equal "comuns: 2", lines[0]
      assert_equal "mudados: 1", lines[1]
    end
  end

  test "imprime uma linha por mudança com _id, id antigo e novo" do
    with_snapshots(
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } }
      ],
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "999" } } }
      ]
    ) do |a_path, b_path|
      out, _err, status = run_task(a_path, b_path)

      assert_equal 0, status
      lines = out.lines.map(&:chomp)
      assert_equal "prod-001 123 → 999", lines[2]
    end
  end

  test "sem A, imprime mensagem e sai com código 1" do
    with_snapshots([], [ { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } } ]) do |_, b_path|
      out, err, status = run_task(nil, b_path)

      assert_equal 1, status
      assert_empty out
      assert_includes err, "faltam argumentos"
    end
  end

  test "sem B, imprime mensagem e sai com código 1" do
    with_snapshots([ { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } } ], []) do |a_path, _|
      out, err, status = run_task(a_path, nil)

      assert_equal 1, status
      assert_empty out
      assert_includes err, "faltam argumentos"
    end
  end

  test "arquivo inexistente, imprime mensagem e sai com código 1" do
    out, err, status = run_task("/nonexistent/file.json", "/nonexistent/other.json")

    assert_equal 1, status
    assert_empty out
    assert_includes err, "não conseguiu ler"
  end

  private

  def run_task(a_path, b_path)
    status = 0
    out, err = capture_io do
      ENV["A"] = a_path
      ENV["B"] = b_path
      Rake::Task["ingestion:compare_snapshots"].execute
    rescue SystemExit => e
      status = e.status
    end
    [ out, err, status ]
  end

  def with_snapshots(a_cards, b_cards)
    Dir.mktmpdir do |tmpdir|
      a_path = File.join(tmpdir, "snapshot_a.json")
      b_path = File.join(tmpdir, "snapshot_b.json")
      File.write(a_path, JSON.generate({ "fetched_at" => Time.now.utc.iso8601, "cards" => a_cards, "sets" => [] }))
      File.write(b_path, JSON.generate({ "fetched_at" => Time.now.utc.iso8601, "cards" => b_cards, "sets" => [] }))
      yield a_path, b_path
    end
  end
end
