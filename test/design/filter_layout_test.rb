require "test_helper"
require_relative "support/stylesheet"

# T9: Filtros em fluxo normal abaixo de 1024px, em duas colunas acima (NAV-22, NAV-23, NAV-28)
# Anel da cor selecionada com 2px em accent (NAV-15)
class FilterLayoutTest < ActiveSupport::TestCase
  setup do
    @stylesheet = Stylesheet.read_stylesheet
    @tokens = Stylesheet.read_root_tokens
  end

  # Extrai o conteúdo dentro de @media (min-width: 64rem) até o fim da folha
  def media_64rem_content
    match = @stylesheet.match(/@media\s*\([^)]*min-width:\s*64rem[^)]*\)\s*\{(.*)\}\s*\z/m)
    assert match, "@media (min-width: 64rem) não encontrada ou não é o último bloco"
    match[1]
  end

  # Extrai tudo que está FORA de @media queries (antes da primeira)
  def content_outside_media
    match = @stylesheet.match(/\A(.*?)@media/m)
    return @stylesheet unless match
    match[1]
  end

  test "fora de media query, .catalog__filters usa display: flex; flex-wrap: wrap" do
    outside = content_outside_media

    # Procura a regra .catalog__filters (última antes de @media, pois há redefinição)
    assert outside.include?(".catalog__filters"),
           "regra .catalog__filters não encontrada fora de media query"

    # Encontra a última .catalog__filters { ... } antes de @media (vence em cascata CSS)
    # scan com grupo retorna array de arrays: [["corpo1"], ["corpo2"]]
    all_matches = outside.scan(/\.catalog__filters\s*\{([^}]*)\}/)
    assert all_matches.any?, "regra .catalog__filters não tem corpo"

    body = all_matches.last[0]  # Última ocorrência vence em CSS cascata; [0] extrai do array interno
    assert body.include?("display: flex"),
           ".catalog__filters deve ter 'display: flex' fora de media query"
    assert body.include?("flex-wrap: wrap"),
           ".catalog__filters deve ter 'flex-wrap: wrap' fora de media query"
    assert !body.include?("overflow-x"),
           ".catalog__filters não deve ter 'overflow-x' fora de media query"
  end

  test "fora de media query, .catalog__filters não tem position nem float" do
    outside = content_outside_media

    # Última ocorrência (scan com grupo retorna array de arrays)
    all_matches = outside.scan(/\.catalog__filters\s*\{([^}]*)\}/)
    body = all_matches.last[0]

    # Verifica se há position: ... (fora de media query)
    refute body.match?(/position:\s*(?!static)/),
           ".catalog__filters não deve ter 'position' diferente de static fora de media query"

    refute body.include?("float:"),
           ".catalog__filters não deve ter 'float' fora de media query"
  end

  test "dentro de @media (min-width: 64rem), .catalog usa grid de duas colunas" do
    media = media_64rem_content

    assert media.include?(".catalog"),
           ".catalog não aparece em @media (min-width: 64rem)"

    catalog_match = media.match(/\.catalog\s*\{([^}]*)\}/)
    assert catalog_match, ".catalog não tem corpo em media query"

    body = catalog_match[1]
    assert body.include?("display: grid"),
           ".catalog deve ter 'display: grid' em @media (min-width: 64rem)"
    assert body.include?("grid-template-columns:"),
           ".catalog deve ter 'grid-template-columns:' em @media (min-width: 64rem)"
  end

  test "dentro de @media (min-width: 64rem), .catalog__filters está na coluna 1" do
    media = media_64rem_content

    assert media.include?(".catalog__filters"),
           ".catalog__filters não aparece em @media (min-width: 64rem)"

    filters_match = media.match(/\.catalog__filters\s*\{([^}]*)\}/)
    assert filters_match, ".catalog__filters não tem corpo em media query"

    body = filters_match[1]
    assert body.include?("grid-column: 1"),
           ".catalog__filters deve ter 'grid-column: 1' em @media (min-width: 64rem)"
  end

  test ".catalog__chip tem min-height 44px, border 1px border-strong, border-radius" do
    assert @stylesheet.include?(".catalog__chip {"),
           "regra .catalog__chip não encontrada"
    assert @stylesheet.include?("min-height: 44px"),
           ".catalog__chip deve ter 'min-height: 44px'"
    assert @stylesheet.include?("border: 1px solid var(--border-strong)"),
           ".catalog__chip deve ter 'border: 1px solid var(--border-strong)'"
    assert @stylesheet.include?("border-radius: var(--radius-sm)"),
           ".catalog__chip deve ter 'border-radius: var(--radius-sm)'"
  end

  test ".catalog__chip--active com fundo accent e texto on-accent" do
    assert @stylesheet.include?(".catalog__chip--active {"),
           "regra .catalog__chip--active não encontrada"
    assert @stylesheet.include?("background-color: var(--accent)"),
           ".catalog__chip--active deve ter 'background-color: var(--accent)'"
    assert @stylesheet.include?("color: var(--on-accent)"),
           ".catalog__chip--active deve ter 'color: var(--on-accent)'"
  end

  # NAV-35: o chip de cor ativo é um anel sem preenchimento, como o "Red" ativo
  # do canvas (Main.dc.html). O fundo accent do chip ativo exclui o de cor.
  test "chip de cor ativo tem anel de 2px em accent e nenhum preenchimento" do
    active = Stylesheet.resolved("catalog__chip--color.catalog__chip--active")
    assert_equal "2px solid var(--accent)", active["outline"]
    assert_equal "2px", active["outline-offset"]

    filled = Stylesheet.rules.select do |selector, body|
      selector.include?("catalog__chip--active") &&
        Stylesheet.declarations(body).any? { |property, value| property.start_with?("background") && value.include?("accent") }
    end
    refute_empty filled, "o chip ativo que não é de cor perdeu o fundo accent"
    filled.each do |selector, _|
      assert_includes selector, ":not(.catalog__chip--color)",
                      "#{selector} preenche de accent também o chip de cor"
    end
  end

  # O chip de cor continua flex como os outros chips, para a amostra, o nome e
  # o "×" ficarem alinhados ao centro dos 44px.
  test "chip de cor não sobrescreve o display flex do chip" do
    assert_equal "inline-flex", Stylesheet.resolved("catalog__chip")["display"]
    assert_nil Stylesheet.resolved("catalog__chip--color")["display"],
               ".catalog__chip--color não pode trocar o display de .catalog__chip"
  end


  test "dentro de @media (min-width: 64rem), .catalog__grid está na coluna 2" do
    media = media_64rem_content

    assert media.include?(".catalog__grid"),
           ".catalog__grid não aparece em @media (min-width: 64rem)"

    # .catalog__grid pode estar em seletor multi-classe (.catalog__grid, .catalog__empty, ...)
    grid_match = media.match(/\.catalog__grid[^{]*\{([^}]*)\}/)
    assert grid_match, ".catalog__grid não tem corpo em media query"

    body = grid_match[1]
    assert body.include?("grid-column: 2"),
           ".catalog__grid deve ter 'grid-column: 2' em @media (min-width: 64rem)"
  end

  test "dentro de @media (min-width: 64rem), os demais filhos (.catalog > *) ocupam 1 / -1" do
    media = media_64rem_content

    assert media.include?(".catalog > *"),
           ".catalog > * não aparece em @media (min-width: 64rem)"

    rule_match = media.match(/\.catalog\s*>\s*\*\s*\{([^}]*)\}/)
    assert rule_match, ".catalog > * não tem corpo em media query"

    body = rule_match[1]
    assert body.include?("grid-column: 1 / -1"),
           ".catalog > * deve ter 'grid-column: 1 / -1' em @media (min-width: 64rem)"
  end

  test "checkbox, rádio, select e botão têm min-height e min-width de 24px" do
    outside = content_outside_media

    # Procura a regra dos mínimos
    assert outside.include?("min-height: 24px"),
           "min-height: 24px não encontrado"
    assert outside.include?("min-width: 24px"),
           "min-width: 24px não encontrado"

    # Verifica que checkbox, rádio, select e botão estão na mesma regra (ou em regra separada)
    rule_match = outside.match(/\.catalog__filter-group\s+input\[type="checkbox"\][\s,]*\.catalog__filter-group\s+input\[type="radio"\][\s,]*\.catalog__filter-group\s+select[\s,]*\.catalog__filters\s+button\[type="submit"\]\s*\{([^}]*)\}/)

    if rule_match
      body = rule_match[1]
      assert body.include?("min-height: 24px") && body.include?("min-width: 24px"),
             "regra conjunta deve ter min-height e min-width de 24px"
    else
      # Verifica se cada um tem seu próprio min-height e min-width
      selectors = [
        ".catalog__filter-group input[type=\"checkbox\"]",
        ".catalog__filter-group input[type=\"radio\"]",
        ".catalog__filter-group select",
        ".catalog__filters button[type=\"submit\"]"
      ]

      selectors.each do |selector|
        rule_match = outside.match(/#{Regexp.escape(selector)}\s*\{([^}]*)\}/)
        assert rule_match,
               "#{selector} não tem regra CSS"

        body = rule_match[1]
        assert body.include?("min-height") && body.include?("24px"),
               "#{selector} deve ter min-height de 24px"
        assert body.include?("min-width") && body.include?("24px"),
               "#{selector} deve ter min-width de 24px"
      end
    end
  end
end
