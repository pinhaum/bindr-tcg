require "test_helper"

# T13 (decks) — incremento e decremento de carta no deck (DCK-05, DCK-06,
# DCK-18, DCK-36, DCK-37, DCK-39). A corrida (DCK-38) fica em
# `deck_entries_concurrency_test.rb`, que precisa rodar fora da transação do
# teste.
class DeckEntriesTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  TURBO_STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    @user = User.create!(email: "deck-t13@example.com", password: PASSWORD)
    @other = User.create!(email: "deck-t13-outro@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT13", name: "Decks T13", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "DT13-002", name: "Carta Preta", card_type: "character",
                         colors: [ "Black" ])
    @leader = Card.create!(card_set: @set, card_number: "DT13-001", name: "Leader Preto", card_type: "leader",
                           colors: [ "Black" ])
    @deck = Deck.create!(user: @user, name: "Meu deck")
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def quantity_in(deck = @deck, card = @card)
    DeckEntry.where(deck: deck, card: card).pick(:quantity)
  end

  # --- Incremento (DCK-05, DCK-18) ---

  test "o incremento de carta nova cria a entrada com 1, e o seguinte leva a 2" do
    sign_in

    post increment_deck_card_path(@deck, @card)
    assert_equal 1, quantity_in

    post increment_deck_card_path(@deck, @card)
    assert_equal 2, quantity_in
    assert_equal 1, DeckEntry.where(deck: @deck, card: @card).count
  end

  # DCK-18 — 4 é o máximo do jogo, mas a regra só muda o status.
  test "a 5ª cópia é aceita e gravada" do
    @deck.entries.create!(card: @card, quantity: 4)
    sign_in

    post increment_deck_card_path(@deck, @card)

    assert_equal 5, quantity_in
    assert_equal :invalid, @deck.reload.legality.status
  end

  # DCK-39 — 50 é limite do modelo, não regra de jogo.
  test "em 50, o incremento é recusado com alerta em português e a quantidade fica em 50" do
    @deck.entries.create!(card: @card, quantity: 50)
    sign_in

    post increment_deck_card_path(@deck, @card), headers: { "Referer" => deck_url(@deck) }

    assert_redirected_to deck_path(@deck)
    assert_equal "O máximo é 50 cópias por carta no deck.", flash[:alert]
    assert_equal 50, quantity_in
  end

  test "carta Leader enviada a increment dá 422 sem gravar" do
    sign_in

    assert_no_difference -> { DeckEntry.count } do
      post increment_deck_card_path(@deck, @leader)
    end

    assert_response :unprocessable_entity
    assert_nil @deck.reload.leader_card_id
  end

  # --- Decremento (DCK-06) ---

  test "o decremento leva 2 a 1 e, em 1, remove a entrada" do
    @deck.entries.create!(card: @card, quantity: 2)
    sign_in

    post decrement_deck_card_path(@deck, @card)
    assert_equal 1, quantity_in

    post decrement_deck_card_path(@deck, @card)
    assert_not DeckEntry.exists?(deck: @deck, card: @card)
  end

  test "sem entrada, o decremento não cria nada" do
    sign_in

    assert_no_difference -> { DeckEntry.count } do
      post decrement_deck_card_path(@deck, @card), headers: { "Referer" => deck_url(@deck) }
    end

    assert_redirected_to deck_path(@deck)
    assert_equal "DT13-002 não está no deck “Meu deck”.", flash[:alert]
  end

  # --- Resposta dupla (DCK-05) ---

  test "com Accept turbo-stream, a resposta atualiza o alvo da carta com a quantidade nova" do
    @deck.entries.create!(card: @card, quantity: 2)
    sign_in

    post increment_deck_card_path(@deck, @card), headers: TURBO_STREAM

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='update'][target='deck_entry_card_#{@card.id}'] template" do |template|
      assert_includes template.first.inner_html, "3 cópias de Carta Preta no deck"
    end
    assert_equal 3, quantity_in
  end

  test "o decremento que remove a entrada responde o Stream com zero" do
    @deck.entries.create!(card: @card, quantity: 1)
    sign_in

    post decrement_deck_card_path(@deck, @card), headers: TURBO_STREAM

    assert_select "turbo-stream[action='update'][target='deck_entry_card_#{@card.id}'] template" do |template|
      assert_includes template.first.inner_html, "0 cópias de Carta Preta no deck"
    end
  end

  test "sem o header de Turbo Stream, o incremento redireciona" do
    sign_in

    post increment_deck_card_path(@deck, @card), headers: { "Referer" => card_url(@card.card_number) }

    assert_redirected_to card_path(@card.card_number)
    assert_equal "DT13-002: 1 cópia no deck “Meu deck”.", flash[:notice]
  end

  test "um Referer de outro host cai no deck" do
    sign_in

    post increment_deck_card_path(@deck, @card), headers: { "Referer" => "https://evil.example/x" }

    assert_redirected_to deck_path(@deck)
  end

  # --- Isolamento (DCK-36) e sessão (DCK-37) ---

  test "deck de outro usuário dá 404 sem gravar" do
    alien = Deck.create!(user: @other, name: "Alheio")
    alien.entries.create!(card: @card, quantity: 2)
    sign_in

    post increment_deck_card_path(alien, @card)
    assert_response :not_found

    post decrement_deck_card_path(alien, @card)
    assert_response :not_found

    assert_equal 2, quantity_in(alien)
  end

  test "sem sessão, incremento e decremento redirecionam sem gravar" do
    @deck.entries.create!(card: @card, quantity: 2)

    post increment_deck_card_path(@deck, @card)
    assert_redirected_to new_session_path

    post decrement_deck_card_path(@deck, @card)
    assert_redirected_to new_session_path

    assert_equal 2, quantity_in
  end
end
