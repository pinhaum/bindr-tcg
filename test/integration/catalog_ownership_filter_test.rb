require "test_helper"

# T15 — Chips de posse (NAV-12, NAV-13).
#
# Com sessão, aparecem três chips-link "Todas", "Tenho" e "Não tenho", exclusivos
# entre si. Seguir o chip produz a mesma contagem que a URL digitada à mão.
# Sem sessão, nada é renderizado.
class CatalogOwnershipFilterTest < ActionDispatch::IntegrationTest
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")

    # Zoro: possuído pelo usuário
    @zoro = Card.create!(
      card_number: "OP01-001", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ], cost: 3, power: 5000, set_id: @op01.id
    )
    @zoro_variant = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT,
      card: @zoro, set_id: @op01.id, variant_code: "OP01-001",
      rarity: "L", art_kind: "base", image_url: "https://example.test/OP01-001.png"
    )

    # Nami: não possuído pelo usuário
    @nami = Card.create!(
      card_number: "OP01-002", name: "Nami",
      card_type: "character", colors: [ "Green" ], cost: 1, power: 1000, set_id: @op01.id
    )
    @nami_variant = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT,
      card: @nami, set_id: @op01.id, variant_code: "OP01-002",
      rarity: "C", art_kind: "base", image_url: "https://example.test/OP01-002.png"
    )

    # Law: não possuído pelo usuário
    @law = Card.create!(
      card_number: "OP01-003", name: "Trafalgar Law",
      card_type: "leader", colors: [ "Blue" ], cost: 4, power: 0, set_id: @op01.id
    )
    @law_variant = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT,
      card: @law, set_id: @op01.id, variant_code: "OP01-003",
      rarity: "SR", art_kind: "base", image_url: "https://example.test/OP01-003.png"
    )

    # Usuário da sessão
    @user = User.create!(email: "zoro@example.com", password: "password")

    # Usuário sem nenhuma cópia (para isolamento)
    @other_user = User.create!(email: "law@example.com", password: "password")
    mark_catalog_present!
  end

  # --- NAV-12: Chips com sessão ---

  test "com sessão, aparecem três chips Todas/Tenho/Não tenho" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path

    assert_response :success

    # Procura dentro do fieldset de posse (que vem após o h2 "Posse")
    ownership_chips = css_select("div.catalog__filter-group:has(h2:contains('Posse')) a.catalog__chip")
    chip_texts = ownership_chips.map { |c| c.text.strip.delete("×").strip }

    assert_includes chip_texts, "Todas"
    assert_includes chip_texts, "Tenho"
    assert_includes chip_texts, "Não tenho"
  end

  test "sem parâmetro, o chip 'Todas' fica ativo" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path

    ownership_group = css_select("div.catalog__filter-group:has(h2:contains('Posse'))").first
    assert ownership_group, "fieldset de posse ausente"

    todas = ownership_group.at_css("a.catalog__chip.catalog__chip--active")
    assert todas, "chip Todas ativo ausente"
    assert_match /Todas/, todas.text

    tenho = ownership_group.at_css("a.catalog__chip:not(.catalog__chip--active)")
    assert tenho, "chip inativo ausente"
  end

  test "?owned=owned marca o chip 'Tenho' como ativo" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "owned")

    ownership_group = css_select("div.catalog__filter-group:has(h2:contains('Posse'))").first
    tenho_ativo = ownership_group.css("a.catalog__chip.catalog__chip--active").find { |c| c.text.include?("Tenho") }
    assert tenho_ativo, "chip Tenho ativo ausente"

    todas_inativo = ownership_group.css("a.catalog__chip:not(.catalog__chip--active)").find { |c| c.text.include?("Todas") }
    assert todas_inativo, "chip Todas inativo ausente"
  end

  test "?owned=missing marca o chip 'Não tenho' como ativo" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "missing")

    ownership_group = css_select("div.catalog__filter-group:has(h2:contains('Posse'))").first
    nao_tenho_ativo = ownership_group.css("a.catalog__chip.catalog__chip--active").find { |c| c.text.include?("Não tenho") }
    assert nao_tenho_ativo, "chip Não tenho ativo ausente"
  end

  test "?owned=bogus marca o chip 'Todas' como fallback" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "bogus")

    ownership_group = css_select("div.catalog__filter-group:has(h2:contains('Posse'))").first
    todas_ativo = ownership_group.css("a.catalog__chip.catalog__chip--active").find { |c| c.text.include?("Todas") }
    assert todas_ativo, "chip Todas ativo ausente (fallback para valor inválido)"
  end

  # --- NAV-13: Sem sessão, nenhum chip owned ---

  test "anônimo não vê nenhum chip owned, mesmo sem parâmetro" do
    get catalog_path

    ownership_chips = css_select("div.catalog__filter-group:has(h2:contains('Posse')) a.catalog__chip")
    assert_empty ownership_chips, "chips de posse aparecem sem sessão"
  end

  test "anônimo não vê nenhum chip owned, mesmo com ?owned=owned na URL" do
    get catalog_path(owned: "owned")

    ownership_chips = css_select("div.catalog__filter-group:has(h2:contains('Posse')) a.catalog__chip")
    assert_empty ownership_chips, "chips de posse aparecem sem sessão com parâmetro na URL"
  end

  # --- Clique no chip produz a mesma contagem que a URL digitada à mão ---

  test "seguir o chip 'Tenho' dá a mesma contagem de ?owned=owned digitado à mão" do
    # Coloca Zoro na coleção do usuário
    CollectionItem.create!(user: @user, card_variant: @zoro_variant, quantity: 1)

    post session_path, params: { email: "zoro@example.com", password: "password" }

    # Segue o chip
    get catalog_path
    link = css_select("a.catalog__chip").find { |a| a.text.strip == "Tenho" }
    assert link, "chip Tenho ausente"
    get link["href"]

    from_chip = css_select(".catalog__count").text.squish

    # Segue a URL digitada à mão
    get catalog_path(owned: "owned")
    from_url = css_select(".catalog__count").text.squish

    assert_equal from_url, from_chip
    assert_equal "1 carta · 1 filtro ativo", from_chip
  end

  test "seguir o chip 'Não tenho' dá a mesma contagem de ?owned=missing digitado à mão" do
    # Coloca Zoro na coleção do usuário
    CollectionItem.create!(user: @user, card_variant: @zoro_variant, quantity: 1)

    post session_path, params: { email: "zoro@example.com", password: "password" }

    # Segue o chip
    get catalog_path
    link = css_select("a.catalog__chip").find { |a| a.text.strip == "Não tenho" }
    assert link, "chip Não tenho ausente"
    get link["href"]

    from_chip = css_select(".catalog__count").text.squish

    # Segue a URL digitada à mão
    get catalog_path(owned: "missing")
    from_url = css_select(".catalog__count").text.squish

    assert_equal from_url, from_chip
    assert_equal "2 cartas · 1 filtro ativo", from_chip
  end

  # --- Isolamento: posse de outro usuário não entra ---

  test "a posse de outro usuário não entra no resultado de 'tenho'" do
    # Coloca Zoro na coleção de outro_user
    CollectionItem.create!(user: @other_user, card_variant: @zoro_variant, quantity: 1)

    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "owned")

    # Para @user, Zoro não está possuído (nenhuma cópia)
    assert_select ".catalog__count", text: /^0 cartas/
  end

  test "outro usuário possui a carta X; o usuário logado não. Em ?owned=missing, a carta X aparece" do
    # Coloca Zoro na coleção de outro_user
    CollectionItem.create!(user: @other_user, card_variant: @zoro_variant, quantity: 1)

    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "missing")

    # Para @user, Zoro está em "não tenho" porque a posse de outro_user não entra
    assert_select ".catalog__count", text: /^3 cartas/
    # E Zoro de fato está lá
    assert_select "li", /Roronoa Zoro/
  end
end
