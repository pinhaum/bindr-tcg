require "test_helper"
require_relative "support/stylesheet"

# T28 — Busca e linha de status no desenho do canvas (NAV-46, NAV-47).
#
# Campo de busca e botão "Buscar" com 44px e superfícies do design system;
# linha de status rente à grade.
class CatalogSearchStylingTest < ActiveSupport::TestCase
  test "input de busca tem min-height 44px" do
    body = find_rule_body('.catalog__search input[type="search"]')
    declarations = Stylesheet.declarations(body).to_h
    assert_equal "44px", declarations["min-height"], "Input de busca deve ter min-height 44px"
  end

  test "input de busca tem fundo surface-raised" do
    body = find_rule_body('.catalog__search input[type="search"]')
    declarations = Stylesheet.declarations(body).to_h
    assert_equal "var(--surface-raised)", declarations["background-color"], "Input deve ter fundo surface-raised"
  end

  test "input de busca tem borda border-strong" do
    body = find_rule_body('.catalog__search input[type="search"]')
    declarations = Stylesheet.declarations(body).to_h
    assert_equal "1px solid var(--border-strong)", declarations["border"], "Input deve ter borda border-strong"
  end

  test "botão de busca tem min-height 44px" do
    body = find_rule_body(".catalog__search button")
    declarations = Stylesheet.declarations(body).to_h
    assert_equal "44px", declarations["min-height"], "Botão deve ter min-height 44px"
  end

  test "botão de busca tem fundo transparente" do
    body = find_rule_body(".catalog__search button")
    declarations = Stylesheet.declarations(body).to_h
    assert_equal "var(--transparent)", declarations["background-color"], "Botão deve ter fundo transparente via token"
  end

  test "botão de busca tem borda border-strong" do
    body = find_rule_body(".catalog__search button")
    declarations = Stylesheet.declarations(body).to_h
    assert_equal "1px solid var(--border-strong)", declarations["border"], "Botão deve ter borda border-strong"
  end

  test "status line não tem padding horizontal" do
    body = find_rule_body(".catalog__status")
    declarations = Stylesheet.declarations(body).to_h
    assert_equal "0", declarations["padding"], "Status line não deve ter padding horizontal"
  end

  private

  def find_rule_body(selector)
    rules = Stylesheet.rules
    matching = rules.select { |sel, _| sel == selector }
    assert matching.any?, "Seletor não encontrado: #{selector}"
    matching.first[1]
  end
end
