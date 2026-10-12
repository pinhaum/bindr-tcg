# Uma linha do deck principal: `(deck, carta, quantidade)`. O Leader não entra
# aqui, ele mora em `decks.leader_card_id`.
#
# `UNIQUE (deck_id, card_id)` e `CHECK (quantity BETWEEN 1 AND 50)` são do
# banco (`test/models/deck_schema_test.rb`). As validações repetem o limite
# para que o erro chegue em português em vez de `StatementInvalid`.
class DeckEntry < ApplicationRecord
  QUANTITY_RANGE = 1..50
  MAX_QUANTITY = QUANTITY_RANGE.max

  belongs_to :deck, inverse_of: :entries
  belongs_to :card

  validates :quantity, numericality: { only_integer: true, in: QUANTITY_RANGE,
                                       message: "deve ficar entre #{QUANTITY_RANGE.min} e #{QUANTITY_RANGE.max}" }

  # Não vira CHECK porque o Postgres não faz CHECK entre tabelas, e um trigger
  # só para isso custaria mais que esta validação somada ao controller que
  # recusa Leader no incremento (design.md, Data Models).
  validate :card_must_not_be_a_leader

  # `ON CONFLICT DO UPDATE` lê e escreve num statement só: dois incrementos
  # simultâneos somam os dois em vez de um sobrescrever o outro (DCK-38), e a
  # corrida de criação vira atualização em vez de `RecordNotUnique`. O teto de
  # 50 mora no `WHERE` do `DO UPDATE`, na mesma linha travada: em 50, nada casa,
  # o `RETURNING` volta vazio e a quantidade fica como está. O
  # `CHECK (quantity BETWEEN 1 AND 50)` do banco continua sendo a garantia; o
  # `WHERE` só transforma a violação em mensagem. Devolve a quantidade
  # resultante, ou `nil` no teto.
  def self.increment_for!(deck, card)
    execute_returning_quantity(<<~SQL, deck.id, card.id)
      -- incrementDeckEntry
      INSERT INTO deck_entries (deck_id, card_id, quantity, created_at, updated_at)
      VALUES ($1, $2, 1, now(), now())
      ON CONFLICT (deck_id, card_id)
      DO UPDATE SET quantity = deck_entries.quantity + 1, updated_at = now()
      WHERE deck_entries.quantity < #{MAX_QUANTITY}
      RETURNING quantity
    SQL
  end

  # O piso mora no `WHERE`: acima de 1, o `UPDATE` tira uma cópia; em 1, nada
  # casa e o `DELETE ... WHERE quantity = 1` apaga a entrada (DCK-06). Devolve
  # N-1, `0` quando apagou a linha, ou `nil` quando não havia entrada.
  #
  # O decremento tem duas etapas, e entre elas havia uma janela: com a entrada
  # em 1, o `UPDATE` não casava, um incremento concorrente subia para 2 e o
  # `DELETE ... quantity = 1` também não casava, perdendo o decremento. A janela
  # fecha com o `SELECT ... FOR UPDATE` que abre a transação: as duas etapas
  # rodam com a linha travada, e o incremento espera (achado DB-L4; teste em
  # `deck_entries_concurrency_test.rb`).
  def self.decrement_for!(deck, card)
    transaction do
      execute_returning_quantity(<<~SQL, deck.id, card.id)
        -- lockDeckEntryForDecrement
        SELECT quantity FROM deck_entries
        WHERE deck_id = $1 AND card_id = $2
        FOR UPDATE
      SQL

      decremented = execute_returning_quantity(<<~SQL, deck.id, card.id)
        -- decrementDeckEntry
        UPDATE deck_entries
        SET quantity = quantity - 1, updated_at = now()
        WHERE deck_id = $1 AND card_id = $2 AND quantity > 1
        RETURNING quantity
      SQL
      next decremented if decremented

      removed = execute_returning_quantity(<<~SQL, deck.id, card.id)
        -- deleteLastDeckEntryCopy
        DELETE FROM deck_entries
        WHERE deck_id = $1 AND card_id = $2 AND quantity = 1
        RETURNING quantity
      SQL
      removed && 0
    end
  end

  # `exec_query` com bind params, não interpolação: os ids vêm do request.
  # `BigInteger`, como as colunas `bigint`: `Integer` recusaria um id acima de
  # 2³¹ com `RangeError` (achado DB-L6).
  def self.execute_returning_quantity(sql, deck_id, card_id)
    binds = [
      ActiveRecord::Relation::QueryAttribute.new("deck_id", deck_id, ActiveRecord::Type::BigInteger.new),
      ActiveRecord::Relation::QueryAttribute.new("card_id", card_id, ActiveRecord::Type::BigInteger.new)
    ]
    connection.exec_query(sql, "DeckEntry Quantity", binds).rows.dig(0, 0)
  end
  private_class_method :execute_returning_quantity

  private

  def card_must_not_be_a_leader
    return unless card&.card_type == "leader"

    errors.add(:card, "Leader não entra no deck principal; use-o como Leader do deck")
  end
end
