require "test_helper"

# T27 — Filtros recolhidos no celular (NAV-43, NAV-44, NAV-45).
#
# Em viewport estreita, os controles de filtro ficam num <details> fechado que
# diz quantos filtros estão ativos; em viewport larga, continuam sempre visíveis.
class CatalogFiltersToggleTest < ActionDispatch::IntegrationTest
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

  # --- NAV-43: Details sem open, summary com "Filtros" ---

  test "details envolve só catalog__filters, sem open" do
    get catalog_path

    assert_response :success
    # Existe um <details class="catalog__filters-toggle"> sem atributo open
    assert_select "details.catalog__filters-toggle" do |details|
      assert !details.first.attributes["open"].present?
    end
  end

  test "summary com texto 'Filtros'" do
    get catalog_path

    assert_response :success
    # O <summary> contém "Filtros"
    assert_select "details.catalog__filters-toggle > summary.catalog__filters-summary",
                  text: /^Filtros/
  end

  test "summary sem contagem quando sem filtros" do
    get catalog_path

    assert_response :success
    # O <summary> NÃO contém nenhuma contagem de filtros ativos
    assert_select "details.catalog__filters-toggle > summary.catalog__filters-summary" do |summary|
      text = summary.first.text
      assert !text.include?("filtro ativo")
    end
  end

  test "summary com contagem quando filtro ativo" do
    get catalog_path(colors: [ "Red" ])

    assert_response :success
    # O <summary> contém "1 filtro ativo"
    assert_select "details.catalog__filters-toggle > summary.catalog__filters-summary",
                  text: /Filtros.*1 filtro ativo/
  end

  test "summary com plural quando vários filtros ativos" do
    get catalog_path(colors: [ "Red" ], rarities: [ "L" ])

    assert_response :success
    # O <summary> contém "2 filtros ativos"
    assert_select "details.catalog__filters-toggle > summary.catalog__filters-summary",
                  text: /Filtros.*2 filtros ativos/
  end

  # --- NAV-44: Lista de filtros ativos fora do details ---

  test "ul.catalog__chips fica fora do details" do
    get catalog_path(colors: [ "Red" ])

    assert_response :success
    # Existe um <ul class="catalog__chips"> e NÃO é filho direto de <details>
    assert_select "main.catalog > div.catalog__head > ul.catalog__chips"
    # Não existe um <ul> dentro de <details>
    assert_select "details.catalog__filters-toggle ul.catalog__chips", count: 0
  end

  # --- Comportamento: abrir details e aplicar filtro sem JS ---

  test "abrir details e tocar num chip aplica filtro (NAV-14)" do
    get catalog_path
    # Com details fechado, clicar em um chip navega para a URL do filtro
    assert_select "details.catalog__filters-toggle > div.catalog__filters a.catalog__chip[href*='colors']"
  end

  test "com zero resultados, controles continuam na página (NAV-27)" do
    get catalog_path(colors: [ "Red" ], rarities: [ "L" ])

    assert_response :success
    # Mesmo com zero resultados, o <details> está presente
    assert_select "details.catalog__filters-toggle"
  end
end
