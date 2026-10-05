require "test_helper"

# T12 (decks) — o deck em edição na sessão (DCK-41, DCK-36).
class DeckEditingTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "deck-t12@example.com", password: PASSWORD)
    @other = User.create!(email: "deck-t12-outro@example.com", password: PASSWORD)
    @mine = Deck.create!(user: @user, name: "Meu")
    @alien = Deck.create!(user: @other, name: "Alheio")
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def assert_editing_marker(deck, editing:)
    get deck_path(deck)
    assert_response :success
    if editing
      assert_select "main p", text: "Em edição"
      assert_select "form[action='#{select_deck_path(deck)}']", count: 0
    else
      assert_select "main p", text: "Em edição", count: 0
      assert_select "form[action='#{select_deck_path(deck)}'] button", text: "Editar este deck"
    end
  end

  test "criar um deck o deixa em edição" do
    sign_in

    post decks_path, params: { deck: { name: "Novo" } }
    created = Deck.order(:id).last

    assert_equal created.id, session[:editing_deck_id]
    assert_editing_marker(created, editing: true)
    assert_editing_marker(@mine, editing: false)
  end

  test "select troca o deck em edição" do
    sign_in
    post decks_path, params: { deck: { name: "Novo" } }

    post select_deck_path(@mine)

    assert_redirected_to deck_path(@mine)
    assert_equal @mine.id, session[:editing_deck_id]
    assert_editing_marker(@mine, editing: true)
  end

  test "select de deck de outro usuário dá 404 e não altera a sessão" do
    sign_in
    post select_deck_path(@mine)

    post select_deck_path(@alien)

    assert_response :not_found
    assert_equal @mine.id, session[:editing_deck_id]
  end

  test "sem sessão, select redireciona para o login sem marcar nada" do
    post select_deck_path(@mine)

    assert_redirected_to new_session_path
    assert_nil session[:editing_deck_id]
  end

  # DCK-41 — o deck excluído deixa de ser o deck em edição, e a chave sai da
  # sessão na primeira leitura.
  test "depois de excluído o deck em edição, ele deixa de valer e a chave sai da sessão" do
    sign_in
    post select_deck_path(@mine)
    other_mine = Deck.create!(user: @user, name: "Outro meu")

    delete deck_path(@mine)
    assert_editing_marker(other_mine, editing: false)

    assert_nil session[:editing_deck_id]
  end

  # DCK-36 — login e logout chamam `reset_session`, então a herança entre
  # contas no mesmo navegador não planta mais um id alheio. A revalidação
  # continua sendo a garantia: aqui o deck em edição muda de dono enquanto o id
  # está na sessão, e passa a ser de outro usuário sem a sessão saber.
  test "um id de deck de outro usuário na sessão não é aceito" do
    sign_in(@user)
    post select_deck_path(@mine)
    @mine.update!(user: @other)
    assert_equal @mine.id, session[:editing_deck_id], "pré-condição: o id do deck alheio está na sessão"

    assert_editing_marker(Deck.create!(user: @user, name: "Outro"), editing: false)

    assert_nil session[:editing_deck_id]
  end
end
