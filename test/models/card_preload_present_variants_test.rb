require "test_helper"

# T3 (api-fundacao) — API-21: o pré-carregamento traz só as variantes presentes
# na fonte, numa consulta de variantes para N cartas.
class CardPreloadPresentVariantsTest < ActiveSupport::TestCase
  setup do
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @earlier = Time.utc(2026, 9, 1, 12)
    @latest = Time.utc(2026, 9, 20, 12)
    ImportRun.create!(source: "apitcg", source_revision: "a.json", status: "succeeded", started_at: @earlier)
    ImportRun.create!(source: "apitcg", source_revision: "b.json", status: "succeeded", started_at: @latest)
  end

  def card!(number)
    Card.create!(set_id: @set.id, card_number: number, name: "Carta #{number}",
                 card_type: "character", colors: [ "Red" ])
  end

  def variant!(card, code, last_seen_at)
    CardVariant.create!(card: card, set_id: @set.id, variant_code: code, art_kind: "base",
                        last_seen_at: last_seen_at)
  end

  test "a variante ausente fica fora e a presente entra" do
    card = card!("OP01-001")
    presente = variant!(card, "tcgplayer:1", @latest)
    variant!(card, "tcgplayer:2", @earlier)

    Card.preload_present_variants([ card ])

    assert_equal [ presente.id ], card.card_variants.map(&:id)
  end

  test "carta sem variante presente fica com a lista vazia" do
    card = card!("OP01-001")
    variant!(card, "tcgplayer:1", @earlier)

    Card.preload_present_variants([ card ])

    assert_empty card.card_variants
  end

  test "N cartas custam uma consulta de variantes" do
    cards = %w[OP01-001 OP01-002 OP01-003].each_with_index.map do |number, i|
      card!(number).tap { |c| variant!(c, "tcgplayer:#{i}", @latest) }
    end
    cards = Card.where(id: cards.map(&:id)).to_a

    queries = []
    counter = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "card_variants"') }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      Card.preload_present_variants(cards)
      cards.each { |c| c.card_variants.to_a }
    end

    assert_equal 1, queries.size
  end
end
