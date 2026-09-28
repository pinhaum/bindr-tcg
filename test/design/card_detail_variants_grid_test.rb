require "test_helper"
require_relative "support/stylesheet"

# T8 (conformidade) — variantes do detalhe como cartão de superfície
# (CNF-19/20/21; Mobile-Carta.dc.html:53, Desktop-Carta.dc.html:69).
#
# Cada `li.variant` tem quatro filhos: miniatura, meta, posse (`.ownership`,
# com o stepper) e o formulário da wishlist. Em toda largura eles ficam num
# cartão só (surface, borda, raio, padding); o que muda com a largura é se
# posse e wishlist quebram para a própria linha (estreito) ou cabem ao lado da
# meta, na mesma linha (largo).
class CardDetailVariantsGridTest < ActiveSupport::TestCase
  # `.squish` em vez de comparação exata: o seletor composto (`.variant >
  # .ownership,\n.variant > .wishlist-mark`) quebra linha na folha por
  # legibilidade, e a busca não pode depender de onde exatamente a formatação
  # colocou a quebra.
  def base(selector)
    rule = Stylesheet.rules(outside_media).find { |candidate, _| candidate.squish == selector.squish }
    assert_not_nil rule, "regra #{selector} não encontrada fora de media query"
    Stylesheet.declarations(rule[1]).to_h
  end

  def wide(selector)
    rule = Stylesheet.rules(wide_media).find { |candidate, _| candidate.squish == selector.squish }
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

  # Mobile-Carta.dc.html:53 — surface, borda 1px `--border`, raio `--radius-md`
  # (8px), padding `--space-3` (16px), gap `--space-2` (8px).
  test "a variante é um cartão de superfície com borda, raio e padding do canvas" do
    variant = base(".variant")
    assert_equal "flex", variant["display"]
    assert_equal "var(--space-2)", variant["gap"]
    assert_equal "var(--space-3)", variant["padding"]
    assert_equal "var(--surface-raised)", variant["background"]
    assert_equal "1px solid var(--border)", variant["border"]
    assert_equal "var(--radius-md)", variant["border-radius"]
  end

  test "a miniatura tem medida fixa e não encolhe" do
    art = base(".variant__art")
    assert_equal "80px", art["width"]
    assert_equal "112px", art["height"]
    assert_equal "0", art["flex-shrink"]
  end

  MULTI_SELECTOR = ".variant > .ownership, .variant > .wishlist-mark".freeze

  test "na tela estreita a posse e a wishlist ganham a própria linha" do
    assert_equal "100%", base(MULTI_SELECTOR)["flex-basis"]
  end

  # D:69 — em 1024px ou mais a variante inteira cabe numa linha (`align-items:
  # center`), então posse e wishlist deixam de forçar a própria linha.
  test "na tela larga a posse e a wishlist cabem ao lado da meta, na mesma linha" do
    assert_equal "center", base(".variant")["align-items"]
    assert_equal "auto", wide(MULTI_SELECTOR)["flex-basis"]
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

  test "há divisor de 1px entre o efeito e as variantes (CNF-19)" do
    divider = Stylesheet.resolved("card-detail__variants::before")

    assert_equal '""', divider["content"]
    assert_equal "1px solid var(--border)", divider["border-top"]
  end
end
