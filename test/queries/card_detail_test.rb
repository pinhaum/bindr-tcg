require "test_helper"

# T2 (api-fundacao) — `CardDetail`: as regras do detalhe da carta (API-23,
# API-24, API-25). A classe leva `Query` no nome porque `CardDetailTest` já é
# o teste de integração do detalhe.
class CardDetailQueryTest < ActiveSupport::TestCase
  RUN_AT = Time.utc(2026, 10, 1, 12)

  setup do
    ImportRun.create!(source: "apitcg", source_revision: "cd.json", status: "succeeded", started_at: RUN_AT)
    @user = User.create!(email: "detalhe@example.com", password: "senha-correta")
    @other = User.create!(email: "outro-detalhe@example.com", password: "senha-correta")
    @set = CardSet.create!(code: "CD01", name: "Detalhe", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "CD01-001", name: "Carta", card_type: "character",
                         colors: [ "Black" ])
    @present_a = variant(@card, "tcgplayer:cd-a", seen: true)
    @present_b = variant(@card, "tcgplayer:cd-b", seen: true)
    @absent = variant(@card, "tcgplayer:cd-c", seen: false)
  end

  def variant(card, code, seen:)
    CardVariant.create!(card: card, card_set: @set, variant_code: code, art_kind: "base",
                        last_seen_at: seen ? RUN_AT : RUN_AT - 1.day)
  end

  def detail(user: @user, number: "CD01-001", requested: nil)
    CardDetail.new(card_number: number, user: user, requested_variant: requested).call
  end

  test "lista as presentes ordenadas por variant_code e esconde a ausente não retida" do
    result = detail

    assert_equal @card, result.card
    assert_equal [ @present_a, @present_b ], result.variants
    assert_empty result.absent_variant_ids
  end

  test "ausente retida por coleção aparece e entra em absent_variant_ids" do
    CollectionItem.create!(user: @user, card_variant: @absent, quantity: 1)
    result = detail

    assert_equal [ @present_a, @present_b, @absent ], result.variants
    assert_equal Set.new([ @absent.id ]), result.absent_variant_ids
  end

  test "ausente retida por wishlist aparece" do
    WishlistItem.create!(user: @user, card_variant: @absent, target_quantity: 1)

    assert_includes detail.variants, @absent
  end

  test "ausente retida por coleção com quantidade zero ainda conta" do
    CollectionItem.create!(user: @user, card_variant: @absent, quantity: 0)

    assert_includes detail.variants, @absent
  end

  test "ausente retida por outro usuário e pelo anônimo não aparece" do
    CollectionItem.create!(user: @other, card_variant: @absent, quantity: 1)

    assert_equal [ @present_a, @present_b ], detail.variants
    assert_equal [ @present_a, @present_b ], detail(user: nil).variants
  end

  test "destaque: código válido da carta" do
    assert_equal @present_b, detail(requested: "tcgplayer:cd-b").featured_variant
  end

  test "destaque: código de outra carta cai na primeira presente" do
    other = Card.create!(card_set: @set, card_number: "CD01-002", name: "Outra", card_type: "character",
                         colors: [ "Red" ])
    variant(other, "tcgplayer:cd-z", seen: true)

    assert_equal @present_a, detail(requested: "tcgplayer:cd-z").featured_variant
  end

  test "destaque: lixo e nil caem na primeira presente" do
    assert_equal @present_a, detail(requested: "lixo").featured_variant
    assert_equal @present_a, detail(requested: nil).featured_variant
  end

  test "destaque: ausente não retida pedida cai no padrão" do
    assert_equal @present_a, detail(requested: "tcgplayer:cd-c").featured_variant
  end

  test "destaque: ausente retida pode ser pedida" do
    CollectionItem.create!(user: @user, card_variant: @absent, quantity: 1)

    assert_equal @absent, detail(requested: "tcgplayer:cd-c").featured_variant
  end

  test "destaque: quando só há ausente retida, ela é o padrão" do
    @present_a.update!(last_seen_at: RUN_AT - 1.day)
    @present_b.update!(last_seen_at: RUN_AT - 1.day)
    CollectionItem.create!(user: @user, card_variant: @absent, quantity: 1)

    result = detail

    assert_equal [ @absent ], result.variants
    assert_equal @absent, result.featured_variant
  end

  test "holdings cobre as variantes listadas" do
    CollectionItem.create!(user: @user, card_variant: @present_a, quantity: 2)
    WishlistItem.create!(user: @user, card_variant: @present_b, target_quantity: 3)
    holdings = detail.holdings

    assert_equal 2, holdings.owned_quantity(@present_a)
    assert_equal 3, holdings.wishlist_target(@present_b)
    assert_nil detail(user: nil).holdings.owned_quantity(@present_a)
  end

  test "carta inexistente levanta RecordNotFound" do
    assert_raises(ActiveRecord::RecordNotFound) { detail(number: "XX99-999") }
  end

  test "carta com todas as variantes ocultas levanta RecordNotFound" do
    @present_a.update!(last_seen_at: RUN_AT - 1.day)
    @present_b.update!(last_seen_at: RUN_AT - 1.day)
    @absent.update!(last_seen_at: RUN_AT - 1.day)

    assert_raises(ActiveRecord::RecordNotFound) { detail }
    assert_raises(ActiveRecord::RecordNotFound) { detail(user: nil) }
  end

  test "carta sem variante nenhuma não levanta" do
    bare = Card.create!(card_set: @set, card_number: "CD01-003", name: "Sem arte", card_type: "character",
                        colors: [ "Red" ])
    result = detail(number: bare.card_number)

    assert_empty result.variants
    assert_nil result.featured_variant
  end
end
