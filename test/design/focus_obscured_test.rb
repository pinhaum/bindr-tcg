require "test_helper"
require_relative "support/stylesheet"

# SC 2.4.11 (Res. 12.10): navegação fixa não esconde o foco ao tabular.
# O bloco `:root` base (fora de @media) declara
# `scroll-padding-bottom: var(--body-padding-bottom);`, dimensionando o espaço
# reservado para scroll quando um elemento ganha foco. `:root` casa com `html`,
# o scroller do documento.
class FocusObscuredTest < ActiveSupport::TestCase
  test ":root base declara scroll-padding-bottom igual a var(--body-padding-bottom)" do
    content = Stylesheet.read_stylesheet
    # Extrai o primeiro bloco :root (base, fora de @media)
    root_match = content.match(/:root\s*\{([^{}]+)\}/m)
    assert root_match, "nenhuma regra :root encontrada"

    has_scroll_padding = root_match[1].match?(/scroll-padding-bottom:\s*var\(--body-padding-bottom\)/)
    assert has_scroll_padding, ":root não declara scroll-padding-bottom: var(--body-padding-bottom)"
  end

  test "a folha não tem nenhuma regra com seletor html fora de :root" do
    content = Stylesheet.content_outside_root
    html_rules = content.scan(/html\s*\{/)
    assert_empty html_rules, "folha tem regra para html (deve estar em :root)"
  end
end
