require "test_helper"

# T14 (decks) — "Usar como Leader" (DCK-04, DCK-36).
class DeckLeaderTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  TURBO_STREAM = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }.freeze

  setup do
    @user = User.create!(email: "deck-t14@example.com", password: PASSWORD)
    @other = User.create!(email: "deck-t14-outro@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT14", name: "Decks T14", kind: "booster")
    @first = create_card("DT14-001", "Primeiro Leader", "leader")
    @second = create_card("DT14-002", "Segundo Leader", "leader")
    @card = create_card("DT14-010", "Carta", "character")
    @deck = Deck.create!(user: @user, name: "Meu deck")
    @deck.entries.create!(card: @card, quantity: 3)
  end

  def create_card(number, name, card_type)
    Card.create!(card_set: @set, card_number: number, name: name, card_type: card_type, colors: [ "Black" ])
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def entries_of(deck)
    deck.entries.reload.pluck(:card_id, :quantity)
  end

  test "usar um Leader num deck sem Leader grava, e usar outro o substitui sem mudar as entradas" do
    sign_in

    post deck_leader_path(@deck), params: { card_id: @first.id }, headers: { "Referer" => card_url("DT14-001") }
    assert_redirected_to card_path("DT14-001")
    assert_equal @first.id, @deck.reload.leader_card_id

    post deck_leader_path(@deck), params: { card_id: @second.id }
    assert_equal @second.id, @deck.reload.leader_card_id
    assert_equal [ [ @card.id, 3 ] ], entries_of(@deck)
  end

  test "com Accept turbo-stream, a resposta troca o controle da carta pela indicação de Leader" do
    sign_in

    post deck_leader_path(@deck), params: { card_id: @first.id }, headers: TURBO_STREAM

    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action='update'][target='deck_entry_card_#{@first.id}'] template" do |template|
      assert_includes template.first.inner_html, "Primeiro Leader é o Leader deste deck"
    end
    assert_equal @first.id, @deck.reload.leader_card_id
  end

  test "carta que não é Leader dá 422 sem gravar" do
    @deck.update!(leader: @first)
    sign_in

    post deck_leader_path(@deck), params: { card_id: @card.id }

    assert_response :unprocessable_entity
    assert_equal @first.id, @deck.reload.leader_card_id
    assert_equal [ [ @card.id, 3 ] ], entries_of(@deck)
  end

  test "deck de outro usuário dá 404 sem gravar" do
    alien = Deck.create!(user: @other, name: "Alheio", leader: @first)
    sign_in

    post deck_leader_path(alien), params: { card_id: @second.id }

    assert_response :not_found
    assert_equal @first.id, alien.reload.leader_card_id
  end

  test "sem sessão, redireciona para o login sem gravar" do
    post deck_leader_path(@deck), params: { card_id: @first.id }

    assert_redirected_to new_session_path
    assert_nil @deck.reload.leader_card_id
  end
end
