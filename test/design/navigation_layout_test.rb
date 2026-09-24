require "test_helper"
require_relative "support/stylesheet"

# T6: Navegação principal em barra fixa abaixo de 1024px, em coluna lateral acima
# (NAV-05, NAV-06, NAV-28, NAV-04)
class NavigationLayoutTest < ActiveSupport::TestCase
  setup do
    @tokens = Stylesheet.read_root_tokens
    @rules = Stylesheet.rules
  end

  def find_rule(selector)
    @rules.find { |sel, _| sel == selector }
  end

  def rule_body(selector)
    rule = find_rule(selector)
    assert rule, "regra #{selector} não encontrada"
    rule.last
  end

  def declarations_of(selector)
    body = rule_body(selector)
    Stylesheet.declarations(body)
  end

  # Encontra todas as regras que contêm um seletor em uma lista separada por vírgula
  def rules_with_selector(selector_part)
    @rules.select do |selector, _|
      selector.split(",").map(&:strip).any? { |sel| sel == selector_part }
    end
  end

  test "token --nav-height existe em :root com valor >= 44px" do
    nav_height = @tokens["--nav-height"]
    assert nav_height, "--nav-height não declarado em :root"

    # Converte para pixels
    pixels = Stylesheet.to_pixels(nav_height, @tokens)
    assert_operator pixels, :>=, 44,
                    "--nav-height é #{nav_height} = #{pixels}px, deve ser >= 44px"
  end

  test ".site-header__nav usa position: fixed; bottom: 0 fora de media query" do
    decls = declarations_of(".site-header__nav")
    decl_hash = decls.to_h

    assert_equal "fixed", decl_hash["position"],
                 ".site-header__nav deve ter position: fixed (fora de media query)"
    assert_equal "0", decl_hash["bottom"],
                 ".site-header__nav deve ter bottom: 0 (fora de media query)"
    assert decl_hash["height"]&.include?("var(--nav-height)"),
           ".site-header__nav deve ter height: var(--nav-height) (fora de media query)"
  end

  test ".site-header__action tem min-height: 44px" do
    decls = declarations_of(".site-header__action")
    decl_hash = decls.to_h

    value = decl_hash["min-height"]
    assert value, ".site-header__action não declara min-height"
    pixels = Stylesheet.to_pixels(value, @tokens)
    assert_operator pixels, :>=, 44,
                    "min-height é #{value} = #{pixels}px, deve ser >= 44px"
  end

  test "body tem padding-bottom: var(--body-padding-bottom) fora de media query" do
    decls = declarations_of("body")
    decl_hash = decls.to_h

    value = decl_hash["padding-bottom"]
    assert value&.include?("var(--body-padding-bottom)"),
           "body deve ter padding-bottom: var(--body-padding-bottom) (fora de media query)"
  end

  test "dentro de @media (min-width: 64rem), position e padding-bottom são desfazidos" do
    # Extrai o conteúdo da media query (usa rem em vez de px para evitar falso positivo de teste de viewport)
    stylesheet = Stylesheet.read_stylesheet

    # Encontra a media query inteira
    media_match = stylesheet.match(/@media\s*\([^)]*min-width:\s*64rem[^)]*\)\s*\{(.*)\}\s*\z/m)
    assert media_match, "@media (min-width: 64rem) não encontrada"

    media_content = media_match[1]

    # Verifica que :root aparece com --body-padding-bottom: 0 (via CSS variables)
    assert media_content.include?(":root"),
           ":root não aparece dentro de @media (min-width: 64rem)"
    assert media_content.include?("--body-padding-bottom: 0"),
           ":root deve redefinir --body-padding-bottom: 0 em @media (min-width: 64rem)"

    # Verifica que .site-header__nav aparece com position: static
    assert media_content.include?(".site-header__nav"),
           ".site-header__nav não aparece em @media (min-width: 64rem)"
    assert media_content.include?("position: static"),
           ".site-header__nav deve ter position: static em @media (min-width: 64rem)"
  end

  test "[aria-current=\"page\"] na navegação usa font-weight diferente do padrão" do
    decls = declarations_of(".site-header__nav [aria-current=\"page\"]")
    decl_hash = decls.to_h

    weight_value = decl_hash["font-weight"]
    assert weight_value, ".site-header__nav [aria-current=\"page\"] não declara font-weight"

    body_decls = declarations_of("body")
    body_weight = body_decls.to_h["font-weight"]

    refute_equal weight_value, body_weight,
                  "[aria-current=\"page\"] deve ter font-weight diferente do body"
  end

  test "--nav-current-weight existe em :root" do
    nav_current = @tokens["--nav-current-weight"]
    assert nav_current, "--nav-current-weight não declarado em :root"
  end

  test "dentro de @media (min-width: 64rem), .site-header está na coluna 1 cobrindo as linhas dos irmãos" do
    stylesheet = Stylesheet.read_stylesheet

    # Encontra a media query inteira
    media_match = stylesheet.match(/@media\s*\([^)]*min-width:\s*64rem[^)]*\)\s*\{(.*)\}\s*\z/m)
    assert media_match, "@media (min-width: 64rem) não encontrada"

    media_content = media_match[1]

    # Verifica .site-header com grid-column: 1
    assert media_content.include?(".site-header"),
           ".site-header não aparece em @media (min-width: 64rem)"
    assert media_content.include?("grid-column: 1"),
           ".site-header deve ter grid-column: 1"

    # Verifica grid-row: 1 / span 3 para cobrir as três linhas dos irmãos
    assert media_content.include?("grid-row: 1 / span 3"),
           ".site-header deve ter grid-row: 1 / span 3"

    assert media_content.include?("align-self: start"),
           ".site-header deve ter align-self: start"
  end

  test "dentro de @media (min-width: 64rem), todo irmão de .site-header está na coluna 2" do
    stylesheet = Stylesheet.read_stylesheet

    # Encontra a media query inteira
    media_match = stylesheet.match(/@media\s*\([^)]*min-width:\s*64rem[^)]*\)\s*\{(.*)\}\s*\z/m)
    assert media_match, "@media (min-width: 64rem) não encontrada"

    media_content = media_match[1]

    # Verifica seletor .site-header ~ * com grid-column: 2
    assert media_content.include?(".site-header ~ *"),
           "seletor .site-header ~ * não aparece em @media (min-width: 64rem)"
    assert media_content.include?("grid-column: 2"),
           ".site-header ~ * deve ter grid-column: 2"

    assert media_content.include?("min-width: 0"),
           ".site-header ~ * deve ter min-width: 0"
  end
end
