require "test_helper"

# T5 — Navegação principal: marcação e entrada corrente (NAV-01..04, NAV-07).
#
# Valida a navegação principal adicionada em T5: que a `nav[aria-label="Principal"]`
# existe em toda página, com as entradas corretas conforme autenticação, e que
# `aria-current="page"` marca apenas a página aberta no navegador. Cobre os
# requisitos da spec:
#
# - NAV-01: um único `nav` principal com "Catálogo"
# - NAV-02: com sessão, "Minha pasta" e "Sair"
# - NAV-03: sem sessão, "Entrar" e "Criar conta"
# - NAV-04: `aria-current="page"` na entrada aberta
# - NAV-07: ausência de entradas de baralho, preço ou cotação
#
# Usa as fixtures e helpers de login do projeto (minha_pasta_test.rb,
# sessions_test.rb).
class NavegacaoPrincipalTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nav-test@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster",
                           base_set_size: 5, total_set_size: 7)

    # Criar uma variante para usar em detalhe
    @card = Card.create!(card_set: @set, card_number: "OP01-001", name: "Luffy",
                         card_type: "character", colors: [ "Red" ])
    @variant = CardVariant.create!(card: @card, card_set: @set, variant_code: "base",
                                   rarity: "C", art_kind: "base")
  end

  def sign_in(user = nil)
    user ||= @user
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # --- NAV-01: um único nav[aria-label="Principal"] dentro de header.site-header ---

  test "catálogo tem exatamente um nav[aria-label=\"Principal\"] dentro de header.site-header" do
    get catalog_path

    assert_response :success
    assert_select "header.site-header nav[aria-label='Principal']", count: 1
  end

  test "progresso tem exatamente um nav[aria-label=\"Principal\"] dentro de header.site-header" do
    sign_in
    get progress_path

    assert_response :success
    assert_select "header.site-header nav[aria-label='Principal']", count: 1
  end

  # --- NAV-02: com sessão, as entradas são exatamente Catálogo, Minha pasta e Sair ---

  test "com sessão, a navegação principal tem exatamente Catálogo, Minha pasta e Sair" do
    sign_in
    get catalog_path

    nav = css_select("header.site-header nav[aria-label='Principal']").first
    assert nav, "não encontrou nav principal"

    # Verificar que tem exatamente as três entradas
    entries = css_select("header.site-header nav[aria-label='Principal'] a,
                          header.site-header nav[aria-label='Principal'] button")
    assert_equal 3, entries.size, "deveria ter exatamente 3 entradas na navegação"

    # Verificar os textos
    texts = entries.map(&:text)
    assert texts.include?("Catálogo"), "deve incluir 'Catálogo'"
    assert texts.include?("Minha pasta"), "deve incluir 'Minha pasta'"
    assert texts.include?("Sair"), "deve incluir 'Sair'"
  end

  test "Minha pasta aponta para /progress com sessão" do
    sign_in
    get catalog_path

    assert_select "header.site-header nav[aria-label='Principal'] a[href='#{progress_path}']",
                  text: "Minha pasta"
  end

  test "Sair é um form button com action session_path" do
    sign_in
    get catalog_path

    # button_to gera um form
    assert_select "header.site-header nav[aria-label='Principal'] form[action='#{session_path}']"
    assert_select "header.site-header nav[aria-label='Principal'] form[action='#{session_path}'] button",
                  text: "Sair"
  end

  # --- NAV-03: sem sessão, as entradas são exatamente Catálogo, Entrar e Criar conta ---

  test "sem sessão, a navegação principal tem exatamente Catálogo, Entrar e Criar conta" do
    get catalog_path

    nav = css_select("header.site-header nav[aria-label='Principal']").first
    assert nav, "não encontrou nav principal"

    # Verificar que tem exatamente as três entradas
    entries = css_select("header.site-header nav[aria-label='Principal'] a")
    assert_equal 3, entries.size, "deveria ter exatamente 3 links de navegação"

    # Verificar os textos
    texts = entries.map(&:text)
    assert texts.include?("Catálogo"), "deve incluir 'Catálogo'"
    assert texts.include?("Entrar"), "deve incluir 'Entrar'"
    assert texts.include?("Criar conta"), "deve incluir 'Criar conta'"
  end

  test "Entrar aponta para new_session_path sem sessão" do
    get catalog_path

    assert_select "header.site-header nav[aria-label='Principal'] a[href='#{new_session_path}']",
                  text: "Entrar"
  end

  test "Criar conta aponta para new_registration_path sem sessão" do
    get catalog_path

    assert_select "header.site-header nav[aria-label='Principal'] a[href='#{new_registration_path}']",
                  text: "Criar conta"
  end

  # --- NAV-04: aria-current="page" marca apenas a entrada aberta ---

  test "no catálogo, apenas Catálogo tem aria-current=\"page\"" do
    sign_in
    get catalog_path

    # Catálogo deve ter aria-current
    assert_select "header.site-header nav[aria-label='Principal'] a[href='#{catalog_path}'][aria-current='page']",
                  text: "Catálogo"

    # Minha pasta não deve ter
    minha_pasta_entry = css_select("header.site-header nav[aria-label='Principal'] a[href='#{progress_path}']").first
    assert minha_pasta_entry, "não encontrou entrada Minha pasta"
    assert_nil minha_pasta_entry["aria-current"],
               "Minha pasta não deve ter aria-current no catálogo"

    # Sair não deve ter (é button)
    sair_button = css_select("header.site-header nav[aria-label='Principal'] button").first
    assert sair_button, "não encontrou botão Sair"
    assert_nil sair_button["aria-current"], "Sair não deve ter aria-current"
  end

  test "no catálogo com filtro ativo, Catálogo continua com aria-current=\"page\"" do
    sign_in
    get catalog_path(colors: [ "Red" ], rarities: [ "SR" ])

    assert_response :success
    assert_select "header.site-header nav[aria-label='Principal'] a[aria-current='page']",
                  text: "Catálogo"
  end

  test "em Minha pasta, apenas Minha pasta tem aria-current=\"page\"" do
    sign_in
    get progress_path

    # Minha pasta deve ter aria-current
    assert_select "header.site-header nav[aria-label='Principal'] a[href='#{progress_path}'][aria-current='page']",
                  text: "Minha pasta"

    # Catálogo não deve ter
    catalog_entry = css_select("header.site-header nav[aria-label='Principal'] a[href='#{catalog_path}']").first
    assert catalog_entry, "não encontrou entrada Catálogo"
    assert_nil catalog_entry["aria-current"],
               "Catálogo não deve ter aria-current em /progress"

    # Sair não deve ter (é button)
    sair_button = css_select("header.site-header nav[aria-label='Principal'] button").first
    assert sair_button, "não encontrou botão Sair"
    assert_nil sair_button["aria-current"], "Sair não deve ter aria-current"
  end


  # --- NAV-07: não há entradas para baralho, preço ou cotação ---

  test "a navegação não contém entrada com texto \"baralho\"" do
    sign_in
    get catalog_path

    nav_text = css_select("header.site-header nav[aria-label='Principal']").first.text
    refute_match /baralho/i, nav_text, "não deve haver 'baralho' na navegação"
  end

  test "a navegação não contém entrada com texto \"deck\"" do
    sign_in
    get catalog_path

    nav_text = css_select("header.site-header nav[aria-label='Principal']").first.text
    refute_match /deck/i, nav_text, "não deve haver 'deck' na navegação"
  end

  test "a navegação não contém entrada com texto \"preço\"" do
    sign_in
    get catalog_path

    nav_text = css_select("header.site-header nav[aria-label='Principal']").first.text
    refute_match /preço/i, nav_text, "não deve haver 'preço' na navegação"
  end

  test "a navegação não contém entrada com texto \"price\"" do
    sign_in
    get catalog_path

    nav_text = css_select("header.site-header nav[aria-label='Principal']").first.text
    refute_match /price/i, nav_text, "não deve haver 'price' na navegação"
  end

  test "a navegação não contém entrada com texto \"cotação\"" do
    sign_in
    get catalog_path

    nav_text = css_select("header.site-header nav[aria-label='Principal']").first.text
    refute_match /cotação/i, nav_text, "não deve haver 'cotação' na navegação"
  end

  test "a navegação não contém href para baralho, preço ou cotação" do
    sign_in
    get catalog_path

    entries = css_select("header.site-header nav[aria-label='Principal'] a,
                          header.site-header nav[aria-label='Principal'] button")
    hrefs = entries.map { |e| e["href"] || "" }

    hrefs.each do |href|
      refute_match /baralho|deck|preço|price|cotação/i, href,
                    "nenhum href deve conter baralho, deck, preço, price ou cotação"
    end
  end
end
