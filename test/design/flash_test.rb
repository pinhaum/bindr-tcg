require "test_helper"
require_relative "support/stylesheet"

# INT-06 (Req. 12.8): erro e sucesso se distinguem por mais do que a cor.
#
# `flash--alert` e `flash--notice` precisam de regra própria cada um, e o estilo
# efetivo das duas (base `.flash` mais modificador) continua diferente depois de
# descontadas as declarações de cor. Uma
# mensagem de validação não é ação destrutiva: `danger` fica fora (§11.6).
class FlashTest < ActiveSupport::TestCase
  CHROMATIC_PROPERTY = /\A(?:color|background(?:-color)?|border(?:-(?:top|right|bottom|left))?-color|outline-color)\z/

  BORDER_STYLES = %w[none hidden dotted dashed solid double groove ridge inset outset].freeze

  # `border: 1px solid var(--border)` → largura, estilo e cor em separado, para
  # o modificador que só troca `border-width` sobrescrever o valor certo.
  def self.expand(declarations)
    declarations.flat_map do |property, value|
      next [ [ property, value ] ] unless property == "border"

      value.split(/\s+(?![^(]*\))/).map do |part|
        if BORDER_STYLES.include?(part) then [ "border-style", part ]
        elsif part.match?(/\A(?:\d|thin|medium|thick)/) then [ "border-width", part ]
        else [ "border-color", part ]
        end
      end
    end
  end

  def self.declared(rules, selector)
    expand(rules.select { |sel, _| sel == selector }.flat_map { |_, body| Stylesheet.declarations(body) })
  end

  # Estilo que a mensagem de fato recebe (`.flash` mais o modificador), sem as
  # propriedades de cor. Comparar só as regras dos modificadores deixaria
  # passar um modificador que repete o valor herdado da base.
  def self.non_chromatic(rules, modifier)
    declared(rules, ".flash").to_h
                             .merge(declared(rules, modifier).to_h)
                             .reject { |property, _| property.match?(CHROMATIC_PROPERTY) }
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

  test "a comparação acusa modificador que só repete o estilo da base" do
    css = <<~CSS
      .flash { border: 1px solid var(--border); }
      .flash--alert { border-width: 1px; border-color: var(--border-strong); font-weight: var(--body-weight); }
      .flash--notice { border-style: solid; font-weight: var(--body-weight); }
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
