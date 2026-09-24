require "test_helper"

# T7 — Controles de filtro de cor, tipo, raridade e set (NAV-08, NAV-09,
# NAV-10, NAV-11, NAV-14, NAV-26, NAV-27).
#
# O formulário de filtro ganha controles para color, card_type, rarity e set.
# Sem JavaScript: envio nativo. Filtros ativos sem controle (faixas, q, traits,
# attributes, sort, dir) vão como `hidden`. Dois ou mais sets vêm da URL com o
# `select` mostrando "Todos os sets".
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

  # --- NAV-08, NAV-09: Formulário com controles para cor, tipo, raridade e set ---

  test "a grade exibe um formulário de filtros com checkbox para cor, tipo, raridade e select de set" do
    get catalog_path

    assert_response :success

    # Formulário de filtro
    assert_select "form.catalog__filters[method=get][action=?]", catalog_path

    # Checkboxes de cor (Red, Green, Blue)
    assert_select "input[type=checkbox][name='colors[]'][value=Red]"
    assert_select "input[type=checkbox][name='colors[]'][value=Green]"
    assert_select "input[type=checkbox][name='colors[]'][value=Blue]"

    # Checkboxes de tipo (character, leader)
    assert_select "input[type=checkbox][name='card_types[]'][value=character]"
    assert_select "input[type=checkbox][name='card_types[]'][value=leader]"

    # Checkboxes de raridade (C, L, UC, SR)
    assert_select "input[type=checkbox][name='rarities[]'][value=C]"
    assert_select "input[type=checkbox][name='rarities[]'][value=L]"
    assert_select "input[type=checkbox][name='rarities[]'][value=UC]"
    assert_select "input[type=checkbox][name='rarities[]'][value=SR]"

    # Select de set com "Todos os sets"
    assert_select "select[name='sets[]']" do
      assert_select "option", text: "Todos os sets"
      assert_select "option[value=OP01]", text: "Romance Dawn"
      assert_select "option[value=OP02]", text: "Paramount War"
    end

    # Botão "Filtrar"
    assert_select "button[type=submit]", text: "Filtrar"
  end

  test "o formulário de filtros tem rótulos escritos para cada controle" do
    get catalog_path

    # Dentro do formulário, procura por labels associados aos inputs
    # (não apenas pelo value, mas pelo texto do rótulo)
    assert_select ".catalog__filter-group label", text: /Red|Green|Blue/
    assert_select ".catalog__filter-group label", text: /character|leader/
    assert_select ".catalog__filter-group label", text: /C|L|UC|SR/
  end

  # --- NAV-09: A URL gerada bate com a do query object ---

  # Simula o envio nativo: hidden + select selecionado + checkboxes marcados.
  def submit_filter_form(checked_values)
    form = Nokogiri::HTML(response.body).at_css("form.catalog__filters")
    assert form, "formulário de filtros ausente"

    checkboxes = form.css("input[type=checkbox]").select { |box| checked_values.include?(box["value"]) }
    assert_equal checked_values.size, checkboxes.size, "controle ausente para #{checked_values.inspect}"

    pairs = form.css("input[type=hidden]").map { |input| [ input["name"], input["value"] ] }
    form.css("select").each do |select|
      option = select.at_css("option[selected]") || select.at_css("option")
      pairs << [ select["name"], option["value"] ]
    end
    pairs += checkboxes.map { |box| [ box["name"], box["value"] ] }

    get "#{form["action"]}?#{URI.encode_www_form(pairs)}"
    css_select(".catalog__count").text.strip
  end

  test "o envio nativo do formulário com Red e SR dá a mesma contagem da URL digitada à mão" do
    get catalog_path
    from_form = submit_filter_form(%w[Red SR])

    get catalog_path(colors: [ "Red" ], rarities: [ "SR" ])
    assert_equal css_select(".catalog__count").text.strip, from_form
    assert_equal "1 carta", from_form
    assert_equal 1, CatalogQuery.new(colors: [ "Red" ], rarities: [ "SR" ]).call.total_count
  end

  test "o envio nativo do formulário com Green e C dá a mesma contagem da URL digitada à mão" do
    get catalog_path
    from_form = submit_filter_form(%w[Green C])

    get catalog_path(colors: [ "Green" ], rarities: [ "C" ])
    assert_equal css_select(".catalog__count").text.strip, from_form
    assert_equal "1 carta", from_form
    assert_equal 1, CatalogQuery.new(colors: [ "Green" ], rarities: [ "C" ]).call.total_count
  end

  test "marcar Green e C produz Nami" do
    get catalog_path(colors: [ "Green" ], rarities: [ "C" ])

    expected_count = 1
    assert_select ".catalog__count", text: /^1 carta$/

    query = CatalogQuery.new(colors: [ "Green" ], rarities: [ "C" ])
    assert_equal expected_count, query.call.total_count
  end

  test "marcar set OP01 produz apenas cartas daquele set" do
    get catalog_path(sets: [ "OP01" ])

    # OP01: Zoro, Nami
    expected_count = 2
    assert_select ".catalog__count", text: /^2 cartas$/

    query = CatalogQuery.new(sets: [ "OP01" ])
    assert_equal expected_count, query.call.total_count
  end

  test "marcar sets OP01 e OP02 produz todas as cartas" do
    get catalog_path(sets: [ "OP01", "OP02" ])

    expected_count = 5
    assert_select ".catalog__count", text: /^5 cartas$/

    query = CatalogQuery.new(sets: [ "OP01", "OP02" ])
    assert_equal expected_count, query.call.total_count
  end

  # --- NAV-10: Filtros ativos sem controle vão como hidden ---

  test "q ativo vem como hidden no formulário" do
    get catalog_path(q: "Zoro", colors: [ "Red" ])

    assert_select "input[type=hidden][name=q][value=Zoro]"
    assert_select "input[type=checkbox][name='colors[]'][value=Red][checked]"
  end

  test "faixa de custo vem como hidden no formulário" do
    get catalog_path(colors: [ "Red" ], cost_min: 3, cost_max: 5)

    assert_select "input[type=hidden][name=cost_min][value='3']"
    assert_select "input[type=hidden][name=cost_max][value='5']"
  end

  test "faixa de power vem como hidden no formulário" do
    get catalog_path(colors: [ "Red" ], power_min: 1000, power_max: 5000)

    assert_select "input[type=hidden][name=power_min][value='1000']"
    assert_select "input[type=hidden][name=power_max][value='5000']"
  end

  test "sort e dir vêm como hidden no formulário quando ativos" do
    get catalog_path(q: "Zoro", cost_min: 3, traits: [ "Straw Hat" ], sort: "name", dir: "desc")

    assert_select "input[type=hidden][name=sort][value=name]"
    assert_select "input[type=hidden][name=dir][value=desc]"
  end

  test "traits vêm como hidden no formulário" do
    get catalog_path(colors: [ "Red" ], traits: [ "Straw Hat", "Pirate" ])

    assert_select "input[type=hidden][name='traits[]'][value='Straw Hat']"
    assert_select "input[type=hidden][name='traits[]'][value=Pirate]"
  end

  test "attributes vêm como hidden no formulário" do
    get catalog_path(colors: [ "Red" ], attributes: [ "Attacker", "Slasher" ])

    assert_select "input[type=hidden][name='attributes[]'][value=Attacker]"
    assert_select "input[type=hidden][name='attributes[]'][value=Slasher]"
  end

  test "dois sets na URL vêm como hidden e o select mostra 'Todos os sets'" do
    get catalog_path(sets: [ "OP01", "OP02" ])

    # Hidden: os dois sets ativos
    assert_select "input[type=hidden][name='sets[]'][value=OP01]"
    assert_select "input[type=hidden][name='sets[]'][value=OP02]"

    # Select: mostra "Todos os sets" como selected
    assert_select "select[name='sets[]'] option", text: "Todos os sets" do
      # Verifica que a opção está selected
      assert_select "option[selected]", text: "Todos os sets"
    end
  end

  # --- NAV-11: Valor ativo aparece checked/selected ---

  test "checkbox marcado na URL aparece checked no formulário" do
    get catalog_path(colors: [ "Red" ], card_types: [ "leader" ])

    assert_select "input[type=checkbox][name='colors[]'][value=Red][checked]"
    assert_select "input[type=checkbox][name='card_types[]'][value=leader][checked]"
    assert_select "input[type=checkbox][name='card_types[]'][value=character]:not([checked])"
  end

  test "raridade ativa aparece checked no formulário" do
    get catalog_path(rarities: [ "L", "SR" ])

    assert_select "input[type=checkbox][name='rarities[]'][value=L][checked]"
    assert_select "input[type=checkbox][name='rarities[]'][value=SR][checked]"
    assert_select "input[type=checkbox][name='rarities[]'][value=C]:not([checked])"
  end

  test "set único ativo aparece selected no select" do
    get catalog_path(sets: [ "OP02" ])

    assert_select "select[name='sets[]'] option[value=OP02][selected]"
    assert_select "select[name='sets[]'] option[value=OP01]:not([selected])"
  end

  # --- NAV-26: Parâmetro desconhecido ou inválido é ignorado ---

  test "parâmetro desconhecido não marca controle e não gera erro" do
    get catalog_path(unknown_param: "value", colors: [ "Red" ])

    assert_response :success
    assert_select "input[type=checkbox][name='colors[]'][value=Red][checked]"
    # Nenhum erro na página
    assert_select ".catalog__count"
  end

  test "valor inválido de cor não oferece controle mas continua na URL como filtro" do
    get catalog_path(colors: [ "InvalidColor" ])

    assert_response :success
    # Nenhum checkbox marcado (porque "InvalidColor" não aparece em filter_options)
    assert_select "input[type=checkbox][name='colors[]'][value=InvalidColor]", count: 0
    # Filtro ativo mas sem resultado (como esperado por um filtro que não casa nada)
    assert_select ".catalog__count", text: /^0 cartas$/
  end

  test "valor inválido de raridade não oferece controle mas continua na URL" do
    get catalog_path(rarities: [ "InvalidRarity" ])

    assert_response :success
    assert_select "input[type=checkbox][name='rarities[]'][value=InvalidRarity]", count: 0
    # Filtro ativo mas sem resultado
    assert_select ".catalog__count", text: /^0 cartas$/
  end

  # --- NAV-27: Zero resultados, os controles continuam ---

  test "com zero resultados, os controles continuam renderizados com os valores ativos marcados" do
    get catalog_path(colors: [ "Red" ], rarities: [ "C" ])

    # Sem resultados
    assert_select ".catalog__empty"

    # Mas o formulário continua
    assert_select "form.catalog__filters"
    assert_select "input[type=checkbox][name='colors[]'][value=Red][checked]"
    assert_select "input[type=checkbox][name='rarities[]'][value=C][checked]"
  end

  test "raridade com espaço (SP CARD) tem ID sem espaço e label associada" do
    get catalog_path

    # O input tem ID sem espaço
    assert_select "input[type=checkbox][id='rarity-sp-card'][name='rarities[]'][value='SP CARD']"
    # O label aponta para o ID correspondente
    assert_select "label[for='rarity-sp-card']", text: "SP CARD"
  end

  # --- NAV-14: Sem JavaScript, envio nativo ---

  test "formulário não tem data-controller nem atributos de JS" do
    get catalog_path

    assert_select "form.catalog__filters[data-controller]", count: 0
    assert_select "form.catalog__filters[data-action]", count: 0
  end

  # --- Verificação de que as classes BEM estão presentes ---

  test "formulário de filtros usa classes BEM de catalog" do
    get catalog_path

    assert_select ".catalog__filters"
    assert_select ".catalog__filter-group"
  end
end
