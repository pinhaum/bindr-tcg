require "test_helper"

# T4 (fonte-apitcg) — progresso por números de carta distintos (Req. 9.1, 9.4 e
# 9.5 emendados; SRC-25..SRC-28, SRC-35).
#
# Dois sets com as duas formas que o `base_set_size` derivado (SRC-24) assume:
#
# - `OP01`, numeração própria: 3 números `OP01-*` e 1 reimpressão `ST01-001`.
#   Os números com o prefixo são maioria estrita, então a ingestão grava
#   `base_set_size = 3`, menor que os 4 números distintos do set. O universo do
#   numerador é só `OP01-*`.
# - `ST15`, reimpressão: nenhum número com o prefixo `ST15-` (SRC-35), então a
#   ingestão grava `base_set_size = 2`, igual aos números distintos do set. O
#   universo do numerador é o set inteiro.
class SetProgressNumbersTest < ActiveSupport::TestCase
  OLD_RUN_AT = Time.utc(2026, 9, 1, 12)
  NEW_RUN_AT = Time.utc(2026, 9, 29, 12)

  setup do
    ImportRun.create!(source: "optcgjson", source_revision: "antiga", status: "succeeded", started_at: OLD_RUN_AT)
    ImportRun.create!(source: "apitcg", source_revision: "apitcg-nova.json", status: "succeeded",
                      started_at: NEW_RUN_AT)
    @user = User.create!(email: "numeros@example.com", password: "log-pose-77")

    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster", base_set_size: 3)
    @st01 = CardSet.create!(code: "ST01", name: "Straw Hat Crew", kind: "starter")
    @st15 = CardSet.create!(code: "ST15", name: "Red Edward.Newgate", kind: "starter", base_set_size: 2)

    @luffy = card("OP01-001", @op01)
    @zoro = card("OP01-002", @op01)
    @nami = card("OP01-003", @op01)
    @usopp = card("ST01-001", @st01)
    @ace = card("OP02-013", @op01)
    @marco = card("OP03-013", @op01)

    @luffy_base = variant(@luffy, "tcgplayer:1", @op01, "base")
    @luffy_topper = variant(@luffy, "tcgplayer:2", @op01, "base")
    @luffy_parallel = variant(@luffy, "tcgplayer:3", @op01, "parallel")
    @zoro_alt = variant(@zoro, "tcgplayer:4", @op01, "alternate_art")
    @nami_manga = variant(@nami, "tcgplayer:5", @op01, "manga")
    @usopp_em_op01 = variant(@usopp, "tcgplayer:6", @op01, "base")

    @ace_em_st15 = variant(@ace, "tcgplayer:7", @st15, "base")
    @marco_em_st15 = variant(@marco, "tcgplayer:8", @st15, "promo")
  end

  def card(number, set)
    Card.create!(card_set: set, card_number: number, name: "Carta #{number}", card_type: "character",
                 colors: [ "Red" ])
  end

  def variant(card, code, set, art_kind, seen: NEW_RUN_AT)
    CardVariant.create!(card: card, set_id: set.id, variant_code: code, rarity: "C", art_kind: art_kind,
                        last_seen_at: seen)
  end

  def own(*variants)
    variants.each { |v| CollectionItem.create!(user: @user, card_variant: v, quantity: 1) }
  end

  def progress = SetProgressQuery.new(@user).call.index_by(&:set_code)

  # --- Done when 1: numeração própria conta só os números com o prefixo ---

  test "set de numeração própria conta no numerador só os números com o prefixo do set" do
    own(@luffy_base, @usopp_em_op01)

    op01 = progress["OP01"]

    assert_equal 1, op01.owned_numbers, "ST01-001 está fora do universo de OP01"
    assert_equal 3, op01.base_size
  end

  # --- Done when 2: reimpressão conta todos os números ---

  test "set de reimpressão conta no numerador todos os números do set" do
    own(@ace_em_st15, @marco_em_st15)

    st15 = progress["ST15"]

    assert_equal 2, st15.owned_numbers
    assert_equal 2, st15.base_size
    assert_equal 100.0, st15.completion_percent
  end

  # --- Done when 3 / SRC-28 / SRC-25 ---

  test "base e Box Topper do mesmo número contam uma vez" do
    own(@luffy_base, @luffy_topper)

    assert_equal 1, progress["OP01"].owned_numbers
  end

  test "alternate_art, manga e promo entram no numerador" do
    own(@zoro_alt, @nami_manga, @marco_em_st15)

    resultado = progress

    assert_equal 2, resultado["OP01"].owned_numbers
    assert_equal 1, resultado["ST15"].owned_numbers
  end

  test "parallel não entra no numerador e continua na métrica separada" do
    own(@luffy_parallel)

    op01 = progress["OP01"]

    assert_equal 0, op01.owned_numbers
    assert_equal 1, op01.parallel_owned_variants
    assert_equal 1, op01.parallel_variants
  end

  # --- Done when 4 / SRC-26: teto de 100% ---

  test "mais variantes possuídas que o denominador não passa de 100%" do
    own(@luffy_base, @luffy_topper, @luffy_parallel, @zoro_alt, @nami_manga, @usopp_em_op01)

    op01 = progress["OP01"]

    assert_equal 3, op01.owned_numbers
    assert_equal 100.0, op01.completion_percent
  end

  # --- Done when 6 / SRC-16: presença ---

  test "set sem variante presente não aparece na lista" do
    antigo = CardSet.create!(code: "OLD01", name: "Só na fonte antiga", kind: "booster", base_set_size: 1)
    variant(card("OLD01-001", antigo), "OLD01-001", antigo, "base", seen: OLD_RUN_AT)

    assert_not_includes progress.keys, "OLD01"
    assert_includes progress.keys, "OP01"
  end

  test "variante ausente possuída não entra no numerador" do
    ausente = variant(@zoro, "OP01-002", @op01, "base", seen: OLD_RUN_AT)
    own(ausente)

    assert_equal 0, progress["OP01"].owned_numbers
  end
end
