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

  # T13 (conformidade) — linha do código do tile (Main:65-66, D:144), rótulo da
  # busca (Main:24, D:68) e topo do catálogo em 1280px (D:62-64).
  test "a linha do código é flex numa linha só, com gap de 8px (Main:65)" do
    line = Stylesheet.resolved("card-tile__number-line")

    assert_equal "flex", line["display"]
    assert_equal "nowrap", line["flex-wrap"]
    assert_equal "center", line["align-items"]
    assert_equal 8.0, Stylesheet.to_pixels(line["gap"])
  end

  test "o código não quebra no hífen e continua no estilo code de 13px (Main:65)" do
    assert_equal "nowrap", Stylesheet.resolved("card-tile__number")["white-space"]
    assert Stylesheet.code_styled?("card-tile__number")
    assert_equal 13.0, Stylesheet.to_pixels(Stylesheet.resolved("card-tile__number")["font-size"])
  end

  test "raridade e \"N impressões\" não quebram e o excesso vira reticências (Main:66)" do
    rarity = Stylesheet.resolved("card-tile__rarity")

    assert_equal "nowrap", rarity["white-space"]
    assert_equal "hidden", rarity["overflow"]
    assert_equal "ellipsis", rarity["text-overflow"]
    assert_equal "0", rarity["min-width"], "sem min-width: 0 o flex item não encolhe e o texto vaza"
    assert_equal 13.0, Stylesheet.to_pixels(rarity["font-size"])
    assert_equal 18.0, Stylesheet.to_pixels(rarity["line-height"])
    assert_equal "var(--ink-muted)", rarity["color"]
  end

  test "o rótulo da busca é legenda 13/18 em ink-muted e peso regular (Main:24)" do
    label = Stylesheet.resolved("catalog__search-label")

    assert_equal 13.0, Stylesheet.to_pixels(label["font-size"])
    assert_equal 18.0, Stylesheet.to_pixels(label["line-height"])
    assert_equal "var(--ink-muted)", label["color"]
    assert_equal "var(--caption-weight)", label["font-weight"]
    assert_equal "400", Stylesheet.read_root_tokens["--caption-weight"]
  end

  # Causa do vão: o cabeçalho cobre as linhas 1–3 e o grid divide a altura dele
  # entre as linhas `auto`, então as duas linhas de flash vazias mediam ~80px.
  test "em ≥1024px sem flash as duas linhas acima do cabeçalho do catálogo medem 0 (D:62-64)" do
    rule = @wide_rules.find { |selector, _| selector == "body:has(> main.catalog):not(:has(.flash))" }

    assert rule, "falta a regra que zera as linhas de flash quando não há flash"
    assert_equal "0 0 auto 1fr", Stylesheet.declarations(rule[1]).to_h["grid-template-rows"]
  end

  test "em ≥1024px o título fica no topo do conteúdo só com o recuo de 24px (D:62-64)" do
    head = Stylesheet.resolved("catalog__head", @wide_rules)
    title = Stylesheet.resolved("catalog__title")

    top, *_ = head["padding"].split
    assert_equal 24.0, Stylesheet.to_pixels(top)
    assert_nil head["margin"]
    assert_nil head["margin-top"]
    assert_equal "0", title["margin"].split.first, "margem acima do h1 somaria ao recuo"
    assert_nil title["margin-top"]
  end
end
