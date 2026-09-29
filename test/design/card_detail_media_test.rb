require "test_helper"
require_relative "support/stylesheet"

# T6 (conformidade) — CNF-14, CNF-15: miniatura ao lado do título abaixo de
# 1024px, imagem maior dentro de um `<details>`; em 1024px ou mais o
# `<details>` vira coluna própria de 320px sempre visível (mesma técnica do
# `.catalog__filters-toggle`, NAV-45).
class CardDetailMediaTest < ActiveSupport::TestCase
  setup do
    css = Stylesheet.content_without_comments
    @wide = CatalogGridCanvasTest.wide_block(css)
    @narrow_rules = Stylesheet.rules(css.sub(@wide, ""))
    @wide_rules = Stylesheet.rules(@wide)
  end

  test "fora de media query, a miniatura tem a medida do artboard (Mobile-Carta.dc.html:24)" do
    thumb = Stylesheet.resolved("card-detail__thumb", @narrow_rules)

    assert_equal 155.0, Stylesheet.to_pixels(thumb["width"])
    assert_equal 217.0, Stylesheet.to_pixels(thumb["height"])
    assert_equal "var(--surface-sunken)", thumb["background"]
  end

  test "fora de media query, .card-detail__media tem aspect-ratio 5/7" do
    media = Stylesheet.resolved("card-detail__media", @narrow_rules)

    assert_equal "5 / 7", media["aspect-ratio"]
  end

  test "fora de media query, .card-detail__media tem background var(--surface-sunken)" do
    media = Stylesheet.resolved("card-detail__media", @narrow_rules)

    assert_equal "var(--surface-sunken)", media["background"]
  end

  test "fora de media query, .card-detail__image e .card-detail__placeholder são absolutos" do
    outside = Stylesheet.content_without_comments.sub(@wide, "")

    combined_match = outside.match(/\.card-detail__image,\s*\.card-detail__placeholder\s*\{([^}]*)\}/)
    assert combined_match, ".card-detail__image, .card-detail__placeholder combinados não encontrados"

    body = combined_match[1]
    assert body.include?("position: absolute"),
           "regra combinada deve ter 'position: absolute'"
    assert body.include?("inset: 0"),
           "regra combinada deve ter 'inset: 0'"
  end

  test "dentro de @media (min-width: 64rem), a miniatura some (CNF-15)" do
    thumb = Stylesheet.resolved("card-detail__thumb", @wide_rules)

    assert_equal "none", thumb["display"]
  end

  test "dentro de @media (min-width: 64rem), o <details> vira coluna sempre visível (CNF-15)" do
    expand = Stylesheet.resolved("card-detail__expand", @wide_rules)

    assert_equal "contents", expand["display"]

    forced = @wide_rules.find { |selector, _| selector == ".card-detail__expand::details-content" }&.last
    assert forced, ".card-detail__expand::details-content não encontrada em @media (min-width: 64rem)"
    assert_match(/content-visibility:\s*visible/, forced)
  end

  test "dentro de @media (min-width: 64rem), .card-detail__media tem 320×448 e fica na coluna 1" do
    media = Stylesheet.resolved("card-detail__media", @wide_rules)

    assert_equal "1", media["grid-column"]
    assert_equal 320.0, Stylesheet.to_pixels(media["width"])
    # A altura vem de `aspect-ratio: 5 / 7` (declarado fora da media query) e
    # não de uma segunda declaração de `height`: 320 × 7/5 = 448, a medida do
    # artboard (Desktop-Carta.dc.html:33).
    assert_nil media["height"]
    assert_equal "5 / 7", Stylesheet.resolved("card-detail__media", @narrow_rules)["aspect-ratio"]
  end

  test "dentro de @media (min-width: 64rem), .card-detail__head fica na coluna 2" do
    head = Stylesheet.resolved("card-detail__head", @wide_rules)

    assert_equal "2", head["grid-column"]
  end

  test "dentro de @media (min-width: 64rem), .card-detail tem grid com 320px na primeira coluna" do
    card_detail = Stylesheet.resolved("card-detail", @wide_rules)

    assert_equal "grid", card_detail["display"]
    assert_match(/\A320px/, card_detail["grid-template-columns"])
  end

  test "dentro de @media (min-width: 64rem), .card-detail__data está na coluna 2" do
    data = Stylesheet.resolved("card-detail__data", @wide_rules)

    assert_equal "2", data["grid-column"]
  end

  # Desktop-Carta.dc.html:32-37 — a imagem de 320×448 abre a coluna, na altura do
  # título; sem `align-self: start` ela era centralizada na linha alta dos dados.
  test "dentro de @media (min-width: 64rem), a imagem alinha ao topo, na altura do título (D:32-37)" do
    media = Stylesheet.resolved("card-detail__media", @wide_rules)

    assert_equal "start", media["align-self"]
    assert_equal "1 / span 2", media["grid-row"]
    assert_equal 0.0, Stylesheet.to_pixels(media["margin-top"])
  end
end
