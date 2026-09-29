require "test_helper"
require_relative "../design/support/stylesheet"
require_relative "../design/catalog_grid_canvas_test"

# T17 — Linha de status do catálogo (NAV-36, NAV-27).
# T4 (conformidade) — CNF-05..CNF-09: frase única "N cartas" (+ "· M filtros
# ativos" com filtro), "Limpar filtros" de 44px e o convite anônimo único.
#
# Contagem de resultados numa linha de status. Com filtro ativo, mostra quantos
# filtros estão aplicados e oferece "Limpar filtros".
class CatalogStatusLineTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  def sign_in
    user = User.create!(email: "status-line-t4@example.com", password: PASSWORD)
    post session_path, params: { email: user.email, password: PASSWORD }
  end
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")

    @zoro = create_card(
      card_number: "OP01-001", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ], cost: 3, power: 5000
    )
    CardVariant.create!(
      card: @zoro, set_id: @op01.id, variant_code: "OP01-001",
      rarity: "L", art_kind: "base", image_url: "https://example.test/OP01-001.png"
    )

    @nami = create_card(
      card_number: "OP01-002", name: "Nami",
      card_type: "character", colors: [ "Green" ], cost: 1, power: 1000
    )
    CardVariant.create!(
      card: @nami, set_id: @op01.id, variant_code: "OP01-002",
      rarity: "C", art_kind: "base", image_url: "https://example.test/OP01-002.png"
    )

    @sanji = create_card(
      card_number: "OP01-003", name: "Sanji",
      card_type: "leader", colors: [ "Blue" ], cost: 2, power: 2000
    )
    CardVariant.create!(
      card: @sanji, set_id: @op01.id, variant_code: "OP01-003",
      rarity: "SR", art_kind: "base", image_url: "https://example.test/OP01-003.png"
    )
  end

  def create_card(**attrs)
    Card.create!(set_id: @op01.id, **attrs)
  end

  # --- NAV-36: Sem filtro, só o total ---

  test "sem filtro, exibe só 'N cartas'" do
    sign_in
    get catalog_path

    assert_response :success
    # Há um <p> com .catalog__count e texto "3 cartas" (sem sessão o convite
    # de login mora fora desse <p>, mas ainda assim a frase precisa ser exata)
    assert_select ".catalog__count", text: /^3 cartas$/

    # Não há linha de status com filtros ativos (quando não há filtro, não renderiza)
    # Mas a spec diz "Com filtro ativo, oferece". Sem filtro, não deve haver
    # "Limpar filtros" em nenhum lugar (exceto em estado vazio, se houver).
    refute response.body.include?("Limpar filtros")
  end

  # --- NAV-36: Com filtro ativo, exibe contagem e botão ---

  test "com um filtro ativo, exibe '1 filtro ativo' e 'Limpar filtros'" do
    get catalog_path(colors: [ "Red" ])

    assert_response :success

    # A linha de status deve dizer "1 filtro ativo"
    assert_select ".catalog__status", text: /1 filtro ativo/

    # E deve ter um link "Limpar filtros" apontando para o catálogo sem filtros
    assert_select ".catalog__status a[href*='/catalog']", text: "Limpar filtros" do |link|
      # O link não deve ter "colors" na URL
      refute link.attr("href").include?("colors")
    end
  end

  test "com dois filtros ativos (cores e raridade), exibe '2 filtros ativos'" do
    get catalog_path(colors: [ "Red" ], rarities: [ "L" ])

    assert_response :success

    # A linha de status deve dizer "2 filtros ativos"
    assert_select ".catalog__status", text: /2 filtros ativos/

    # Link "Limpar filtros" aponta para catálogo sem filtros
    assert_select ".catalog__status a[href*='/catalog']", text: "Limpar filtros"
  end

  test "com três filtros (cores, raridade, tipo), exibe '3 filtros ativos'" do
    get catalog_path(colors: [ "Red" ], rarities: [ "SR" ], card_types: [ "character" ])

    assert_response :success

    assert_select ".catalog__status", text: /3 filtros ativos/
  end

  # --- NAV-36: sort e dir não contam como filtro ---

  test "sort e dir não contam como filtro, só '1 filtro ativo' para cores" do
    get catalog_path(colors: [ "Red" ], sort: "name", dir: "desc")

    assert_response :success

    # Apenas cores conta; sort e dir não
    assert_select ".catalog__status", text: /1 filtro ativo/
  end

  test "page não conta como filtro, só cores" do
    get catalog_path(colors: [ "Green" ], page: 2)

    assert_response :success

    assert_select ".catalog__status", text: /1 filtro ativo/
  end

  # --- NAV-27: "Limpar filtros" preserva sort e dir ---

  test "'Limpar filtros' preserva sort e dir quando ativos" do
    get catalog_path(colors: [ "Red" ], sort: "name", dir: "desc")

    assert_response :success

    # Link deve conter sort=name e dir=desc, mas não colors
    link = css_select(".catalog__status a[href*='/catalog']").first
    href = link.attr("href")
    assert href.include?("sort=name"), "sort não preservado em 'Limpar filtros'"
    assert href.include?("dir=desc"), "dir não preservado em 'Limpar filtros'"
    refute href.include?("colors"), "colors não deve estar no link 'Limpar filtros'"
  end

  # --- NAV-36: Estado vazio com filtro ativo ---

  # Decisão da T17: com zero resultados a linha de status continua dizendo
  # quantos filtros estão ativos, e o "Limpar filtros" fica só no estado vazio,
  # que o catalog_grid_test já exige.
  #
  # Com sessão para isolar esta asserção do convite anônimo (CNF-07), que é um
  # `<a>` à parte dentro de `.catalog__status` e tem teste próprio abaixo.
  test "com zero resultados e filtro ativo, a linha diz o filtro e o vazio oferece limpar" do
    sign_in
    get catalog_path(colors: [ "Purple" ])

    assert_response :success
    assert_select ".catalog__status .catalog__filter-count", text: /1 filtro ativo/
    assert_select ".catalog__status a", count: 0
    assert_select ".catalog__empty a", text: "Limpar filtros", count: 1
  end

  # --- NAV-27: Alvo ≥ 24px para "Limpar filtros" ---

  test "'Limpar filtros' tem min-height e min-width ≥ 24px" do
    get catalog_path(colors: [ "Red" ])

    assert_response :success
    assert_select ".catalog__status a.catalog__clear-filters", text: "Limpar filtros"

    rule = Stylesheet.resolved("catalog__clear-filters")
    assert_operator Stylesheet.to_pixels(rule.fetch("min-height")), :>=, 24
    assert_operator Stylesheet.to_pixels(rule.fetch("min-width")), :>=, 24
  end

  test "com zero resultados, 'Limpar filtros' do vazio preserva sort e dir" do
    get catalog_path(colors: [ "Purple" ], sort: "name", dir: "desc")

    assert_response :success
    assert_select ".catalog__empty a", text: "Limpar filtros", count: 1

    href = css_select(".catalog__empty a").first.attr("href")
    assert_includes href, "sort=name"
    assert_includes href, "dir=desc"
    assert_not_includes href, "colors"
  end

  # --- NAV-36: a contagem é a de chips, e o total mora na mesma linha ---

  test "duas cores contam dois filtros, como dois chips" do
    get catalog_path(colors: [ "Red", "Green" ])

    assert_select ".catalog__status .catalog__filter-count", text: /^\s*·\s*2 filtros ativos\s*$/
  end

  test "o total de cartas fica dentro da linha de status, com ou sem filtro" do
    get catalog_path
    assert_select ".catalog__status .catalog__count", text: /^\s*3 cartas\s*$/

    get catalog_path(colors: [ "Red" ])
    assert_select ".catalog__status .catalog__count", text: /^\s*1 carta\s*·\s*1 filtro ativo\s*$/
    assert_select ".catalog__status .catalog__clear-filters", text: "Limpar filtros"
  end

  test "a linha de status não usa style inline" do
    get catalog_path(colors: [ "Red" ])

    assert_select ".catalog__status [style]", count: 0
  end

  test "com zero resultados, Limpar filtros aparece uma vez só" do
    get catalog_path(colors: [ "Red" ], rarities: [ "C" ])

    assert_select ".catalog__empty"
    assert_select "a", text: "Limpar filtros", count: 1
  end

  # --- CNF-41: "Limpar filtros" do estado vazio com altura mínima de 44px ---

  test "'Limpar filtros' no estado vazio resolve min-height ≥ 44px (CNF-41)" do
    get catalog_path(colors: [ "Purple" ])

    assert_response :success
    assert_select ".catalog__empty a.catalog__empty-reset", text: "Limpar filtros"

    rule = Stylesheet.resolved("catalog__empty-reset")
    assert_operator Stylesheet.to_pixels(rule.fetch("min-height")), :>=, 44
  end

  # --- NAV-36: Com paginação, contagem é o total, não o tamanho da página ---

  test "a contagem mostra o total de cartas, não o tamanho da página" do
    # Cria 35 cartas para ultrapassar uma página (padrão 30 por página)
    @op01.update(name: "Page Test")
    35.times do |i|
      create_card(
        card_number: "OP01-#{'%03d' % (i + 100)}", name: "Card #{i}",
        card_type: "character", colors: [ "Red" ], cost: 1, power: 1000
      )
    end

    # Primeira página tem 30 cartas, mas o total de "Red" é 35 + 1 (Zoro) = 36
    get catalog_path(colors: [ "Red" ])

    assert_response :success

    # A contagem deve dizer "36 cartas", não "30 cartas"
    assert_select ".catalog__count", text: /^\s*36 cartas\s*·\s*1 filtro ativo\s*$/
  end

  # --- CNF-05: contagem sem filtro (a frase inteira é só "N cartas") ---

  test "sem filtro, a frase de status é exatamente 'N cartas', sem '· filtros ativos'" do
    get catalog_path

    assert_select ".catalog__count", text: /^3 cartas$/
    assert_select ".catalog__filter-count", count: 0
  end

  # --- CNF-06: "Limpar filtros" ≥ 44px e preserva sort/dir ---

  test "'Limpar filtros' resolve min-height e borda ≥ 44px (CNF-06)" do
    get catalog_path(colors: [ "Red" ])

    rule = Stylesheet.resolved("catalog__clear-filters")
    assert_operator Stylesheet.to_pixels(rule.fetch("min-height")), :>=, 44
    assert rule.fetch("border").present?, "'Limpar filtros' precisa de borda"
  end

  # --- CNF-07: convite anônimo único, dentro da linha de status ---

  test "anônimo vê 'Entrar para registrar posse' exatamente uma vez, na linha de status" do
    get catalog_path

    assert_select "a", text: "Entrar para registrar posse", count: 1
    assert_select ".catalog__status a[href=?]", new_session_path,
      text: "Entrar para registrar posse", count: 1
  end

  test "com sessão, o convite de login não aparece" do
    sign_in
    get catalog_path

    assert_select "a", text: "Entrar para registrar posse", count: 0
  end

  # --- CNF-09: rótulo e placeholder da busca ---

  test "busca tem o rótulo e o placeholder do canvas" do
    get catalog_path

    assert_select "label[for=catalog-q]", text: "Buscar por nome ou card_number"
    assert_select "input#catalog-q[placeholder=?]", "OP01-024"
  end

  # --- CNF-08: busca e status na mesma linha em ≥1024px, recuo igual ao corpo ---

  test "em ≥1024px, o wrapper de busca+status vira flex row e a busca tem 480px (CNF-08)" do
    css = Stylesheet.content_without_comments
    wide = CatalogGridCanvasTest.wide_block(css)
    wide_rules = Stylesheet.rules(wide)

    rule = Stylesheet.resolved("catalog__head-row", wide_rules)
    assert_equal "flex", rule.fetch("display")

    search_rule = Stylesheet.resolved("catalog__search", wide_rules)
    assert_equal "30rem", search_rule.fetch("width"),
      "a busca deve ter 480px (30rem) em ≥1024px conforme CNF-08"
  end

  test "o recuo lateral de .catalog__head e .catalog__body é o mesmo, em ≥1024px (CNF-08)" do
    css = Stylesheet.content_without_comments
    wide = CatalogGridCanvasTest.wide_block(css)
    wide_rules = Stylesheet.rules(wide)
    tokens = Stylesheet.read_root_tokens

    head_rule = Stylesheet.resolved("catalog__head", wide_rules)
    body_rule = Stylesheet.resolved("catalog__body", wide_rules)

    # padding na forma "topo direita/esquerda baixo"
    head_padding = head_rule.fetch("padding", "")
    body_padding = body_rule.fetch("padding", "")

    # CSS padding: 4 valores = top right bottom left; 3 valores = top right+left bottom
    # Extrai esquerda e direita com parsing correto
    def extract_horizontal_padding(padding_str)
      parts = padding_str.split(/\s+/)
      case parts.length
      when 4
        { left: parts[3], right: parts[1] }
      when 3
        { left: parts[1], right: parts[1] }
      when 2
        { left: parts[1], right: parts[1] }
      else
        { left: parts[0], right: parts[0] }
      end
    end

    head_h = extract_horizontal_padding(head_padding)
    body_h = extract_horizontal_padding(body_padding)

    # Resolve para pixels
    head_left_px = Stylesheet.to_pixels(head_h[:left], tokens)
    head_right_px = Stylesheet.to_pixels(head_h[:right], tokens)
    body_left_px = Stylesheet.to_pixels(body_h[:left], tokens)
    body_right_px = Stylesheet.to_pixels(body_h[:right], tokens)

    assert_equal head_left_px, body_left_px,
                 "recuo esquerdo (left) deve ser igual entre .catalog__head e .catalog__body"
    assert_equal head_right_px, body_right_px,
                 "recuo direito (right) deve ser igual entre .catalog__head e .catalog__body"
  end

  # --- CNF-10: "Sua coleção" não aparece mais no catálogo ---

  test "'Sua coleção' não aparece no catálogo, com ou sem sessão" do
    sign_in
    get catalog_path
    refute response.body.include?("Sua coleção")
    assert_select "#catalog_owned_total", 0

    delete session_path
    get catalog_path
    refute response.body.include?("Sua coleção")
  end

  test "o incremento de posse não traz mais um Turbo Stream para catalog_owned_total" do
    user = User.create!(email: "status-line-cnf10@example.com", password: PASSWORD)
    set = CardSet.create!(code: "OPcnf10", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OPcnf10-001", name: "Nami",
      card_type: "character", colors: [ "Green" ], cost: 1, power: 1000)
    variant = CardVariant.create!(card: card, card_set: set, variant_code: "OPcnf10-001",
      rarity: "C", art_kind: "base")

    post session_path, params: { email: user.email, password: PASSWORD }
    post increment_collection_item_path(card_variant_id: variant.id),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[target=catalog_owned_total]", 0
  end
end
