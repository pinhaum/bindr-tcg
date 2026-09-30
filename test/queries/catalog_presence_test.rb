require "test_helper"

# T2 (fonte-apitcg) — SRC-15 e SRC-16: grade, busca, filtros e lista de sets
# consideram só as variantes presentes na fonte, isto é, vistas pelo último
# run `succeeded` da ingestão. A carta e o set entram quando têm ao menos uma
# variante presente.
#
# O cenário é o da troca de fonte: um run `succeeded` antigo (optcgjson) e um
# novo (apitcg). O que a ingestão nova não viu fica com o `last_seen_at` do
# run antigo e, portanto, ausente.
class CatalogPresenceTest < ActiveSupport::TestCase
  OLD_RUN_AT = Time.utc(2026, 9, 1, 12)
  NEW_RUN_AT = Time.utc(2026, 9, 29, 12)

  setup do
    ImportRun.create!(source: "optcgjson", source_revision: "antiga", status: "succeeded", started_at: OLD_RUN_AT)
    ImportRun.create!(source: "apitcg", source_revision: "apitcg-nova.json", status: "succeeded",
                      started_at: NEW_RUN_AT)

    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster", released_on: Date.new(2022, 12, 2))
    @st01 = CardSet.create!(code: "ST01", name: "Straw Hat Crew", kind: "starter", released_on: Date.new(2022, 7, 8))
    # Set só da fonte antiga, lançado depois de todos: se a presença não
    # valesse na ordem padrão, a carta dele abriria a grade.
    @antigo = CardSet.create!(code: "OLD01", name: "Só na fonte antiga", kind: "booster",
                              released_on: Date.new(2026, 1, 1))

    @zoro = card("OP01-001", "Roronoa Zoro", colors: [ "Red" ], card_type: "leader")
    variant(@zoro, "tcgplayer:1", @op01, rarity: "L", seen: NEW_RUN_AT)

    # Única variante ausente: não pode aparecer em lugar nenhum.
    @fantasma = card("OLD01-001", "Fantasma Purpura", colors: [ "Purple" ], card_type: "stage",
                     set: @antigo)
    @fantasma_variant = variant(@fantasma, "OLD01-001", @antigo, rarity: "SEC", seen: OLD_RUN_AT)

    # Presente em ST01, ausente em OP01.
    @nami = card("OP01-016", "Nami", colors: [ "Blue" ], card_type: "character")
    @nami_ausente = variant(@nami, "OP01-016_p1", @op01, rarity: "SR", seen: OLD_RUN_AT)
    @nami_presente = variant(@nami, "tcgplayer:2", @st01, rarity: "C", seen: NEW_RUN_AT)
  end

  def card(number, name, colors:, card_type:, set: @op01)
    Card.create!(set_id: set.id, card_number: number, name: name, colors: colors, card_type: card_type)
  end

  def variant(card, code, set, rarity:, seen:)
    CardVariant.create!(card: card, set_id: set.id, variant_code: code, rarity: rarity, art_kind: "base",
                        last_seen_at: seen)
  end

  def numbers(params = {}, user = nil)
    CatalogQuery.new(params, user).call.records.map(&:card_number).sort
  end

  # --- Done when 1: carta cuja única variante está ausente some de tudo ---

  test "carta com a única variante ausente não aparece na grade" do
    assert_equal %w[OP01-001 OP01-016], numbers
  end

  test "carta com a única variante ausente não aparece na busca" do
    assert_empty numbers(q: "Fantasma")
    assert_empty numbers(q: "OLD01-001")
  end

  test "carta com a única variante ausente não aparece em nenhum filtro" do
    assert_empty numbers(colors: [ "Purple" ])
    assert_empty numbers(card_types: [ "stage" ])
    assert_empty numbers(sets: [ "OLD01" ])
    assert_empty numbers(rarities: [ "SEC" ])
  end

  test "carta com a única variante ausente não aparece no filtro de posse, mesmo possuída" do
    user = User.create!(email: "dono@example.com", password: "senha-segura-123")
    CollectionItem.create!(user: user, card_variant: @fantasma_variant, quantity: 2)

    assert_empty numbers({ owned: "owned" }, user)
    refute_includes numbers({ owned: "missing" }, user), "OLD01-001"
  end

  # --- Done when 2: variante presente num set e ausente em outro ---

  test "carta presente em ST01 e ausente em OP01 casa só o filtro de ST01" do
    assert_includes numbers(sets: [ "ST01" ]), "OP01-016"
    refute_includes numbers(sets: [ "OP01" ]), "OP01-016"
  end

  test "a raridade da variante ausente não faz a carta casar o filtro" do
    refute_includes numbers(rarities: [ "SR" ]), "OP01-016"
    assert_includes numbers(rarities: [ "C" ]), "OP01-016"
  end

  test "a posse da variante ausente não faz a carta contar como possuída" do
    user = User.create!(email: "dona@example.com", password: "senha-segura-123")
    CollectionItem.create!(user: user, card_variant: @nami_ausente, quantity: 1)

    refute_includes numbers({ owned: "owned" }, user), "OP01-016"
    assert_includes numbers({ owned: "missing" }, user), "OP01-016"
  end

  # --- Done when 3: filter_options só com o que está presente ---

  test "filter_options não lista set sem variante presente" do
    codes = CatalogQuery.filter_options[:sets].map { |set| set[:code] }

    assert_equal %w[OP01 ST01], codes
  end

  test "filter_options não lista raridade, cor nem tipo que só existem no ausente" do
    options = CatalogQuery.filter_options

    assert_equal %w[C L], options[:rarities].sort
    assert_equal %w[Blue Red], options[:colors].sort
    assert_equal %w[character leader], options[:card_types]
  end

  # --- Done when 4 / SRC-15: ordem padrão pelo set presente mais recente ---

  test "sem parâmetros, a primeira carta é do set presente lançado por último" do
    op02 = CardSet.create!(code: "OP02", name: "Paramount War", kind: "booster", released_on: Date.new(2023, 3, 10))
    ace = card("OP02-013", "Ace", colors: [ "Red" ], card_type: "character", set: op02)
    variant(ace, "tcgplayer:3", op02, rarity: "SR", seen: NEW_RUN_AT)

    assert_equal "OP02-013", CatalogQuery.new.call.records.first.card_number
  end
end
