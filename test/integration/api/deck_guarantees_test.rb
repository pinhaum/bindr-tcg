require "test_helper"

# T4 (spa-troca) — garantias de deck que viviam nos testes HTML e passam a ser
# provadas só pela API (STRO-23, STRO-31): o deck em edição é revalidado a cada
# leitura, o deck apagado no meio do pedido é 404 sem gravar, a leitura do deck
# não depende de a entrada continuar lá, o número de consultas não cresce com as
# entradas e o import aceita deck fora das regras e nunca reaproveita deck.
#
# Roda **fora** da transação do teste: o `INSERT` contra deck apagado dá
# violação de FK, que dentro de uma transação envenenaria o resto do teste, e a
# entrada que "some" é apagada por uma segunda conexão, que só enxerga o que foi
# commitado. O que o teste cria, o `teardown` apaga.
class Api::DeckGuaranteesTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  self.use_transactional_tests = false

  # Nomes únicos por execução: um `teardown` que não rodou antes não derruba a
  # próxima execução com `RecordNotUnique`.
  setup do
    suffix = SecureRandom.hex(4).upcase
    @user = User.create!(email: "api-deck-garantias-#{suffix.downcase}@example.com", password: PASSWORD)
    @other = User.create!(email: "api-deck-garantias-b-#{suffix.downcase}@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "SG4#{suffix}", name: "Deck garantias", kind: "booster")
    @leader = card!("SG4#{suffix}-001", card_type: "leader")
    @card = card!("SG4#{suffix}-002")
    @mine = Deck.create!(user: @user, name: "Meu", leader: @leader)
    sign_in
  end

  # Tolerante a setup parcial: o que não chegou a ser criado é `nil`, e o
  # `where(id: nil)` não apaga nada.
  teardown do
    user_ids = [ @user&.id, @other&.id ]
    deck_ids = Deck.where(user_id: user_ids).pluck(:id)
    DeckEntry.where(deck_id: deck_ids).delete_all
    Deck.where(id: deck_ids).delete_all
    Session.where(user_id: user_ids).delete_all
    User.where(id: user_ids).delete_all
    Card.where(set_id: @set&.id).delete_all
    CardSet.where(id: @set&.id).delete_all
  end

  def card!(number, card_type: "character")
    Card.create!(card_set: @set, card_number: number, name: "Carta #{number}", card_type: card_type,
                 colors: [ "Black" ])
  end

  def sign_in
    get "/api/session"
    token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: @user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => token }
    @token = response.parsed_body.dig("data", "csrf_token") || token
  end

  def send_json(verb, path, payload = nil)
    public_send(verb, path, params: payload&.to_json,
                            headers: { "Content-Type" => "application/json", "X-CSRF-Token" => @token })
  end

  def body = response.parsed_body

  def editing_deck_of(card)
    get "/api/cards/#{card.card_number}"
    assert_response :ok
    body.dig("data", "editing_deck")
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  # Troca o método de classe só durante o bloco, e sempre o devolve.
  def overriding(klass, name, impl)
    klass.define_singleton_method(name, &impl)
    yield
  ensure
    klass.singleton_class.send(:remove_method, name)
  end

  def entries_of(deck) = deck.entries.pluck(:card_id, :quantity).to_h

  # --- Deck em edição (deck_editing:71,86) ---

  test "o id de um deck que mudou de dono não vale, e a chave sai da sessão" do
    send_json :post, "/api/decks/#{@mine.id}/select"
    assert_response :ok
    assert_equal({ "id" => @mine.id, "name" => "Meu" }, body["data"])
    assert_equal @mine.id, session[:editing_deck_id], "pré-condição: o id do deck está na sessão"

    @mine.update!(user: @other)

    assert_nil editing_deck_of(@card)
    assert_nil session[:editing_deck_id]
  end

  test "excluir o deck em edição limpa a chave da sessão" do
    other_mine = Deck.create!(user: @user, name: "Outro meu")
    send_json :post, "/api/decks/#{@mine.id}/select"
    assert_equal @mine.id, editing_deck_of(@card)["id"], "pré-condição: o deck está em edição"

    send_json :delete, "/api/decks/#{@mine.id}"
    assert_response :ok

    assert_nil editing_deck_of(@card)
    assert_nil session[:editing_deck_id]
    assert_equal [ other_mine.id ], @user.decks.pluck(:id), "só o deck excluído saiu"
  end

  # --- Deck some no meio do pedido (deck_entries_concurrency:194,214) ---

  # Outra aba apaga o deck depois do `find` do deck e antes do `INSERT`. O stub
  # de `Card.find_by!` roda entre os dois, porque `set_card` vem depois de
  # `set_deck`.
  test "incremento contra deck apagado depois do find responde 404 sem gravar" do
    deck_id = @mine.id
    card = @card

    overriding(Card, :find_by!, lambda { |*|
      Deck.where(id: deck_id).delete_all
      card
    }) do
      send_json :post, "/api/decks/#{deck_id}/cards/#{card.card_number}/increment"
    end

    assert_response :not_found
    assert_equal "not_found", body.dig("error", "code")
    assert_not Deck.exists?(deck_id)
    assert_not DeckEntry.exists?(card_id: card.id)
  end

  # Uma entrada some (decremento em outra conexão, já commitado) entre o `find`
  # do deck e a `DeckShortfallQuery`. No retrato único, a leitura ainda vê a
  # entrada nas duas consultas e responde 200, sem `KeyError`.
  test "GET /api/decks/:id não levanta erro quando a entrada some entre as leituras" do
    @mine.entries.create!(card: @card, quantity: 2)
    real_new = DeckShortfallQuery.method(:new)
    pool = ActiveRecord::Base.connection_pool
    deck_id = @mine.id

    overriding(DeckShortfallQuery, :new, lambda { |*args, **kwargs|
      other = pool.checkout
      begin
        other.execute("DELETE FROM deck_entries WHERE deck_id = #{Integer(deck_id)}")
      ensure
        pool.checkin(other)
      end
      real_new.call(*args, **kwargs)
    }) do
      get "/api/decks/#{deck_id}"
    end

    assert_response :ok
    entry = body.dig("data", "entries").find { |line| line["card_number"] == @card.card_number }
    assert_equal [ 2, 2, 0 ], entry.values_at("quantity", "required", "owned")
    assert_equal 2, entry["missing"]
    assert_empty DeckEntry.where(deck_id: deck_id)
  end

  # --- Consultas (deck_page:217) ---

  test "o número de consultas de GET /api/decks/:id é o mesmo com 2 e com 20 entradas" do
    small = Deck.create!(user: @user, name: "Pequeno", leader: @leader)
    big = Deck.create!(user: @user, name: "Grande", leader: @leader)
    cards = (3..22).map { |n| card!(format("#{@set.code}-%03d", n)) }
    cards.first(2).each { |card| small.entries.create!(card: card, quantity: 1) }
    cards.each { |card| big.entries.create!(card: card, quantity: 2) }

    get "/api/decks/#{@mine.id}" # aquece o que só a primeira leitura paga
    small_count = count_queries { get "/api/decks/#{small.id}" }
    assert_response :ok
    assert_equal 2, body.dig("data", "entries").size
    big_count = count_queries { get "/api/decks/#{big.id}" }
    assert_response :ok
    assert_equal 20, body.dig("data", "entries").size

    assert_equal small_count, big_count
  end

  # --- Import (deck_imports:92,173) ---

  test "importar uma lista com 5 cópias cria o deck e ele sai com status invalid" do
    card_number = @card.card_number

    assert_difference -> { @user.decks.count }, 1 do
      send_json :post, "/api/decks/import", { name: "Cinco", list: "1x#{@leader.card_number}\n5x#{card_number}" }
    end

    assert_response :created
    assert_equal "invalid", body.dig("data", "status")
    deck = @user.decks.find_by!(name: "Cinco")
    assert_equal({ @card.id => 5 }, entries_of(deck))
  end

  test "importar a mesma lista duas vezes cria dois decks e não altera o primeiro" do
    list = "1x#{@leader.card_number}\n3x#{@card.card_number}"
    send_json :post, "/api/decks/import", { name: "Primeiro", list: list }
    assert_response :created
    first = @user.decks.find(body.dig("data", "id"))
    before = [ first.name, first.leader_card_id, entries_of(first), first.updated_at ]

    assert_difference -> { @user.decks.count }, 1 do
      send_json :post, "/api/decks/import", { name: "Segundo", list: list }
    end

    assert_response :created
    assert_not_equal first.id, body.dig("data", "id")
    assert_equal before, [ first.reload.name, first.leader_card_id, entries_of(first), first.updated_at ]
  end
end
