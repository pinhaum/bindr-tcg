require "test_helper"

# T1 (api-fundacao) — `VariantHoldings`: posse e meta por variante para um
# usuário (API-31, API-32).
class VariantHoldingsTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "posse@example.com", password: "senha-correta")
    @other = User.create!(email: "outro@example.com", password: "senha-correta")
    @set = CardSet.create!(code: "VH01", name: "Holdings", kind: "booster")
    card = Card.create!(card_set: @set, card_number: "VH01-001", name: "Carta", card_type: "character",
                        colors: [ "Black" ])
    @owned = CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:vh-1", art_kind: "base")
    @zero = CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:vh-2", art_kind: "parallel")
    @none = CardVariant.create!(card: card, card_set: @set, variant_code: "tcgplayer:vh-3", art_kind: "manga")
    @variants = [ @owned, @zero, @none ]
  end

  def holdings(user) = VariantHoldings.new(user, @variants)

  def count_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s.in?([ "SCHEMA", "TRANSACTION" ])

      queries << payload[:sql]
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "anônimo: nil nas duas leituras, hashes vazios e nenhuma consulta" do
    queries = count_queries do
      h = holdings(nil)
      assert_nil h.owned_quantity(@owned)
      assert_nil h.wishlist_target(@owned)
      assert_equal({}, h.owned_quantities)
      assert_equal({}, h.wishlist_targets)
    end

    assert_empty queries
  end

  test "logado com lista de variantes vazia: hashes vazios e nenhuma consulta" do
    queries = count_queries do
      h = VariantHoldings.new(@user, [])
      assert_equal({}, h.owned_quantities)
      assert_equal({}, h.wishlist_targets)
      assert_equal 0, h.owned_quantity(@owned)
      assert_nil h.wishlist_target(@owned)
    end

    assert_empty queries
  end

  test "autenticado sem item: posse 0 e meta nil" do
    h = holdings(@user)

    assert_equal 0, h.owned_quantity(@none)
    assert_nil h.wishlist_target(@none)
    assert_equal({}, h.owned_quantities)
    assert_equal({}, h.wishlist_targets)
  end

  test "com item: devolve a quantidade e a meta no formato id => valor" do
    CollectionItem.create!(user: @user, card_variant: @owned, quantity: 3)
    WishlistItem.create!(user: @user, card_variant: @none, target_quantity: 2)
    h = holdings(@user)

    assert_equal 3, h.owned_quantity(@owned)
    assert_equal 2, h.wishlist_target(@none)
    assert_equal({ @owned.id => 3 }, h.owned_quantities)
    assert_equal({ @none.id => 2 }, h.wishlist_targets)
  end

  test "quantidade zero registrada continua sendo 0, presente no hash" do
    CollectionItem.create!(user: @user, card_variant: @zero, quantity: 0)
    h = holdings(@user)

    assert_equal 0, h.owned_quantity(@zero)
    assert_equal({ @zero.id => 0 }, h.owned_quantities)
  end

  test "dois usuários: B não vê a posse nem a meta de A" do
    CollectionItem.create!(user: @user, card_variant: @owned, quantity: 4)
    WishlistItem.create!(user: @user, card_variant: @none, target_quantity: 1)
    h = holdings(@other)

    assert_equal 0, h.owned_quantity(@owned)
    assert_nil h.wishlist_target(@none)
    assert_equal({}, h.owned_quantities)
    assert_equal({}, h.wishlist_targets)
  end

  test "só considera as variantes recebidas" do
    other_card = Card.create!(card_set: @set, card_number: "VH01-002", name: "Outra", card_type: "character",
                              colors: [ "Red" ])
    outside = CardVariant.create!(card: other_card, card_set: @set, variant_code: "tcgplayer:vh-9", art_kind: "base")
    CollectionItem.create!(user: @user, card_variant: outside, quantity: 5)

    assert_equal({}, holdings(@user).owned_quantities)
  end

  test "uma consulta por hash, repetida a leitura não consulta de novo" do
    CollectionItem.create!(user: @user, card_variant: @owned, quantity: 1)
    WishlistItem.create!(user: @user, card_variant: @none, target_quantity: 1)
    h = holdings(@user)

    queries = count_queries do
      3.times do
        h.owned_quantities
        h.owned_quantity(@owned)
        h.wishlist_targets
        h.wishlist_target(@none)
      end
    end

    assert_equal 2, queries.size
    assert_equal 1, queries.count { |sql| sql.include?("collection_items") }
    assert_equal 1, queries.count { |sql| sql.include?("wishlist_items") }
  end
end
