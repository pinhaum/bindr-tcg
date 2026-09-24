require "test_helper"
require_relative "support/stylesheet"

# SC 2.4.11 (Res. 12.10): navegação fixa não esconde o foco ao tabular.
# A regra `html { scroll-padding-bottom: var(--body-padding-bottom); }`
# dimensiona o espaço reservado para scroll quando um elemento ganha foco.
class FocusObscuredTest < ActiveSupport::TestCase
  setup { @rules = Stylesheet.rules }

  test "html declara scroll-padding-bottom igual a var(--body-padding-bottom)" do
    html_rules = @rules.select { |selector, _| selector.strip == "html" }
    assert_not_empty html_rules, "nenhuma regra para html"

    declarations = html_rules.flat_map do |_selector, body|
      Stylesheet.declarations(body)
    end

    has_scroll_padding = declarations.any? do |property, value|
      property == "scroll-padding-bottom" && value == "var(--body-padding-bottom)"
    end

    assert has_scroll_padding, "html não declara scroll-padding-bottom: var(--body-padding-bottom)"
  end
end
