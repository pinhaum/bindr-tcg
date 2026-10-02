require "test_helper"

# T8 (decks) — lista e criação de deck (DCK-01, DCK-08, DCK-36, DCK-37, DCK-39).
#
# Integração sobre o HTML renderizado: não há navegador no container
# (SPEC_DEVIATION do projeto).
class DecksTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "deck-t8@example.com", password: PASSWORD)
    @other = User.create!(email: "deck-t8-outro@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT08", name: "Decks T8", kind: "booster")
    @leader = create_card("DT08-001", name: "Leader Preto", card_type: "leader")
  end

  def create_card(number, name: "Carta #{number}", card_type: "character", colors: [ "Black" ])
    Card.create!(card_set: @set, card_number: number, name: name, card_type: card_type, colors: colors)
  end

  def create_deck(user: @user, name: "Deck", leader: nil, entries: {})
    Deck.create!(user: user, name: name, leader: leader).tap do |deck|
      entries.each { |card, quantity| deck.entries.create!(card: card, quantity: quantity) }
    end
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # O `<li>` de um deck na lista, achado pelo link com o nome dele.
  def deck_item(deck)
    css_select("main li").find { |li| li.at_css("a[href='#{deck_path(deck)}']") }
  end

  def field(item, label)
    item.css("dt").find { |dt| dt.text.strip == label }&.next_element&.text&.strip
  end

  # --- Criar (DCK-01) ---

  test "criar com um nome gera um deck vazio do usuário da sessão e abre a página dele" do
    sign_in

    assert_difference -> { Deck.count }, 1 do
      post decks_path, params: { deck: { name: "Luffy Preto" } }
    end

    deck = Deck.order(:id).last
    assert_equal [ @user.id, "Luffy Preto", nil, 0 ],
                 [ deck.user_id, deck.name, deck.leader_card_id, deck.entries.count ]
    assert_redirected_to deck_path(deck)

    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Luffy Preto"
  end

  # Req. 6.5 — o dono vem da sessão: um `user_id` no corpo não muda nada.
  test "user_id no corpo do formulário é ignorado" do
    sign_in

    post decks_path, params: { deck: { name: "Meu", user_id: @other.id } }

    assert_equal @user.id, Deck.order(:id).last.user_id
  end

  test "a página de novo deck tem o formulário de nome" do
    sign_in

    get new_deck_path

    assert_response :success
    assert_select "form[action='#{decks_path}'][method='post'] input[name='deck[name]']"
  end

  # --- Nome inválido (DCK-39) ---

  test "nome vazio re-renderiza com 422 e mensagem em português, sem criar nada" do
    sign_in

    assert_no_difference -> { Deck.count } do
      post decks_path, params: { deck: { name: "   " } }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", text: "O nome não pode ficar vazio."
  end

  # T24 (achado M3 da revisão de a11y) — o erro fica ligado ao campo.
  test "com nome inválido, o campo tem aria-invalid e aria-describedby para a mensagem" do
    sign_in

    post decks_path, params: { deck: { name: "" } }

    assert_select "input[name='deck[name]'][aria-invalid='true'][aria-describedby='deck-name-error']"
    assert_select "#deck-name-error li", text: "O nome não pode ficar vazio."
  end

  test "sem erro, o campo não tem aria-invalid nem aria-describedby, e o rótulo diz o limite" do
    sign_in

    get new_deck_path

    assert_select "input[name='deck[name]']" do |inputs|
      assert_nil inputs.first["aria-invalid"]
      assert_nil inputs.first["aria-describedby"]
    end
    assert_select "label[for='deck_name']" do |labels|
      assert_equal "Nome do deck (até 60 caracteres)", labels.first.text.squish
    end
  end

  test "nome de 61 caracteres re-renderiza com 422 e mensagem em português, sem criar nada" do
    sign_in

    assert_no_difference -> { Deck.count } do
      post decks_path, params: { deck: { name: "a" * 61 } }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", text: "O nome pode ter no máximo 60 caracteres."
  end

  # --- Lista (DCK-08) ---

  test "a lista mostra cada deck do usuário com nome, Leader, N / 50 e status em português" do
    cards = (2..14).map { |n| create_card(format("DT08-%03d", n)) }
    full = cards.first(12).to_h { |card| [ card, 4 ] }.merge(cards.last => 2)
    valid = create_deck(name: "Completo", leader: @leader, entries: full)
    incomplete = create_deck(name: "Sem Leader", entries: { cards.first => 3 })
    invalid = create_deck(name: "Cinco cópias", leader: @leader, entries: { cards.first => 5 })
    sign_in

    get decks_path

    assert_response :success
    assert_equal [ "Leader Preto (DT08-001)", "50 / 50", "válido" ],
                 [ "Leader", "Cartas", "Status" ].map { |label| field(deck_item(valid), label) }
    assert_equal [ "Sem Leader", "3 / 50", "incompleto" ],
                 [ "Leader", "Cartas", "Status" ].map { |label| field(deck_item(incomplete), label) }
    assert_equal [ "Leader Preto (DT08-001)", "5 / 50", "inválido" ],
                 [ "Leader", "Cartas", "Status" ].map { |label| field(deck_item(invalid), label) }
  end

  test "a lista não mostra decks de outro usuário" do
    mine = create_deck(name: "Meu deck")
    alien = create_deck(user: @other, name: "Deck alheio")
    sign_in

    get decks_path

    assert_select "main a[href='#{deck_path(mine)}']", text: "Meu deck"
    assert_select "main a[href='#{deck_path(alien)}']", count: 0
    assert_no_match(/Deck alheio/, response.body)
  end

  # --- Isolamento (DCK-36) ---

  test "abrir o deck de outro usuário dá 404" do
    alien = create_deck(user: @other, name: "Deck alheio")
    sign_in

    get deck_path(alien)

    assert_response :not_found
  end

  # --- Sem sessão (DCK-37) ---

  test "sem sessão, toda rota de deck redireciona para o login" do
    deck = create_deck

    [ decks_path, new_deck_path, deck_path(deck) ].each do |path|
      get path
      assert_redirected_to new_session_path, "GET #{path} deveria redirecionar"
    end
  end

  test "sem sessão, criar redireciona para o login sem criar nada" do
    assert_no_difference -> { Deck.count } do
      post decks_path, params: { deck: { name: "Anônimo" } }
    end

    assert_redirected_to new_session_path
  end

  # --- Navegação ---

  test "Baralhos aparece na navegação com sessão e tem aria-current na lista de decks" do
    sign_in

    get decks_path

    assert_select "nav[aria-label='Principal'] a[href='#{decks_path}'][aria-current='page']", text: "Baralhos"
  end

  test "Baralhos não aparece na navegação sem sessão" do
    get catalog_path

    assert_select "nav[aria-label='Principal'] a[href='#{decks_path}']", count: 0
  end
end
