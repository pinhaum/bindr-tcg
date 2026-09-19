require "test_helper"

# T10 — contrato do query object (`design.md` §4.2).
#
# Os testes daqui derivam do Req. 4, não da implementação: cada um nomeia o
# critério de aceitação que exercita. Em particular, `OU` dentro da categoria e
# `E` entre categorias (Req. 4.3 e 4.4) são asserções sobre *quais cartas
# voltam*, não sobre o SQL gerado — trocar `AND` por `OR` na implementação tem
# que derrubar o teste.
class CatalogQueryTest < ActiveSupport::TestCase
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @st01 = CardSet.create!(code: "ST01", name: "Straw Hat Crew", kind: "starter")

    @zoro = create_card(
      card_number: "OP01-001", name: "Roronoa Zoro", card_type: "leader",
      colors: [ "Red" ], cost: 3, power: 5000, counter: 1000,
      traits: [ "Straw Hat Crew" ], attributes_list: [ "Slash" ]
    )
    @nami = create_card(
      card_number: "OP01-002", name: "Nami", card_type: "character",
      colors: [ "Green" ], cost: 1, power: 1000, counter: 2000,
      traits: [ "Straw Hat Crew" ], attributes_list: [ "Special" ]
    )
    # Multicolorida: tem que aparecer tanto no filtro de Red quanto no de Blue
    # (Req. 4.5). É o caso que uma comparação de igualdade de array perderia.
    @law = create_card(
      card_number: "OP01-003", name: "Trafalgar Law", card_type: "leader",
      colors: [ "Red", "Blue" ], cost: 4, power: 5000, counter: nil,
      traits: [ "Heart Pirates" ], attributes_list: [ "Slash" ]
    )
    @event = create_card(
      card_number: "OP01-004", name: "Gum-Gum Pistol", card_type: "event",
      colors: [ "Red" ], cost: 1, power: nil, counter: nil,
      traits: [ "Straw Hat Crew" ], attributes_list: []
    )

    create_variant(@zoro, "OP01-001_p1", rarity: "L", card_set: @op01)
    create_variant(@nami, "OP01-002", rarity: "C", card_set: @op01)
    create_variant(@law, "OP01-003", rarity: "L", card_set: @op01)
    # Reimpressão em outro set: o filtro por set tem que achar esta carta por
    # ST01 mesmo o `set_id` da carta apontando para OP01 (1402 casos no
    # catálogo real).
    create_variant(@event, "ST01-004", rarity: "UC", card_set: @st01)
  end

  def create_card(**attrs)
    Card.create!(set_id: @op01.id, **attrs)
  end

  def create_variant(card, variant_code, rarity:, card_set:)
    CardVariant.create!(card: card, set_id: card_set.id, variant_code: variant_code,
                        rarity: rarity, art_kind: "base")
  end

  def numbers(result)
    result.records.map(&:card_number).sort
  end

  # --- Req. 4.1: cada filtro isolado ---

  test "filtra por cor" do
    resultado = CatalogQuery.new(colors: [ "Green" ]).call

    assert_equal [ "OP01-002" ], numbers(resultado)
  end

  test "filtra por tipo de carta" do
    resultado = CatalogQuery.new(card_types: [ "event" ]).call

    assert_equal [ "OP01-004" ], numbers(resultado)
  end

  test "filtra por set através das variantes, não pelo set de estreia da carta" do
    resultado = CatalogQuery.new(sets: [ "ST01" ]).call

    assert_equal [ "OP01-004" ], numbers(resultado)
  end

  test "filtra por raridade da variante" do
    resultado = CatalogQuery.new(rarities: [ "L" ]).call

    assert_equal [ "OP01-001", "OP01-003" ], numbers(resultado)
  end

  test "filtra por attribute" do
    resultado = CatalogQuery.new(attributes: [ "Special" ]).call

    assert_equal [ "OP01-002" ], numbers(resultado)
  end

  test "filtra por trait" do
    resultado = CatalogQuery.new(traits: [ "Heart Pirates" ]).call

    assert_equal [ "OP01-003" ], numbers(resultado)
  end

  # --- Req. 4.2: faixas ---

  test "filtra por faixa de custo" do
    resultado = CatalogQuery.new(cost_min: 3, cost_max: 4).call

    assert_equal [ "OP01-001", "OP01-003" ], numbers(resultado)
  end

  test "filtra por faixa de power" do
    resultado = CatalogQuery.new(power_min: 5000).call

    assert_equal [ "OP01-001", "OP01-003" ], numbers(resultado)
  end

  # `counter` NULL é "não tem counter", não counter 0. Uma faixa que começa em
  # 0 não pode arrastar as cartas sem counter junto.
  test "faixa de counter não inclui cartas sem counter" do
    resultado = CatalogQuery.new(counter_min: 0).call

    assert_equal [ "OP01-001", "OP01-002" ], numbers(resultado)
    refute_includes numbers(resultado), "OP01-003"
  end

  # --- Req. 4.4: OU dentro da categoria ---

  test "dois valores da mesma categoria combinam com OU" do
    resultado = CatalogQuery.new(colors: [ "Green", "Blue" ]).call

    assert_equal [ "OP01-002", "OP01-003" ], numbers(resultado)
  end

  # --- Req. 4.5: multicolorida ---

  test "filtro por cor inclui multicoloridas que contêm aquela cor" do
    vermelhas = numbers(CatalogQuery.new(colors: [ "Red" ]).call)
    azuis = numbers(CatalogQuery.new(colors: [ "Blue" ]).call)

    assert_includes vermelhas, "OP01-003", "a Red/Blue tem que entrar no filtro de Red"
    assert_includes azuis, "OP01-003", "a mesma carta tem que entrar no filtro de Blue"
  end

  # --- Req. 4.3: E entre categorias ---

  test "categorias diferentes combinam com E, não com OU" do
    resultado = CatalogQuery.new(colors: [ "Red" ], card_types: [ "leader" ]).call

    # Se fosse OU, `OP01-002` (Green character) ficaria de fora mas `OP01-004`
    # (Red event) entraria. A ausência dele é o que distingue E de OU.
    assert_equal [ "OP01-001", "OP01-003" ], numbers(resultado)
  end

  test "três categorias combinam com E" do
    resultado = CatalogQuery.new(
      colors: [ "Red" ], card_types: [ "leader" ], traits: [ "Straw Hat Crew" ]
    ).call

    assert_equal [ "OP01-001" ], numbers(resultado)
  end

  test "filtro de faixa combina com E com filtro de categoria" do
    resultado = CatalogQuery.new(colors: [ "Red" ], cost_min: 4).call

    assert_equal [ "OP01-003" ], numbers(resultado)
  end

  # --- Regra de robustez: parâmetro inválido é ignorado, nunca 500 ---

  test "parâmetro desconhecido é ignorado" do
    resultado = CatalogQuery.new(filtro_que_nao_existe: "x", colors: [ "Green" ]).call

    assert_equal [ "OP01-002" ], numbers(resultado)
  end

  test "valor não numérico em faixa é ignorado em vez de levantar erro" do
    resultado = CatalogQuery.new(cost_min: "abacaxi").call

    assert_equal 4, resultado.total_count
  end

  test "sort e dir desconhecidos caem no padrão em vez de levantar erro" do
    resultado = CatalogQuery.new(sort: "'; DROP TABLE cards; --", dir: "sideways").call

    assert_equal %w[OP01-001 OP01-002 OP01-003 OP01-004],
                 resultado.records.map(&:card_number)
  end

  test "valor inexistente numa categoria devolve vazio sem erro" do
    resultado = CatalogQuery.new(colors: [ "Chartreuse" ]).call

    assert_empty resultado.records
    assert_equal 0, resultado.total_count
  end

  test "page e per_page fora de faixa são saneados" do
    resultado = CatalogQuery.new(page: -3, per_page: 99_999).call

    assert_equal 1, resultado.page
    assert_operator resultado.per_page, :<=, CatalogQuery::MAX_PER_PAGE
    assert_equal 4, resultado.records.size
  end

  # --- Req. 4.8 e 4.6: total_count e filtros ativos normalizados ---

  test "total_count conta o conjunto filtrado inteiro, não a página" do
    resultado = CatalogQuery.new(colors: [ "Red" ], per_page: 1).call

    assert_equal 1, resultado.records.size
    assert_equal 3, resultado.total_count
  end

  test "filtros ativos vêm normalizados para renderizar os chips" do
    resultado = CatalogQuery.new(colors: [ "Red", "" ], cost_min: "2", sort: "name").call

    assert_equal [ "Red" ], resultado.active_filters[:colors]
    assert_equal 2, resultado.active_filters[:cost_min]
    refute resultado.active_filters.key?(:card_types),
           "categoria sem valor não pode virar chip"
  end

  test "filtros ativos não listam parâmetro inválido descartado" do
    resultado = CatalogQuery.new(cost_min: "abacaxi", colors: [ "Red" ]).call

    refute resultado.active_filters.key?(:cost_min)
    assert_equal [ "Red" ], resultado.active_filters[:colors]
  end

  # --- Req. 2.4: ordenação ---

  test "ordena por nome ascendente e descendente" do
    asc = CatalogQuery.new(sort: "name", dir: "asc").call.records.map(&:name)
    desc = CatalogQuery.new(sort: "name", dir: "desc").call.records.map(&:name)

    assert_equal asc, asc.sort
    assert_equal asc.reverse, desc
  end

  test "ordenação por coluna anulável mantém todas as cartas no resultado" do
    resultado = CatalogQuery.new(sort: "power").call

    assert_equal 4, resultado.records.size
  end
end
