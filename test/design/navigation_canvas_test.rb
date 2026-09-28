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

  # O "Sair" é um `button_to`: o item flex da barra é o form, não o botão.
  # Canvas (Main.dc.html): entradas com flex-grow 1, encostadas.
  def test_mobile_nav_entries_flex_grow
    assert_equal "1", Stylesheet.resolved("site-header__nav > a")["flex"]
    assert_equal "1", Stylesheet.resolved("site-header__nav > form")["flex"],
      "o form do Sair precisa crescer como os links"
    assert_equal "1", Stylesheet.resolved("site-header__nav > form > button")["flex"]
    assert_nil find_rule(".site-header__nav").then { |rule| parse_declarations(rule)["gap"] },
      "as entradas da barra inferior se encostam, sem gap"
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

  # T9 (conformidade), CNF-23 — "Voltar ao catálogo" existe uma vez, sem "←",
  # ≥44px e bordado (independe de viewport: a mesma regra vale em 390px e em
  # ≥1024px, só a posição no layout muda).
  def test_back_to_catalog_link_styling
    resolved = Stylesheet.resolved("site-header__back")
    assert resolved.any?, ".site-header__back deve existir"
    assert_equal "44px", resolved["min-height"],
      ".site-header__back deve ter min-height: ≥ 44px"
    assert_match(/solid.*var\(--border-strong\)/, resolved["border"],
      ".site-header__back deve ter borda border-strong")
    assert_equal "0 var(--space-3)", resolved["padding"],
      ".site-header__back deve ter padding 0 16px"
  end

  # T9 (conformidade), CNF-24 — Marca "Bindr" em desktop usa a tipografia
  # `display` (28/32/700); abaixo de 1024px ela continua existindo mas sem
  # essa tipografia (T9 não altera o mobile).
  def test_sidebar_brand_typography_in_wide_layout
    wide = CatalogGridCanvasTest.wide_block
    wide_rules = Stylesheet.rules(wide)
    resolved = Stylesheet.resolved("site-header__brand", wide_rules)

    assert_equal "var(--display-size)", resolved["font-size"],
      ".site-header__brand em ≥1024px deve usar --display-size"
    assert_equal "var(--display-line-height)", resolved["line-height"],
      ".site-header__brand em ≥1024px deve usar --display-line-height"
    assert_equal "var(--display-weight)", Stylesheet.resolved("site-header__brand")["font-weight"],
      ".site-header__brand já usa --display-weight em qualquer viewport"
  end

  # T9: o slot da coluna lateral (`site-header__aside`, reutilizado pela T11)
  # tem o divisor de 1px antes dele só em ≥1024px — abaixo disso ele não deve
  # aparecer separado da navegação por um traço.
  def test_sidebar_aside_divider_only_in_wide_layout
    wide = CatalogGridCanvasTest.wide_block
    wide_rules = Stylesheet.rules(wide)
    resolved = Stylesheet.resolved("site-header__aside", wide_rules)

    assert_equal "1px solid var(--border)", resolved["border-top"],
      ".site-header__aside em ≥1024px deve ter divisor border-top: 1px solid var(--border)"

    narrow_rules = Stylesheet.rules(Stylesheet.content_without_comments.sub(wide, ""))
    narrow_resolved = Stylesheet.resolved("site-header__aside", narrow_rules)
    assert_nil narrow_resolved["border-top"],
      ".site-header__aside não deve ter divisor fora de ≥1024px"
  end
end
