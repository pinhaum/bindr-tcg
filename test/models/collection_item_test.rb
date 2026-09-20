require "test_helper"

# T5 fecha a Fase 2 pela base: o registro de posse e as garantias que o
# protegem. Os três primeiros testes vão ao banco por **SQL direto**, no padrão
# de `catalog_schema_test.rb`, porque a afirmação que interessa não é "o Active
# Record valida" — é "o banco recusa". Validação de model não segura um
# `UPDATE` manual nem uma corrida entre duas abas (spec.md, Edge Cases), e a
# coleção é o dado insubstituível do produto (design.md §5.2).
class CollectionItemTest < ActiveSupport::TestCase
  def connection
    ActiveRecord::Base.connection
  end

  # `select_value` passa pelo cache de consulta do Active Record: repetir o
  # mesmo INSERT literal devolveria o resultado memoizado sem ir ao banco, e o
  # teste de unicidade nunca veria a violação. Mesma razão de
  # `catalog_schema_test.rb`.
  def insert_returning_id(sql)
    connection.uncached { connection.select_value(sql) }
  end

  def create_user(email: "nami@example.com")
    User.create!(email: email, password: "senha-correta")
  end

  # Cada teste cria os seus registros: o projeto não usa fixtures YAML e a
  # suíte roda em paralelo, então códigos precisam ser únicos por teste.
  def create_variant(suffix: "a")
    set = CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: "OP01-#{suffix}",
      rarity: "L", art_kind: "base")
  end

  def insert_item(user:, variant:, quantity:)
    insert_returning_id(<<~SQL)
      INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
      VALUES (#{user.id}, #{variant.id}, #{quantity}, now(), now())
      RETURNING id
    SQL
  end

  # Done when: teste prova, por SQL direto, que `UNIQUE (user_id,
  # card_variant_id)` é do banco.
  # Req. 7.8 / COL-13 — incremento em duas abas ao mesmo tempo não pode gerar
  # dois registros. `validates :uniqueness` tem janela de corrida; o índice
  # único não tem.
  test "o par (user_id, card_variant_id) é único no banco" do
    user = create_user(email: "unico@example.com")
    variant = create_variant(suffix: "u1")
    insert_item(user: user, variant: variant, quantity: 1)

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      insert_item(user: user, variant: variant, quantity: 4)
    end
    assert_match(/index_collection_items_on_user_id_and_card_variant_id/, error.message)
  end

  # A unicidade é do **par**: dois usuários com a mesma variante são o caso
  # normal do produto (spec.md, Isolamento entre usuários, critério 3), e uma
  # constraint apertada demais o transformaria em duplicata.
  test "dois usuários podem possuir a mesma variante" do
    variant = create_variant(suffix: "u2")
    insert_item(user: create_user(email: "luffy@example.com"), variant: variant, quantity: 1)
    insert_item(user: create_user(email: "zoro@example.com"), variant: variant, quantity: 2)

    # A asserção é a **coexistência**, não a ausência de exceção: um INSERT que
    # sobrescrevesse a linha anterior em vez de acrescentar uma também deixaria
    # de levantar, e um `assert insert_item(...)` sozinho passaria.
    assert_equal [ 1, 2 ],
                 CollectionItem.where(card_variant: variant).order(:quantity).pluck(:quantity)
  end

  # Done when: teste prova, por SQL direto, que `CHECK (quantity >= 0)` é do
  # banco.
  # Req. 7.4 / COL-09 — o piso não pode depender do controller: um `UPDATE ...
  # SET quantity = quantity - 1` direto passaria por fora de qualquer
  # validação.
  test "quantidade negativa é recusada pelo banco no INSERT" do
    user = create_user(email: "check-insert@example.com")
    variant = create_variant(suffix: "c1")

    error = assert_raises(ActiveRecord::StatementInvalid) do
      insert_item(user: user, variant: variant, quantity: -1)
    end
    assert_match(/collection_items_quantity_check/, error.message)
  end

  test "quantidade negativa é recusada pelo banco no UPDATE direto" do
    user = create_user(email: "check-update@example.com")
    variant = create_variant(suffix: "c2")
    id = insert_item(user: user, variant: variant, quantity: 0)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      connection.uncached do
        connection.execute("UPDATE collection_items SET quantity = quantity - 1 WHERE id = #{id}")
      end
    end
    assert_match(/collection_items_quantity_check/, error.message)
  end

  # Done when: teste prova que a FK recusa apagar uma variante possuída.
  # Req. 1.7 / design.md §5.2 — a ingestão não tem delete, mas se um dia
  # tivesse, `restrict` transforma a perda calada em erro barulhento. Sem esta
  # constraint, apagar uma variante do catálogo (regenerável) levaria junto o
  # registro do usuário (insubstituível).
  test "apagar uma variante possuída é impedido pelo banco" do
    user = create_user(email: "fk-variant@example.com")
    variant = create_variant(suffix: "f1")
    insert_item(user: user, variant: variant, quantity: 2)

    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      connection.uncached { connection.execute("DELETE FROM card_variants WHERE id = #{variant.id}") }
    end
    # Nenhuma asserção depois do raise: a violação aborta a transação do teste,
    # e qualquer consulta seguinte falharia com `InFailedSqlTransaction` em vez
    # de dizer algo sobre o schema. O nome da constraint na mensagem é a prova
    # de que quem recusou foi a FK de `collection_items`, e não outra coisa.
    assert_match(/collection_items/, error.message)
  end

  test "nenhuma foreign key de collection_items usa delete em cascata" do
    cascading = connection.select_values(<<~SQL)
      SELECT conname
      FROM pg_constraint
      WHERE contype = 'f'
        AND confdeltype <> 'r'
        AND conrelid::regclass::text = 'collection_items'
    SQL

    assert_empty cascading,
                 "FK de collection_items sem ON DELETE RESTRICT: #{cascading.join(', ')}"
  end

  # Done when: quantidade zero é representável e tratada como não possuída.
  # Req. 7.3 / COL-08 — zero é uma linha existente com quantidade 0, não a
  # ausência da linha. Quem zerou mantém o registro, e é isso que faz o filtro
  # do Req. 7.6 conseguir distinguir "nunca teve" de "não tem mais".
  test "quantidade zero é persistida como registro existente" do
    user = create_user(email: "zero@example.com")
    item = CollectionItem.create!(user: user, card_variant: create_variant(suffix: "z1"), quantity: 0)

    assert_equal 0, item.reload.quantity
    assert CollectionItem.exists?(item.id)
  end

  test "owned? é falso com quantidade zero e verdadeiro a partir de uma cópia" do
    user = create_user(email: "owned-pred@example.com")
    item = CollectionItem.create!(user: user, card_variant: create_variant(suffix: "z2"), quantity: 0)

    assert_not item.owned?

    item.update!(quantity: 1)
    assert item.owned?
  end

  test "o escopo owned exclui a quantidade zero e unowned só traz ela" do
    user = create_user(email: "owned-scope@example.com")
    zerada = CollectionItem.create!(user: user, card_variant: create_variant(suffix: "s1"), quantity: 0)
    possuida = CollectionItem.create!(user: user, card_variant: create_variant(suffix: "s2"), quantity: 3)

    assert_equal [ possuida.id ], CollectionItem.for_user(user).owned.pluck(:id)
    assert_equal [ zerada.id ], CollectionItem.for_user(user).unowned.pluck(:id)
  end

  # Req. 6.5 / COL-05 — a consulta parte do usuário da sessão. Este teste fixa
  # o isolamento na camada onde ele é barato de garantir; a T7 volta a ele pelo
  # HTTP.
  test "for_user devolve apenas os itens do usuário informado" do
    dono = create_user(email: "dono@example.com")
    outro = create_user(email: "outro@example.com")
    variant = create_variant(suffix: "i1")
    meu = CollectionItem.create!(user: dono, card_variant: variant, quantity: 1)
    CollectionItem.create!(user: outro, card_variant: variant, quantity: 9)

    assert_equal [ meu.id ], CollectionItem.for_user(dono).pluck(:id)
  end

  # O anônimo do catálogo público chega aqui como `Current.user` nil. Relação
  # vazia, não erro: o catálogo renderiza sem sessão (Req. 7.6, critério 3).
  test "for_user com nil devolve relação vazia sem levantar erro" do
    CollectionItem.create!(user: create_user(email: "anon@example.com"),
      card_variant: create_variant(suffix: "n1"), quantity: 5)

    assert_empty CollectionItem.for_user(nil)
  end

  # O ponto do tipo exigido: um id vindo do request não pode virar consulta
  # silenciosamente. `for_user(params[:user_id])` tem de explodir em
  # desenvolvimento e em teste, não retornar os itens de outra pessoa.
  test "for_user recusa um id no lugar do objeto User" do
    user = create_user(email: "id-recusado@example.com")

    assert_raises(ArgumentError) { CollectionItem.for_user(user.id) }
    assert_raises(ArgumentError) { CollectionItem.for_user(user.id.to_s) }
  end
end
