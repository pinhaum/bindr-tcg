require "test_helper"
require "stringio"

# SPOR-42: duas confirmações simultâneas do mesmo token — uma 200, uma 409 e a
# coleção gravada uma só vez. Roda fora da transação do teste, para que cada
# thread tenha a sua conexão (mesma técnica de `card_variants_concurrency_test`).
#
# A sobreposição é forçada: uma conexão à parte trava a linha do staging, as
# duas requisições disparam, o teste espera ambas paradas no `Lock` e só então
# solta a trava.
class Api::CollectionImportsConcurrencyTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  LOCK_WAIT_TIMEOUT = 10

  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4).upcase
    @user = User.create!(email: "api-import-corrida-#{suffix.downcase}@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "SC5#{suffix}", name: "Import corrida", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "SC5#{suffix}-001", name: "Carta", card_type: "character",
                         colors: [ "Black" ])
    @variant = CardVariant.create!(card: @card, card_set: @set, variant_code: "tcgplayer:#{suffix}",
                                   rarity: "R", art_kind: "base", last_seen_at: Time.current,
                                   image_url: "https://cdn.example.com/#{suffix}.png")
    @csv = "card_number,variant_code,card_name,quantity\n#{@card.card_number},#{@variant.variant_code},Carta,3\n"
  end

  teardown do
    CollectionImport.where(user_id: @user&.id).delete_all
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
      s.instance_variable_set(:@csrf, s.response.parsed_body.dig("data", "csrf_token"))
    end
  end

  def upload_token
    s = sign_in_session
    file = Rack::Test::UploadedFile.new(StringIO.new(@csv), "text/csv", original_filename: "colecao.csv")
    s.post "/api/collection/imports", params: { file: file },
                                      headers: { "X-CSRF-Token" => s.instance_variable_get(:@csrf) }
    assert_equal 201, s.response.status
    s.response.parsed_body.dig("data", "token")
  end

  def race_confirm(token, lock_sql:)
    sessions = 2.times.map { sign_in_session }
    pool = ActiveRecord::Base.connection_pool
    holder = pool.checkout
    holder.begin_db_transaction
    locked = true
    holder.execute(lock_sql)

    workers = sessions.map do |s|
      Thread.new do
        pool.with_connection do
          s.post "/api/collection/imports/#{token}/confirm",
                 headers: { "X-CSRF-Token" => s.instance_variable_get(:@csrf) }
        end
        s
      end
    end

    wait_until_blocked(2)
    holder.commit_db_transaction
    locked = false
    workers.map(&:value)
  ensure
    if holder
      holder.rollback_db_transaction if locked
      pool.checkin(holder)
    end
    workers&.each(&:join)
  end

  def wait_until_blocked(count)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + LOCK_WAIT_TIMEOUT
    loop do
      blocked = ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value(<<~SQL) }.to_i
        -- countBlockedImportConfirmations
        SELECT count(*) FROM pg_stat_activity
        WHERE datname = current_database()
          AND pid <> pg_backend_pid()
          AND wait_event_type = 'Lock'
      SQL
      return if blocked >= count

      flunk "esperava #{count} confirmações bloqueadas, vi #{blocked}" if
        Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.01
    end
  end

  test "duas confirmações simultâneas do mesmo token: uma 200, uma 409, gravada uma vez" do
    token = upload_token
    staging = CollectionImport.find_by!(user: @user)

    results = race_confirm(token, lock_sql: "SELECT 1 FROM collection_imports WHERE id = #{Integer(staging.id)} FOR UPDATE")

    assert_equal [ 200, 409 ], results.map { |s| s.response.status }.sort
    assert_equal [ 3 ], CollectionItem.where(user_id: @user.id).pluck(:quantity)
    assert_equal "confirmado", staging.reload.status
  end
end
