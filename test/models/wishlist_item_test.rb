require "test_helper"

# T12 entrega a tabela da wishlist e as garantias que protegem o desejo do
# usuário. Os testes de constraint vão ao banco por **SQL direto**, no padrão
# de `collection_item_test.rb` e `catalog_schema_test.rb`, porque a afirmação
# que interessa não é "o Active Record valida" — é "o banco recusa". Validação
# de model não segura um `UPDATE` manual nem uma corrida entre duas abas
# (spec.md, Edge Cases), e a wishlist é dado insubstituível do usuário como a
# coleção (design.md §5.2).
class WishlistItemTest < ActiveSupport::TestCase
  def connection
    ActiveRecord::Base.connection
  end

  # `select_value` passa pelo cache de consulta do Active Record: repetir o
  # mesmo INSERT literal devolveria o resultado memoizado sem ir ao banco, e o
  # teste de unicidade nunca veria a violação.
  def insert_returning_id(sql)
    connection.uncached { connection.select_value(sql) }
  end

  def create_user(email: "nami-wish@example.com")
    User.create!(email: email, password: "senha-correta")
  end

  # Cada teste cria os seus registros: o projeto não usa fixtures YAML e a
  # suíte roda em paralelo, então códigos e e-mails precisam ser únicos por
  # teste.
  def create_variant(suffix:)
    set = CardSet.create!(code: "WL#{suffix}", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "WL01-#{suffix}", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: "WL01-#{suffix}",
      rarity: "L", art_kind: "base")
  end

  def insert_item(user:, variant:, target_quantity:)
    insert_returning_id(<<~SQL)
      INSERT INTO wishlist_items (user_id, card_variant_id, target_quantity, created_at, updated_at)
      VALUES (#{user.id}, #{variant.id}, #{target_quantity}, now(), now())
      RETURNING id
    SQL
  end

  # Done when: teste por SQL direto prova que `UNIQUE (user_id,
  # card_variant_id)` é do banco.
  # Req. 8.5 / COL-14 — marcar a mesma variante em duas abas ao mesmo tempo não
  # pode gerar dois itens. `validates :uniqueness` tem janela de corrida; o
  # índice único não tem.
  test "o par (user_id, card_variant_id) é único no banco" do
    user = create_user(email: "wish-unico@example.com")
    variant = create_variant(suffix: "u1")
    insert_item(user: user, variant: variant, target_quantity: 1)

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      insert_item(user: user, variant: variant, target_quantity: 4)
    end
    assert_match(/index_wishlist_items_on_user_id_and_card_variant_id/, error.message)
  end

  # A unicidade é do **par**: dois usuários desejando a mesma variante é o caso
  # normal do produto, e uma constraint apertada demais o transformaria em
  # duplicata.
  test "dois usuários podem desejar a mesma variante" do
    variant = create_variant(suffix: "u2")
    insert_item(user: create_user(email: "wish-luffy@example.com"), variant: variant, target_quantity: 1)
    insert_item(user: create_user(email: "wish-zoro@example.com"), variant: variant, target_quantity: 2)

    # A asserção é a **coexistência**, não a ausência de exceção: um INSERT que
    # sobrescrevesse a linha anterior em vez de acrescentar uma também deixaria
    # de levantar, e um `assert insert_item(...)` sozinho passaria.
    assert_equal [ 1, 2 ],
                 WishlistItem.where(card_variant: variant).order(:target_quantity).pluck(:target_quantity)
  end

  # Done when: teste por SQL direto prova que `CHECK (target_quantity >= 1)` é
  # do banco.
  # Req. 8.1 / COL-14 — o piso é **1**, não 0, ao contrário de
  # `collection_items`. A assimetria é deliberada e está justificada na
  # migração: posse zero é estado legítimo ("tenho a linha, não tenho a
  # carta"), desejo zero não é desejo nenhum.
  test "alvo zero é recusado pelo banco no INSERT" do
    user = create_user(email: "wish-zero@example.com")
    variant = create_variant(suffix: "c1")

    error = assert_raises(ActiveRecord::StatementInvalid) do
      insert_item(user: user, variant: variant, target_quantity: 0)
    end
    assert_match(/wishlist_items_target_quantity_check/, error.message)
  end

  test "alvo negativo é recusado pelo banco no INSERT" do
    user = create_user(email: "wish-negativo@example.com")
    variant = create_variant(suffix: "c2")

    error = assert_raises(ActiveRecord::StatementInvalid) do
      insert_item(user: user, variant: variant, target_quantity: -1)
    end
    assert_match(/wishlist_items_target_quantity_check/, error.message)
  end

  # O caminho que nenhuma validação de model cobre: zerar o alvo por `UPDATE`
  # direto. É o mesmo par INSERT/UPDATE de `collection_item_test.rb`.
  test "zerar o alvo é recusado pelo banco no UPDATE direto" do
    user = create_user(email: "wish-update@example.com")
    variant = create_variant(suffix: "c3")
    id = insert_item(user: user, variant: variant, target_quantity: 1)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      connection.uncached do
        connection.execute("UPDATE wishlist_items SET target_quantity = target_quantity - 1 WHERE id = #{id}")
      end
    end
    assert_match(/wishlist_items_target_quantity_check/, error.message)
  end

  # O limite inferior legítimo passa. Sem esta asserção, um `CHECK
  # (target_quantity >= 2)` — ou qualquer piso alto demais — também deixaria os
  # testes acima verdes.
  test "alvo de uma cópia é aceito" do
    user = create_user(email: "wish-um@example.com")
    item = WishlistItem.create!(user: user, card_variant: create_variant(suffix: "c4"), target_quantity: 1)

    assert_equal 1, item.reload.target_quantity
  end

  # Done when: teste prova que a FK recusa apagar uma variante desejada.
  # Req. 1.7 / design.md §5.2 — a ingestão não tem delete, mas se um dia
  # tivesse, `restrict` transforma a perda calada em erro barulhento. Sem esta
  # constraint, apagar uma variante do catálogo (regenerável) levaria junto o
  # desejo do usuário (insubstituível).
  test "apagar uma variante desejada é impedido pelo banco" do
    user = create_user(email: "wish-fk-variant@example.com")
    variant = create_variant(suffix: "f1")
    insert_item(user: user, variant: variant, target_quantity: 2)

    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      connection.uncached { connection.execute("DELETE FROM card_variants WHERE id = #{variant.id}") }
    end
    # Nenhuma asserção depois do raise: a violação aborta a transação do teste,
    # e qualquer consulta seguinte falharia com `InFailedSqlTransaction` em vez
    # de dizer algo sobre o schema. O nome da constraint na mensagem é a prova
    # de que quem recusou foi a FK de `wishlist_items`, e não outra coisa.
    assert_match(/wishlist_items/, error.message)
  end

  test "apagar um usuário com wishlist é impedido pelo banco" do
    user = create_user(email: "wish-fk-user@example.com")
    insert_item(user: user, variant: create_variant(suffix: "f2"), target_quantity: 3)

    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      connection.uncached { connection.execute("DELETE FROM users WHERE id = #{user.id}") }
    end
    assert_match(/wishlist_items/, error.message)
  end

  # Done when: nenhuma FK em cascata — a ingestão não pode apagar dado do
  # usuário. A asserção é sobre `confdeltype <> 'r'` e não sobre `= 'c'`:
  # `SET NULL` e `SET DEFAULT` também destruiriam o vínculo, e a coluna é
  # `null: false`, então o efeito seria erro ou lixo, nunca o desejado.
  test "nenhuma foreign key de wishlist_items usa delete em cascata" do
    cascading = connection.select_values(<<~SQL)
      SELECT conname
      FROM pg_constraint
      WHERE contype = 'f'
        AND confdeltype <> 'r'
        AND conrelid::regclass::text = 'wishlist_items'
    SQL

    assert_empty cascading,
                 "FK de wishlist_items sem ON DELETE RESTRICT: #{cascading.join(', ')}"
  end

  # As duas FKs existem. Sem esta asserção, a de cascata acima passaria vazia
  # numa tabela **sem nenhuma** foreign key — o pior caso possível.
  test "as duas referências são foreign keys de verdade" do
    fks = connection.select_values(<<~SQL)
      SELECT conname
      FROM pg_constraint
      WHERE contype = 'f' AND conrelid::regclass::text = 'wishlist_items'
    SQL

    assert_equal 2, fks.size, "wishlist_items deveria ter FK para users e para card_variants"
  end

  # Req. 6.5 / COL-05 — a consulta parte do usuário da sessão, nunca de um id
  # vindo do request. Mesmo contrato de `CollectionItem.for_user`; a T13 vai
  # consumi-lo no controller.
  test "for_user devolve apenas os itens do usuário informado" do
    dono = create_user(email: "wish-dono@example.com")
    outro = create_user(email: "wish-outro@example.com")
    variant = create_variant(suffix: "i1")
    meu = WishlistItem.create!(user: dono, card_variant: variant, target_quantity: 1)
    WishlistItem.create!(user: outro, card_variant: variant, target_quantity: 9)

    assert_equal [ meu.id ], WishlistItem.for_user(dono).pluck(:id)
  end

  test "for_user com nil devolve relação vazia sem levantar erro" do
    WishlistItem.create!(user: create_user(email: "wish-anon@example.com"),
      card_variant: create_variant(suffix: "n1"), target_quantity: 5)

    assert_empty WishlistItem.for_user(nil)
  end

  test "for_user recusa um id no lugar do objeto User" do
    user = create_user(email: "wish-id-recusado@example.com")

    assert_raises(ArgumentError) { WishlistItem.for_user(user.id) }
    assert_raises(ArgumentError) { WishlistItem.for_user(user.id.to_s) }
  end

  # A validação de model não substitui o `CHECK`, mas precisa concordar com
  # ele: um formulário que aceitasse 0 estouraria 500 em vez de dizer o que
  # está errado.
  test "o model rejeita alvo zero com mensagem em vez de erro de banco" do
    item = WishlistItem.new(user: create_user(email: "wish-validacao@example.com"),
      card_variant: create_variant(suffix: "v1"), target_quantity: 0)

    assert_not item.valid?
    assert_includes item.errors.attribute_names, :target_quantity
  end
end
