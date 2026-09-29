require "test_helper"

# T3 (conformidade) — CNF-01, CNF-02, CNF-03, CNF-04: o tile da grade deixa de
# renderizar controle de posse ou convite e passa a mostrar só o selo com o
# total de cópias da carta, e a raridade ou "N impressões" ao lado do código.
class CatalogTileTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "conformidade-t3@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OPct3", name: "Romance Dawn", kind: "booster")
  end

  def create_card(number:, name:)
    Card.create!(card_set: @set, card_number: number, name: name,
      card_type: "character", colors: [ "Red" ], cost: 2, power: 3000)
  end

  def create_variant(card, code, rarity: "C")
    CardVariant.create!(card: card, card_set: @set, variant_code: code, rarity: rarity, art_kind: "base")
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def tile_for(card)
    css_select(".card-tile").find { |node| node.at_css(".card-tile__number").text.strip == card.card_number }
  end

  # --- CNF-01: nenhum controle de posse ou convite, com ou sem sessão ---

  test "com sessão, nenhum tile tem controle de posse ou convite" do
    card = create_card(number: "OP01-ct3a", name: "Sanji")
    create_variant(card, "OP01-ct3a")
    sign_in

    get catalog_path

    assert_response :success
    assert_select ".card-tile form", 0
    assert_select ".card-tile button", 0
    assert_select ".card-tile .ownership", 0
    assert_select ".card-tile", text: /Entrar para registrar posse/, count: 0
  end

  test "anônimo: nenhum tile tem controle de posse ou convite" do
    card = create_card(number: "OP01-ct3b", name: "Sanji")
    create_variant(card, "OP01-ct3b")

    get catalog_path

    assert_response :success
    assert_select ".card-tile form", 0
    assert_select ".card-tile button", 0
    assert_select ".card-tile a", text: "Entrar para registrar posse", count: 0
  end

  # --- CNF-02: selo com o total de cópias da carta, com sessão e posse ---

  test "com sessão, carta de três variantes com 2 + 1 + 0 cópias mostra o selo 3 cópias" do
    card = create_card(number: "OP01-ct3c", name: "Zoro")
    a, b, c = %w[OP01-ct3c OP01-ct3c_p1 OP01-ct3c_p2].map { |code| create_variant(card, code) }
    CollectionItem.create!(user: @user, card_variant: a, quantity: 2)
    CollectionItem.create!(user: @user, card_variant: b, quantity: 1)
    CollectionItem.create!(user: @user, card_variant: c, quantity: 0)
    sign_in

    get catalog_path

    tile = tile_for(card)
    badge = tile.at_css(".card-tile__badge")
    assert badge, "o tile de #{card.card_number} não trouxe o selo"
    assert_equal "3", badge.text.strip
    assert_equal "3 cópias", badge["aria-label"]
    assert_equal "img", badge["role"], "aria-label em span sem papel não vira nome acessível"
  end

  test "com uma cópia o nome acessível do selo está no singular" do
    card = create_card(number: "OP01-ct3d", name: "Nami")
    variant = create_variant(card, "OP01-ct3d")
    CollectionItem.create!(user: @user, card_variant: variant, quantity: 1)
    sign_in

    get catalog_path

    badge = tile_for(card).at_css(".card-tile__badge")
    assert badge
    assert_equal "1", badge.text.strip
    assert_equal "1 cópia", badge["aria-label"]
  end

  # --- CNF-03: sem selo para anônimo ou quantidade zero ---

  test "anônimo não vê selo, mesmo havendo posse de outro usuário" do
    card = create_card(number: "OP01-ct3e", name: "Robin")
    variant = create_variant(card, "OP01-ct3e")
    CollectionItem.create!(user: @user, card_variant: variant, quantity: 5)

    get catalog_path

    assert_select ".card-tile__badge", 0
  end

  test "usuário sem cópia não vê selo" do
    card = create_card(number: "OP01-ct3f", name: "Chopper")
    create_variant(card, "OP01-ct3f")
    sign_in

    get catalog_path

    tile = tile_for(card)
    assert_nil tile.at_css(".card-tile__badge")
  end

  test "quantidade zerada não mostra selo" do
    card = create_card(number: "OP01-ct3g", name: "Franky")
    variant = create_variant(card, "OP01-ct3g")
    CollectionItem.create!(user: @user, card_variant: variant, quantity: 0)
    sign_in

    get catalog_path

    tile = tile_for(card)
    assert_nil tile.at_css(".card-tile__badge")
  end

  # --- CNF-04: raridade de variante única, ou "N impressões" ---

  test "carta de uma variante mostra a raridade ao lado do código" do
    card = create_card(number: "OP01-ct3h", name: "Brook")
    create_variant(card, "OP01-ct3h", rarity: "SR")

    get catalog_path

    tile = tile_for(card)
    assert_equal "SR", tile.at_css(".card-tile__rarity").text.strip
  end

  test "carta de três variantes mostra N impressões no lugar da raridade" do
    card = create_card(number: "OP01-ct3i", name: "Jinbe")
    %w[OP01-ct3i OP01-ct3i_p1 OP01-ct3i_p2].each { |code| create_variant(card, code) }

    get catalog_path

    tile = tile_for(card)
    assert_equal "3 impressões", tile.at_css(".card-tile__rarity").text.strip
  end

  # T13 (conformidade) — Main:65-66: código e raridade (ou "N impressões") são
  # irmãos na mesma linha do tile.
  test "código e raridade estão na mesma linha do tile" do
    card = create_card(number: "OP01-ct13a", name: "Usopp")
    create_variant(card, "OP01-ct13a", rarity: "SR")

    get catalog_path

    line = tile_for(card).at_css(".card-tile__number-line")
    assert_equal [ "OP01-ct13a", "SR" ], line.css("span").map { |node| node.text.strip }
  end

  test "com mais de uma variante a linha traz o código e 'N impressões'" do
    card = create_card(number: "OP01-ct13b", name: "Brook")
    create_variant(card, "OP01-ct13b")
    create_variant(card, "OP01-ct13b_p1")
    create_variant(card, "OP01-ct13b_p2")

    get catalog_path

    line = tile_for(card).at_css(".card-tile__number-line")
    assert_equal [ "OP01-ct13b", "3 impressões" ], line.css("span").map { |node| node.text.strip }
  end
end
