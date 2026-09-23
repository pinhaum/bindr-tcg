require "test_helper"
require_relative "support/stylesheet"

# INT-09 (Req. 12.9), INT-05 (Req. 12.3): anel de foco único, 2px sólido em
# `accent` com 2px de deslocamento, para todo elemento focável. O par do anel a
# 3:1 sobre as três superfícies está em contrast_test.rb:247, :258 e :269.
class FocusTest < ActiveSupport::TestCase
  FOCUSABLE = %w[a button input select textarea summary].freeze
  RING = /\Aoutline:\s*2px solid var\(--accent\)\z/

  def self.outline_rules(rules)
    rules.select do |_, body|
      Stylesheet.declarations(body).any? { |property, _| property.start_with?("outline") }
    end
  end

  # Declarações de outline que somem com o anel ou o deixam translúcido.
  def self.ring_breakers(rules)
    outline_rules(rules).flat_map do |selector, body|
      Stylesheet.declarations(body).filter_map do |property, value|
        next unless property.match?(/\Aoutline(?:-color|-style|-width)?\z/)

        removed = value.match?(/\A(?:none|0)\z/) || value.match?(/(?:\A|\s)(?:none|0)(?:\s|\z)/)
        translucent = value.match?(/transparent|rgba\(|hsla\(|\/\s*\d|#\h{8}\b|#\h{4}\b/)
        "#{selector.squish} { #{property}: #{value} }" if removed || translucent
      end
    end
  end

  # Regra de controle ou de foco que usa a hairline decorativa `border`.
  CONTROL_SELECTOR = /(?:\A|[\s,>+~(])(?:button|input|select)\b|__button\b|__input\b|:focus/

  # Toda classe que recebe o anel de foco é controle, mesmo fora do padrão
  # `__button`/`__input` (`.wishlist-mark__submit`, `.import-preview__confirm`).
  def self.focus_ring_classes(rules)
    rules.select { |selector, _| selector.include?(":focus") }
         .flat_map { |selector, _| selector.scan(/\.([a-zA-Z0-9_-]+):focus/).flatten }
         .uniq
  end

  def self.decorative_border_on_controls(rules)
    control_classes = focus_ring_classes(rules)
    rules.select do |selector, body|
      control = selector.match?(CONTROL_SELECTOR) ||
                selector.scan(/\.([a-zA-Z0-9_-]+)/).flatten.intersect?(control_classes)
      control && body.match?(/var\(--border\)/)
    end.map(&:first)
  end

  setup { @rules = Stylesheet.rules }

  test "uma única regra de foco cobre todo elemento focável com o anel em accent" do
    focus_rules = self.class.outline_rules(@rules).select { |selector, _| selector.include?(":focus") }

    assert_equal 1, focus_rules.size, "mais de uma regra de anel de foco:\n#{focus_rules.map(&:first).join("\n")}"

    selector, body = focus_rules.first
    parts = selector.split(",").map(&:strip)
    FOCUSABLE.each do |element|
      assert_includes parts, "#{element}:focus-visible", "o anel de foco não cobre #{element}"
    end

    declarations = Stylesheet.declarations(body)
    assert declarations.any? { |property, value| "#{property}: #{value}".match?(RING) },
           "o anel não é 2px sólido em accent: #{declarations.inspect}"
    assert_includes declarations, [ "outline-offset", "2px" ]
  end

  test "nenhuma regra tira o anel nem o deixa translúcido" do
    assert_empty self.class.ring_breakers(@rules)
    leftovers = Stylesheet.content_without_comments.scan(/outline:[^;]*currentcolor/)
    assert_empty leftovers, "sobrou anel em currentcolor"
  end

  test "a guarda do anel acusa outline removido e translúcido" do
    css = <<~CSS
      .a:focus { outline: none; }
      .b:focus-visible { outline: 0; }
      .c:focus-visible { outline: 2px solid rgba(255 158 20 / 50%); }
      .d:focus-visible { outline-color: transparent; }
      .e:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
    CSS

    assert_equal 4, self.class.ring_breakers(Stylesheet.rules(css)).size
  end

  test "border decorativa não aparece em regra de controle nem de foco" do
    assert_empty self.class.decorative_border_on_controls(@rules)
  end

  test "a guarda de border em controle acusa button, __input e :focus" do
    css = <<~CSS
      .x__button { border: 1px solid var(--border); }
      .y__input { border-color: var(--border); }
      .z:focus-visible { outline: 2px solid var(--border); }
      .w__field input { border: 1px solid var(--border-strong); }
      .v__card { border: 1px solid var(--border); }
      .u__submit:focus-visible { outline: 2px solid var(--accent); }
      .u__submit { border: 1px solid var(--border); }
    CSS

    assert_equal %w[.x__button .y__input .z:focus-visible .u__submit],
                 self.class.decorative_border_on_controls(Stylesheet.rules(css))
  end
end
