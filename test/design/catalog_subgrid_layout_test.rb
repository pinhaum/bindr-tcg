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
end
