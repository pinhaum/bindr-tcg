require "test_helper"
require_relative "support/stylesheet"

# INT-07 (Req. 12.6; `.context/design.md` §11.5–§11.6): posse não é cor.
#
# A variante possuída ganha badge `radius-full` em `accent` com a quantidade.
# Dois lugares mostram esse mesmo badge — o detalhe (`.ownership__count--owned`,
# por variante) e o selo da grade (`.card-tile__badge`, por carta — CNF-02,
# T3 da `conformidade`) — e `radius-full` é exclusivo dos dois: não existe
# segundo nível de âmbar para indicar posse.
class OwnershipBadgeTest < ActiveSupport::TestCase
  BADGE = ".ownership__count--owned".freeze
  GRID_BADGE = ".card-tile__badge".freeze
  DETAIL_BADGE = ".card-detail__badge".freeze
  AMBER_HUE = 66.0
  HUE_TOLERANCE = 6.0
  # Abaixo deste croma a matiz é instável e a cor é lida como cinza, não âmbar.
  MIN_CHROMA = 0.05
  WIDE = /@media\s*\(min-width:\s*64rem\)\s*\{/

  def self.amber_tokens(tokens)
    tokens.select do |_, value|
      next false unless value.match?(/\A#\h{6}\z/)

      oklch = Stylesheet.hex_to_oklch(value)
      oklch[:C] >= MIN_CHROMA && (oklch[:H] - AMBER_HUE).abs <= HUE_TOLERANCE
    end.keys
  end

  def self.radius_full_users(rules)
    rules.select { |_, body| body.include?("var(--radius-full)") }
         .flat_map { |selector, _| selector.split(",").map(&:strip) }
  end

  def self.wide_block(css = Stylesheet.content_without_comments)
    start = css.index(WIDE) or return ""
    open = css.index("{", start)
    depth = 0
    css.each_char.with_index.drop(open).each do |char, index|
      depth += 1 if char == "{"
      depth -= 1 if char == "}"
      return css[(open + 1)...index] if depth.zero?
    end
    ""
  end

  setup do
    css = Stylesheet.content_without_comments
    @wide = self.class.wide_block(css)
    @rules = Stylesheet.rules
    @narrow_rules = Stylesheet.rules(css.sub(@wide, ""))
    @wide_rules = Stylesheet.rules(@wide)
  end

  test "o badge de posse é radius-full, fundo accent e texto on-accent" do
    body = @rules.find { |selector, _| selector == BADGE }&.last

    assert body, "regra #{BADGE} sumiu da folha"
    assert_match(/border-radius:\s*var\(--radius-full\)/, body)
    assert_match(/background-color:\s*var\(--accent\)/, body)
    assert_match(/(?<![-\w])color:\s*var\(--on-accent\)/, body)
  end

  test "os selos da grade e do detalhe são radius-full, fundo accent e texto on-accent" do
    [ GRID_BADGE, DETAIL_BADGE ].each do |selector|
      rule = Stylesheet.resolved(selector.delete_prefix("."), @rules)

      assert_equal "var(--radius-full)", rule["border-radius"], selector
      assert_equal "var(--accent)", rule["background-color"], selector
      assert_equal "var(--on-accent)", rule["color"], selector
    end
  end

  test "radius-full só aparece nos badges de quantidade" do
    assert_equal [ BADGE, GRID_BADGE, DETAIL_BADGE ].sort, self.class.radius_full_users(@rules).sort
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

  test "o selo está posicionado no canto superior direito (CNF-02, CNF-16)" do
    rule = Stylesheet.resolved(GRID_BADGE.delete_prefix("."), @narrow_rules)

    assert_equal "absolute", rule["position"], GRID_BADGE
    assert_equal "var(--space-2)", rule["top"], "#{GRID_BADGE} no viewport estreito"
    assert_equal "var(--space-2)", rule["right"], "#{GRID_BADGE} no viewport estreito"
    assert_nil rule["bottom"], "#{GRID_BADGE} não deve ter bottom"
    assert_nil rule["left"], "#{GRID_BADGE} não deve ter left"

    rule = Stylesheet.resolved(DETAIL_BADGE.delete_prefix("."), @narrow_rules)

    assert_equal "absolute", rule["position"], DETAIL_BADGE
    assert_equal "var(--space-2)", rule["top"], "#{DETAIL_BADGE} no viewport estreito"
    assert_equal "var(--space-2)", rule["right"], "#{DETAIL_BADGE} no viewport estreito"
    assert_nil rule["bottom"], "#{DETAIL_BADGE} não deve ter bottom"
    assert_nil rule["left"], "#{DETAIL_BADGE} não deve ter left"

    rule = Stylesheet.resolved(DETAIL_BADGE.delete_prefix("."), @wide_rules)

    assert_equal "var(--space-3)", rule["top"], "#{DETAIL_BADGE} em ≥1024px"
    assert_equal "var(--space-3)", rule["right"], "#{DETAIL_BADGE} em ≥1024px"
  end
end
