require "test_helper"
require_relative "support/stylesheet"

# INT-06 (Req. 12.8): erro e sucesso se distinguem por mais do que a cor.
#
# `flash--alert` e `flash--notice` precisam de regra própria cada um, e as duas
# regras continuam diferentes depois de descontadas as declarações de cor. Uma
# mensagem de validação não é ação destrutiva: `danger` fica fora (§11.6).
class FlashTest < ActiveSupport::TestCase
  CHROMATIC_PROPERTY = /\A(?:color|background(?:-color)?|border(?:-(?:top|right|bottom|left))?-color|outline-color)\z/

  # Declarações não-cromáticas de todas as regras cujo seletor é exatamente `selector`.
  def self.non_chromatic(rules, selector)
    rules.select { |sel, _| sel == selector }
         .flat_map { |_, body| Stylesheet.declarations(body) }
         .reject { |property, _| property.match?(CHROMATIC_PROPERTY) }
         .sort
  end

  setup { @rules = Stylesheet.rules }

  test "alert e notice têm regra própria" do
    %w[.flash--alert .flash--notice].each do |selector|
      assert @rules.any? { |sel, body| sel == selector && Stylesheet.declarations(body).any? },
             "a folha não tem regra com declaração para #{selector}"
    end
  end

  test "descontada a cor, alert e notice continuam diferentes" do
    alert = self.class.non_chromatic(@rules, ".flash--alert")
    notice = self.class.non_chromatic(@rules, ".flash--notice")

    assert_not_equal alert, notice,
                     "`flash--alert` e `flash--notice` diferem só por cor: #{alert.inspect}"
  end

  test "a comparação acusa duas regras que diferem só por cor" do
    css = <<~CSS
      .flash--alert { color: var(--ink); border-color: var(--border-strong); border-width: 2px; }
      .flash--notice { color: var(--ink-muted); border-color: var(--border); border-width: 2px; }
    CSS
    rules = Stylesheet.rules(css)

    assert_equal self.class.non_chromatic(rules, ".flash--alert"),
                 self.class.non_chromatic(rules, ".flash--notice")
  end

  test "a mensagem de erro não usa danger" do
    offenders = @rules.select { |selector, body| selector.include?("flash") && body.include?("var(--danger)") }

    assert_empty offenders.map(&:first), "`danger` é reservado a ação destrutiva confirmada (§11.6)"
  end
end
