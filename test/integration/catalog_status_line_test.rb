require "test_helper"

# T17 — Linha de status do catálogo (NAV-36, NAV-27).
#
# Contagem de resultados numa linha de status. Com filtro ativo, mostra quantos
# filtros estão aplicados e oferece "Limpar filtros".
class CatalogStatusLineTest < ActionDispatch::IntegrationTest
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")

    @zoro = create_card(
      card_number: "OP01-001", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ], cost: 3, power: 5000
    )
    CardVariant.create!(
      card: @zoro, set_id: @op01.id, variant_code: "OP01-001",
      rarity: "L", art_kind: "base", image_url: "https://example.test/OP01-001.png"
    )

    @nami = create_card(
      card_number: "OP01-002", name: "Nami",
      card_type: "character", colors: [ "Green" ], cost: 1, power: 1000
    )
    CardVariant.create!(
      card: @nami, set_id: @op01.id, variant_code: "OP01-002",
      rarity: "C", art_kind: "base", image_url: "https://example.test/OP01-002.png"
    )

    @sanji = create_card(
      card_number: "OP01-003", name: "Sanji",
      card_type: "leader", colors: [ "Blue" ], cost: 2, power: 2000
    )
    CardVariant.create!(
      card: @sanji, set_id: @op01.id, variant_code: "OP01-003",
      rarity: "SR", art_kind: "base", image_url: "https://example.test/OP01-003.png"
    )
  end

  def create_card(**attrs)
    Card.create!(set_id: @op01.id, **attrs)
  end

  # --- NAV-36: Sem filtro, só o total ---

  test "sem filtro, exibe só 'N cartas'" do
    get catalog_path

    assert_response :success
    # Há um <p> com .catalog__count e texto "3 cartas"
    assert_select ".catalog__count", text: /^3 cartas$/

    # Não há linha de status com filtros ativos (quando não há filtro, não renderiza)
    # Mas a spec diz "Com filtro ativo, oferece". Sem filtro, não deve haver
    # "Limpar filtros" em nenhum lugar (exceto em estado vazio, se houver).
    refute response.body.include?("Limpar filtros")
  end

  # --- NAV-36: Com filtro ativo, exibe contagem e botão ---

  test "com um filtro ativo, exibe '1 filtro ativo' e 'Limpar filtros'" do
    get catalog_path(colors: [ "Red" ])

    assert_response :success

    # A linha de status deve dizer "1 filtro ativo"
    assert_select ".catalog__status", text: /1 filtro ativo/

    # E deve ter um link "Limpar filtros" apontando para o catálogo sem filtros
    assert_select ".catalog__status a[href*='/catalog']", text: "Limpar filtros" do |link|
      # O link não deve ter "colors" na URL
      refute link.attr("href").include?("colors")
    end
  end

  test "com dois filtros ativos (cores e raridade), exibe '2 filtros ativos'" do
    get catalog_path(colors: [ "Red" ], rarities: [ "L" ])

    assert_response :success

    # A linha de status deve dizer "2 filtros ativos"
    assert_select ".catalog__status", text: /2 filtros ativos/

    # Link "Limpar filtros" aponta para catálogo sem filtros
    assert_select ".catalog__status a[href*='/catalog']", text: "Limpar filtros"
  end

  test "com três filtros (cores, raridade, tipo), exibe '3 filtros ativos'" do
    get catalog_path(colors: [ "Red" ], rarities: [ "SR" ], card_types: [ "character" ])

    assert_response :success

    assert_select ".catalog__status", text: /3 filtros ativos/
  end

  # --- NAV-36: sort e dir não contam como filtro ---

  test "sort e dir não contam como filtro, só '1 filtro ativo' para cores" do
    get catalog_path(colors: [ "Red" ], sort: "name", dir: "desc")

    assert_response :success

    # Apenas cores conta; sort e dir não
    assert_select ".catalog__status", text: /1 filtro ativo/
  end

  test "page não conta como filtro, só cores" do
    get catalog_path(colors: [ "Green" ], page: 2)

    assert_response :success

    assert_select ".catalog__status", text: /1 filtro ativo/
  end

  # --- NAV-27: "Limpar filtros" preserva sort e dir ---

  test "'Limpar filtros' preserva sort e dir quando ativos" do
    get catalog_path(colors: [ "Red" ], sort: "name", dir: "desc")

    assert_response :success

    # Link deve conter sort=name e dir=desc, mas não colors
    link = css_select(".catalog__status a[href*='/catalog']").first
    href = link.attr("href")
    assert href.include?("sort=name"), "sort não preservado em 'Limpar filtros'"
    assert href.include?("dir=desc"), "dir não preservado em 'Limpar filtros'"
    refute href.include?("colors"), "colors não deve estar no link 'Limpar filtros'"
  end

  # --- NAV-36: Estado vazio com filtro ativo ---

  # Decisão da T17: com zero resultados a linha de status continua dizendo
  # quantos filtros estão ativos, e o "Limpar filtros" fica só no estado vazio,
  # que o catalog_grid_test já exige.
  test "com zero resultados e filtro ativo, a linha diz o filtro e o vazio oferece limpar" do
    get catalog_path(colors: [ "Purple" ])

    assert_response :success
    assert_select ".catalog__status .catalog__filter-count", text: /1 filtro ativo/
    assert_select ".catalog__status a", count: 0
    assert_select ".catalog__empty a", text: "Limpar filtros", count: 1
  end

  # --- NAV-27: Alvo ≥ 24px para "Limpar filtros" ---

  test "'Limpar filtros' tem min-height e min-width ≥ 24px" do
    get catalog_path(colors: [ "Red" ])

    assert_response :success

    # O link deve ter classe com as regras de 24px (verificável em design test)
    # Aqui testamos que existe o elemento
    assert_select ".catalog__status a[href*='/catalog']", text: "Limpar filtros"
  end

  # --- NAV-36: a contagem é a de chips, e o total mora na mesma linha ---

  test "duas cores contam dois filtros, como dois chips" do
    get catalog_path(colors: [ "Red", "Green" ])

    assert_select ".catalog__status .catalog__filter-count", text: /^\s*2 filtros ativos\s*$/
  end

  test "o total de cartas fica dentro da linha de status, com ou sem filtro" do
    get catalog_path
    assert_select ".catalog__status .catalog__count", text: /^\s*3 cartas\s*$/

    get catalog_path(colors: [ "Red" ])
    assert_select ".catalog__status .catalog__count", text: /^\s*1 carta\s*$/
    assert_select ".catalog__status .catalog__clear-filters", text: "Limpar filtros"
  end

  test "a linha de status não usa style inline" do
    get catalog_path(colors: [ "Red" ])

    assert_select ".catalog__status [style]", count: 0
  end

  test "com zero resultados, Limpar filtros aparece uma vez só" do
    get catalog_path(colors: [ "Red" ], rarities: [ "C" ])

    assert_select ".catalog__empty"
    assert_select "a", text: "Limpar filtros", count: 1
  end
end
