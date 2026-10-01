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

    @luffy = card("OP01-001")
    @luffy_old = variant(@luffy, "OP01-001", OLD_RUN_AT)
    @luffy_new = variant(@luffy, "tcgplayer:11", NEW_RUN_AT)
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
    # As linhas exatas já excluem qualquer dado do usuário (SRC-23).
    assert_equal [ "movidos: 1 | pulados: 1", "pulado: OP01-004 | OP01-004 | sem candidato" ], out.lines.map(&:chomp)
    assert_equal @luffy_new.id, moved.reload.card_variant_id
    assert_equal @usopp_old.id, skipped.reload.card_variant_id
  end

  test "a saída traz as linhas de colisão e de ambíguo com o texto exato" do
    CollectionItem.create!(user: @user, card_variant: @luffy_new, quantity: 1)
    CollectionItem.create!(user: @user, card_variant: @luffy_old, quantity: 1)
    nami = card("OP01-016")
    nami_old = variant(nami, "OP01-016", OLD_RUN_AT)
    variant(nami, "tcgplayer:21", NEW_RUN_AT)
    variant(nami, "tcgplayer:22", NEW_RUN_AT)
    CollectionItem.create!(user: @user, card_variant: nami_old, quantity: 1)

    out, _err, status = run_task

    assert_equal 0, status
    assert_equal [ "movidos: 0 | pulados: 2", "pulado: OP01-001 | OP01-001 | colisão",
                   "pulado: OP01-016 | OP01-016 | ambíguo" ], out.lines.map(&:chomp)
  end

  test "a segunda execução não move nada e repete os pulados" do
    moved = CollectionItem.create!(user: @user, card_variant: @luffy_old, quantity: 2)
    WishlistItem.create!(user: @user, card_variant: @usopp_old, target_quantity: 1)
    run_task

    out, _err, status = run_task

    assert_equal 0, status
    assert_equal [ "movidos: 0 | pulados: 1", "pulado: OP01-004 | OP01-004 | sem candidato" ], out.lines.map(&:chomp)
    assert_equal @luffy_new.id, moved.reload.card_variant_id
  end

  test "sem nada a mover nem a pular, imprime os dois totais zerados" do
    out, err, status = run_task

    assert_equal 0, status
    assert_empty err
    assert_equal "movidos: 0 | pulados: 0\n", out
  end

  test "sem run succeeded, imprime a mensagem de SRC-23 e sai com código 1" do
    item = CollectionItem.create!(user: @user, card_variant: @luffy_old, quantity: 2)
    ImportRun.update_all(status: "failed")

    out, err, status = run_task

    assert_equal 1, status
    assert_empty out
    assert_equal "nenhuma ingestão concluída; rode ingestion:import antes\n", err
    assert_equal @luffy_old.id, item.reload.card_variant_id
  end

  test "coleção alterada durante o remap: mensagem no stderr e código 1" do
    remap = Ingestion::Remap
    remap.singleton_class.alias_method(:call_original, :call)
    remap.define_singleton_method(:call) { raise Ingestion::Remap::ConcurrentChange, Ingestion::Remap::CONCURRENT_CHANGE_MESSAGE }

    out, err, status = run_task

    assert_equal 1, status
    assert_empty out
    assert_equal "a coleção mudou durante o remapeamento; rode ingestion:remap de novo\n", err
  ensure
    remap.singleton_class.alias_method(:call, :call_original)
    remap.singleton_class.remove_method(:call_original)
  end
end
