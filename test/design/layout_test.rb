require "test_helper"
require_relative "support/stylesheet"

# A conta de 360px de `.context/design.md` §11.5, com os valores reais da folha:
# duas colunas de `--tile-min`, mais a margem lateral da página dos dois lados,
# mais o gutter da grade, cabem no viewport do Req. 2.5.
class LayoutTest < ActiveSupport::TestCase
  VIEWPORT = 360

  setup do
    @tokens = Stylesheet.read_root_tokens
    @rules = Stylesheet.rules
  end

  def declaration(selector, property)
    body = @rules.find { |sel, _| sel == selector }&.last
    assert body, "regra #{selector} sumiu da folha"

    value = Stylesheet.declarations(body).find { |prop, _| prop == property }&.last
    assert value, "#{selector} não declara #{property}"
    value
  end

  # Lado horizontal de um `padding` abreviado: 1 valor vale para os quatro lados,
  # 2 ou 3 valores têm o horizontal no segundo, 4 valores têm direita e esquerda.
  def horizontal_padding(value)
    parts = value.split
    right, left = case parts.size
    when 1 then [ parts[0], parts[0] ]
    when 2, 3 then [ parts[1], parts[1] ]
    else [ parts[1], parts[3] ]
    end
    Stylesheet.to_pixels(right, @tokens) + Stylesheet.to_pixels(left, @tokens)
  end

  test "duas colunas da grade cabem em 360px com a margem da página e o gutter" do
    tile_min = Stylesheet.to_pixels(@tokens.fetch("--tile-min"), @tokens)
    page = horizontal_padding(declaration(".catalog", "padding"))
    gutter = Stylesheet.to_pixels(declaration(".catalog__grid", "gap"), @tokens)

    total = 2 * tile_min + page + gutter

    assert_operator total, :<=, VIEWPORT,
                    "2 × #{tile_min} + #{page} de margem + #{gutter} de gutter = #{total}px, acima de #{VIEWPORT}px"
  end

  test "a margem e o gutter vêm da escala de §11.5" do
    assert_equal "var(--space-4)", declaration(".catalog", "padding"),
                 "§11.5: a margem lateral da página é `space-4`"
    assert_equal "var(--space-2)", declaration(".catalog__grid", "gap"),
                 "§11.5: o gutter da grade é `space-2`"
  end

  test "a conversão resolve token encadeado e recusa token ausente" do
    assert_equal 24.0, Stylesheet.to_pixels("var(--space-4)", @tokens)
    assert_equal 12.0, Stylesheet.to_pixels("0.75rem", @tokens)
    assert_raises(ArgumentError) { Stylesheet.to_pixels("var(--nao-existe)", @tokens) }
  end
end
