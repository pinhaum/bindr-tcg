require "test_helper"

# T3 (fonte-apitcg) — SRC-16, SRC-17 e SRC-18 na página de detalhe e no tile.
#
# A variante ausente da fonte (não vista pelo último run `succeeded`) some do
# catálogo, mas continua sendo dado do usuário: quem a tem na coleção ou na
# wishlist a vê no detalhe, rotulada "fora da fonte", com a quantidade intacta.
# Para os demais, ela não existe.
class CardDetailAbsentVariantTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  OLD_RUN_AT = Time.utc(2026, 9, 1, 12)
  NEW_RUN_AT = Time.utc(2026, 9, 29, 12)

  setup do
    ImportRun.create!(source: "optcgjson", source_revision: "antiga", status: "succeeded", started_at: OLD_RUN_AT)
    ImportRun.create!(source: "apitcg", source_revision: "apitcg-nova.json", status: "succeeded",
                      started_at: NEW_RUN_AT)

    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @user = User.create!(email: "dono-fonte@example.com", password: PASSWORD)
    @outro = User.create!(email: "outro-fonte@example.com", password: PASSWORD)

    @zoro = Card.create!(set_id: @set.id, card_number: "OP01-001", name: "Roronoa Zoro",
                         card_type: "leader", colors: [ "Red" ])
    # `OP01-001_p1` ordena antes de `tcgplayer:…`: se a ausente entrasse no
    # tile, seria a primeira variante dele.
    @ausente = variant(@zoro, "OP01-001_p1", seen: OLD_RUN_AT, rarity: "SEC")
    @presente = variant(@zoro, "tcgplayer:101", seen: NEW_RUN_AT, rarity: "L")

    # Carta que só tem variante ausente: o catálogo não a lista mais.
    @nami = Card.create!(set_id: @set.id, card_number: "OP01-016", name: "Nami",
                         card_type: "character", colors: [ "Blue" ])
    @nami_ausente = variant(@nami, "OP01-016", seen: OLD_RUN_AT, rarity: "R")
  end

  def variant(card, code, seen:, rarity:)
    CardVariant.create!(card: card, set_id: @set.id, variant_code: code, rarity: rarity, art_kind: "base",
                        image_url: "https://example.test/#{code}.png", last_seen_at: seen)
  end

  def sign_in(user = @user) = post(session_path, params: { email: user.email, password: PASSWORD })

  def variant_codes = css_select(".variant__code").map { |node| node.text.strip }

  def variant_item(code)
    css_select(".variant").find { |node| node.at_css(".variant__code")&.text&.strip == code }
  end

  # --- Done when 1 e 2: a ausente não aparece para quem não a tem ---

  test "sem sessão, a variante ausente não aparece no detalhe" do
    get card_path(@zoro.card_number)

    assert_response :success
    assert_equal [ "tcgplayer:101" ], variant_codes
    assert_select ".variant", text: /fora da fonte/, count: 0
  end

  test "com sessão e sem item na ausente, ela não aparece no detalhe" do
    CollectionItem.create!(user: @outro, card_variant: @ausente, quantity: 3)
    sign_in

    get card_path(@zoro.card_number)

    assert_equal [ "tcgplayer:101" ], variant_codes
  end

  # --- Done when 3: o dono vê a ausente, rotulada, com a quantidade intacta ---

  test "com item de coleção na ausente, ela aparece rotulada 'fora da fonte' e com a quantidade" do
    CollectionItem.create!(user: @user, card_variant: @ausente, quantity: 3)
    sign_in

    get card_path(@zoro.card_number)

    assert_equal [ "OP01-001_p1", "tcgplayer:101" ], variant_codes
    ausente = variant_item("OP01-001_p1")
    assert_includes ausente.text, "fora da fonte"
    assert_equal "3", ausente.at_css(".ownership__count").text.strip
    assert_not_includes variant_item("tcgplayer:101").text, "fora da fonte"
    assert_equal 3, CollectionItem.find_by!(user: @user, card_variant: @ausente).quantity
  end

  test "com item de wishlist na ausente, ela aparece rotulada 'fora da fonte'" do
    WishlistItem.create!(user: @user, card_variant: @ausente, target_quantity: 2)
    sign_in

    get card_path(@zoro.card_number)

    assert_equal [ "OP01-001_p1", "tcgplayer:101" ], variant_codes
    assert_includes variant_item("OP01-001_p1").text, "fora da fonte"
    assert_equal 2, WishlistItem.find_by!(user: @user, card_variant: @ausente).target_quantity
  end

  # --- Done when 4: carta só com ausentes, por URL direta ---

  test "carta só com variantes ausentes responde 200 para o dono do item" do
    CollectionItem.create!(user: @user, card_variant: @nami_ausente, quantity: 1)
    sign_in

    get card_path(@nami.card_number)

    assert_response :success
    assert_equal [ "OP01-016" ], variant_codes
    assert_includes variant_item("OP01-016").text, "fora da fonte"
  end

  test "carta só com variantes ausentes responde 404 para quem não tem item" do
    CollectionItem.create!(user: @outro, card_variant: @nami_ausente, quantity: 1)
    sign_in

    get card_path(@nami.card_number)

    assert_response :not_found
  end

  test "carta só com variantes ausentes responde 404 sem sessão" do
    get card_path(@nami.card_number)

    assert_response :not_found
  end

  test "o catálogo não lista a carta só com variantes ausentes, nem para o dono" do
    CollectionItem.create!(user: @user, card_variant: @nami_ausente, quantity: 1)
    sign_in

    get catalog_path

    assert_select ".card-tile a[href=?]", card_path(@nami.card_number), count: 0
  end

  # --- Done when 5: o tile usa a primeira variante presente ---

  test "o tile da grade usa a primeira variante presente" do
    get catalog_path

    assert_select ".card-tile img[src=?]", card_image_path("tcgplayer:101")
    assert_select "img[src=?]", card_image_path("OP01-001_p1"), count: 0
  end
end
