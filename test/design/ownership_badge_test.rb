require "test_helper"
require_relative "support/stylesheet"

# INT-07 (Req. 12.6; `.context/design.md` §11.5–§11.6): posse não é cor.
#
# A variante possuída ganha badge `radius-full` em `accent` com a quantidade.
# `radius-full` é exclusivo desse badge, e não existe segundo nível de âmbar
# para indicar posse.
class OwnershipBadgeTest < ActiveSupport::TestCase
  BADGE = ".ownership__count--owned".freeze
  AMBER_HUE = 66.0
  HUE_TOLERANCE = 6.0
  # Abaixo deste croma a matiz é instável e a cor é lida como cinza, não âmbar.
  MIN_CHROMA = 0.05

  def self.amber_tokens(tokens)
    tokens.select do |_, value|
      next false unless value.match?(/\A#\h{6}\z/)

      oklch = Stylesheet.hex_to_oklch(value)
      oklch[:C] >= MIN_CHROMA && (oklch[:H] - AMBER_HUE).abs <= HUE_TOLERANCE
    end.keys
  end

  def self.radius_full_users(rules)
    rules.select { |_, body| body.include?("var(--radius-full)") }.map(&:first)
  end

  setup { @rules = Stylesheet.rules }

  test "o badge de posse é radius-full, fundo accent e texto on-accent" do
    body = @rules.find { |selector, _| selector == BADGE }&.last

    assert body, "regra #{BADGE} sumiu da folha"
    assert_match(/border-radius:\s*var\(--radius-full\)/, body)
    assert_match(/background-color:\s*var\(--accent\)/, body)
    assert_match(/(?<![-\w])color:\s*var\(--on-accent\)/, body)
  end

  test "radius-full só aparece no badge de quantidade" do
    assert_equal [ BADGE ], self.class.radius_full_users(@rules)
  end

  test "a guarda de radius-full acusa um segundo uso" do
    css = "#{BADGE} { border-radius: var(--radius-full); } .card-tile { border-radius: var(--radius-full); }"

    assert_equal [ BADGE, ".card-tile" ], self.class.radius_full_users(Stylesheet.rules(css))
  end

  test "não existe segundo token de âmbar" do
    assert_equal [ "--accent" ], self.class.amber_tokens(Stylesheet.read_root_tokens)
  end

  test "a guarda de âmbar acusa um segundo nível" do
    tokens = { "--accent" => "#ff9e14", "--accent-soft" => "#b36e0e", "--ink" => "#e9f0f3" }

    assert_equal %w[--accent --accent-soft], self.class.amber_tokens(tokens)
  end
end
