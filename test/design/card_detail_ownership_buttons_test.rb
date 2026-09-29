require "test_helper"
require_relative "support/stylesheet"

# T31: Controles de posse de 44px no detalhe (NAV-50)
#
# No detalhe da carta, os botões +1 e −1 passam a ter alvo de 44×44px;
# na grade, continuam com 24px.
class CardDetailOwnershipButtonsTest < ActiveSupport::TestCase
  setup do
    @rules = Stylesheet.rules
  end

  test "a regra base .ownership__button continua com min-height e min-width de 24px" do
    base_rule = @rules.find { |selector, _| selector == ".ownership__button" }&.last
    assert base_rule, "regra base .ownership__button sumiu"

    decls = Stylesheet.declarations(base_rule).to_h
    assert_equal "24px", decls["min-height"], ".ownership__button deve ter min-height: 24px na regra base"
    assert_equal "24px", decls["min-width"], ".ownership__button deve ter min-width: 24px na regra base"
  end

  test "regra escopada .card-detail .ownership__button tem min-height e min-width de 44px" do
    scoped_rule = @rules.find { |selector, _| selector == ".card-detail .ownership__button" }&.last
    assert scoped_rule, "regra escopada .card-detail .ownership__button sumiu da folha"

    decls = Stylesheet.declarations(scoped_rule).to_h
    assert_equal "44px", decls["min-height"], ".card-detail .ownership__button deve ter min-height: 44px"
    assert_equal "44px", decls["min-width"], ".card-detail .ownership__button deve ter min-width: 44px"
  end

  test "a regra escopada não redeclara outras propriedades" do
    scoped_rule = @rules.find { |selector, _| selector == ".card-detail .ownership__button" }&.last
    assert scoped_rule, "regra escopada não encontrada"

    decls = Stylesheet.declarations(scoped_rule).to_h
    assert_equal 2, decls.size, "regra escopada deve ter exatamente min-height e min-width"
  end

  # Mobile-Carta.dc.html:63 — `[n]` de 44×44px, sunken, borda forte, 15px 600.
  test "o [n] do stepper tem 44px de largura e altura no detalhe" do
    step = Stylesheet.declarations(@rules.find { |selector, _| selector == ".card-detail .ownership__step" }&.last.to_s).to_h

    assert_equal "44px", step["min-width"]
    assert_equal "44px", step["min-height"]
  end

  test "o [n] é sunken, com borda forte e texto 15px peso 600" do
    step = Stylesheet.resolved("ownership__step", @rules)

    assert_equal "var(--surface-sunken)", step["background-color"]
    assert_equal "1px solid var(--border-strong)", step["border"]
    assert_equal "var(--body-strong-weight)", step["font-weight"]
    assert_equal 600, Stylesheet.read_root_tokens["--body-strong-weight"].to_i
  end

  # Mobile-Carta.dc.html:74 — "não tenho" é 13px, muted, peso regular.
  test "o não tenho é legenda 13px muted de peso regular" do
    empty = Stylesheet.resolved("ownership__empty", @rules)
    tokens = Stylesheet.read_root_tokens

    assert_equal "var(--ink-muted)", empty["color"]
    assert_equal 13.0, Stylesheet.to_pixels(empty["font-size"])
    assert_equal 400, tokens[empty["font-weight"][/var\((--[a-z-]+)\)/, 1]].to_i
  end

  test "o rótulo da unidade sai da vista em zero, sem display none" do
    unit = Stylesheet.resolved("ownership__unit--empty", @rules)

    assert_equal "absolute", unit["position"]
    assert_equal "inset(50%)", unit["clip-path"]
    assert_nil unit["display"]
  end
end
