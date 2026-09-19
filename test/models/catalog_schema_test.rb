require "test_helper"

# T3 não entrega comportamento de aplicação — entrega garantias de banco. Cada
# teste aqui corresponde a um item do "Done when" da task e, atrás dele, a uma
# invariante que existe para impedir que a ingestão corrompa a coleção
# (design.md §5.2). Por isso as asserções são contra o banco real, não contra
# validações de modelo: uma validação de Rails não segura um `UPDATE` direto.
class CatalogSchemaTest < ActiveSupport::TestCase
  def connection
    ActiveRecord::Base.connection
  end

  # `select_value` passa pelo cache de consulta do Active Record: repetir o
  # mesmo INSERT literal devolveria o resultado memoizado sem ir ao banco, e o
  # teste de unicidade nunca veria a violação. Todo INSERT deste arquivo passa
  # por aqui para garantir que o banco é de fato exercitado.
  def insert_returning_id(sql)
    connection.uncached { connection.select_value(sql) }
  end

  def create_set(code: "OP01")
    insert_returning_id(
      "INSERT INTO sets (code, name, kind, created_at, updated_at) " \
      "VALUES (#{connection.quote(code)}, 'Romance Dawn', 'booster', now(), now()) RETURNING id"
    )
  end

  def create_card(set_id:, card_number: "OP01-001", counter: nil, colors: [ "Red" ])
    insert_returning_id(<<~SQL)
      INSERT INTO cards (set_id, card_number, name, card_type, colors, counter, created_at, updated_at)
      VALUES (
        #{set_id},
        #{connection.quote(card_number)},
        'Roronoa Zoro',
        'leader',
        #{connection.quote("{#{colors.join(',')}}")},
        #{counter.nil? ? 'NULL' : counter},
        now(), now()
      ) RETURNING id
    SQL
  end

  def create_variant(card_id:, set_id:, variant_code:, rarity: "L")
    insert_returning_id(<<~SQL)
      INSERT INTO card_variants (card_id, set_id, variant_code, rarity, art_kind, created_at, updated_at)
      VALUES (#{card_id}, #{set_id}, #{connection.quote(variant_code)}, #{connection.quote(rarity)}, 'base', now(), now())
      RETURNING id
    SQL
  end

  # Done when: `card_number` único.
  # Req. 1.2 — a ingestão atualiza a carta existente em vez de duplicar. Sem a
  # constraint, um upsert defeituoso duplica silenciosamente.
  test "card_number é único no banco" do
    set_id = create_set
    create_card(set_id: set_id, card_number: "OP01-001")

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      create_card(set_id: set_id, card_number: "OP01-001")
    end
    assert_match(/card_number/, error.message)
  end

  # Done when: `(card_id, variant_code)` único.
  # Req. 1.3 — mesma variante da mesma carta não duplica.
  test "o par (card_id, variant_code) é único no banco" do
    set_id = create_set
    card_id = create_card(set_id: set_id)
    create_variant(card_id: card_id, set_id: set_id, variant_code: "OP01-001_p1")

    assert_raises(ActiveRecord::RecordNotUnique) do
      create_variant(card_id: card_id, set_id: set_id, variant_code: "OP01-001_p1")
    end
  end

  # A mesma variante pode aparecer em dois sets (caso P-029_r1, verificado na
  # fixture). A unicidade é por (card_id, variant_code) e não pode envolver
  # set_id, senão o caso real vira duplicata.
  test "variant_code idêntico em cartas diferentes é permitido" do
    set_id = create_set
    other_set_id = create_set(code: "ST16")
    card_id = create_card(set_id: set_id, card_number: "P-029")
    other_card_id = create_card(set_id: other_set_id, card_number: "P-030")

    create_variant(card_id: card_id, set_id: set_id, variant_code: "P-029_r1")
    assert create_variant(card_id: other_card_id, set_id: other_set_id, variant_code: "P-029_r1")
  end

  # Done when: foreign keys sem delete em cascata.
  # Req. 1.7 / design.md §5.2 — deletar uma variante em cascata apagaria o
  # registro de coleção do usuário. Nenhuma FK do catálogo pode cascatear.
  test "nenhuma foreign key do catálogo usa delete em cascata" do
    cascading = connection.select_values(<<~SQL)
      SELECT conname
      FROM pg_constraint
      WHERE contype = 'f'
        AND confdeltype = 'c'
        AND conrelid::regclass::text IN ('cards', 'card_variants')
    SQL

    assert_empty cascading,
                 "FK com ON DELETE CASCADE encontrada: #{cascading.join(', ')}"
  end

  test "deletar um set com cartas é impedido pelo banco" do
    set_id = create_set
    create_card(set_id: set_id)

    assert_raises(ActiveRecord::InvalidForeignKey) do
      connection.execute("DELETE FROM sets WHERE id = #{set_id}")
    end
  end

  # Done when: `rarity` como texto, não enum.
  # design.md §3.3 — a fonte é um scraper comunitário; raridade nova não pode
  # derrubar a ingestão.
  test "rarity aceita um valor fora da lista conhecida hoje" do
    set_id = create_set
    card_id = create_card(set_id: set_id)

    variant_id = create_variant(card_id: card_id, set_id: set_id,
                                variant_code: "OP01-001_x1", rarity: "RARIDADE INEDITA")

    assert_equal "RARIDADE INEDITA",
                 connection.select_value("SELECT rarity FROM card_variants WHERE id = #{variant_id}")
    assert_equal "text",
                 connection.select_value(<<~SQL)
                   SELECT data_type FROM information_schema.columns
                   WHERE table_name = 'card_variants' AND column_name = 'rarity'
                 SQL
  end

  # Done when: `counter` permite NULL, distinto de 0.
  # design.md §3.3 — "não tem counter" não é "counter de 0".
  test "counter NULL é persistido como NULL e não como 0" do
    set_id = create_set
    sem_counter = create_card(set_id: set_id, card_number: "OP01-001", counter: nil)
    com_counter_zero = create_card(set_id: set_id, card_number: "OP01-002", counter: 0)

    assert_nil connection.select_value("SELECT counter FROM cards WHERE id = #{sem_counter}")
    assert_equal 0, connection.select_value("SELECT counter FROM cards WHERE id = #{com_counter_zero}")
    assert_equal 1,
                 connection.select_value("SELECT count(*) FROM cards WHERE counter IS NULL"),
                 "counter NULL e counter 0 precisam ser distinguíveis em consulta"
  end

  # Done when: `colors`, `traits`, `attributes` como arrays Postgres.
  # design.md §3.3 — o filtro multicolor do Req. 4.5 depende de array + GIN.
  test "colors, traits e attributes são arrays Postgres" do
    array_columns = connection.select_rows(<<~SQL).to_h
      SELECT column_name, data_type FROM information_schema.columns
      WHERE table_name = 'cards' AND column_name IN ('colors', 'traits', 'attributes_list')
    SQL

    assert_equal %w[ARRAY ARRAY ARRAY], array_columns.values_at("colors", "traits", "attributes_list")
  end

  test "uma carta multicolorida guarda as duas cores no mesmo array" do
    set_id = create_set
    card_id = create_card(set_id: set_id, colors: [ "Red", "Green" ])

    assert_equal 1,
                 connection.select_value(
                   "SELECT count(*) FROM cards WHERE id = #{card_id} AND colors @> ARRAY['Green']::text[]"
                 )
  end

  # Req. 1.10 — a revisão usada tem de ser auditável no resumo da execução.
  test "import_runs exige source_revision" do
    assert_raises(ActiveRecord::NotNullViolation) do
      connection.execute(<<~SQL)
        INSERT INTO import_runs (source, status, started_at, created_at, updated_at)
        VALUES ('optcgjson', 'running', now(), now(), now())
      SQL
    end
  end
end
