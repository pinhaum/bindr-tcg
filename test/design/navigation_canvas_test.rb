require "test_helper"
require_relative "support/stylesheet"

class NavigationCanvasTest < Minitest::Test
  def setup
    @tokens = Stylesheet.read_root_tokens
    @rules = Stylesheet.rules
  end

  def find_rule(selector)
    # Normaliza espaço em branco no seletor procurado
    normalized_sel = selector.gsub(/\s+/, " ").strip
    @rules.find do |sel, _|
      sel.gsub(/\s+/, " ").strip == normalized_sel
    end&.last
  end

  def parse_declarations(body)
    Stylesheet.declarations(body).to_h
  end

  def find_media_rule(media_query, selector)
    stylesheet = Stylesheet.read_stylesheet
    # Extrai o bloco @media
    pattern = /@media\s*#{Regexp.escape(media_query)}\s*\{([^{}]*(?:\{[^}]*\}[^{}]*)*)\}/m
    match = stylesheet.match(pattern)
    return nil unless match

    media_content = match[1]
    # Procura o seletor dentro do bloco @media
    media_content.scan(/([^{}]+)\{([^{}]*)\}/).find do |sel, _|
      sel.strip == selector
    end&.then { |sel, body| parse_declarations(body) }
  end

  # NAV-05, NAV-28, NAV-30: Barra inferior em mobile
  # AC 1: .site-header__nav com background-color: var(--surface-raised) e cada
  # entrada (link e botão "Sair") com flex: 1
  def test_mobile_nav_has_surface_raised_background
    rule = find_rule(".site-header__nav")
    assert rule, ".site-header__nav deve existir"
    decl = parse_declarations(rule)
    assert_equal "var(--surface-raised)", decl["background-color"],
      ".site-header__nav deve ter background-color: var(--surface-raised)"
  end

  def test_mobile_nav_entries_flex_grow
    # Validação direta: grep pelo padrão de flex: 1 após os seletores
    stylesheet = Stylesheet.read_stylesheet
    # Procura por ".site-header__nav > a" seguido por ".site-header__nav button" com "flex: 1"
    assert stylesheet.match?(/\.site-header__nav\s*>\s*a[,\s]+\.site-header__nav\s+button\s*\{\s*flex:\s*1\s*;\s*\}/),
      ".site-header__nav > a e .site-header__nav button devem ter flex: 1"
  end

  # AC 2: .site-header__nav [aria-current="page"] com surface-sunken e ink;
  # demais com ink-muted
  def test_mobile_nav_current_page_styling
    rule = find_rule('.site-header__nav [aria-current="page"]')
    assert rule, '.site-header__nav [aria-current="page"] deve existir'
    decl = parse_declarations(rule)
    assert_equal "var(--surface-sunken)", decl["background-color"],
      "entrada ativa deve ter background-color: var(--surface-sunken)"
    assert_equal "var(--ink)", decl["color"],
      "entrada ativa deve ter color: var(--ink)"
  end

  def test_mobile_nav_inactive_color
    rule = find_rule('.site-header__nav a:not([aria-current="page"])')
    if rule
      decl = parse_declarations(rule)
      assert_equal "var(--ink-muted)", decl["color"],
        "entradas inativas devem ter color: var(--ink-muted)"
    end
  end

  # AC 3: Token --sidebar-width em :root
  def test_sidebar_width_token_exists
    assert_equal "280px", @tokens["--sidebar-width"],
      ":root deve ter --sidebar-width: 280px"
  end

  # AC 3: Token body-grid-columns em ≥ 64rem muda para var(--sidebar-width) minmax(0, 1fr)
  def test_desktop_body_grid_columns
    rule = find_media_rule("(min-width: 64rem)", ":root")
    assert rule, "@media (min-width: 64rem) e :root devem existir"
    expected_columns = "var(--sidebar-width) minmax(0, 1fr)"
    assert_equal expected_columns, rule["--body-grid-columns"],
      "--body-grid-columns em desktop deve ser '#{expected_columns}'"
  end

  # AC 4: Em ≥ 64rem, .site-header com background-color, border-right, altura inteira
  def test_desktop_site_header_styling
    rule = find_media_rule("(min-width: 64rem)", ".site-header")
    assert rule, ".site-header dentro de @media (min-width: 64rem) deve existir"
    assert_equal "var(--surface-raised)", rule["background-color"],
      ".site-header em desktop deve ter background-color: var(--surface-raised)"
    assert_equal "1px solid var(--border)", rule["border-right"],
      ".site-header em desktop deve ter border-right: 1px solid var(--border)"
  end

  # AC 4: Em ≥ 64rem, entradas empilhadas com min-height: 44px
  def test_desktop_nav_entries_stacked
    nav_rule = find_media_rule("(min-width: 64rem)", ".site-header__nav")
    assert nav_rule, ".site-header__nav dentro de @media deve existir"
    assert_equal "column", nav_rule["flex-direction"],
      ".site-header__nav em desktop deve ter flex-direction: column"

    rule_links = find_media_rule("(min-width: 64rem)", ".site-header__nav a")
    assert rule_links, ".site-header__nav a dentro de @media deve existir"
    assert_equal "44px", rule_links["min-height"],
      ".site-header__nav a em desktop deve ter min-height: 44px"
  end

  # AC 5: NAV-28 — em 360px a barra não desaparece nem overflow
  def test_mobile_nav_fits_360px
    rule = find_rule(".site-header__nav")
    decl = parse_declarations(rule)
    # Deve estar fixada na base, sem overflow
    assert_equal "fixed", decl["position"],
      ".site-header__nav deve ter position: fixed"
    assert_equal "0", decl["bottom"],
      ".site-header__nav deve estar no topo inferior"
  end
end
