# A leitura da página do deck (SDEC-47), fora do controller para que HTML e
# JSON respondam o mesmo. O usuário entra por argumento, nunca por `Current`
# (ver `CardDetail`).
#
# As leituras rodam num retrato só (`REPEATABLE READ`). Em `READ COMMITTED`,
# cada consulta vê o banco do seu instante: um decremento que apagasse uma
# entrada entre o `find` e a `DeckShortfallQuery` deixaria a entrada sem linha
# de falta, e a view levantaria `KeyError` (achado DB-M3).
#
# Deck de outro usuário e id inexistente são `RecordNotFound`: o deck sai de
# `user.decks`, e a resposta não revela que ele existe (DCK-36).
class DeckDetail
  Result = Struct.new(:deck, :legality, :absent_card_ids, :shortfall_by_card_id)

  def initialize(user:, deck_id:)
    @user = user
    @deck_id = deck_id
  end

  def call
    consistent_snapshot do
      deck = @user.decks.includes(:leader, entries: :card).find(@deck_id)

      # DCK-21..23 — pedida, possuída e falta, derivadas da coleção atual numa
      # consulta, sem nada gravado.
      Result.new(deck, deck.legality, absent_card_ids(deck),
                 DeckShortfallQuery.new(@user, deck: deck).call.index_by { |row| row.card.id })
    end
  end

  private
    # O nível de isolamento só pode ser escolhido na transação de fora. Já
    # dentro de uma (a do teste transacional, ou um chamador futuro), o Rails
    # recusaria com `TransactionIsolationError`, e as leituras entram nela. A
    # prova do retrato único roda fora da transação do teste, em
    # `deck_entries_concurrency_test.rb`.
    def consistent_snapshot(&)
      return yield if Deck.connection.transaction_open?

      Deck.transaction(isolation: :repeatable_read, &)
    end

    # DCK-19 — a carta está "fora da fonte" quando nenhuma variante dela está
    # presente (`CardVariant::PRESENT_SQL`), a mesma regra do catálogo. Ela
    # continua no deck e contando para as regras: só ganha a marca.
    def absent_card_ids(deck)
      ids = [ deck.leader_card_id, *deck.entries.map(&:card_id) ].compact
      ids.to_set - CardVariant.present.where(card_id: ids).distinct.pluck(:card_id)
    end
end
