require "test_helper"
require_relative "support/stylesheet"

class CatalogGridCanvasTest < ActiveSupport::TestCase
  def rules_in_media_query
    @rules_in_media_query ||= begin
      content = Stylesheet.read_stylesheet
      media_part = content[/@media\s*\(min-width:\s*64rem\)\s*\{(.+?)\}\s*(?=@|\Z)/m, 1]
      return [] unless media_part
      Stylesheet.rules(media_part)
    end
  end

  def rules_outside_media_query
    @rules_outside_media_query ||= Stylesheet.rules(Stylesheet.content_outside_root)
  end

  test "catalog__grid outside media query has 2 columns" do
    grid_rule = rules_outside_media_query.find { |selector, _| selector.strip == ".catalog__grid" }
    assert_not_nil grid_rule, "Rule for .catalog__grid not found outside media query"
    _, body = grid_rule
    declarations = Stylesheet.declarations(body)
    grid_cols = declarations.find { |prop, _| prop == "grid-template-columns" }&.[](1)
    assert_equal "repeat(auto-fill, minmax(var(--tile-min), 1fr))", grid_cols,
                 ".catalog__grid outside media query should use auto-fill for responsive columns"
  end

  test "catalog__grid outside media query has gap 8px" do
    grid_rule = rules_outside_media_query.find { |selector, _| selector.strip == ".catalog__grid" }
    assert_not_nil grid_rule
    _, body = grid_rule
    declarations = Stylesheet.declarations(body)
    gap = declarations.find { |prop, _| prop == "gap" }&.[](1)
    assert_equal "var(--space-2)", gap, ".catalog__grid outside media query should have gap: var(--space-2) (8px)"
  end

  def declarations_in_media(selector)
    rule = rules_in_media_query.find { |candidate, _| candidate.strip == selector }
    assert_not_nil rule, "regra #{selector} não encontrada em @media (min-width: 64rem)"
    Stylesheet.declarations(rule[1]).to_h
  end

  test "catalog__grid inside media query has 5 columns" do
    grid = declarations_in_media(".catalog__grid")
    grid_cols = grid["grid-template-columns"]
    assert_equal "repeat(5, minmax(0, 1fr))", grid_cols,
                 ".catalog__grid should have 5 equal columns in 1280px (CNF-12)"
  end

  test "catalog__grid inside media query has gap 16px" do
    grid = declarations_in_media(".catalog__grid")
    gap = grid["gap"]
    assert_equal "var(--space-3)", gap, ".catalog__grid should have gap: var(--space-3) (16px) in 1280px (CNF-12)"
  end

  test "card-tile has padding 16px" do
    tile_rule = rules_outside_media_query.find { |selector, _| selector.strip == ".card-tile" }
    assert_not_nil tile_rule, "Rule for .card-tile not found"
    _, body = tile_rule
    declarations = Stylesheet.declarations(body)
    padding = declarations.find { |prop, _| prop == "padding" }&.[](1)
    resolved_padding = Stylesheet.to_pixels(padding)
    assert_equal 16.0, resolved_padding, ".card-tile should have padding: 16px (CNF-13)"
  end

  test "card-tile__art has padding 8px" do
    art_rule = rules_outside_media_query.find { |selector, _| selector.strip == ".card-tile__art" }
    assert_not_nil art_rule, "Rule for .card-tile__art not found"
    _, body = art_rule
    declarations = Stylesheet.declarations(body)
    padding = declarations.find { |prop, _| prop == "padding" }&.[](1)
    resolved_padding = Stylesheet.to_pixels(padding)
    assert_equal 8.0, resolved_padding, ".card-tile__art should have padding: 8px (CNF-13)"
  end

  test "card-tile__art has sunken background" do
    art_rule = rules_outside_media_query.find { |selector, _| selector.strip == ".card-tile__art" }
    assert_not_nil art_rule
    _, body = art_rule
    declarations = Stylesheet.declarations(body)
    background = declarations.find { |prop, _| prop == "background" }&.[](1)
    assert_equal "var(--surface-sunken)", background, ".card-tile__art should have background: var(--surface-sunken) (CNF-13)"
  end
end
