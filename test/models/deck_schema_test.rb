require "test_helper"

# T2 (decks) — as garantias de `decks` e `deck_entries` provadas pelo banco, por
# SQL direto, no padrão de `collection_item_test.rb`. A afirmação que interessa
# é "o banco recusa", não "o Active Record valida": validação de model não
# segura um `UPDATE` manual nem uma corrida entre duas abas.
class DeckSchemaTest < ActiveSupport::TestCase
  def connection
    ActiveRecord::Base.connection
  end

  # `uncached` pela mesma razão de `collection_item_test.rb`: repetir o mesmo
  # INSERT literal devolveria o resultado memoizado sem ir ao banco.
  def sql_value(sql)
    connection.uncached { connection.select_value(sql) }
  end

  def sql_execute(sql)
    connection.uncached { connection.execute(sql) }
  end

  def create_user(email:)
    User.create!(email: email, password: "senha-correta")
  end

  # Cada teste cria os seus registros: a suíte roda em paralelo e os códigos
  # precisam ser únicos por teste.
  def create_card(suffix:, card_type: "character")
    set = CardSet.find_or_create_by!(code: "DK#{suffix}") { |s| s.name = "Deck Set", s.kind = "booster" }
    Card.create!(card_set: set, card_number: "DK01-#{suffix}", name: "Carta #{suffix}",
      card_type: card_type, colors: [ "Black" ])
  end

  def insert_deck(user:, name: "Deck", leader: nil)
    sql_value(<<~SQL)
      INSERT INTO decks (user_id, name, leader_card_id, created_at, updated_at)
      VALUES (#{user.id}, #{connection.quote(name)}, #{leader ? leader.id : 'NULL'}, now(), now())
      RETURNING id
    SQL
  end

  # O nome da FK que parte de `table.column`, lido do catálogo do Postgres.
  # A mensagem de violação traz o nome da constraint, e casar com ele prova
  # qual coluna recusou, não só qual tabela (T22, L6).
  def foreign_key_name(table, column)
    connection.select_value(<<~SQL)
      SELECT conname FROM pg_constraint
      WHERE contype = 'f' AND conrelid = #{connection.quote(table)}::regclass
        AND conkey = ARRAY[(SELECT attnum FROM pg_attribute
                            WHERE attrelid = #{connection.quote(table)}::regclass
                              AND attname = #{connection.quote(column)})]
    SQL
  end

  def insert_entry(deck_id:, card:, quantity:)
    sql_value(<<~SQL)
      INSERT INTO deck_entries (deck_id, card_id, quantity, created_at, updated_at)
      VALUES (#{deck_id}, #{card.id}, #{quantity}, now(), now())
      RETURNING id
    SQL
  end

  # DCK-02 — no máximo uma entrada por carta por deck, garantida no banco.
  test "o par (deck_id, card_id) é único no banco" do
    deck_id = insert_deck(user: create_user(email: "unico-deck@example.com"))
    card = create_card(suffix: "u1")
    insert_entry(deck_id: deck_id, card: card, quantity: 1)

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      insert_entry(deck_id: deck_id, card: card, quantity: 2)
    end
    assert_match(/index_deck_entries_on_deck_id_and_card_id/, error.message)
  end

  # DCK-39 — quantidade de 1 a 50, pelo banco.
  test "quantidade 0 é recusada pelo banco" do
    deck_id = insert_deck(user: create_user(email: "q0@example.com"))

    error = assert_raises(ActiveRecord::StatementInvalid) do
      insert_entry(deck_id: deck_id, card: create_card(suffix: "q0"), quantity: 0)
    end
    assert_match(/deck_entries_quantity_check/, error.message)
  end

  test "quantidade 51 é recusada pelo banco" do
    deck_id = insert_deck(user: create_user(email: "q51@example.com"))

    error = assert_raises(ActiveRecord::StatementInvalid) do
      insert_entry(deck_id: deck_id, card: create_card(suffix: "q51"), quantity: 51)
    end
    assert_match(/deck_entries_quantity_check/, error.message)
  end

  # O limite também segura o `UPDATE` direto, que é o caminho do incremento
  # atômico (design.md, DeckEntriesController).
  test "UPDATE direto acima de 50 é recusado pelo banco" do
    deck_id = insert_deck(user: create_user(email: "q-update@example.com"))
    id = insert_entry(deck_id: deck_id, card: create_card(suffix: "qu"), quantity: 50)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      sql_execute("UPDATE deck_entries SET quantity = quantity + 1 WHERE id = #{id}")
    end
    assert_match(/deck_entries_quantity_check/, error.message)
  end

  test "quantidades 1 e 50 são aceitas pelo banco" do
    deck_id = insert_deck(user: create_user(email: "q-limites@example.com"))
    insert_entry(deck_id: deck_id, card: create_card(suffix: "l1"), quantity: 1)
    insert_entry(deck_id: deck_id, card: create_card(suffix: "l50"), quantity: 50)

    assert_equal [ 1, 50 ],
                 connection.select_values("SELECT quantity FROM deck_entries WHERE deck_id = #{deck_id} ORDER BY quantity")
  end

  # DCK-39 — nome de 1 a 60 caracteres, pelo banco.
  test "nome vazio é recusado pelo banco" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      insert_deck(user: create_user(email: "nome-vazio@example.com"), name: "")
    end
    assert_match(/decks_name_length_check/, error.message)
  end

  test "nome de 61 caracteres é recusado pelo banco" do
    error = assert_raises(ActiveRecord::StatementInvalid) do
      insert_deck(user: create_user(email: "nome-61@example.com"), name: "a" * 61)
    end
    assert_match(/decks_name_length_check/, error.message)
  end

  test "nome de 60 caracteres é aceito pelo banco" do
    id = insert_deck(user: create_user(email: "nome-60@example.com"), name: "a" * 60)

    assert_equal 60, sql_value("SELECT char_length(name) FROM decks WHERE id = #{id}")
  end

  # DCK-40 — apagar a carta que é Leader de um deck falha pela FK.
  test "apagar uma carta que é Leader de um deck é impedido pelo banco" do
    leader = create_card(suffix: "fl", card_type: "leader")
    insert_deck(user: create_user(email: "fk-leader@example.com"), leader: leader)
    # Lido antes do DELETE: depois do raise, a transação do teste está abortada.
    constraint = foreign_key_name("decks", "leader_card_id")
    assert_not_nil constraint

    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      sql_execute("DELETE FROM cards WHERE id = #{leader.id}")
    end
    # O nome da constraint na mensagem prova que quem recusou foi a FK de
    # `decks.leader_card_id`.
    assert_includes error.message, constraint
  end

  # DCK-40 — apagar a carta que está numa entrada falha pela FK.
  test "apagar uma carta que está numa entrada é impedido pelo banco" do
    deck_id = insert_deck(user: create_user(email: "fk-entry@example.com"))
    card = create_card(suffix: "fe")
    insert_entry(deck_id: deck_id, card: card, quantity: 4)
    constraint = foreign_key_name("deck_entries", "card_id")
    assert_not_nil constraint

    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      sql_execute("DELETE FROM cards WHERE id = #{card.id}")
    end
    assert_includes error.message, constraint
  end

  # DCK-40 — nenhuma FK que parte de `cards` cascateia, e a única cascata das
  # duas tabelas é `deck_entries.deck_id`.
  test "só deck_entries.deck_id usa delete em cascata" do
    rows = connection.select_rows(<<~SQL)
      SELECT conrelid::regclass::text, confrelid::regclass::text, confdeltype
      FROM pg_constraint
      WHERE contype = 'f'
        AND conrelid::regclass::text IN ('decks', 'deck_entries')
      ORDER BY 1, 2
    SQL

    assert_equal [
      [ "deck_entries", "cards", "r" ],
      [ "deck_entries", "decks", "c" ],
      [ "decks", "cards", "r" ],
      [ "decks", "users", "r" ]
    ], rows
  end

  # T22 (M2) — os quatro índices da migração. Os três simples atendem as FKs
  # (busca por dono, e o `ON DELETE RESTRICT` de `cards`, que sem índice faz
  # varredura em `decks` e `deck_entries` a cada carta apagada). O único é o
  # DCK-02 e também atende a busca por `deck_id`.
  test "os índices de decks e deck_entries existem com as colunas e a unicidade da migração" do
    indexes = %w[decks deck_entries].flat_map do |table|
      connection.indexes(table).map { |index| [ table, index.columns, index.unique ] }
    end

    assert_equal [
      [ "deck_entries", [ "card_id" ], false ],
      [ "deck_entries", [ "deck_id", "card_id" ], true ],
      [ "decks", [ "leader_card_id" ], false ],
      [ "decks", [ "user_id" ], false ]
    ], indexes.sort_by { |table, columns, _| [ table, columns ] }
  end

  # DCK-09 — `DELETE FROM decks` apaga só as entradas daquele deck.
  test "apagar um deck apaga só as entradas dele" do
    user = create_user(email: "cascata@example.com")
    card = create_card(suffix: "cs")
    gone = insert_deck(user: user, name: "Vai")
    kept = insert_deck(user: user, name: "Fica")
    insert_entry(deck_id: gone, card: card, quantity: 2)
    kept_entry = insert_entry(deck_id: kept, card: card, quantity: 3)

    sql_execute("DELETE FROM decks WHERE id = #{gone}")

    assert_equal 0, sql_value("SELECT count(*) FROM deck_entries WHERE deck_id = #{gone}")
    assert_equal [ [ kept_entry, 3 ] ],
                 connection.select_rows("SELECT id, quantity FROM deck_entries WHERE deck_id = #{kept}")
    assert_equal 1, sql_value("SELECT count(*) FROM cards WHERE id = #{card.id}")
  end
end
