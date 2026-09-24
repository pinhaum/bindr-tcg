require "test_helper"

# T8 — Controle de posse (NAV-12, NAV-13).
#
# Com sessão, o formulário de filtro ganha o controle de posse com "todas", "tenho"
# e "não tenho". Sem sessão, ele não é renderizado. Os três rádios produzem as mesmas
# cartas que a URL digitada à mão (Req. 7.6).
class CatalogOwnershipFilterTest < ActionDispatch::IntegrationTest
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")

    # Zoro: possuído pelo usuário
    @zoro = Card.create!(
      card_number: "OP01-001", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ], cost: 3, power: 5000, set_id: @op01.id
    )
    @zoro_variant = CardVariant.create!(
      card: @zoro, set_id: @op01.id, variant_code: "OP01-001",
      rarity: "L", art_kind: "base", image_url: "https://example.test/OP01-001.png"
    )

    # Nami: não possuído pelo usuário
    @nami = Card.create!(
      card_number: "OP01-002", name: "Nami",
      card_type: "character", colors: [ "Green" ], cost: 1, power: 1000, set_id: @op01.id
    )
    @nami_variant = CardVariant.create!(
      card: @nami, set_id: @op01.id, variant_code: "OP01-002",
      rarity: "C", art_kind: "base", image_url: "https://example.test/OP01-002.png"
    )

    # Law: não possuído pelo usuário
    @law = Card.create!(
      card_number: "OP01-003", name: "Trafalgar Law",
      card_type: "leader", colors: [ "Blue" ], cost: 4, power: 0, set_id: @op01.id
    )
    @law_variant = CardVariant.create!(
      card: @law, set_id: @op01.id, variant_code: "OP01-003",
      rarity: "SR", art_kind: "base", image_url: "https://example.test/OP01-003.png"
    )

    # Usuário da sessão
    @user = User.create!(email: "zoro@example.com", password: "password")

    # Usuário sem nenhuma cópia (para isolamento)
    @other_user = User.create!(email: "law@example.com", password: "password")
  end

  # --- NAV-12: Controles com sessão ---

  test "com sessão, os três rádios aparecem dentro de fieldset com legend" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path

    assert_response :success

    # Fieldset com legend
    assert_select "div.catalog__filter-group" do
      assert_select "fieldset" do
        assert_select "legend", text: "Posse"
      end
    end

    # Três rádios com nomes e valores corretos
    assert_select "input[type=radio][name=owned][value=all]"
    assert_select "input[type=radio][name=owned][value=owned]"
    assert_select "input[type=radio][name=owned][value=missing]"

    # Labels associados
    assert_select "label[for=owned-all]", text: "Todas"
    assert_select "label[for=owned-owned]", text: "Tenho"
    assert_select "label[for=owned-missing]", text: "Não tenho"
  end

  test "sem parâmetro, o rádio 'todas' fica checked" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path

    assert_select "input[type=radio][name=owned][value=all][checked]"
    assert_select "input[type=radio][name=owned][value=owned]:not([checked])"
    assert_select "input[type=radio][name=owned][value=missing]:not([checked])"
  end

  test "?owned=owned marca o rádio 'tenho'" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "owned")

    assert_select "input[type=radio][name=owned][value=owned][checked]"
    assert_select "input[type=radio][name=owned][value=all]:not([checked])"
    assert_select "input[type=radio][name=owned][value=missing]:not([checked])"
  end

  test "?owned=missing marca o rádio 'não tenho'" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "missing")

    assert_select "input[type=radio][name=owned][value=missing][checked]"
    assert_select "input[type=radio][name=owned][value=all]:not([checked])"
    assert_select "input[type=radio][name=owned][value=owned]:not([checked])"
  end

  test "?owned=bogus marca o rádio 'todas' como fallback" do
    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "bogus")

    assert_select "input[type=radio][name=owned][value=all][checked]"
    assert_select "input[type=radio][name=owned][value=owned]:not([checked])"
    assert_select "input[type=radio][name=owned][value=missing]:not([checked])"
  end

  # --- NAV-13: Sem sessão, nenhum campo owned ---

  test "anônimo não vê nenhum rádio owned, mesmo sem parâmetro" do
    get catalog_path

    assert_select "input[name=owned]", count: 0
  end

  test "anônimo não vê nenhum rádio owned, mesmo com ?owned=owned na URL" do
    get catalog_path(owned: "owned")

    assert_select "input[name=owned]", count: 0
  end

  # --- NAV-12 (continuação): Envio real do formulário ---

  test "envio do formulário com 'tenho' dá a mesma contagem de ?owned=owned digitado à mão" do
    # Coloca Zoro na coleção do usuário
    CollectionItem.create!(user: @user, card_variant: @zoro_variant, quantity: 1)

    post session_path, params: { email: "zoro@example.com", password: "password" }

    # Envia via formulário
    get catalog_path
    from_form = submit_filter_form("owned")

    # Envia via URL digitada à mão
    get catalog_path(owned: "owned")
    from_url = css_select(".catalog__count").text.strip

    assert_equal from_url, from_form
    assert_equal "1 carta", from_form
  end

  test "envio do formulário com 'não tenho' dá a mesma contagem de ?owned=missing digitado à mão" do
    # Coloca Zoro na coleção do usuário
    CollectionItem.create!(user: @user, card_variant: @zoro_variant, quantity: 1)

    post session_path, params: { email: "zoro@example.com", password: "password" }

    # Envia via formulário
    get catalog_path
    from_form = submit_filter_form("missing")

    # Envia via URL digitada à mão
    get catalog_path(owned: "missing")
    from_url = css_select(".catalog__count").text.strip

    assert_equal from_url, from_form
    assert_equal "2 cartas", from_form
  end

  # --- Isolamento: posse de outro usuário não entra ---

  test "a posse de outro usuário não entra no resultado de 'tenho'" do
    # Coloca Zoro na coleção de outro_user
    CollectionItem.create!(user: @other_user, card_variant: @zoro_variant, quantity: 1)

    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "owned")

    # Para @user, Zoro não está possuído (nenhuma cópia)
    assert_select ".catalog__count", text: /^0 cartas$/
  end

  test "outro usuário possui a carta X; o usuário logado não. Em ?owned=missing, a carta X aparece" do
    # Coloca Zoro na coleção de outro_user
    CollectionItem.create!(user: @other_user, card_variant: @zoro_variant, quantity: 1)

    post session_path, params: { email: "zoro@example.com", password: "password" }
    get catalog_path(owned: "missing")

    # Para @user, Zoro está em "não tenho" porque a posse de outro_user não entra
    assert_select ".catalog__count", text: /^3 cartas$/
    # E Zoro de fato está lá
    assert_select "li", /Roronoa Zoro/
  end

  private

  # Simula o envio nativo do formulário pelo navegador.
  def submit_filter_form(owned_value)
    form = Nokogiri::HTML(response.body).at_css("form.catalog__filters")
    assert form, "formulário de filtros ausente"

    radio = form.css("input[type=radio]").find { |r| r["value"] == owned_value }
    assert radio, "rádio #{owned_value} ausente"

    pairs = form.css("input[type=hidden]").map { |input| [ input["name"], input["value"] ] }
    form.css("select").each do |select|
      option = select.at_css("option[selected]") || select.at_css("option")
      pairs << [ select["name"], option["value"] ]
    end
    pairs << [ radio["name"], radio["value"] ]

    get "#{form["action"]}?#{URI.encode_www_form(pairs)}"
    css_select(".catalog__count").text.strip
  end
end
