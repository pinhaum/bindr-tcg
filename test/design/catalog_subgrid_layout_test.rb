require "test_helper"
require_relative "support/stylesheet"

class CatalogSubgridLayoutTest < ActiveSupport::TestCase
  def rules_in_media_query
    @rules_in_media_query ||= begin
      content = Stylesheet.read_stylesheet
      media_part = content[/@media\s*\(min-width:\s*64rem\)\s*\{(.+?)\}\s*(?=@|\Z)/m, 1]
      return [] unless media_part
      Stylesheet.rules(media_part)
    end
  end

  test "catalog in media query has grid-column 1/-1" do
    catalog_rule = rules_in_media_query.find { |selector, _| selector.strip == ".catalog" }
    assert_not_nil catalog_rule, "Rule for .catalog not found in media query"
    _, body = catalog_rule
    declarations = Stylesheet.declarations(body)
    grid_col = declarations.find { |prop, _| prop == "grid-column" }&.[](1)
    assert_equal "1 / -1", grid_col, ".catalog should have grid-column: 1 / -1"
  end

  test "catalog has display grid" do
    catalog_rule = rules_in_media_query.find { |selector, _| selector.strip == ".catalog" }
    assert_not_nil catalog_rule
    _, body = catalog_rule
    declarations = Stylesheet.declarations(body)
    display = declarations.find { |prop, _| prop == "display" }&.[](1)
    assert_equal "grid", display
  end

  test "catalog has subgrid columns" do
    catalog_rule = rules_in_media_query.find { |selector, _| selector.strip == ".catalog" }
    assert_not_nil catalog_rule
    _, body = catalog_rule
    declarations = Stylesheet.declarations(body)
    grid_cols = declarations.find { |prop, _| prop == "grid-template-columns" }&.[](1)
    assert_equal "subgrid", grid_cols
  end

  test "catalog head positioned at column 2, row 1" do
    head_rule = rules_in_media_query.find { |selector, _| selector.strip == ".catalog__head" }
    assert_not_nil head_rule, "Rule for .catalog__head not found"
    _, body = head_rule
    declarations = Stylesheet.declarations(body)
    assert_equal "2", declarations.find { |p, _| p == "grid-column" }&.[](1)
    assert_equal "1", declarations.find { |p, _| p == "grid-row" }&.[](1)
  end

  test "catalog filters positioned at column 1, row 2" do
    filters_rule = rules_in_media_query.find { |selector, _| selector.strip == ".catalog__filters" }
    assert_not_nil filters_rule, "Rule for .catalog__filters not found"
    _, body = filters_rule
    declarations = Stylesheet.declarations(body)
    assert_equal "1", declarations.find { |p, _| p == "grid-column" }&.[](1)
    assert_equal "2", declarations.find { |p, _| p == "grid-row" }&.[](1)
  end

  test "catalog body positioned at column 2, row 2" do
    body_rule = rules_in_media_query.find { |selector, _| selector.strip == ".catalog__body" }
    assert_not_nil body_rule, "Rule for .catalog__body not found"
    _, body_content = body_rule
    declarations = Stylesheet.declarations(body_content)
    assert_equal "2", declarations.find { |p, _| p == "grid-column" }&.[](1)
    assert_equal "2", declarations.find { |p, _| p == "grid-row" }&.[](1)
  end

  test "catalog has row-gap" do
    catalog_rule = rules_in_media_query.find { |selector, _| selector.strip == ".catalog" }
    assert_not_nil catalog_rule
    _, body = catalog_rule
    declarations = Stylesheet.declarations(body)
    row_gap = declarations.find { |p, _| p == "row-gap" }
    assert_not_nil row_gap, "row-gap not found in .catalog"
  end

  def declarations_in_media(selector)
    rule = rules_in_media_query.find { |candidate, _| candidate.strip == selector }
    assert_not_nil rule, "regra #{selector} não encontrada em @media (min-width: 64rem)"
    Stylesheet.declarations(rule[1]).to_h
  end

  # Sem linhas explícitas, `main` (colunas 1 / -1) não pode sobrepor o cabeçalho
  # das linhas 1–3 e cai para baixo dele, depois de uma tela inteira.
  test "no catálogo largo o main cobre a linha do cabeçalho e a dos filtros, com subgrid nas linhas" do
    catalog = declarations_in_media(".catalog")
    assert_equal "3 / span 2", catalog["grid-row"]
    assert_equal "subgrid", catalog["grid-template-rows"]

    body = declarations_in_media("body:has(> main.catalog)")
    assert_equal 4, body["grid-template-rows"].split.size,
                 "o body do catálogo precisa das linhas flash, flash, cabeçalho e filtros"
  end

  test "no catálogo largo o cabeçalho não mede a tela inteira e fica acima do main" do
    header = declarations_in_media("body:has(> main.catalog) > .site-header")
    assert_equal "1 / span 3", header["grid-row"]
    assert_equal "auto", header["height"]
    assert_equal "1", header["z-index"]
  end

  # Desktop-Catalogo.dc.html: os filtros ficam no aside de 280px, em
  # surface-raised com borda direita, até o fim da página.
  test "os filtros continuam a coluna lateral" do
    filters = declarations_in_media(".catalog__filters")
    assert_equal "var(--surface-raised)", filters["background-color"]
    assert_equal "1px solid var(--border)", filters["border-right"]
    assert_equal "stretch", filters["align-self"]
  end

  # NAV-42: filtros empilhados com espaço fixo entre grupos
  test "os filtros da coluna lateral usam gap var(--space-4)" do
    filters = declarations_in_media(".catalog__filters")
    assert_equal "var(--space-4)", filters["gap"],
                 ".catalog__filters deve ter gap: var(--space-4) para espaçamento fixo entre grupos"
  end

  # NAV-42: linha do subgrid não estica o espaço
  test "os filtros da coluna lateral usam align-content start" do
    filters = declarations_in_media(".catalog__filters")
    assert_equal "start", filters["align-content"],
                 ".catalog__filters deve ter align-content: start para não esticar entre grupos"
  end

  # NAV-42: sem margin entre grupos em ≥ 64rem
  test "catalog__filter-group tem margin-bottom zero em ≥ 64rem" do
    filter_group = declarations_in_media(".catalog__filter-group")
    assert_equal "0", filter_group["margin-bottom"],
                 ".catalog__filter-group deve ter margin-bottom: 0 em ≥ 64rem (gap controla espaço)"
  end

  # NAV-42: navegação e filtros formam uma superfície só na coluna 1. Sem isto,
  # o padding do main (que cobre as duas colunas) recua os filtros e a margem
  # e a borda da regra base desenham uma faixa de surface-base entre eles.
  test "na coluna lateral os filtros encostam no cabeçalho, sem faixa de outro fundo" do
    assert_equal "0", declarations_in_media(".catalog")["padding"],
                 "o padding do main.catalog recua a coluna 1 e mostra surface-base em volta dos filtros"
    filters = declarations_in_media(".catalog__filters")
    assert_equal "0", filters["margin"], "a margem da regra base abre uma faixa entre cabeçalho e filtros"
    assert_equal "none", filters["border"], "a moldura da regra base separa os filtros do cabeçalho"
    assert_equal "0", filters["border-radius"]
    assert_equal "var(--surface-raised)", filters["background-color"]
  end
end
