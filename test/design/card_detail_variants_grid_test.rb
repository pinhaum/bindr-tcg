require "test_helper"
require_relative "support/stylesheet"

# T30 — variantes do detalhe em linhas (NAV-49, NAV-28).
#
# Cada `li.variant` tem quatro filhos: miniatura, meta, posse e o formulário da
# wishlist. São três colunas em toda largura; o que muda com a largura é onde
# os controles (os filhos a partir do terceiro) caem.
class CardDetailVariantsGridTest < ActiveSupport::TestCase
  def base(selector)
    rule = Stylesheet.rules(outside_media).find { |candidate, _| candidate.strip == selector }
    assert_not_nil rule, "regra #{selector} não encontrada fora de media query"
    Stylesheet.declarations(rule[1]).to_h
  end

  def wide(selector)
    rule = Stylesheet.rules(wide_media).find { |candidate, _| candidate.strip == selector }
    assert_not_nil rule, "regra #{selector} não encontrada em @media (min-width: 64rem)"
    Stylesheet.declarations(rule[1]).to_h
  end

  def outside_media
    Stylesheet.read_stylesheet[/\A(.*?)@media/m, 1]
  end

  def wide_media
    Stylesheet.read_stylesheet[/@media\s*\(min-width:\s*64rem\)\s*\{(.+?)\}\s*(?=@|\Z)/m, 1]
  end

  test "a lista empilha uma variante por linha" do
    list = base(".variant-list")
    assert_equal "flex", list["display"]
    assert_equal "column", list["flex-direction"]
  end

  # minmax(0, 1fr): com 1fr, o nome longo do set alarga a coluna do meio e
  # empurra os controles para fora da tela em 360px.
  test "cada variante é um grid de miniatura, meta e controles" do
    variant = base(".variant")
    assert_equal "grid", variant["display"]
    assert_equal "auto minmax(0, 1fr) auto", variant["grid-template-columns"]
  end

  test "a miniatura tem medida fixa e ocupa a altura da linha" do
    art = base(".variant__art")
    assert_equal "80px", art["width"]
    assert_equal "112px", art["height"]
    assert_equal "span 3", art["grid-row"]
  end

  test "na tela estreita os controles descem para baixo da meta" do
    assert_equal "2 / -1", base(".variant > :nth-child(n + 3)")["grid-column"]
  end

  test "na tela larga os controles ficam na terceira coluna, ao lado da meta" do
    assert_equal "3", wide(".variant > :nth-child(n + 3)")["grid-column"]
  end

  test "os rótulos da meta saem da vista pelo recorte, sem display none" do
    dt = base(".variant__meta dt")
    assert_equal "absolute", dt["position"]
    assert_equal "1px", dt["width"]
    assert_equal "1px", dt["height"]
    assert_equal "hidden", dt["overflow"]
    assert_equal "inset(50%)", dt["clip-path"]
    assert_equal "nowrap", dt["white-space"]
    assert_nil dt["display"], "display none tiraria o rótulo do leitor de tela"
  end
end
