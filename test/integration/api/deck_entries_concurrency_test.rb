require "test_helper"

# T7 (spa-decks) — SDEC-56: somar e tirar a mesma carta do mesmo deck, ao mesmo
# tempo, pela API, vale todas as operações, o teto de 50 vale sob corrida e
# nenhum `quantity` abaixo de 1 é gravado. O SQL atômico de
# `DeckEntry.increment_for!`/`decrement_for!` é provado pela API, com a mesma
# técnica de `deck_entries_concurrency_test` e `card_variants_concurrency_test`.
#
# Cada thread usa uma conexão do pool e uma sessão de integração própria. Por
# isso o arquivo roda **fora** da transação do teste: dentro dela, as threads
# dividiriam uma conexão só e a corrida não existiria. O que o teste cria, o
# teste apaga no `teardown`.
#
# A sobreposição é forçada: uma conexão à parte trava a linha disputada numa
# transação aberta, os POSTs disparam, o teste espera vê-los todos parados em
# `pg_stat_activity` com `wait_event_type = 'Lock'` e só então solta a trava.
#
# Conexões ao mesmo tempo: a do teste, a da trava e uma por thread. O pool tem
# cinco, então o teto é de três requisições por corrida.
class Api::DeckEntriesConcurrencyTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  LOCK_WAIT_TIMEOUT = 10
  CAP_MESSAGE = "O máximo é 50 cópias por carta no deck.".freeze

  self.use_transactional_tests = false

  # Nomes únicos por execução: um `teardown` que não rodou antes não derruba a
  # próxima execução com `RecordNotUnique`.
  setup do
    suffix = SecureRandom.hex(4).upcase
    @user = User.create!(email: "api-deck-corrida-#{suffix.downcase}@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "SD7#{suffix}", name: "Deck corrida", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "SD7#{suffix}-002", name: "Carta", card_type: "character",
                         colors: [ "Black" ])
    @deck = Deck.create!(user: @user, name: "Corrida")
  end

  # Tolerante a setup parcial: o que não chegou a ser criado é `nil`, e o
  # `where(id: nil)` não apaga nada.
  teardown do
    DeckEntry.where(deck_id: @deck&.id).delete_all
    Deck.where(id: @deck&.id).delete_all
    Session.where(user_id: @user&.id).delete_all
    User.where(id: @user&.id).delete_all
    Card.where(id: @card&.id).delete_all
    CardSet.where(id: @set&.id).delete_all
  end

  def sign_in_session
    open_session.tap do |s|
      s.post "/api/session", params: { email: @user.email, password: PASSWORD }.to_json,
                             headers: { "Content-Type" => "application/json" }
    end
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
        -- countBlockedApiDeckEntryRequests
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

  def operation_path(operation)
    public_send(:"api_#{operation}_deck_card_path", @deck, @card.card_number)
  end

  # Sem entrada, não há linha de `deck_entries` para travar. A trava vai no
  # deck: o `INSERT` checa a FK com `FOR KEY SHARE` na linha dele, e o
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

  def reported_quantities(results)
    results.map { |s| s.response.parsed_body.dig("data", "quantity") }
  end

  test "três incrementos simultâneos a partir de zero terminam em 3" do
    path = operation_path(:increment)

    results = race(path, path, path, lock_sql: deck_lock)

    assert_equal [ 200, 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 1, 2, 3 ], reported_quantities(results).sort
    assert_equal [ 3 ], quantities
  end

  test "três incrementos simultâneos a partir de 1 terminam em 4" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 1)
    path = operation_path(:increment)

    results = race(path, path, path, lock_sql: entry_lock)

    assert_equal [ 200, 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 2, 3, 4 ], reported_quantities(results).sort
    assert_equal [ 4 ], quantities
  end

  # O teto de 50 mora no `WHERE` do `DO UPDATE`: dos três, só dois passam e o
  # excedente recebe 422 com a frase do HTML, sem gravar.
  test "três incrementos simultâneos a partir de 48 terminam em 50 e o excedente é 422" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 48)
    path = operation_path(:increment)

    results = race(path, path, path, lock_sql: entry_lock)

    assert_equal [ 200, 200, 422 ], results.map { |s| s.response.status }.sort
    assert_equal [ 49, 50 ], reported_quantities(results.select { |s| s.response.status == 200 }).sort
    refused = results.find { |s| s.response.status == 422 }.response.parsed_body
    assert_equal "validation_failed", refused.dig("error", "code")
    assert_equal CAP_MESSAGE, refused.dig("error", "message")
    assert_equal [ 50 ], quantities
  end

  # Discrimina o *lost update*: dois decrementos lidos em Ruby veriam 2 e
  # gravariam 1; no banco, o segundo reavalia a linha já decrementada. O
  # segundo encontra a linha apagada e responde 200 com zero, sem gravar.
  test "dois decrementos simultâneos a partir de 2 terminam sem entrada" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 2)
    path = operation_path(:decrement)

    results = race(path, path, lock_sql: entry_lock)

    assert_equal [ 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 0, 1 ], reported_quantities(results).sort
    assert_empty quantities
  end

  # Só um decremento apaga a linha; os outros dois já encontram zero. O
  # `CHECK (quantity >= 1)` derrubaria a requisição com 500 se algum gravasse 0.
  test "três decrementos simultâneos a partir de 1 terminam sem entrada e sem quantidade abaixo de 1" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 1)
    path = operation_path(:decrement)

    results = race(path, path, path, lock_sql: entry_lock)

    assert_equal [ 200, 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 0, 0, 0 ], reported_quantities(results)
    assert_empty quantities
  end

  # 1 + 1 − 1 = 1, em qualquer ordem. Sem a trava do decremento, o incremento
  # que passasse primeiro deixaria o `DELETE ... quantity = 1` sem casar.
  test "incremento e decremento simultâneos a partir de 1 terminam em 1" do
    DeckEntry.create!(deck: @deck, card: @card, quantity: 1)

    results = race(operation_path(:increment), operation_path(:decrement), lock_sql: entry_lock)

    assert_equal [ 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 1 ], quantities
  end
end
