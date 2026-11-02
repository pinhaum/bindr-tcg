require "test_helper"

# T4 (spa-carta) — SCAR-44: incrementos e decrementos da mesma variante e do
# mesmo usuário, ao mesmo tempo, valem todos e nunca deixam a quantidade
# negativa. O SQL atômico da posse só tinha comentário (design.md, Risks); aqui
# ele é provado pela API, com a mesma técnica de `deck_entries_concurrency_test`.
#
# Cada thread usa uma conexão do pool e uma sessão de integração própria. Por
# isso o arquivo roda **fora** da transação do teste: dentro dela, as threads
# dividiriam uma conexão só e a corrida não existiria. O que o teste cria, o
# teste apaga no `teardown`.
#
# A sobreposição é forçada: uma conexão à parte trava a linha disputada numa
# transação aberta, os POSTs disparam, o teste espera vê-los todos parados em
# `pg_stat_activity` com `wait_event_type = 'Lock'` e só então solta a trava.
# Uma implementação de ler-somar-gravar em Ruby leria o mesmo valor nas duas
# requisições e perderia uma operação.
#
# Conexões ao mesmo tempo: a do teste, a da trava e uma por thread. O pool tem
# cinco, então o teto é de três requisições por corrida.
class Api::CardVariantsConcurrencyTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  LOCK_WAIT_TIMEOUT = 10

  self.use_transactional_tests = false

  # Nomes únicos por execução: um `teardown` que não rodou antes não derruba a
  # próxima execução com `RecordNotUnique`.
  setup do
    suffix = SecureRandom.hex(4).upcase
    @user = User.create!(email: "api-posse-corrida-#{suffix.downcase}@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "SC4#{suffix}", name: "Posse corrida", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "SC4#{suffix}-001", name: "Carta", card_type: "character",
                         colors: [ "Black" ])
    @variant = CardVariant.create!(card: @card, card_set: @set, variant_code: "tcgplayer:#{suffix}",
                                   rarity: "R", art_kind: "base", last_seen_at: Time.current,
                                   image_url: "https://cdn.example.com/#{suffix}.png")
  end

  # Tolerante a setup parcial: o que não chegou a ser criado é `nil`, e o
  # `where(id: nil)` não apaga nada.
  teardown do
    CollectionItem.where(user_id: @user&.id).delete_all
    Session.where(user_id: @user&.id).delete_all
    User.where(id: @user&.id).delete_all
    CardVariant.where(id: @variant&.id).delete_all
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
        -- countBlockedOwnershipRequests
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
    public_send(:"api_#{operation}_card_variant_path",
                card_number: @card.card_number, variant_code: @variant.variant_code)
  end

  # Sem registro, não há linha de `collection_items` para travar. A trava vai
  # no usuário: o `INSERT` checa a FK com `FOR KEY SHARE` na linha dele, e o
  # `FOR UPDATE` segura esse passo.
  def user_lock
    "SELECT 1 FROM users WHERE id = #{Integer(@user.id)} FOR UPDATE"
  end

  def item_lock
    "SELECT 1 FROM collection_items WHERE user_id = #{Integer(@user.id)} " \
      "AND card_variant_id = #{Integer(@variant.id)} FOR UPDATE"
  end

  def quantities
    CollectionItem.where(user_id: @user.id, card_variant_id: @variant.id).pluck(:quantity)
  end

  def owned_quantities(results)
    results.map { |s| s.response.parsed_body.dig("data", "owned_quantity") }
  end

  test "três incrementos simultâneos a partir de zero terminam em 3" do
    path = operation_path(:increment)

    results = race(path, path, path, lock_sql: user_lock)

    assert_equal [ 200, 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 1, 2, 3 ], owned_quantities(results).sort
    assert_equal [ 3 ], quantities
  end

  test "três incrementos simultâneos a partir de 1 terminam em 4" do
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 1)
    path = operation_path(:increment)

    results = race(path, path, path, lock_sql: item_lock)

    assert_equal [ 200, 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 2, 3, 4 ], owned_quantities(results).sort
    assert_equal [ 4 ], quantities
  end

  # Só um decremento passa; os outros dois já encontram zero, respondem 200 com
  # `owned_quantity: 0` e não gravam nada. O `CHECK (quantity >= 0)` derrubaria
  # a requisição com 500 se algum deles escrevesse -1.
  test "três decrementos simultâneos a partir de 1 terminam em 0, sem quantidade negativa" do
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 1)
    path = operation_path(:decrement)

    results = race(path, path, path, lock_sql: item_lock)

    assert_equal [ 200, 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 0, 0, 0 ], owned_quantities(results)
    assert_equal [ 0 ], quantities
  end

  # Discrimina o *lost update*: dois decrementos lidos em Ruby veriam 2 e
  # gravariam 1; no banco, o segundo reavalia a linha já decrementada.
  test "dois decrementos simultâneos a partir de 2 terminam em 0" do
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 2)
    path = operation_path(:decrement)

    results = race(path, path, lock_sql: item_lock)

    assert_equal [ 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 0, 1 ], owned_quantities(results).sort
    assert_equal [ 0 ], quantities
  end

  # 1 + 1 − 1 = 1, em qualquer ordem, e o decremento nunca vê a linha em zero
  # por causa de um incremento perdido.
  test "incremento e decremento simultâneos a partir de 1 terminam em 1" do
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 1)

    results = race(operation_path(:increment), operation_path(:decrement), lock_sql: item_lock)

    assert_equal [ 200, 200 ], results.map { |s| s.response.status }
    assert_equal [ 1 ], quantities
  end
end
