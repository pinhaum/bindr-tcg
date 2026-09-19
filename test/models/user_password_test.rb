require "test_helper"

# T1 entrega a senha do usuário. As asserções aqui separam duas coisas que é
# fácil confundir: o que o Active Model garante (digest, verificação) e o que
# o banco garante (unicidade do e-mail sem distinção de caixa). A segunda é
# testada por SQL direto, no padrão de `catalog_schema_test.rb`, porque uma
# validação de Rails não segura um `INSERT` direto.
class UserPasswordTest < ActiveSupport::TestCase
  def connection
    ActiveRecord::Base.connection
  end

  # `select_value` passa pelo cache de consulta do Active Record; repetir o
  # mesmo INSERT literal devolveria o resultado memoizado sem ir ao banco.
  def insert_user(email:, digest: "x")
    connection.uncached do
      connection.select_value(<<~SQL)
        INSERT INTO users (email, password_digest, created_at, updated_at)
        VALUES (#{connection.quote(email)}, #{connection.quote(digest)}, now(), now())
        RETURNING id
      SQL
    end
  end

  def create_user(email: "ace@example.com", password: "senha-correta")
    User.create!(email: email, password: password)
  end

  # Done when: `User` responde a `password=` e grava `password_digest`.
  # Req. 6.2 — a senha nunca é persistida em claro.
  test "password= grava um digest bcrypt e nenhuma coluna guarda a senha em claro" do
    senha = "senha-correta"
    user = create_user(password: senha)

    assert_not_nil user.password_digest
    assert_not_equal senha, user.password_digest
    assert BCrypt::Password.valid_hash?(user.password_digest),
      "password_digest deveria ser um hash bcrypt válido"

    # Varre a linha inteira no banco, não só o atributo: uma coluna nova que
    # viesse a espelhar a senha seria pega aqui.
    row = connection.uncached do
      connection.select_one("SELECT * FROM users WHERE id = #{user.id}")
    end
    row.each_value do |value|
      assert_not_equal senha, value.to_s,
        "nenhuma coluna de `users` pode conter a senha em claro"
    end
  end

  # Done when: `User` responde a `authenticate`.
  test "authenticate aceita a senha certa e recusa a errada" do
    user = create_user(password: "senha-correta")

    assert user.authenticate("senha-correta")
    assert_not user.authenticate("senha-errada")
  end

  # Done when: `authenticate_by(email:, password:)` devolve o usuário com a
  # senha certa e `nil` com a errada.
  test "authenticate_by devolve o usuário com a senha certa" do
    user = create_user(email: "luffy@example.com", password: "senha-correta")

    assert_equal user, User.authenticate_by(email: "luffy@example.com", password: "senha-correta")
  end

  test "authenticate_by devolve nil com a senha errada" do
    create_user(email: "zoro@example.com", password: "senha-correta")

    assert_nil User.authenticate_by(email: "zoro@example.com", password: "senha-errada")
  end

  test "authenticate_by devolve nil para e-mail inexistente" do
    assert_nil User.authenticate_by(email: "ninguem@example.com", password: "senha-correta")
  end

  # Done when: o e-mail é único sem distinção de caixa, pelo índice
  # `index_users_on_lower_email` do banco.
  # Req. 6.1 — a garantia é do schema. O INSERT é direto para provar que a
  # violação vem do banco, e não de uma validação do model.
  test "e-mail é único sem distinção de caixa no banco" do
    insert_user(email: "nami@example.com")

    assert_raises(ActiveRecord::RecordNotUnique) do
      insert_user(email: "NAMI@example.com")
    end
  end

  # `authenticate_by` resolve o usuário com `find_by(email:)`, que é
  # sensível à caixa (activerecord-8.0.5.1/.../secure_password.rb:52). O
  # índice único impede que as duas grafias coexistam, mas não faz a busca
  # casar. Normalizar a caixa na entrada é do fluxo de autenticação (T4);
  # este teste fixa o comportamento atual para que a T4 o mude de propósito,
  # e não por acidente.
  test "authenticate_by é sensível à caixa do e-mail — normalização é da T4" do
    create_user(email: "sanji@example.com", password: "senha-correta")

    assert_nil User.authenticate_by(email: "SANJI@example.com", password: "senha-correta")
  end

  # Done when: `has_many :collection_items, dependent: :restrict_with_exception`
  # continua no model. Req. 1.7 — a coleção é insubstituível; apagar um
  # usuário não pode levá-la junto em silêncio.
  test "apagar usuário com itens de coleção é recusado" do
    user = create_user(email: "usopp@example.com")
    set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-001", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ])
    variant = CardVariant.create!(card: card, card_set: set, variant_code: "OP01-001", rarity: "L", art_kind: "base")
    CollectionItem.create!(user: user, card_variant: variant, quantity: 1)

    assert_raises(ActiveRecord::DeleteRestrictionError) { user.destroy }
    assert User.exists?(user.id)
  end
end
