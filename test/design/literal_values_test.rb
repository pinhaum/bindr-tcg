require "test_helper"
require_relative "support/stylesheet"

# Guarda de literais (INT-01, INT-12; `.context/design.md` §11.3–§11.5).
#
# Nos blocos guardados, as propriedades de cor, tipografia, espaçamento e raio
# só aceitam `var(--…)` de um token declarado em `:root`. A guarda cresce por
# task: T4 cobre o seletor raiz e os blocos de layout e catálogo.
class LiteralValuesTest < ActiveSupport::TestCase
  # Blocos BEM guardados. A lista vive aqui, não é lida da folha.
  GUARDED_BLOCKS = %w[
    site-header flash-area flash catalog filter-chip card-tile pagination
  ].freeze

  # Propriedades cujo valor precisa vir de token.
  GOVERNED_PROPERTY = /\A(?:
    font-size | line-height | font-weight |
    color | background-color | background | border-color |
    padding(?:-(?:top|right|bottom|left))? |
    margin(?:-(?:top|right|bottom|left))? |
    gap | row-gap | column-gap |
    border-radius
  )\z/x

  # `border` e seus lados: a espessura e o estilo são literais legítimos; a cor não.
  BORDER_SHORTHAND = /\Aborder(?:-(?:top|right|bottom|left))?\z/

  # Literais aceitos sem token (exceções declaradas no "Done when" da T4).
  ALLOWED_LITERALS = %w[0 auto 100% 1fr inherit].freeze

  # O que pode sobrar num `border` depois de tirar o token de cor.
  BORDER_PART = /\A(?:0|none|\d+(?:\.\d+)?px|solid|dashed|dotted|double)\z/

  VAR_REFERENCE = /var\((--[a-z0-9-]+)\)/

  def self.guarded?(selector)
    blocks = Stylesheet.blocks_of(selector)
    blocks.empty? || blocks.intersect?(GUARDED_BLOCKS)
  end

  # Devolve as violações de uma folha, uma string por declaração infratora.
  def self.violations(css, tokens)
    Stylesheet.rules(css).select { |selector, _| guarded?(selector) }.flat_map do |selector, body|
      Stylesheet.declarations(body).filter_map do |property, value|
        problem = value_problem(property, value, tokens)
        "#{selector.squish} { #{property}: #{value} } — #{problem}" if problem
      end
    end
  end

  def self.value_problem(property, value, tokens)
    border = property.match?(BORDER_SHORTHAND)
    return unless border || property.match?(GOVERNED_PROPERTY)

    undeclared = value.scan(VAR_REFERENCE).flatten.reject { |name| tokens.key?(name) }
    return "token não declarado em :root: #{undeclared.join(', ')}" if undeclared.any?

    rest = value.gsub(VAR_REFERENCE, " ").split(/[\s,]+/).reject(&:empty?)

    if border
      return if value.match?(VAR_REFERENCE) || rest.all? { |part| part.match?(/\A(?:0|none)\z/) }

      "borda sem token de cor"
    else
      literals = rest - ALLOWED_LITERALS
      "literal #{literals.join(' ')}" if literals.any?
    end
  end

  setup do
    @tokens = Stylesheet.read_root_tokens
    @rules = Stylesheet.rules
  end

  test "os blocos guardados não têm literal em cor, tipografia, espaçamento e raio" do
    violations = self.class.violations(Stylesheet.read_stylesheet, @tokens)

    assert_empty violations,
                 "declarações com literal onde o design system exige token:\n#{violations.join("\n")}"
  end

  test "a guarda acusa literal, borda em currentcolor e token inexistente" do
    css = <<~CSS
      :root { --space-2: 8px; --border-strong: #717e84; }
      .catalog__title { font-size: 1.5rem; margin: 0 0 var(--space-2); }
      .filter-chip { border: 1px solid currentcolor; }
      .card-tile { padding: var(--space-9); }
      .pagination { gap: var(--space-2); border: 1px solid var(--border-strong); }
      .fora-da-guarda { font-size: 12px; }
    CSS

    violations = self.class.violations(css, Stylesheet.read_root_tokens.slice("--space-2", "--border-strong"))

    assert_equal 3, violations.size, violations.join("\n")
    assert violations.any? { |v| v.include?(".catalog__title") && v.include?("literal 1.5rem") }
    assert violations.any? { |v| v.include?(".filter-chip") && v.include?("borda sem token") }
    assert violations.any? { |v| v.include?(".card-tile") && v.include?("--space-9") }
  end

  test "todo bloco guardado existe na folha" do
    present = @rules.flat_map { |selector, _| Stylesheet.blocks_of(selector) }.uniq

    assert_empty GUARDED_BLOCKS - present,
                 "bloco guardado sem regra na folha: a guarda estaria vigiando o vazio"
  end

  test "o seletor raiz está sob a guarda e consome os tokens de corpo" do
    body = @rules.find { |selector, _| selector == "body" }&.last

    assert body, "a folha perdeu a regra de body"
    assert_match(/font-size:\s*var\(--body-size\)/, body)
    assert_match(/line-height:\s*var\(--body-line-height\)/, body)
  end

  # `opacity: 0.7` fazia o papel de texto secundário; o design system tem token
  # para isso (`ink-muted`), e opacidade sobre fundo escuro não tem contraste
  # verificável pelo teste de pares.
  test "texto secundário dos blocos guardados usa ink-muted, não opacidade" do
    offenders = @rules.select do |selector, body|
      self.class.guarded?(selector) && body.match?(/(?<![-\w])opacity\s*:/)
    end

    assert_empty offenders.map(&:first), "opacidade usada no lugar de `ink-muted`"

    %w[.card-tile__number .card-tile__placeholder-number].each do |selector|
      body = @rules.find { |sel, _| sel == selector }&.last
      assert body, "regra #{selector} sumiu da folha"
      assert_match(/(?<![-\w])color:\s*var\(--ink-muted\)/, body, "#{selector} precisa de `ink-muted`")
    end
  end

  # §11.3: `surface-raised` fica a 1.20:1 de `surface-base`; sozinho não delimita.
  test "surface-raised nunca aparece sem borda no mesmo seletor" do
    raised = @rules.select { |_, body| body.include?("var(--surface-raised)") }

    raised.each do |selector, body|
      assert_match(/(?<![-\w])border(?:-(?:top|right|bottom|left))?\s*:[^;]*var\(--border(?:-strong)?\)/, body,
                   "#{selector} usa `surface-raised` sem `border` ou `border-strong`")
    end
  end

  test "a guarda de surface-raised acusa preenchimento sem borda" do
    css = ".card-tile { background-color: var(--surface-raised); }"
    body = Stylesheet.rules(css).first.last

    assert_no_match(/(?<![-\w])border(?:-(?:top|right|bottom|left))?\s*:[^;]*var\(--border(?:-strong)?\)/, body)
  end

  test "o chip de filtro é delimitado por border-strong, não por currentcolor" do
    body = @rules.find { |selector, _| selector == ".filter-chip" }&.last

    assert body, "regra .filter-chip sumiu da folha"
    assert_match(/border:\s*1px solid var\(--border-strong\)/, body)
  end

  test "tile e poço da imagem usam radius-md" do
    %w[.card-tile .card-tile__art].each do |selector|
      body = @rules.find { |sel, _| sel == selector }&.last
      assert body, "regra #{selector} sumiu da folha"
      assert_match(/border-radius:\s*var\(--radius-md\)/, body, "#{selector} precisa de `radius-md`")
    end
  end

  # Edge Case do reflow: quando a imagem falha, o placeholder ocupa exatamente a
  # caixa dela. A caixa é a do poço, cuja proporção é a única declarada: imagem e
  # placeholder a preenchem pela mesma regra, e nenhum dos dois declara a própria.
  test "placeholder e imagem compartilham a caixa de proporção do poço" do
    art = @rules.find { |selector, _| selector == ".card-tile__art" }&.last
    assert art, "regra .card-tile__art sumiu da folha"
    assert_match(/aspect-ratio:\s*5 \/ 7/, art)
    assert_match(/background:\s*var\(--surface-sunken\)/, art)

    shared = @rules.find do |selector, _|
      selector.split(",").map(&:strip).sort == %w[.card-tile__image .card-tile__placeholder]
    end
    assert shared, "imagem e placeholder precisam ser dimensionados pela mesma regra"
    %w[position:\s*absolute inset:\s*0 width:\s*100% height:\s*100%].each do |declaration|
      assert_match(/#{declaration}/, shared.last)
    end

    own = @rules.select do |selector, body|
      selector.match?(/\.card-tile__(?:image|placeholder)(?![-\w])/) &&
        body.match?(/(?<![-\w])(?:aspect-ratio|height|width)\s*:/) && !selector.include?(",")
    end
    assert_empty own.map(&:first), "imagem ou placeholder declarando caixa própria causa reflow"

    placeholder = @rules.find { |selector, _| selector == ".card-tile__placeholder" }&.last
    assert_match(/background-color:\s*var\(--surface-sunken\)/, placeholder.to_s,
                 "o placeholder é o poço em `surface-sunken`")
  end
end
