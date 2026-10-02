require "test_helper"

# T13 (decks) — DCK-38: dois incrementos simultâneos da mesma carta no mesmo
# deck valem os dois. É o primeiro teste de corrida do projeto: a coleção tem
# o mesmo SQL atômico, mas só comentado (design.md, Risks).
#
# Cada thread usa uma conexão própria do pool e uma sessão de integração
# própria. Por isso o arquivo roda **fora** da transação do teste: dentro
# dela, o Rails faria as threads dividirem uma conexão só, e a corrida não
# existiria. O que o teste cria, o teste apaga no `teardown`.
class DeckEntriesConcurrencyTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  self.use_transactional_tests = false

  setup do
    @user = User.create!(email: "deck-t13-corrida@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT13C", name: "Decks T13 corrida", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "DT13C-002", name: "Carta", card_type: "character",
                         colors: [ "Black" ])
    @deck = Deck.create!(user: @user, name: "Corrida")
  end

  teardown do
    DeckEntry.where(deck_id: @deck.id).delete_all
    Deck.where(id: @deck.id).delete_all
    Session.where(user_id: @user.id).delete_all
    User.where(id: @user.id).delete_all
    Card.where(id: @card.id).delete_all
    CardSet.where(id: @set.id).delete_all
  end

  # Cada thread abre a própria sessão e faz login antes da largada. As duas
  # esperam na mesma barreira e disparam o POST juntas.
  def race(path, threads: 2)
    sessions = Array.new(threads) do
      open_session.tap { |s| s.post session_path, params: { email: @user.email, password: PASSWORD } }
    end
    start = Queue.new

    workers = sessions.map do |integration|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.pop
          integration.post path
          integration.response.status
        end
      end
    end
    threads.times { start << :go }

    workers.map(&:value)
  end

  test "dois incrementos simultâneos da mesma carta terminam em 2" do
    statuses = race(increment_deck_card_path(@deck, @card))

    assert_equal [ 302, 302 ], statuses
    assert_equal [ 2 ], DeckEntry.where(deck_id: @deck.id, card_id: @card.id).pluck(:quantity)
  end

  test "dois decrementos simultâneos a partir de 2 terminam sem entrada" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 2)

    statuses = race(decrement_deck_card_path(@deck, @card))

    assert_equal [ 302, 302 ], statuses
    assert_not DeckEntry.exists?(deck_id: @deck.id, card_id: @card.id)
  end
end
