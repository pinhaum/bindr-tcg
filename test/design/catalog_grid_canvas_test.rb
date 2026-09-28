require "test_helper"
require_relative "support/stylesheet"

# T5 (conformidade) — CNF-12 e CNF-13: grade de cinco colunas em ≥1024px, tile
# e arte com o recuo do canvas (`Desktop-Catalogo.dc.html:77-80`,
# `Main.dc.html:55-58`) e o divisor entre navegação e filtros (D:27).
#
# A folha tem um único bloco `@media (min-width: 64rem)`. Ele é recortado pelo
# balanceamento das chaves: um regex não guloso até "}" para no fim da primeira
# regra interna, e um guloso até "}" seguido de "@" ou do fim do arquivo engole
# as regras que vêm depois do bloco — e aí uma regra fora da media query
# passaria por regra de dentro.
class CatalogGridCanvasTest < ActiveSupport::TestCase
  WIDE = /@media\s*\(min-width:\s*64rem\)\s*\{/

  def self.wide_block(css = Stylesheet.content_without_comments)
    start = css.index(WIDE) or return ""
    open = css.index("{", start)
    depth = 0
    css.each_char.with_index.drop(open).each do |char, index|
      depth += 1 if char == "{"
      depth -= 1 if char == "}"
      return css[(open + 1)...index] if depth.zero?
    end
    ""
  end

  setup do
    css = Stylesheet.content_without_comments
    @wide = self.class.wide_block(css)
    @narrow_rules = Stylesheet.rules(css.sub(@wide, ""))
    @wide_rules = Stylesheet.rules(@wide)
  end

  test "o recorte do bloco largo não inclui regra de fora dele" do
    assert_not_empty @wide
    assert_nil Stylesheet.resolved("pagination", @wide_rules)["display"],
               ".pagination só é declarada fora da media query"
  end

  test "fora do bloco largo a grade mantém o reflow com gap de 8px (D7, Req. 2.5)" do
    grid = Stylesheet.resolved("catalog__grid", @narrow_rules)

    assert_match(/\Arepeat\(auto-fill,/, grid["grid-template-columns"])
    assert_equal 8.0, Stylesheet.to_pixels(grid["gap"])
  end

  test "em ≥1024px a grade tem cinco colunas iguais e gap de 16px (CNF-12)" do
    grid = Stylesheet.resolved("catalog__grid", @wide_rules)

    assert_equal "repeat(5, minmax(0, 1fr))", grid["grid-template-columns"]
    assert_equal 16.0, Stylesheet.to_pixels(grid["gap"])
  end

  test "o tile tem recuo de 16px, fundo surface e borda (CNF-13)" do
    tile = Stylesheet.resolved("card-tile")

    assert_equal 16.0, Stylesheet.to_pixels(tile["padding"])
    assert_equal "var(--surface-raised)", tile["background-color"]
    assert_equal "1px solid var(--border)", tile["border"]
  end

  test "a arte é emoldurada em sunken com recuo de 8px (CNF-13)" do
    art = Stylesheet.resolved("card-tile__art")

    assert_equal 8.0, Stylesheet.to_pixels(art["padding"])
    assert_equal "var(--surface-sunken)", art["background"]
  end

  test "em ≥1024px há divisor de 1px entre navegação e filtros (CNF-13)" do
    divider = Stylesheet.resolved("catalog__filters::before", @wide_rules)

    assert_equal '""', divider["content"]
    assert_equal "1px solid var(--border)", divider["border-top"]
  end
end
