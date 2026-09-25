require "test_helper"
require_relative "support/stylesheet"

# T19: Indicadores em cartões com número destaque e barra de progresso (NAV-37, NAV-38)
class ProgressCanvasTest < ActiveSupport::TestCase
  setup do
    @rules = Stylesheet.rules
    @tokens = Stylesheet.read_root_tokens
  end

  def find_rule(selector)
    @rules.find { |sel, _| sel == selector }
  end

  def rule_properties(selector)
    rule = find_rule(selector)
    assert rule, "Regra #{selector} não encontrada"
    decls = Stylesheet.declarations(rule.last)
    Hash[decls]
  end

  # NAV-37: indicadores como cartões (surface-raised, borda, raio-md, padding)
  test "progress__stat é cartão com fundo, borda, raio" do
    props = rule_properties(".progress__stat")
    assert props["background-color"]&.include?("surface-raised"),
      ".progress__stat deve ter background-color com surface-raised"
    assert props["border"]&.include?("1px solid"),
      ".progress__stat deve ter borda 1px solid"
    assert props["border-radius"]&.include?("radius-md"),
      ".progress__stat deve ter border-radius radius-md"
    assert props["padding"]&.include?("space-2"),
      ".progress__stat deve ter padding space-2"
  end

  # NAV-37: número em display (28px, 700)
  test "progress__stat-value usa estilo display" do
    props = rule_properties(".progress__stat-value")
    assert props["font-size"]&.include?("display-size"),
      ".progress__stat-value deve ter font-size display-size"
    assert props["font-weight"]&.include?("display-weight"),
      ".progress__stat-value deve ter font-weight display-weight"
  end

  # NAV-37: legenda em caption (13px, muted)
  test "progress__stat-label usa estilo caption e cor muted" do
    props = rule_properties(".progress__stat-label")
    assert props["font-size"]&.include?("caption-size"),
      ".progress__stat-label deve ter font-size caption-size"
    assert props["color"]&.include?("ink-muted"),
      ".progress__stat-label deve ter color ink-muted"
  end

  # NAV-28: grid 2 colunas em 360px
  test "progress__summary é grid 2 colunas" do
    props = rule_properties(".progress__summary")
    assert props["display"] == "grid",
      ".progress__summary deve ter display grid"
    assert props["grid-template-columns"]&.include?("repeat(2"),
      ".progress__summary deve ter grid-template-columns repeat(2, ...)"
  end

  # NAV-38: barra de progresso com trilho e preenchimento
  test "progress-set__bar tem trilho surface-sunken e preenchimento border-strong" do
    props = rule_properties(".progress-set__bar")
    assert props["background-color"]&.include?("surface-sunken"),
      ".progress-set__bar deve ter background-color surface-sunken (trilho)"
    assert props["accent-color"]&.include?("border-strong"),
      ".progress-set__bar deve ter accent-color border-strong (preenchimento)"
    assert props["height"] == "8px",
      ".progress-set__bar deve ter height 8px"
    assert props["border-radius"]&.include?("radius-sm"),
      ".progress-set__bar deve ter border-radius radius-sm"
  end

  # NAV-38: barra 100% de largura
  test "progress-set__bar ocupa 100% da largura do set" do
    props = rule_properties(".progress-set__bar")
    assert props["width"] == "100%",
      ".progress-set__bar deve ter width 100%"
  end
end
