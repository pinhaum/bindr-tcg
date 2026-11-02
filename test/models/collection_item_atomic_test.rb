require "test_helper"

# SCAR-44 / SCAR-49: o SQL atômico de posse mora no model, para que o controller
# HTML e a API JSON compartilhem a mesma operação.
class CollectionItemAtomicTest < ActiveSupport::TestCase
  def create_user(email: "nami@example.com")
    User.create!(email: email, password: "senha-correta")
  end

  def create_variant(suffix: "a")
    set = CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: "OP01-#{suffix}",
      rarity: "L", art_kind: "base")
  end

  def quantity_of(user, variant)
    CollectionItem.for_user(user).where(card_variant: variant).pick(:quantity)
  end

  test "increment_for! sem registro cria com quantidade 1 e devolve 1" do
    user = create_user
    variant = create_variant

    assert_equal 1, CollectionItem.increment_for!(user, variant)
    assert_equal 1, quantity_of(user, variant)
  end

  test "increment_for! com 3 cópias devolve 4" do
    user = create_user
    variant = create_variant
    CollectionItem.create!(user: user, card_variant: variant, quantity: 3)

    assert_equal 4, CollectionItem.increment_for!(user, variant)
    assert_equal 4, quantity_of(user, variant)
  end

  test "decrement_for! com 2 cópias devolve 1" do
    user = create_user
    variant = create_variant
    CollectionItem.create!(user: user, card_variant: variant, quantity: 2)

    assert_equal 1, CollectionItem.decrement_for!(user, variant)
    assert_equal 1, quantity_of(user, variant)
  end

  test "decrement_for! com 0 cópias devolve nil e mantém o registro em zero" do
    user = create_user
    variant = create_variant
    CollectionItem.create!(user: user, card_variant: variant, quantity: 0)

    assert_nil CollectionItem.decrement_for!(user, variant)
    assert_equal 0, quantity_of(user, variant)
  end

  test "decrement_for! sem registro devolve nil e não cria registro" do
    user = create_user
    variant = create_variant

    assert_nil CollectionItem.decrement_for!(user, variant)
    assert_equal 0, CollectionItem.for_user(user).count
  end

  test "os métodos só tocam o registro do usuário e da variante passados" do
    user = create_user
    other = create_user(email: "luffy@example.com")
    variant = create_variant
    other_variant = create_variant(suffix: "b")
    CollectionItem.create!(user: other, card_variant: variant, quantity: 5)
    CollectionItem.create!(user: user, card_variant: other_variant, quantity: 7)

    CollectionItem.increment_for!(user, variant)
    CollectionItem.decrement_for!(user, variant)
    CollectionItem.decrement_for!(user, variant)

    assert_equal 5, quantity_of(other, variant)
    assert_equal 7, quantity_of(user, other_variant)
    assert_equal 0, quantity_of(user, variant)
  end
end
