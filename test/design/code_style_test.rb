require "test_helper"
require_relative "support/stylesheet"

# INT-08 (Req. 12.7; `.context/design.md` §11.4): `card_number` e `variant_code`
# saem no estilo `code` — mono, 500, 13px/18px — em toda ocorrência.
class CodeStyleTest < ActiveSupport::TestCase
  # Classes que envolvem só o identificador, mais `.code` para o inline.
  IDENTIFIER_CLASSES = %w[
    code card-tile__number card-tile__placeholder-number card-detail__number
    variant__code import-preview__number import-preview__variant
    import-summary__number-card import-summary__variant
  ].freeze

  test "toda classe de identificador resolve para o estilo code" do
    rules = Stylesheet.rules
    off = IDENTIFIER_CLASSES.reject { |klass| Stylesheet.code_styled?(klass, rules) }

    assert_empty off, off.map { |klass| "#{klass}: #{Stylesheet.resolved(klass, rules).inspect}" }.join("\n")
  end

  test "o estilo resolvido acusa sobrescrita posterior" do
    css = <<~CSS
      .code, .x__number { font-family: var(--font-mono); font-size: var(--code-size);
                          line-height: var(--code-line-height); font-weight: var(--code-weight); }
      .x__number { font-weight: var(--display-weight); }
    CSS
    rules = Stylesheet.rules(css)

    assert Stylesheet.code_styled?("code", rules)
    assert_not Stylesheet.code_styled?("x__number", rules)
    assert_not Stylesheet.code_styled?("x", rules)
  end
end
