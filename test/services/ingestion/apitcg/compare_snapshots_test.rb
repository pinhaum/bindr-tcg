require "test_helper"
require "tmpdir"

# T15 (fonte-apitcg) — `CompareSnapshots` (SRC-31): cruza dois snapshots
# pelo `_id` e informa quantos produtos comuns mudaram de `markets.tcgplayer.id`.
class Ingestion::Apitcg::CompareSnapshotsTest < ActiveSupport::TestCase
  def test_two_snapshots_with_one_id_changed
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
      result = Ingestion::Apitcg::CompareSnapshots.call(a_path, b_path)

      assert_equal 2, result.common
      assert_equal 1, result.changed
      assert_equal 1, result.changes.size
      assert_equal "prod-001", result.changes[0][:_id]
      assert_equal "123", result.changes[0][:from]
      assert_equal "999", result.changes[0][:to]
    end
  end

  def test_product_only_in_one_side_does_not_count_as_change
    with_snapshots(
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } },
        { "_id" => "prod-002", "markets" => { "tcgplayer" => { "id" => "456" } } }
      ],
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } }
      ]
    ) do |a_path, b_path|
      result = Ingestion::Apitcg::CompareSnapshots.call(a_path, b_path)

      assert_equal 1, result.common
      assert_equal 0, result.changed
      assert_equal 1, result.only_in_a
      assert_equal 0, result.only_in_b
    end
  end

  def test_no_changes_when_tcgplayer_ids_are_identical
    with_snapshots(
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } }
      ],
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } }
      ]
    ) do |a_path, b_path|
      result = Ingestion::Apitcg::CompareSnapshots.call(a_path, b_path)

      assert_equal 1, result.common
      assert_equal 0, result.changed
    end
  end

  def test_id_absent_on_one_side_counts_as_change
    with_snapshots(
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => { "id" => "123" } } }
      ],
      [
        { "_id" => "prod-001", "markets" => { "tcgplayer" => {} } }
      ]
    ) do |a_path, b_path|
      result = Ingestion::Apitcg::CompareSnapshots.call(a_path, b_path)

      assert_equal 1, result.common
      assert_equal 1, result.changed
      assert_equal "prod-001", result.changes[0][:_id]
      assert_equal "123", result.changes[0][:from]
      assert_nil result.changes[0][:to]
    end
  end

  private

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
