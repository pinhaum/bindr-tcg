require "test_helper"

# T1 (fonte-apitcg) — SRC-16: "presente na fonte" é ter sido vista na última
# execução da ingestão com status `succeeded`. A ingestão grava em
# `last_seen_at` o `started_at` do run que viu a variante (`upsert.rb`), e é
# sobre esse par que o scope decide.
class CardVariantPresenceTest < ActiveSupport::TestCase
  setup do
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(set_id: @set.id, card_number: "OP01-001", name: "Roronoa Zoro",
                         card_type: "leader", colors: [ "Red" ])
    @earlier = Time.utc(2026, 9, 1, 12)
    @latest = Time.utc(2026, 9, 20, 12)
  end

  def run!(status, started_at)
    ImportRun.create!(source: "apitcg", source_revision: "apitcg-teste.json", status: status,
                      started_at: started_at)
  end

  def variant!(code, last_seen_at)
    CardVariant.create!(card: @card, set_id: @set.id, variant_code: code, art_kind: "base",
                        last_seen_at: last_seen_at)
  end

  test "sem nenhum run succeeded, nenhuma variante é presente" do
    variant!("OP01-001", @latest)
    run!("failed", @latest)
    run!("running", @latest)

    assert_empty CardVariant.present
  end

  test "a variante vista no último run succeeded é presente" do
    run!("succeeded", @latest)
    vista = variant!("tcgplayer:1", @latest)

    assert_equal [ vista.id ], CardVariant.present.pluck(:id)
  end

  test "a variante vista só num run succeeded anterior é ausente" do
    run!("succeeded", @earlier)
    run!("succeeded", @latest)
    antiga = variant!("OP01-001", @earlier)
    nova = variant!("tcgplayer:1", @latest)

    assert_equal [ nova.id ], CardVariant.present.pluck(:id)
    assert_not_includes CardVariant.present.pluck(:id), antiga.id
  end

  test "um run failed depois do succeeded não altera a presença" do
    run!("succeeded", @earlier)
    antes = variant!("OP01-001", @earlier)
    run!("failed", @latest)

    assert_equal [ antes.id ], CardVariant.present.pluck(:id)
  end

  test "variante nunca vista por nenhum run não é presente" do
    run!("succeeded", @latest)
    variant!("OP01-001", nil)

    assert_empty CardVariant.present
  end
end
