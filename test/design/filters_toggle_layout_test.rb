require "test_helper"
require_relative "support/stylesheet"

# T27 — filtros recolhidos no celular e sempre visíveis na tela larga (NAV-43,
# NAV-45). A marcação é um `<details>` sem `open`; o que o abre na tela larga é
# a folha, e é ela que este teste lê, recortada pela media query.
class FiltersToggleLayoutTest < ActiveSupport::TestCase
  def rules_in_media_query
    @rules_in_media_query ||= begin
      content = Stylesheet.read_stylesheet
      media_part = content[/@media\s*\(min-width:\s*64rem\)\s*\{(.+?)\}\s*(?=@|\Z)/m, 1]
      assert media_part, "@media (min-width: 64rem) não encontrada"
      Stylesheet.rules(media_part)
    end
  end

  def declarations_in_media(selector)
    rule = rules_in_media_query.find { |candidate, _| candidate.strip == selector }
    assert_not_nil rule, "regra #{selector} não encontrada em @media (min-width: 64rem)"
    Stylesheet.declarations(rule[1]).to_h
  end

  test "na tela larga o summary sai de vista (NAV-45)" do
    assert_equal "none", declarations_in_media(".catalog__filters-summary")["display"]
  end

  # Sem isto o conteúdo de um <details> fechado não é renderizado.
  test "na tela larga o conteúdo do details fechado aparece (NAV-45)" do
    content = declarations_in_media(".catalog__filters-toggle::details-content")
    assert_equal "visible", content["content-visibility"]
    assert_equal "contents", content["display"]
  end

  # O <details> fica entre main.catalog e .catalog__filters. Sem `contents`, ele
  # vira o item do subgrid, sem posição, e os filtros sobem para baixo do
  # cabeçalho enquanto a grade desce (captura catalogo-1280-sessao.png).
  test "na tela larga o details não ocupa célula do subgrid do catálogo (NAV-32)" do
    assert_equal "contents", declarations_in_media(".catalog__filters-toggle")["display"]
  end
end
