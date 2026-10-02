require "test_helper"

# T13 e T23 (decks) — DCK-38: dois incrementos simultâneos da mesma carta no
# mesmo deck valem os dois. É o primeiro teste de corrida do projeto: a coleção
# tem o mesmo SQL atômico, mas só comentado (design.md, Risks).
#
# Cada thread usa uma conexão própria do pool e uma sessão de integração
# própria. Por isso o arquivo roda **fora** da transação do teste: dentro
# dela, o Rails faria as threads dividirem uma conexão só, e a corrida não
# existiria. O que o teste cria, o teste apaga no `teardown`.
#
# A sobreposição é forçada, não esperada (achado DB-H1): uma terceira conexão
# trava a linha disputada numa transação aberta, os POSTs são disparados, o
# teste espera até ver todos parados em `pg_stat_activity` com
# `wait_event_type = 'Lock'` e só então solta a trava. Sem isso, uma
# implementação com *lost update* (ler em Ruby e gravar depois) passaria
# sempre que uma requisição terminasse antes da outra começar.
#
# Conexões ao mesmo tempo: a do teste, a da trava e uma por thread. Com duas
# threads são quatro, dentro do pool de cinco do `database.yml`.
class DeckEntriesConcurrencyTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  LOCK_WAIT_TIMEOUT = 10

  self.use_transactional_tests = false

  # Nomes únicos por execução (achado DB-L7): um `teardown` que não rodou numa
  # execução anterior não derruba a próxima com `RecordNotUnique`.
  setup do
    suffix = SecureRandom.hex(4).upcase
    @user = User.create!(email: "deck-t13-corrida-#{suffix.downcase}@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT13C#{suffix}", name: "Decks T13 corrida", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "DT13C#{suffix}-002", name: "Carta", card_type: "character",
                         colors: [ "Black" ])
    @deck = Deck.create!(user: @user, name: "Corrida")
  end

  # Tolerante a setup parcial (achado DB-L7): o que não chegou a ser criado é
  # `nil`, e o `where(id: nil)` não apaga nada.
  teardown do
    DeckEntry.where(deck_id: @deck&.id).delete_all
    Deck.where(id: @deck&.id).delete_all
    Session.where(user_id: @user&.id).delete_all
    User.where(id: @user&.id).delete_all
    Card.where(id: @card&.id).delete_all
    CardSet.where(id: @set&.id).delete_all
  end

  # O minitest 6 não traz mais `stub`. A troca vale só dentro do bloco, e
  # tirar o método do singleton devolve o herdado.
  def overriding(klass, name, impl)
    klass.define_singleton_method(name, &impl)
    yield
  ensure
    klass.singleton_class.send(:remove_method, name)
  end

  def sign_in_session
    open_session.tap { |s| s.post session_path, params: { email: @user.email, password: PASSWORD } }
  end

  # Segura `lock_sql` numa conexão à parte, dispara um POST por caminho, cada
  # um na sua thread e na sua sessão, e espera todos bloqueados antes de
  # soltar. Devolve as sessões, na ordem dos caminhos, já com a resposta.
  def race(*paths, lock_sql:)
    sessions = paths.map { sign_in_session }
    pool = ActiveRecord::Base.connection_pool
    holder = pool.checkout
    holder.begin_db_transaction
    locked = true
    holder.execute(lock_sql)

    workers = sessions.zip(paths).map do |integration, path|
      Thread.new do
        pool.with_connection { integration.post path }
        integration
      end
    end

    wait_until_blocked(paths.size)
    holder.commit_db_transaction
    locked = false
    workers.map(&:value)
  ensure
    # Se a espera falhar, a trava sai aqui: sem isso as threads ficariam
    # presas e o `join` nunca voltaria. O gerenciador de transações do Rails
    # não sabe do `BEGIN` cru, então a conta é feita à mão.
    if holder
      holder.rollback_db_transaction if locked
      pool.checkin(holder)
    end
    workers&.each(&:join)
  end

  # O teste só segue quando as requisições estão de fato paradas na trava.
  # Se não chegarem lá no prazo, falha: sem sobreposição o teste não prova
  # nada.
  def wait_until_blocked(count)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + LOCK_WAIT_TIMEOUT
    loop do
      # `uncached`: a mesma consulta repetida cairia no query cache e
      # devolveria sempre a primeira contagem.
      blocked = ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value(<<~SQL) }.to_i
        -- countBlockedDeckEntryRequests
        SELECT count(*) FROM pg_stat_activity
        WHERE datname = current_database()
          AND pid <> pg_backend_pid()
          AND wait_event_type = 'Lock'
      SQL
      return if blocked >= count

      flunk "esperava #{count} requisições bloqueadas, vi #{blocked}" if
        Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.01
    end
  end

  # Sem entrada, não há linha de `deck_entries` para travar. A trava vai no
  # deck: o `INSERT` checa a FK com `FOR KEY SHARE` na linha do deck, e o
  # `FOR UPDATE` segura esse passo.
  def deck_lock
    "SELECT 1 FROM decks WHERE id = #{Integer(@deck.id)} FOR UPDATE"
  end

  def entry_lock
    "SELECT 1 FROM deck_entries WHERE deck_id = #{Integer(@deck.id)} AND card_id = #{Integer(@card.id)} FOR UPDATE"
  end

  def quantities
    DeckEntry.where(deck_id: @deck.id, card_id: @card.id).pluck(:quantity)
  end

  test "dois incrementos simultâneos da mesma carta terminam em 2" do
    path = increment_deck_card_path(@deck, @card)

    results = race(path, path, lock_sql: deck_lock)

    assert_equal [ 302, 302 ], results.map { |s| s.response.status }
    assert_equal [ 2 ], quantities
  end

  test "dois incrementos simultâneos a partir de 1 terminam em 3" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 1)
    path = increment_deck_card_path(@deck, @card)

    results = race(path, path, lock_sql: entry_lock)

    assert_equal [ 302, 302 ], results.map { |s| s.response.status }
    assert_equal [ 3 ], quantities
  end

  # DCK-39 sob corrida: o teto de 50 vale na linha travada, então só um dos
  # dois passa, e o outro recebe a recusa.
  test "dois incrementos simultâneos a partir de 49 terminam em 50 e exatamente um é recusado" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 49)
    path = increment_deck_card_path(@deck, @card)

    results = race(path, path, lock_sql: entry_lock)

    assert_equal [ 302, 302 ], results.map { |s| s.response.status }
    assert_equal [ 50 ], quantities
    alerts = results.map { |s| s.flash[:alert] }
    assert_equal 1, alerts.count("O máximo é 50 cópias por carta no deck.")
    assert_equal 1, alerts.count(nil)
  end

  test "dois decrementos simultâneos a partir de 2 terminam sem entrada" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 2)
    path = decrement_deck_card_path(@deck, @card)

    results = race(path, path, lock_sql: entry_lock)

    assert_equal [ 302, 302 ], results.map { |s| s.response.status }
    assert_empty quantities
  end

  # Os dois valem: 1 + 1 − 1 = 1, em qualquer ordem. Sem a trava do decremento
  # (cabeçalho do controller), o incremento que passasse primeiro deixaria o
  # `DELETE ... quantity = 1` sem casar, e o resultado seria 2.
  test "incremento e decremento simultâneos a partir de 1 terminam em 1, sem recusa" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 1)

    results = race(increment_deck_card_path(@deck, @card), decrement_deck_card_path(@deck, @card),
                   lock_sql: entry_lock)

    assert_equal [ 302, 302 ], results.map { |s| s.response.status }
    assert_equal [ 1 ], quantities
    assert_equal [ nil, nil ], results.map { |s| s.flash[:alert] }
  end

  # DB-M2 — outra aba apaga o deck depois do `find` e antes do `INSERT`. O
  # stub de `Card.find` roda entre os dois, porque `set_card` vem depois de
  # `set_deck`.
  test "incremento contra deck apagado depois do find responde 404 sem gravar" do
    integration = sign_in_session
    card = @card
    deck_id = @deck.id

    overriding(Card, :find, lambda { |_id|
      Deck.where(id: deck_id).delete_all
      card
    }) do
      integration.post increment_deck_card_path(@deck, @card)
    end

    assert_equal 404, integration.response.status
    assert_not Deck.exists?(deck_id)
    assert_empty quantities
  end

  # DB-M3 — uma entrada some (decremento em outra conexão, já commitado) entre
  # o `find` da página e a `DeckShortfallQuery`. No retrato único, a página
  # ainda vê a entrada nas duas leituras e responde 200, sem `KeyError`.
  test "a página do deck não levanta erro quando a entrada some entre as leituras" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 2)
    integration = sign_in_session
    real_new = DeckShortfallQuery.method(:new)
    pool = ActiveRecord::Base.connection_pool
    deck_id = @deck.id

    overriding(DeckShortfallQuery, :new, lambda { |*args, **kwargs|
      other = pool.checkout
      begin
        other.execute("DELETE FROM deck_entries WHERE deck_id = #{Integer(deck_id)}")
      ensure
        pool.checkin(other)
      end
      real_new.call(*args, **kwargs)
    }) do
      integration.get deck_path(@deck)
    end

    assert_equal 200, integration.response.status
    assert_includes integration.response.body, "pedida 2, possuída 0, falta 2"
    assert_empty quantities
  end
end
