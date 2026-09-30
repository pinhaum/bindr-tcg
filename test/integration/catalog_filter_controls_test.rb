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
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT,
      card: @zoro, set_id: @op01.id, variant_code: "OP01-001",
      rarity: "L", art_kind: "base", image_url: "https://example.test/OP01-001.png"
    )

    # Nami: Green, character, rarity C
    @nami = create_card(
      card_number: "OP01-002", name: "Nami",
      card_type: "character", colors: [ "Green" ], cost: 1, power: 1000
    )
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT,
      card: @nami, set_id: @op01.id, variant_code: "OP01-002",
      rarity: "C", art_kind: "base", image_url: "https://example.test/OP01-002.png"
    )

    # Law: Red + Blue, leader, rarity SR, em OP02
    @law = create_card(
      card_number: "OP02-001", name: "Trafalgar Law",
      card_type: "leader", colors: [ "Red", "Blue" ], cost: 4
    )
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT,
      card: @law, set_id: @op02.id, variant_code: "OP02-001",
      rarity: "SR", art_kind: "base", image_url: "https://example.test/OP02-001.png"
    )

    # Luffy: Red, leader, rarity UC (para ter uma rarity diferente de L, C, SR)
    @luffy = create_card(
      card_number: "OP02-002", name: "Monkey D. Luffy",
      card_type: "leader", colors: [ "Red" ], cost: 5
    )
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT,
      card: @luffy, set_id: @op02.id, variant_code: "OP02-002",
      rarity: "UC", art_kind: "base", image_url: "https://example.test/OP02-002.png"
    )

    # Robin: rarity SP CARD (com espaço) para testar ID sem espaço
    @robin = create_card(
      card_number: "OP02-003", name: "Nico Robin",
      card_type: "character", colors: [ "Purple" ], cost: 2
    )
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT,
      card: @robin, set_id: @op02.id, variant_code: "OP02-003",
      rarity: "SP CARD", art_kind: "base", image_url: "https://example.test/OP02-003.png"
    )
    mark_catalog_present!
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
    assert_select ".catalog__filters form" do
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
    from_chip = css_select(".catalog__count").text.squish

    get catalog_path(colors: [ "Red" ])
    from_manual = css_select(".catalog__count").text.squish

    assert_equal from_manual, from_chip
  end

  test "seguir dois chips produz mesma contagem que URL manual" do
    get catalog_path(colors: [ "Red" ])
    html = Nokogiri::HTML(response.body)
    # SR deve estar disponível pois temos cartas Red + SR
    sr_chip = html.at_css("a.catalog__chip[href*='rarities%5B%5D=SR']")
    assert sr_chip, "chip SR não encontrado"

    get sr_chip["href"]
    from_chips = css_select(".catalog__count").text.squish

    get catalog_path(colors: [ "Red" ], rarities: [ "SR" ])
    from_manual = css_select(".catalog__count").text.squish

    assert_equal from_manual, from_chips
    assert_equal "1 carta · 2 filtros ativos", from_chips
  end

  test "chip ativo tem aria-label descritivo e 'x' visível (NAV-34)" do
    get catalog_path(colors: [ "Red" ])

    assert_select "a.catalog__chip.catalog__chip--active[aria-label*='Remover filtro']"
    assert_select "a.catalog__chip.catalog__chip--active[aria-label*='Red']"
    # Chip de cor ativo deve ter span com "×" (mata M41)
    assert_select "a.catalog__chip--color.catalog__chip--active span[aria-hidden='true']", text: "×"
  end

  test "chip inativo não tem aria-label nem 'x'" do
    get catalog_path

    html = Nokogiri::HTML(response.body)
    green_chips = html.css("a.catalog__chip:not(.catalog__chip--active)[href*='Green']")
    green_chip = green_chips.first
    assert green_chip, "chip Green inativo não encontrado"
    assert !green_chip["aria-label"], "chip inativo não deve ter aria-label"

    # Chips inativos têm a swatch (span.catalog__chip-swatch) mas não o "×"
    # O "×" é renderizado apenas em chips ativos, dentro de um span[aria-hidden="true"]
    x_span = green_chip.css("span[aria-hidden='true']").find { |s| s.text.include?("×") }
    assert !x_span, "chip inativo não deve ter '×'"
  end

  test "set OP01 selected dá 2 cartas, set OP02 dá 3 cartas, ambos dão 5" do
    get catalog_path(sets: [ "OP01" ])
    assert_select ".catalog__count", text: /^2 cartas/

    get catalog_path(sets: [ "OP02" ])
    assert_select ".catalog__count", text: /^3 cartas/

    get catalog_path(sets: [ "OP01", "OP02" ])
    assert_select ".catalog__count", text: /^5 cartas/
  end

  test "set selecionado aparece como selected no select (NAV-11, mata M43)" do
    # Um set ativo: OP02 selected, OP01 não
    get catalog_path(sets: [ "OP02" ])

    assert_select "select[name='sets[]'] option[value=OP02][selected]"
    assert_select "select[name='sets[]'] option[value=OP01]:not([selected])"
  end

  # --- NAV-10: Filtros ativos sem controle vão como hidden ---

  test "q ativo vem como hidden no formulário de set" do
    get catalog_path(q: "Zoro", colors: [ "Red" ])

    assert_select ".catalog__filters form input[type=hidden][name=q][value=Zoro]"
    assert_select "a.catalog__chip.catalog__chip--active[aria-label='Remover filtro Cor: Red']"
    # Chip ativo remove o valor (alternância, NAV-33), não o contém
    assert_select "a.catalog__chip.catalog__chip--active[aria-label='Remover filtro Cor: Red']", 1 do |chip|
      refute chip.attr("href").include?("colors%5B%5D=Red")
    end
  end

  test "faixa de custo, power, counter vêm como hidden no formulário de set" do
    get catalog_path(colors: [ "Red" ], cost_min: 3, cost_max: 5, power_min: 1000, power_max: 5000, counter_min: 1, counter_max: 10)

    form = css_select(".catalog__filters form").first
    assert form.to_s.include?("name=\"cost_min\""), "cost_min não em hidden"
    assert form.to_s.include?("name=\"cost_max\""), "cost_max não em hidden"
    assert form.to_s.include?("name=\"power_min\""), "power_min não em hidden"
  end

  test "sort e dir vêm como hidden no formulário de set quando ativos" do
    get catalog_path(q: "Zoro", cost_min: 3, traits: [ "Straw Hat" ], sort: "name", dir: "desc")

    form = css_select(".catalog__filters form").first
    assert form.to_s.include?("name=\"sort\""), "sort não em hidden"
    assert form.to_s.include?("name=\"dir\""), "dir não em hidden"
  end

  test "traits e attributes vêm como hidden no formulário de set" do
    get catalog_path(colors: [ "Red" ], traits: [ "Straw Hat", "Pirate" ], attributes: [ "Attacker", "Slasher" ])

    form = css_select(".catalog__filters form").first
    assert form.to_s.include?("traits"), "traits não em hidden"
    assert form.to_s.include?("attributes"), "attributes não em hidden"
  end

  test "cores, tipos, raridades ativos vêm como hidden no formulário de set" do
    get catalog_path(colors: [ "Red", "Green" ], card_types: [ "leader" ], rarities: [ "SR" ])

    assert_select ".catalog__filters form input[type=hidden][name='colors[]'][value=Red]"
    assert_select ".catalog__filters form input[type=hidden][name='colors[]'][value=Green]"
    assert_select ".catalog__filters form input[type=hidden][name='card_types[]'][value=leader]"
    assert_select ".catalog__filters form input[type=hidden][name='rarities[]'][value=SR]"
  end

  test "dois sets na URL vêm como hidden e o select mostra 'Todos os sets'" do
    get catalog_path(sets: [ "OP01", "OP02" ])

    form = css_select(".catalog__filters form").first
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

  test "cor inválida não oferece chip (NAV-26)" do
    # Teste da robustez: passar um valor que não existe no banco.
    # O comportamento: nenhum chip oferece a cor inválida, e a busca retorna zero.
    get catalog_path(colors: [ "InvalidColor" ])

    assert_response :success
    # Nenhum chip de cor com aria-label menciona InvalidColor
    html = Nokogiri::HTML(response.body)
    invalid_color_chips = html.css("a.catalog__chip--color[aria-label*='InvalidColor']")
    assert invalid_color_chips.empty?, "nenhum chip deve marcar cor inválida"
    assert_select ".catalog__count", text: /^0 cartas/
  end

  test "raridade inválida não oferece chip (NAV-26)" do
    # Teste da robustez: valores desconhecidos não produzem erro.
    get catalog_path(rarities: [ "InvalidRarity" ])

    assert_response :success
    # Nenhum chip tem aria-label com "InvalidRarity"
    html = Nokogiri::HTML(response.body)
    invalid_rarity_chips = html.css("a.catalog__chip[aria-label*='InvalidRarity']")
    assert invalid_rarity_chips.empty?, "nenhum chip deve marcar raridade inválida"
    assert_select ".catalog__count", text: /^0 cartas/
  end

  # --- NAV-27: Zero resultados, os chips continuam renderizados ---

  test "com zero resultados, os chips continuam renderizados e os ativos marcados (NAV-27)" do
    get catalog_path(colors: [ "Red" ], rarities: [ "C" ])

    # Sem resultados
    assert_select ".catalog__empty"

    # Chips continuam visíveis e ativos: Red de cor e C de raridade
    assert_select "a.catalog__chip--color.catalog__chip--active[aria-label='Remover filtro Cor: Red']"
    assert_select "a.catalog__chip.catalog__chip--active[aria-label='Remover filtro Raridade: C']"
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

  # --- T16a: Chip de cor ativo com classe catalog__chip--color ---

  test "com colors[]=Red, o chip ativo de Red tem as classes catalog__chip--color e catalog__chip--active (T16a)" do
    get catalog_path(colors: [ "Red" ])

    # Chip de cor Red deve ter AMBAS as classes
    assert_select "a.catalog__chip--color.catalog__chip--active[aria-label='Remover filtro Cor: Red']", count: 1
  end

  test "chip ativo de raridade (rarities[]=SR) NÃO tem catalog__chip--color (T16a)" do
    get catalog_path(rarities: [ "SR" ])

    html = Nokogiri::HTML(response.body)
    # Procura pelo chip ativo de raridade
    rarity_chip = html.at_css("a.catalog__chip--active[aria-label='Remover filtro Raridade: SR']")
    assert rarity_chip, "Chip ativo de raridade não encontrado"

    # Verifica que NÃO tem a classe catalog__chip--color
    refute rarity_chip["class"].include?("catalog__chip--color"),
           "Chip de raridade não deve ter classe catalog__chip--color"
  end

  # --- T4 (conformidade) — CNF-11: tipo exibido com inicial maiúscula ---

  test "chips de tipo exibem inicial maiúscula, mas a URL continua minúscula (CNF-11)" do
    get catalog_path

    assert_select "a.catalog__chip", text: "Character"
    assert_select "a.catalog__chip", text: "Leader"
    assert_select "a.catalog__chip[href*='card_types%5B%5D=character']"
    assert_select "a.catalog__chip[href*='card_types%5B%5D=leader']"
  end

  test "seguir o chip Leader filtra pelo valor minúsculo da URL" do
    get catalog_path
    html = Nokogiri::HTML(response.body)
    leader_chip = html.at_css("a.catalog__chip[href*='card_types%5B%5D=leader']")
    assert leader_chip, "chip Leader não encontrado"

    get leader_chip["href"]
    assert_select ".catalog__count", text: /^3 cartas/
  end

  # --- T4 (conformidade) — CNF-31: chip "Todas" sem "×" quando não há posse ativa ---

  PASSWORD = "log-pose-77".freeze

  def sign_in
    user = User.create!(email: "filter-controls-t4@example.com", password: PASSWORD)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  test "sem owned ativo, o chip 'Todas' tem aria-current e nem '×' nem nome de remoção (CNF-31)" do
    sign_in
    get catalog_path

    html = Nokogiri::HTML(response.body)
    todas_chip = html.css("a.catalog__chip").find { |node| node.text.strip == "Todas" }
    assert todas_chip, "chip 'Todas' não encontrado"
    assert_equal "true", todas_chip["aria-current"]
    assert_nil todas_chip["aria-label"], "'Todas' sem filtro ativo não deve prometer remoção"
    refute todas_chip.text.include?("×"), "'Todas' sem filtro ativo não deve ter '×'"
  end

  test "com owned=missing ativo, 'Todas' volta a ser um link comum de alternância" do
    sign_in
    get catalog_path(owned: "missing")

    html = Nokogiri::HTML(response.body)
    todas_chip = html.css("a.catalog__chip").find { |node| node.text.strip == "Todas" }
    assert todas_chip, "chip 'Todas' não encontrado"
    assert_nil todas_chip["aria-current"]
    refute todas_chip["class"].include?("catalog__chip--active")
  end
end
