require "test_helper"

# T2 entrega a sessão persistida. O teste que importa aqui é o da **assimetria**
# entre as duas associações do `User`: sessão é derivada e some com o usuário;
# item de coleção é insubstituível e impede que o usuário seja apagado
# (design.md §5.2). Um `dependent:` trocado por descuido destruiria dado do
# usuário em silêncio, e é exatamente isso que estas asserções barram.
class SessionTest < ActiveSupport::TestCase
  def connection
    ActiveRecord::Base.connection
  end

  def create_user(email: "franky@example.com")
    User.create!(email: email, password: "senha-correta")
  end

  def create_variant
    set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-001", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: "OP01-001",
      rarity: "L", art_kind: "base")
  end

  # Done when: `Session belongs_to :user`.
  test "sessão pertence a um usuário" do
    user = create_user
    session = Session.create!(user: user, ip_address: "203.0.113.10", user_agent: "rails-test")

    assert_equal user, session.reload.user
  end

  # Done when: `User has_many :sessions, dependent: :destroy`.
  test "apagar usuário apaga suas sessões" do
    user = create_user(email: "robin@example.com")
    Session.create!(user: user, ip_address: "203.0.113.11", user_agent: "rails-test")
    Session.create!(user: user, ip_address: "203.0.113.12", user_agent: "rails-test")

    assert_difference -> { Session.count }, -2 do
      user.destroy
    end
    assert_not User.exists?(user.id)
  end

  # Done when: apagar um usuário **não** apaga seus `collection_items` — a FK é
  # `restrict`. Req. 1.7: a coleção é o dado insubstituível do produto.
  test "apagar usuário com coleção é recusado e não apaga nem sessão nem item" do
    user = create_user(email: "jinbe@example.com")
    Session.create!(user: user, ip_address: "203.0.113.13", user_agent: "rails-test")
    CollectionItem.create!(user: user, card_variant: create_variant, quantity: 3)

    assert_raises(ActiveRecord::DeleteRestrictionError) { user.destroy }

    # A recusa tem de ser total: um `destroy` abortado no meio que já tivesse
    # apagado as sessões deixaria o usuário num estado pela metade.
    assert User.exists?(user.id)
    assert_equal 1, user.sessions.count
    assert_equal 3, user.collection_items.sole.quantity
  end

  # A garantia é do banco, não do Active Record: a FK de `sessions` é
  # `on_delete: :cascade`, então mesmo um DELETE direto leva a sessão junto.
  test "FK de sessions é cascade no banco" do
    user = create_user(email: "brook2@example.com")
    Session.create!(user: user, ip_address: "203.0.113.14", user_agent: "rails-test")

    connection.uncached do
      connection.execute("DELETE FROM users WHERE id = #{user.id}")
    end

    assert_equal 0, Session.where(user_id: user.id).count
  end

  # Contraprova da anterior, no mesmo nível: a FK de `collection_items` é
  # `restrict`, então o DELETE direto é barrado pelo banco.
  test "FK de collection_items é restrict no banco" do
    user = create_user(email: "chopper2@example.com")
    CollectionItem.create!(user: user, card_variant: create_variant, quantity: 1)

    assert_raises(ActiveRecord::InvalidForeignKey) do
      connection.uncached do
        connection.execute("DELETE FROM users WHERE id = #{user.id}")
      end
    end
  end
end
