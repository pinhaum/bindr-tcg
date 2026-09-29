require "test_helper"
require_relative "support/stylesheet"

# T11 (CNF-30, CNF-32, CNF-33): layout da pasta, "Adicionar cartas à pasta" e o
# campo de arquivo do import, medidos pela folha resolvida. Cada asserção tem o
# valor do artboard/spec, não o texto da regra.
class ProgressAddCardsTest < ActiveSupport::TestCase
  DESKTOP = /@media\s*\(min-width:\s*64rem\)\s*\{/

  # Corpo de cada bloco `@media (min-width: 64rem)`, casando chaves.
  def self.desktop_blocks(css)
    blocks = []
    css.scan(DESKTOP) do
      start = Regexp.last_match.end(0)
      depth = 1
      index = start
      while depth.positive?
        depth += 1 if css[index] == "{"
        depth -= 1 if css[index] == "}"
        index += 1
      end
      blocks << css[start...(index - 1)]
    end
    blocks
  end

  CSS = Stylesheet.content_without_comments
  DESKTOP_CSS = desktop_blocks(CSS).join("\n")
  BASE_CSS = desktop_blocks(CSS).reduce(CSS) { |css, block| css.sub(block, "") }
  BASE = Stylesheet.rules(BASE_CSS)
  DESKTOP_RULES = Stylesheet.rules(DESKTOP_CSS)

  def base(klass) = Stylesheet.resolved(klass, BASE)
  def desktop(klass) = Stylesheet.resolved(klass, DESKTOP_RULES)
  def px(value) = Stylesheet.to_pixels(value)

  test "a folha tem um bloco de 64rem para a pasta" do
    refute_empty DESKTOP_CSS
    assert_operator DESKTOP_RULES.size, :>, 5
  end

  # --- CNF-30 ---

  test "cartões: 2 colunas com gap 8px abaixo de 1024px" do
    summary = base("progress__summary")
    assert_equal "repeat(2, minmax(0, 1fr))", summary["grid-template-columns"]
    assert_equal 8.0, px(summary["gap"])
  end

  test "cartões: 4 colunas iguais com gap 16px em 1024px ou mais" do
    summary = desktop("progress__summary")
    assert_equal "repeat(4, minmax(0, 1fr))", summary["grid-template-columns"]
    assert_equal 16.0, px(summary["gap"])
  end

  test "pasta: uma coluna abaixo de 1024px" do
    assert_equal "1fr", base("progress__content")["grid-template-columns"]
  end

  test "pasta: sets à esquerda e ações numa coluna de 420px, gap 24px, alinhadas ao topo" do
    content = desktop("progress__content")
    assert_equal "minmax(0, 1fr) 420px", content["grid-template-columns"]
    assert_equal "flex-start", content["align-items"]
    assert_equal 24.0, px(content["gap"])
  end

  test "pasta: a lista ocupa a coluna 1 e as ações a coluna 2, na mesma linha" do
    assert_equal({ "grid-column" => "1", "grid-row" => "1" },
                 desktop("progress__list").slice("grid-column", "grid-row"))
    assert_equal({ "grid-column" => "2", "grid-row" => "1" },
                 desktop("progress__secondary").slice("grid-column", "grid-row"))
  end

  # --- CNF-32 ---

  test "Adicionar cartas abaixo de 1024px: fixo acima da barra inferior, accent, 44px" do
    add = base("progress__add-cards")
    assert_equal "fixed", add["position"]
    assert_equal "var(--nav-height)", add["bottom"]
    assert_equal "var(--accent)", add["background-color"]
    assert_equal "var(--on-accent)", add["color"]
    assert_operator px(add["min-height"]), :>=, 44.0
    assert_equal 8.0, px(add["border-radius"])
    assert_equal "1px solid var(--border)", add["border-top"]
    assert_equal [ 16.0, 24.0 ], add["padding"].split.map { |value| px(value) }
    tokens = Stylesheet.read_root_tokens
    typography = %w[font-size line-height font-weight].map { |property| tokens[add[property][/var\((--[a-z0-9-]+)\)/, 1]] }
    assert_equal [ "15px", "22px", "600" ], typography
  end

  test "reserva no fim da pasta cobre o botão fixo e a barra inferior" do
    reserve = base("progress")["padding-bottom"]
    reserve = Stylesheet.read_root_tokens.fetch(reserve[/var\((--[a-z0-9-]+)\)/, 1])
    total = reserve.scan(/var\((--[a-z0-9-]+)\)/).flatten.sum { |name| px("var(#{name})") }

    button = 44.0 + 2 * 16.0
    assert_operator total, :>=, px("var(--nav-height)") + button
  end

  # SC 2.4.11: o foco rolado para o fim da pasta não fica sob o botão fixo.
  test "na pasta, o scroll-padding reserva o botão fixo abaixo de 1024px e só a barra acima" do
    selector = ":root:has(.progress__add-cards)"
    scroll_padding = ->(rules) { rules.select { |sel, _| sel.strip == selector }.flat_map { |_, body| Stylesheet.declarations(body) }.to_h["scroll-padding-bottom"] }

    assert_equal "var(--progress-reserve)", scroll_padding.call(BASE)
    assert_equal "var(--body-padding-bottom)", scroll_padding.call(DESKTOP_RULES)
  end

  # D:27 (Desktop-Pasta): na coluna lateral o botão segue em accent, raio 8,
  # 44px; só sai do fixo. Não herda mais o desenho bordado de `.site-header__back`.
  test "Adicionar cartas em 1024px ou mais: sai do fixo e segue em accent, 44px, raio 8, sem posição fixa" do
    add = Stylesheet.resolved("progress__add-cards", BASE + DESKTOP_RULES)

    assert_equal "static", add["position"]
    assert_equal "var(--accent)", add["background-color"]
    assert_equal "var(--on-accent)", add["color"]
    assert_operator px(add["min-height"]), :>=, 44.0
    assert_equal 8.0, px(add["border-radius"])
  end

  test "na coluna lateral o botão ocupa a largura e diz só Adicionar cartas" do
    add = desktop("progress__add-cards")
    assert_equal "stretch", add["align-self"]
    assert_equal "center", add["justify-content"]
    assert_equal "none", desktop("progress__add-cards-suffix")["display"]
    assert_nil base("progress__add-cards-suffix")["display"], "abaixo de 1024px o rótulo é o do canvas móvel, com 'à pasta'"
  end

  test "divisor de 1px entre a navegação e a coluna lateral" do
    assert_equal "1px solid var(--border)", desktop("site-header__aside")["border-top"]
  end

  test "o slot compartilhado da coluna lateral não é fixo nem accent em nenhum viewport" do
    [ base("site-header__aside"), desktop("site-header__aside") ].each do |aside|
      assert_nil aside["position"]
      refute_includes aside.values.join(" "), "accent"
    end
  end

  # --- CNF-33 ---

  test "campo de arquivo do import: surface, borda do design system e 44px" do
    rule = Stylesheet.rules.find { |selector, _| selector == '.auth__field input[type="file"]' }
    assert rule, "regra do campo de arquivo não encontrada"

    file_input = Stylesheet.declarations(rule.last).to_h
    assert_equal "var(--surface-raised)", file_input["background-color"]
    assert_equal "1px solid var(--border-strong)", file_input["border"]
    assert_operator px(file_input["min-height"]), :>=, 44.0
  end
end
