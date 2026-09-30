require "test_helper"
require "rake"

# T6 (fonte-apitcg) — `ingestion:remap` (SRC-19, SRC-21, SRC-23): a task chama
# `Ingestion::Remap`, imprime o total movido e uma linha por item pulado com
# `card_number`, `variant_code` antigo e motivo, sem nenhum dado do usuário, e
# sai com código 1 quando não há ingestão concluída.
class IngestionRemapTaskTest < ActiveSupport::TestCase
  OLD_RUN_AT = Time.utc(2026, 9, 1, 12)
  NEW_RUN_AT = Time.utc(2026, 9, 29, 12)

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("ingestion:remap")

    ImportRun.create!(source: "optcgjson", source_revision: "antiga", status: "succeeded", started_at: OLD_RUN_AT)
    ImportRun.create!(source: "apitcg", source_revision: "apitcg-nova.json", status: "succeeded",
                      started_at: NEW_RUN_AT)
    @user = User.create!(email: "dona-da-pasta@example.com", password: "log-pose-77")
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")

    luffy = card("OP01-001")
    @luffy_old = variant(luffy, "OP01-001", OLD_RUN_AT)
    variant(luffy, "tcgplayer:11", NEW_RUN_AT)
    usopp = card("OP01-004")
    @usopp_old = variant(usopp, "OP01-004", OLD_RUN_AT)
  end

  def card(number)
    Card.create!(set_id: @set.id, card_number: number, name: "Carta #{number}", card_type: "character",
                 colors: [ "Red" ])
  end

  def variant(card, code, seen)
    CardVariant.create!(card: card, set_id: @set.id, variant_code: code, rarity: "C", art_kind: "base",
                        last_seen_at: seen)
  end

  # Devolve `[stdout, stderr, código de saída]`; sem `exit`, o código é 0.
  def run_task
    status = 0
    out, err = capture_io do
      Rake::Task["ingestion:remap"].execute
    rescue SystemExit => e
      status = e.status
    end
    [ out, err, status ]
  end

  test "imprime o total movido e uma linha por pulado, e sai com código 0" do
    moved = CollectionItem.create!(user: @user, card_variant: @luffy_old, quantity: 2)
    skipped = WishlistItem.create!(user: @user, card_variant: @usopp_old, target_quantity: 1)

    out, err, status = run_task

    assert_equal 0, status
    assert_empty err
    assert_equal [ "movidos: 1 | pulados: 1", "pulado: OP01-004 | OP01-004 | sem candidato" ], out.lines.map(&:chomp)
    [ @user.email, @user.id, moved.id, skipped.id ].each do |dado|
      refute_match(/\b#{Regexp.escape(dado.to_s)}\b/, out, "a saída não pode expor dado do usuário")
    end
  end

  test "sem run succeeded, imprime a mensagem de SRC-23 e sai com código 1" do
    item = CollectionItem.create!(user: @user, card_variant: @luffy_old, quantity: 2)
    ImportRun.update_all(status: "failed")

    out, err, status = run_task

    assert_equal 1, status
    assert_includes out + err, "nenhuma ingestão concluída; rode ingestion:import antes"
    assert_equal @luffy_old.id, item.reload.card_variant_id
  end
end
