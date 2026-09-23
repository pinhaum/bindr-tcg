require "test_helper"

# T1 — opções de filtro presentes no catálogo (NAV-08).
#
# `filter_options` devolve os valores distintos de cor, tipo de carta e raridade
# presentes no banco, e os sets (código e nome), todos ordenados. Os nomes das
# chaves são os parâmetros de URL do query object, e nenhum valor é repetido.
class CatalogFilterOptionsTest < ActiveSupport::TestCase
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @st01 = CardSet.create!(code: "ST01", name: "Straw Hat Crew", kind: "starter")

    @zoro = create_card(
      card_number: "OP01-001", name: "Roronoa Zoro", card_type: "leader",
      colors: [ "Red" ], cost: 3, power: 5000,
      traits: [ "Straw Hat Crew" ]
    )
    # Multicolorida: contribui com Red, Green e Blue
    @law = create_card(
      card_number: "OP01-003", name: "Trafalgar Law", card_type: "leader",
      colors: [ "Red", "Green", "Blue" ], cost: 4, power: 5000,
      traits: [ "Heart Pirates" ]
    )
    # Character diferente de Leader
    @nami = create_card(
      card_number: "OP01-002", name: "Nami", card_type: "character",
      colors: [ "Green" ], cost: 1, power: 1000,
      traits: [ "Straw Hat Crew" ]
    )
    # Event
    @event = create_card(
      card_number: "OP01-004", name: "Gum-Gum Pistol", card_type: "event",
      colors: [ "Red" ], cost: 1, power: nil,
      traits: []
    )

    # Variantes em OP01 com diferentes raridades
    create_variant(@zoro, "OP01-001_p1", rarity: "L", card_set: @op01)
    create_variant(@law, "OP01-003", rarity: "SR", card_set: @op01)
    create_variant(@nami, "OP01-002", rarity: "C", card_set: @op01)
    create_variant(@event, "OP01-004", rarity: "UC", card_set: @op01)

    # Reimpressão da mesma carta em ST01
    create_variant(@event, "ST01-004", rarity: "R", card_set: @st01)
  end

  def create_card(**attrs)
    Card.create!(set_id: @op01.id, **attrs)
  end

  def create_variant(card, variant_code, rarity:, card_set:)
    CardVariant.create!(card: card, set_id: card_set.id, variant_code: variant_code,
                        rarity: rarity, art_kind: "base")
  end

  # Done when: os nomes das chaves são `colors`, `card_types`, `rarities`, `sets`,
  # lidos das constantes do query object
  test "retorna um hash com as chaves corretas" do
    result = CatalogQuery.filter_options

    assert result.is_a?(Hash)
    assert_equal %w[card_types colors rarities sets], result.keys.map(&:to_s).sort
  end

  # Done when: carta multicolor contribui com cada uma das cores. Valor repetido
  # aparece uma vez só.
  test "cores: multicolorida aparece em cada uma das suas cores, sem repetição" do
    result = CatalogQuery.filter_options

    # Zoro é Red (leader), Law é Red/Green/Blue, Nami é Green, Event é Red
    # Cores únicas: Red (3 cartas), Green (2), Blue (1)
    assert_equal [ "Blue", "Green", "Red" ], result[:colors].sort
  end

  # Done when: nenhuma cor repetida
  test "cores sem valor duplicado no resultado" do
    result = CatalogQuery.filter_options

    assert_equal result[:colors].uniq, result[:colors],
                 "as cores devem ser únicas"
  end

  # Done when: raridade vem das variantes, não das cartas
  test "raridades: vêm das variantes, incluindo reimprimir em sets diferentes" do
    result = CatalogQuery.filter_options

    # OP01-001_p1: L
    # OP01-003: SR
    # OP01-002: C
    # OP01-004: UC (em OP01) e R (em ST01)
    # Raridades únicas: C, L, R, SR, UC
    assert_equal [ "C", "L", "R", "SR", "UC" ], result[:rarities].sort
  end

  # Done when: nenhuma raridade repetida
  test "raridades sem valor duplicado no resultado" do
    result = CatalogQuery.filter_options

    assert_equal result[:rarities].uniq, result[:rarities],
                 "as raridades devem ser únicas"
  end

  # Done when: tipos de carta (card_types)
  test "tipos de carta: retorna character, event, leader" do
    result = CatalogQuery.filter_options

    # Zoro: leader, Nami: character, Law: leader, Event: event
    # Tipos únicos: character, event, leader
    assert_equal [ "character", "event", "leader" ], result[:card_types].sort
  end

  # Done when: nenhum tipo repetido
  test "tipos de carta sem valor duplicado no resultado" do
    result = CatalogQuery.filter_options

    assert_equal result[:card_types].uniq, result[:card_types],
                 "os tipos devem ser únicos"
  end

  # Done when: sets com código e nome
  test "sets: retorna código e nome de cada set" do
    result = CatalogQuery.filter_options

    expected_sets = [ { code: "OP01", name: "Romance Dawn" },
                      { code: "ST01", name: "Straw Hat Crew" } ]

    assert_equal expected_sets, result[:sets]
  end

  # Done when: catálogo vazio devolve listas vazias
  test "catálogo vazio devolve listas vazias" do
    CardVariant.destroy_all
    Card.destroy_all

    result = CatalogQuery.filter_options

    assert_equal [], result[:colors]
    assert_equal [], result[:card_types]
    assert_equal [], result[:rarities]
    assert_equal [], result[:sets]
  end


  # Done when: nenhum valor repetido em nenhuma categoria
  test "sem duplicatas em nenhuma categoria" do
    result = CatalogQuery.filter_options

    result.each do |key, values|
      next if key == :sets # sets é um array de hashes, não de strings

      assert_equal values.uniq, values,
                   "#{key} tem duplicatas: #{values.inspect}"
    end
  end

  # Done when: sets ordernados por código
  test "sets ordenados por código" do
    # Criar mais sets
    CardSet.create!(code: "OP02", name: "Unkown Worlds", kind: "booster")
    CardSet.create!(code: "OP00", name: "Pre-Release", kind: "booster")

    result = CatalogQuery.filter_options

    codes = result[:sets].map { |s| s[:code] }
    # OP01, ST01 já existem; OP02, OP00 agora também
    # Ordenados: OP00, OP01, OP02, ST01
    assert_equal codes.sort, codes
  end
end
