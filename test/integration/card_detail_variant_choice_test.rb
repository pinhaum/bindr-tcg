require "test_helper"

# CNF-42 — escolher uma variante na lista troca a imagem principal, o selo, a
# legenda e a raridade/set do cabeçalho, sem JavaScript, pela URL `?variant=`.
class CardDetailVariantChoiceTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "zoro-cnf40@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    @promo_set = CardSet.create!(code: "P", name: "Promo", kind: "promo")
    @card = Card.create!(set_id: @set.id, card_number: "OP01-001", name: "Roronoa Zoro",
                         card_type: "character", colors: [ "Red" ], power: 5000)
    @base = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: @card, set_id: @set.id,
                                variant_code: "OP01-001", rarity: "R", art_kind: "base",
                                illustrator: "Eiichiro Oda",
                                image_url: "https://example.com/OP01-001.png")
    @alt = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: @card, set_id: @promo_set.id,
                               variant_code: "OP01-001_p1", rarity: "SEC", art_kind: "alternate_art",
                               illustrator: "Boichi",
                               image_url: "https://example.com/OP01-001_p1.png")

    other = Card.create!(set_id: @set.id, card_number: "OP01-002", name: "Nami",
                         card_type: "character", colors: [ "Blue" ], power: 1000)
    CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: other, set_id: @set.id,
                        variant_code: "OP01-002", rarity: "C", art_kind: "base",
                        image_url: "https://example.com/OP01-002.png")
    mark_catalog_present!
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def assert_hero(variant_code, rarity:, set_code:, illustrator:)
    assert_select ".card-detail__thumb img.card-detail__image[src=?][alt=?]",
                  card_image_path(variant_code), "Roronoa Zoro #{variant_code}"
    assert_select ".card-detail__media img.card-detail__image[src=?]", card_image_path(variant_code)
    assert_select ".card-detail__chips .card-detail__chip", text: rarity
    assert_select ".card-detail__set", text: /· #{set_code}\s*\z/
    assert_select ".card-detail__illustrator", text: "Ilustração: #{illustrator}"
    assert_select ".variant--current", count: 1
    assert_select "a.variant__art[aria-current=true]", count: 1 do |link|
      assert_equal card_path(@card.card_number, variant: variant_code), link.first["href"]
    end
  end

  test "sem escolha, a primeira variante listada fica em destaque e marcada na lista" do
    get card_path(@card.card_number)

    assert_response :success
    assert_hero "OP01-001", rarity: "R", set_code: "OP01", illustrator: "Eiichiro Oda"
  end

  test "com ?variant=, a variante escolhida assume a imagem principal e o cabeçalho" do
    get card_path(@card.card_number, variant: "OP01-001_p1")

    assert_response :success
    assert_hero "OP01-001_p1", rarity: "SEC", set_code: "P", illustrator: "Boichi"
    assert_select ".card-detail__chips .card-detail__chip", text: "R", count: 0
  end

  test "cada miniatura da lista é um link para a própria variante, com nome acessível, sem script novo" do
    get card_path(@card.card_number)
    scripts = response.body.scan(/<script\b/).size

    [ @base, @alt ].each do |variant|
      assert_select "a.variant__art[href=?][data-turbo-action=replace][aria-label=?]",
                    card_path(@card.card_number, variant: variant.variant_code),
                    "Mostrar #{variant.variant_code} na imagem principal"
    end

    get card_path(@card.card_number, variant: "OP01-001_p1")
    assert_equal scripts, response.body.scan(/<script\b/).size
  end

  test "variant desconhecido, de outra carta, vazio ou em array é ignorado e cai na primeira variante" do
    [ "nao-existe", "OP01-002", "", "../../etc/passwd", [ "OP01-001_p1" ] ].each do |value|
      get card_path(@card.card_number, variant: value)

      assert_response :success, "variant=#{value.inspect} não pode dar erro"
      assert_hero "OP01-001", rarity: "R", set_code: "OP01", illustrator: "Eiichiro Oda"
    end
  end

  test "o selo sobre a imagem principal acompanha a variante escolhida" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @alt, quantity: 3)

    get card_path(@card.card_number)
    assert_select ".card-detail__badge", count: 0

    get card_path(@card.card_number, variant: "OP01-001_p1")
    assert_select ".card-detail__thumb .card-detail__badge", text: "3"
    assert_select ".card-detail__expand .card-detail__badge", text: "3"
  end

  # SRC-17 — o cenário da troca de fonte: o código antigo (`OP01-003`) ficou
  # ausente e ordena **antes** do novo (`tcgplayer:…`), presente. Sem a
  # ordenação a favor da ausente, "primeira listada" e "primeira presente"
  # coincidiriam e o padrão não seria exercido.
  def create_switched_card(with_present: true)
    card = Card.create!(set_id: @set.id, card_number: "OP01-003", name: "Nami",
                        card_type: "character", colors: [ "Blue" ], power: 1000)
    absent = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT - 1.day, card: card, set_id: @set.id,
                                 variant_code: "OP01-003", rarity: "C", art_kind: "base",
                                 image_url: "https://example.com/OP01-003.png")
    present = if with_present
      CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: card, set_id: @set.id,
                          variant_code: "tcgplayer:999", rarity: "C", art_kind: "base",
                          image_url: "https://example.com/999.jpg")
    end
    [ card, absent, present ]
  end

  def assert_hero_code(variant_code)
    assert_select ".card-detail__media img.card-detail__image[src=?]", card_image_path(variant_code)
    assert_select "a.variant__art[aria-current=true][href$=?]", "variant=#{CGI.escape(variant_code)}"
  end

  test "sem escolha, a primeira variante presente fica em destaque, mesmo com uma ausente antes dela" do
    card, absent, = create_switched_card
    sign_in
    CollectionItem.create!(user: @user, card_variant: absent, quantity: 1)

    get card_path(card.card_number)

    assert_response :success
    assert_select "a.variant__art", count: 2
    assert_hero_code "tcgplayer:999"
    assert_select ".card-detail__status", count: 0
  end

  test "sem variante presente, a ausente que o usuário tem fica em destaque, rotulada fora da fonte" do
    card, absent, = create_switched_card(with_present: false)
    sign_in
    CollectionItem.create!(user: @user, card_variant: absent, quantity: 1)

    get card_path(card.card_number)

    assert_response :success
    assert_hero_code "OP01-003"
    assert_select ".card-detail__status", text: "Variante fora da fonte"
  end

  test "?variant= de uma ausente que o usuário tem a põe em destaque, rotulada fora da fonte" do
    card, absent, = create_switched_card
    sign_in
    CollectionItem.create!(user: @user, card_variant: absent, quantity: 1)

    get card_path(card.card_number, variant: "OP01-003")

    assert_response :success
    assert_hero_code "OP01-003"
    assert_select ".card-detail__status", text: "Variante fora da fonte"
  end

  # A escolha vale só entre as variantes que a página lista: `?variant=` não
  # pode revelar uma ausente a quem não tem item nela (SRC-16).
  test "?variant= de uma ausente que o visitante não tem é ignorado e não a revela" do
    card, = create_switched_card
    other = User.create!(email: "nami-cnf42@example.com", password: PASSWORD)

    [ nil, other ].each do |user|
      reset!
      sign_in(user) if user
      get card_path(card.card_number, variant: "OP01-003")

      assert_response :success
      assert_hero_code "tcgplayer:999"
      assert_select "a.variant__art", count: 1
      assert_not_includes response.body, card_image_path("OP01-003"), "a ausente vazou (#{user ? 'com' : 'sem'} sessão)"
    end
  end
end
