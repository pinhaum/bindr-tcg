require "test_helper"
require_relative "support/stylesheet"

# Guarda de literais (INT-01, INT-12; `.context/design.md` §11.3–§11.5).
#
# Em toda regra fora de `:root`, as propriedades de cor, tipografia,
# espaçamento e raio só aceitam `var(--…)` de um token declarado em `:root`.
# A guarda cresceu por task (T4 a T6, por grupo de blocos) e desde a T7 varre a
# folha inteira; o conjunto de blocos é conferido contra uma lista fixa para
# que bloco novo não entre sem alguém olhar.
class LiteralValuesTest < ActiveSupport::TestCase
  # Os 21 blocos BEM medidos no inventário de `.specs/features/interface/tasks.md`,
  # mais `code`, o envoltório inline de identificador da T11.
  # A lista vive aqui, não é lida da folha.
  EXPECTED_BLOCKS = %w[
    auth card-detail card-tile catalog code collection-export field filter-chip
    flash flash-area import-preview import-summary ownership pagination
    progress progress-set site-header variant variant-list wishlist
    wishlist-item wishlist-mark
  ].freeze

  # Seletores sem classe: o seletor raiz.
  EXPECTED_CLASSLESS_SELECTORS = [ "*", "body" ].freeze

  # Técnica de ocultação visual (fora do fluxo, recortada): `margin: -1px` é parte
  # dela e não é espaçamento de layout.
  VISUALLY_HIDDEN_EXCEPTIONS = [ [ ".import-preview__rotulo-valor", "margin", "-1px" ] ].freeze

  # Opacidade aceita só como estado inerte de controle, nunca como texto secundário.
  OPACITY_ALLOWED_SELECTORS = [ '.ownership__button[aria-disabled="true"]' ].freeze

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

  # Devolve as violações de uma folha, uma string por declaração infratora.
  def self.violations(css, tokens)
    Stylesheet.rules(css).flat_map do |selector, body|
      Stylesheet.declarations(body).filter_map do |property, value|
        next if VISUALLY_HIDDEN_EXCEPTIONS.include?([ selector, property, value ])

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
      return if rest.all? { |part| part.match?(/\A(?:0|none)\z/) }
      return if value.match?(VAR_REFERENCE) && rest.all? { |part| part.match?(BORDER_PART) }

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

  test "nenhuma regra da folha tem literal em cor, tipografia, espaçamento e raio" do
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
      .bloco-novo { font-size: 12px; }
    CSS

    violations = self.class.violations(css, Stylesheet.read_root_tokens.slice("--space-2", "--border-strong"))

    assert_equal 4, violations.size, violations.join("\n")
    assert violations.any? { |v| v.include?(".bloco-novo") }, "a guarda não pode depender de lista de blocos"
    assert violations.any? { |v| v.include?(".catalog__title") && v.include?("literal 1.5rem") }
    assert violations.any? { |v| v.include?(".filter-chip") && v.include?("borda sem token") }
    assert violations.any? { |v| v.include?(".card-tile") && v.include?("--space-9") }
  end

  test "o conjunto de blocos da folha é o esperado" do
    present = @rules.flat_map { |selector, _| Stylesheet.blocks_of(selector) }.uniq.sort

    assert_equal EXPECTED_BLOCKS.sort, present,
                 "bloco novo ou sumido na folha: revise a guarda e esta lista juntos"

    classless = @rules.map(&:first).select { |selector| Stylesheet.blocks_of(selector).empty? }
    assert_equal EXPECTED_CLASSLESS_SELECTORS, classless,
                 "seletor sem classe novo ou sumido na folha"
  end

  test "a exceção de ocultação visual continua sendo ocultação visual" do
    VISUALLY_HIDDEN_EXCEPTIONS.each do |selector, property, value|
      body = rule(selector)

      assert_includes Stylesheet.declarations(body), [ property, value ]
      assert_match(/position:\s*absolute/, body)
      assert_match(/clip-path:\s*inset\(50%\)/, body)
    end
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
  test "texto secundário usa ink-muted, não opacidade" do
    offenders = @rules.select do |_, body|
      body.match?(/(?<![-\w])opacity\s*:/)
    end

    assert_empty offenders.map(&:first) - OPACITY_ALLOWED_SELECTORS, "opacidade usada no lugar de `ink-muted`"

    %w[.card-tile__number .card-tile__placeholder-number .card-detail__number .ownership__unit].each do |selector|
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

  def rule(selector)
    body = @rules.find { |sel, _| sel == selector }&.last
    assert body, "regra #{selector} sumiu da folha"
    body
  end

  test "o nome da carta no detalhe está em display" do
    body = rule(".card-detail__name")

    assert_match(/font-size:\s*var\(--display-size\)/, body)
    assert_match(/line-height:\s*var\(--display-line-height\)/, body)
    assert_match(/font-weight:\s*var\(--display-weight\)/, body)
  end

  test "rótulos de campo e de metadado da variante estão em caption com ink-muted" do
    [ ".field dt", ".variant__meta dt" ].each do |selector|
      body = rule(selector)

      assert_match(/font-size:\s*var\(--caption-size\)/, body, "#{selector} fora de `caption`")
      assert_match(/line-height:\s*var\(--caption-line-height\)/, body, "#{selector} fora de `caption`")
      assert_match(/(?<![-\w])color:\s*var\(--ink-muted\)/, body, "#{selector} sem `ink-muted`")
    end
  end

  # §11.6: o uso de `accent` na posse é o badge de quantidade (T9), não o botão.
  test "os botões de posse têm borda border-strong, raio radius-md e nenhum fundo accent" do
    body = rule(".ownership__button")

    assert_match(/border:\s*1px solid var\(--border-strong\)/, body)
    assert_match(/border-radius:\s*var\(--radius-md\)/, body)

    accent_fill = @rules.select do |selector, rule_body|
      selector.include?("ownership__button") && rule_body.match?(/background(?:-color)?\s*:[^;]*var\(--accent\)/)
    end
    assert_empty accent_fill.map(&:first), "botão de posse com fundo `accent`"
  end

  test "os campos de autenticação são controles em surface-sunken com border-strong e radius-sm" do
    body = rule(".auth__field input")

    assert_match(/border:\s*1px solid var\(--border-strong\)/, body)
    assert_match(/background-color:\s*var\(--surface-sunken\)/, body)
    assert_match(/border-radius:\s*var\(--radius-sm\)/, body)
  end

  test "o título da autenticação está em display" do
    body = rule(".auth__title")

    assert_match(/font-size:\s*var\(--display-size\)/, body)
    assert_match(/line-height:\s*var\(--display-line-height\)/, body)
    assert_match(/font-weight:\s*var\(--display-weight\)/, body)
  end

  # §11.6: `accent` é raro por construção. Nas regras que a tela de autenticação
  # renderiza (cabeçalho, flash e o próprio bloco), só o envio o usa.
  test "o envio da autenticação é a única ação em accent da tela, com texto on-accent" do
    submit = rule(".auth__submit")
    assert_match(/background-color:\s*var\(--accent\)/, submit)
    assert_match(/(?<![-\w])color:\s*var\(--on-accent\)/, submit)

    screen_blocks = %w[auth site-header flash flash-area]
    accent_users = @rules.select do |selector, body|
      Stylesheet.blocks_of(selector).intersect?(screen_blocks) && body.include?("var(--accent)")
    end
    assert_equal [ ".auth__submit" ], accent_users.map(&:first),
                 "outra regra da tela de autenticação usa `accent`"
  end

  # SC 1.4.1: o rótulo "Atendido" é o sinal (provado em
  # test/integration/wishlist_items_test.rb:235); o modificador só reforça, e
  # reforça por forma. Descontada a cor, a regra continua diferindo.
  test "o modificador de wishlist atendida não depende de cor" do
    declarations = Stylesheet.declarations(rule(".wishlist-item--fulfilled"))
    non_chromatic = declarations.reject do |property, _|
      property.match?(/\A(?:color|background(?:-color)?|border(?:-(?:top|right|bottom|left))?-color)\z/)
    end

    assert_not_empty non_chromatic, "`wishlist-item--fulfilled` difere só por cor"
  end

  # §11.4: `code` é exclusivo de identificador lido caractere a caractere, e o
  # código de set é um deles.
  test "o código de set no progresso está em code" do
    body = rule(".progress-set__code")

    assert_match(/font-family:\s*var\(--font-mono\)/, body)
    assert_match(/font-size:\s*var\(--code-size\)/, body)
    assert_match(/line-height:\s*var\(--code-line-height\)/, body)
    assert_match(/font-weight:\s*var\(--code-weight\)/, body)
  end
end
