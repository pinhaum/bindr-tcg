require "test_helper"

# T8 (spa-decks) — importar a lista do OPTCG Simulator pela API (SDEC-46, SDEC-57, SDEC-58, SDEC-60).
class Api::DeckImportsTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  REFUSED = "A lista não foi importada. Nenhum deck foi criado.".freeze

  setup do
    @user = User.create!(email: "nami-api-imp@example.com", password: PASSWORD)
    @other = User.create!(email: "zoro-api-imp@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "AI03", name: "Api Import", kind: "booster")
    @leader = card!("AI03-001", name: "Leader Preto", card_type: "leader")
    @main = card!("AI03-002", name: "Carta Dois")
    @other_main = card!("AI03-003", name: "Carta Tres")
    sign_in
  end

  def card!(number, name:, card_type: "character")
    Card.create!(card_set: @set, card_number: number, name: name, card_type: card_type, colors: [ "Black" ])
  end

  def sign_in(user = @user)
    get "/api/session"
    @token = response.parsed_body.dig("data", "csrf_token")
    post "/api/session", params: { email: user.email, password: PASSWORD }.to_json,
                         headers: { "Content-Type" => "application/json", "X-CSRF-Token" => @token }
    @token = response.parsed_body.dig("data", "csrf_token") || @token
  end

  def import(payload, token: @token)
    headers = { "Content-Type" => "application/json" }
    headers["X-CSRF-Token"] = token if token
    post "/api/decks/import", params: payload.is_a?(String) ? payload : payload.to_json, headers: headers
  end

  def body = response.parsed_body

  def valid_list = "1xAI03-001\n25xAI03-002\n25xAI03-003"

  test "o texto exportado é importado com o mesmo Leader e as mesmas entradas, e o deck fica em edição" do
    source = Deck.create!(user: @user, name: "Origem", leader: @leader)
    source.entries.create!(card: @main, quantity: 25)
    source.entries.create!(card: @other_main, quantity: 25)
    get "/decks/#{source.id}.txt"
    assert_response :success
    exported = response.body

    assert_difference -> { @user.decks.count }, 1 do
      import({ name: "Copia", list: exported })
    end

    assert_response :created
    deck = @user.decks.find_by!(name: "Copia")
    assert_equal @leader, deck.leader
    assert_equal({ @main.id => 25, @other_main.id => 25 }, deck.entries.pluck(:card_id, :quantity).to_h)
    assert_equal deck.id, body.dig("data", "id")
    assert_equal true, body.dig("data", "editing")
    assert_equal "AI03-001", body.dig("data", "leader", "card_number")
  end

  test "sem nome, o deck leva o nome do Leader" do
    import({ list: valid_list })

    assert_response :created
    assert_equal "Leader Preto", body.dig("data", "name")
  end

  test "sem nome e sem Leader, o nome vazio é recusado e nada é criado" do
    assert_no_difference -> { Deck.count } do
      import({ list: "4xAI03-002" })
    end

    assert_response :unprocessable_entity
    assert_equal "validation_failed", body.dig("error", "code")
    assert_equal [ "O nome não pode ficar vazio." ], body.dig("error", "fields", "name")
  end

  test "linhas ruins voltam em fields.list na ordem, com a mensagem de nada criado" do
    list = "1xAI03-001\nnada\n24xAI03-002\n\n99xAI03-003"

    assert_no_difference -> { Deck.count } do
      import({ list: list })
    end

    assert_response :unprocessable_entity
    assert_equal REFUSED, body.dig("error", "message")
    lines = body.dig("error", "fields", "list")
    assert_equal 2, lines.size
    assert_match(/\ALinha 2: /, lines[0])
    assert_match(/\ALinha 5: /, lines[1])
  end

  test "mais de 200 linhas e mais de 10.000 caracteres recusam pelo limite, sem número de linha" do
    assert_no_difference -> { Deck.count } do
      import({ list: ([ "1xAI03-002" ] * 201).join("\n") })
      assert_response :unprocessable_entity
      assert_equal [ "A lista pode ter no máximo 200 linhas" ], body.dig("error", "fields", "list")

      import({ list: "x" * 10_001 })
      assert_response :unprocessable_entity
      assert_equal [ "A lista pode ter no máximo 10.000 caracteres" ], body.dig("error", "fields", "list")
    end
  end

  test "lista ausente ou que não é texto recusa por lista vazia" do
    assert_no_difference -> { Deck.count } do
      import({ name: "X" })
      assert_response :unprocessable_entity
      assert_equal REFUSED, body.dig("error", "message")
      assert_equal [ Deck::ListText::EMPTY_LIST ], body.dig("error", "fields", "list")

      import({ name: "X", list: [ "4xAI03-002" ] })
      assert_response :unprocessable_entity
      assert_equal [ Deck::ListText::EMPTY_LIST ], body.dig("error", "fields", "list")
    end
  end

  test "sem sessão é 401 e nada é criado" do
    delete "/api/session", headers: { "X-CSRF-Token" => @token }
    assert_no_difference -> { Deck.count } do
      import({ list: valid_list }, token: nil)
    end

    assert_response :unauthorized
    assert_equal "unauthenticated", body.dig("error", "code")
  end

  test "sem token CSRF é 422 invalid_csrf_token e nada é criado" do
    assert_no_difference -> { Deck.count } do
      with_forgery_protection { import({ list: valid_list }, token: nil) }
    end

    assert_response :unprocessable_entity
    assert_equal "invalid_csrf_token", body.dig("error", "code")
  end

  test "user_id do corpo é ignorado: o deck é de quem está na sessão" do
    import({ list: valid_list, user_id: @other.id })

    assert_response :created
    assert_equal 1, @user.decks.count
    assert_equal 0, @other.decks.count
  end

  private
    def with_forgery_protection
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
end
