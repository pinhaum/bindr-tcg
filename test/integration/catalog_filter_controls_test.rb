require "test_helper"

# T14 — Chips de cor, tipo e raridade (NAV-33, NAV-34, NAV-08, NAV-09,
# NAV-10, NAV-11, NAV-26, NAV-27).
#
# Cores, tipos e raridades são agora chips-link que alternam o filtro com um toque.
# Set continua num formulário GET com botão "Aplicar". Sem JavaScript: navegação nativa.
# Filtros ativos sem controle (faixas, q, traits, attributes, sort, dir) vão como `hidden`.
class CatalogFilterControlsTest < ActionDispatch::IntegrationTest
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @op02 = CardSet.create!(code: "OP02", name: "Paramount War", kind: "booster")

    # Zoro: Red, leader, rarity L
    @zoro = create_card(
      card_number: "OP01-001", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ], cost: 3, power: 5000
    )
    CardVariant.create!(
      card: @zoro, set_id: @op01.id, variant_code: "OP01-001",
      rarity: "L", art_kind: "base", image_url: "https://example.test/OP01-001.png"
    )

    # Nami: Green, character, rarity C
    @nami = create_card(
      card_number: "OP01-002", name: "Nami",
      card_type: "character", colors: [ "Green" ], cost: 1, power: 1000
    )
    CardVariant.create!(
      card: @nami, set_id: @op01.id, variant_code: "OP01-002",
      rarity: "C", art_kind: "base", image_url: "https://example.test/OP01-002.png"
    )

    # Law: Red + Blue, leader, rarity SR, em OP02
    @law = create_card(
      card_number: "OP02-001", name: "Trafalgar Law",
      card_type: "leader", colors: [ "Red", "Blue" ], cost: 4
    )
    CardVariant.create!(
      card: @law, set_id: @op02.id, variant_code: "OP02-001",
      rarity: "SR", art_kind: "base", image_url: "https://example.test/OP02-001.png"
    )

    # Luffy: Red, leader, rarity UC (para ter uma rarity diferente de L, C, SR)
    @luffy = create_card(
      card_number: "OP02-002", name: "Monkey D. Luffy",
      card_type: "leader", colors: [ "Red" ], cost: 5
    )
    CardVariant.create!(
      card: @luffy, set_id: @op02.id, variant_code: "OP02-002",
      rarity: "UC", art_kind: "base", image_url: "https://example.test/OP02-002.png"
    )

    # Robin: rarity SP CARD (com espaço) para testar ID sem espaço
    @robin = create_card(
      card_number: "OP02-003", name: "Nico Robin",
      card_type: "character", colors: [ "Purple" ], cost: 2
    )
    CardVariant.create!(
      card: @robin, set_id: @op02.id, variant_code: "OP02-003",
      rarity: "SP CARD", art_kind: "base", image_url: "https://example.test/OP02-003.png"
    )
  end

  def create_card(**attrs)
    Card.create!(set_id: @op01.id, **attrs)
  end

  # --- NAV-08, NAV-33, NAV-34: Chips-link de cor, tipo, raridade e set ---

  test "a grade exibe chips-link para cor, tipo, raridade e um select de set com botão Aplicar" do
    get catalog_path

    assert_response :success

    # Chips de cor existem com href URL-encoded ([] = %5B%5D, & = não precisa encod)
    assert_select "a.catalog__chip[href*='colors%5B%5D=Red']"
    assert_select "a.catalog__chip[href*='colors%5B%5D=Green']"
    assert_select "a.catalog__chip[href*='colors%5B%5D=Blue']"

    # Chips de tipo existem
    assert_select "a.catalog__chip[href*='card_types%5B%5D=character']"
    assert_select "a.catalog__chip[href*='card_types%5B%5D=leader']"

    # Chips de raridade existem
    assert_select "a.catalog__chip[href*='rarities%5B%5D=C']"
    assert_select "a.catalog__chip[href*='rarities%5B%5D=L']"
    assert_select "a.catalog__chip[href*='rarities%5B%5D=UC']"
    assert_select "a.catalog__chip[href*='rarities%5B%5D=SR']"

    # Select de set com "Todos os sets" e botão "Aplicar"
    assert_select "form.catalog__filters" do
      assert_select "select[name='sets[]']" do
        assert_select "option", text: "Todos os sets"
        assert_select "option[value=OP01]", text: "Romance Dawn"
        assert_select "option[value=OP02]", text: "Paramount War"
      end
      assert_select "button[type=submit]", text: "Aplicar"
    end
  end

  test "títulos dos grupos de filtro (h2) existem com o texto esperado" do
    get catalog_path

    assert_select ".catalog__filter-title", text: "Cor"
    assert_select ".catalog__filter-title", text: "Tipo"
    assert_select ".catalog__filter-title", text: "Raridade"
  end

  test "select de set tem label acessível e id correspondente" do
    get catalog_path

    assert_select "label[for=filter-sets]", text: "Set"
    assert_select "select#filter-sets[name='sets[]']"
  end

  # --- NAV-09: A URL do chip bate com o resultado do query object ---

  test "seguir o chip Red dá a mesma contagem que a URL manual com colors=Red" do
    get catalog_path
    html = Nokogiri::HTML(response.body)
    red_chip = html.at_css("a.catalog__chip[href*='colors%5B%5D=Red']")
    assert red_chip, "chip Red não encontrado"

    # Segue o link e compara contagem
    get red_chip["href"]
    from_chip = css_select(".catalog__count").text.strip

    get catalog_path(colors: [ "Red" ])
    from_manual = css_select(".catalog__count").text.strip

    assert_equal from_manual, from_chip
  end

  test "seguir dois chips produz mesma contagem que URL manual" do
    get catalog_path(colors: [ "Red" ])
    html = Nokogiri::HTML(response.body)
    # SR deve estar disponível pois temos cartas Red + SR
    sr_chip = html.at_css("a.catalog__chip[href*='rarities%5B%5D=SR']")
    assert sr_chip, "chip SR não encontrado"

    get sr_chip["href"]
    from_chips = css_select(".catalog__count").text.strip

    get catalog_path(colors: [ "Red" ], rarities: [ "SR" ])
    from_manual = css_select(".catalog__count").text.strip

    assert_equal from_manual, from_chips
    assert_equal "1 carta", from_chips
  end

  test "chip ativo tem aria-label descritivo e 'x' visível (NAV-34)" do
    get catalog_path(colors: [ "Red" ])

    assert_select "a.catalog__chip.catalog__chip--active[aria-label*='Remover filtro']"
    assert_select "a.catalog__chip.catalog__chip--active[aria-label*='Red']"
    assert_select "a.catalog__chip.catalog__chip--active span[aria-hidden='true']"
  end

  test "chip inativo não tem aria-label nem 'x'" do
    get catalog_path

    html = Nokogiri::HTML(response.body)
    green_chips = html.css("a.catalog__chip:not(.catalog__chip--active)[href*='Green']")
    green_chip = green_chips.first
    assert green_chip, "chip Green inativo não encontrado"
    assert !green_chip["aria-label"], "chip inativo não deve ter aria-label"
    assert !green_chip.at_css("span[aria-hidden]"), "chip inativo não deve ter 'x'"
  end

  test "set OP01 selected dá 2 cartas, set OP02 dá 3 cartas, ambos dão 5" do
    get catalog_path(sets: [ "OP01" ])
    assert_select ".catalog__count", text: /^2 cartas$/

    get catalog_path(sets: [ "OP02" ])
    assert_select ".catalog__count", text: /^3 cartas$/

    get catalog_path(sets: [ "OP01", "OP02" ])
    assert_select ".catalog__count", text: /^5 cartas$/
  end

  # --- NAV-10: Filtros ativos sem controle vão como hidden ---

  test "q ativo vem como hidden no formulário de set" do
    get catalog_path(q: "Zoro", colors: [ "Red" ])

    assert_select "form.catalog__filters input[type=hidden][name=q][value=Zoro]"
    assert_select "a.catalog__chip.catalog__chip--active[aria-label='Remover filtro Cor: Red']"
    # Chip ativo remove o valor (alternância, NAV-33), não o contém
    assert_select "a.catalog__chip.catalog__chip--active[aria-label='Remover filtro Cor: Red']", 1 do |chip|
      refute chip.attr("href").include?("colors%5B%5D=Red")
    end
  end

  test "faixa de custo, power, counter vêm como hidden no formulário de set" do
    get catalog_path(colors: [ "Red" ], cost_min: 3, cost_max: 5, power_min: 1000, power_max: 5000, counter_min: 1, counter_max: 10)

    form = css_select("form.catalog__filters").first
    assert form.to_s.include?("name=\"cost_min\""), "cost_min não em hidden"
    assert form.to_s.include?("name=\"cost_max\""), "cost_max não em hidden"
    assert form.to_s.include?("name=\"power_min\""), "power_min não em hidden"
  end

  test "sort e dir vêm como hidden no formulário de set quando ativos" do
    get catalog_path(q: "Zoro", cost_min: 3, traits: [ "Straw Hat" ], sort: "name", dir: "desc")

    form = css_select("form.catalog__filters").first
    assert form.to_s.include?("name=\"sort\""), "sort não em hidden"
    assert form.to_s.include?("name=\"dir\""), "dir não em hidden"
  end

  test "traits e attributes vêm como hidden no formulário de set" do
    get catalog_path(colors: [ "Red" ], traits: [ "Straw Hat", "Pirate" ], attributes: [ "Attacker", "Slasher" ])

    form = css_select("form.catalog__filters").first
    assert form.to_s.include?("traits"), "traits não em hidden"
    assert form.to_s.include?("attributes"), "attributes não em hidden"
  end

  test "cores, tipos, raridades ativos vêm como hidden no formulário de set" do
    get catalog_path(colors: [ "Red", "Green" ], card_types: [ "leader" ], rarities: [ "SR" ])

    assert_select "form.catalog__filters input[type=hidden][name='colors[]'][value=Red]"
    assert_select "form.catalog__filters input[type=hidden][name='colors[]'][value=Green]"
    assert_select "form.catalog__filters input[type=hidden][name='card_types[]'][value=leader]"
    assert_select "form.catalog__filters input[type=hidden][name='rarities[]'][value=SR]"
  end

  test "dois sets na URL vêm como hidden e o select mostra 'Todos os sets'" do
    get catalog_path(sets: [ "OP01", "OP02" ])

    form = css_select("form.catalog__filters").first
    form_text = form.to_s
    # Verifica hidden: dois sets
    assert form_text.scan(/name="sets\[\]".*value="OP01"/).any?, "OP01 não em hidden"
    assert form_text.scan(/name="sets\[\]".*value="OP02"/).any?, "OP02 não em hidden"

    # Select mostra "Todos os sets"
    assert_select "select[name='sets[]'] option[selected]", text: "Todos os sets"
  end

  # --- NAV-26: Parâmetro desconhecido ou inválido é ignorado ---

  test "parâmetro desconhecido não marca chip e não gera erro" do
    get catalog_path(unknown_param: "value", colors: [ "Red" ])

    assert_response :success
    assert_select "a.catalog__chip.catalog__chip--active[aria-label='Remover filtro Cor: Red']", count: 1
    # Chip ativo remove o valor (alternância, NAV-33), não o contém
    assert_select "a.catalog__chip.catalog__chip--active[aria-label='Remover filtro Cor: Red']", 1 do |chip|
      refute chip.attr("href").include?("colors%5B%5D=Red")
    end
    assert_select ".catalog__count"
  end

  test "valor inválido de cor não oferece chip (NAV-26)" do
    get catalog_path(colors: [ "InvalidColor" ])

    assert_response :success
    # Procura por chips com href contendo "InvalidColor%5B%5D"
    assert_select "a.catalog__chip[href*='InvalidColor%5B%5D']", count: 0
    assert_select ".catalog__count", text: /^0 cartas$/
  end

  test "valor inválido de raridade não oferece chip (NAV-26)" do
    get catalog_path(rarities: [ "InvalidRarity" ])

    assert_response :success
    # Procura por chips com href contendo "InvalidRarity%5B%5D"
    assert_select "a.catalog__chip[href*='InvalidRarity%5B%5D']", count: 0
    assert_select ".catalog__count", text: /^0 cartas$/
  end

  # --- NAV-27: Zero resultados, os chips continuam renderizados ---

  test "com zero resultados, os chips continuam renderizados e os ativos marcados (NAV-27)" do
    get catalog_path(colors: [ "Red" ], rarities: [ "C" ])

    # Sem resultados
    assert_select ".catalog__empty"

    # Chips continuam visíveis e ativos
    assert_select "a.catalog__chip.catalog__chip--active[href*='colors']"
    assert_select "a.catalog__chip.catalog__chip--active[href*='rarities%5B%5D=C']"
  end

  # --- NAV-14: Sem JavaScript, navegação nativa ---

  test "chips não têm data-controller nem atributos de JS" do
    get catalog_path

    assert_select "a.catalog__chip[data-controller]", count: 0
    assert_select "a.catalog__chip[data-action]", count: 0
  end

  test "forma do chip é um <a> href com classe catalog__chip" do
    get catalog_path

    html = Nokogiri::HTML(response.body)
    red_chip = html.at_css("a.catalog__chip[href*='colors%5B%5D=Red']")
    assert red_chip, "Red chip deve ser um <a>"
    assert red_chip["href"], "Red chip deve ter href"
    assert red_chip["href"].start_with?("/catalog"), "href deve apontar para catálogo"
  end

  # --- Verificação de que as classes BEM estão presentes ---

  test "grupos de filtro e chips usam classes BEM de catalog" do
    get catalog_path

    assert_select ".catalog__filter-group"
    assert_select ".catalog__filter-title"
    assert_select ".catalog__chips-group"
    assert_select ".catalog__chip"
  end

  test "sem sessão, chips de posse não aparecem" do
    get catalog_path

    # Procura por hrefs contendo "owned" para encontrar chips de posse
    html = Nokogiri::HTML(response.body)
    ownership_chips = html.css("a.catalog__chip[href*='owned']")
    assert ownership_chips.empty?, "não deve haver chips de posse sem sessão"
  end
end
