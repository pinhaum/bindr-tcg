require "test_helper"
require_relative "support/stylesheet"

# T27 — Teste de folha para filtros recolhidos (NAV-45).
#
# Em viewport larga (≥ 64rem), o summary fica oculto e o conteúdo permanece visível.
class FiltersToggleLayoutTest < ActiveSupport::TestCase
  setup do
    @css = Stylesheet.read_stylesheet
    # Extrai o bloco @media (min-width: 64rem)
    media_match = @css.match(/@media \(min-width: 64rem\)\s*\{(.*?)^\}/m)
    @media_block = media_match[1] if media_match
  end

  test "summary está oculto em viewport larga (NAV-45)" do
    assert @media_block, "Falta @media (min-width: 64rem)"

    # Procura a regra .catalog__filters-summary
    summary_rule = @media_block.match(/\.catalog__filters-summary\s*\{([^}]*)\}/m)
    assert summary_rule, "Falta regra .catalog__filters-summary em @media larga"

    rule_body = summary_rule[1]
    assert rule_body.include?("display: none"), "summary deve ter display: none em viewport larga"
  end

  test "details-toggle tem margin e padding zerados em viewport larga" do
    assert @media_block, "Falta @media (min-width: 64rem)"

    # Procura a regra .catalog__filters-toggle (que não seja summary)
    toggle_rule = @media_block.match(/\.catalog__filters-toggle\s*\{([^}]*)\}/m)
    assert toggle_rule, "Falta regra .catalog__filters-toggle em @media larga"

    rule_body = toggle_rule[1]
    assert rule_body.include?("margin: 0"), "details deve ter margin: 0"
    assert rule_body.include?("padding: 0"), "details deve ter padding: 0"
  end
end
