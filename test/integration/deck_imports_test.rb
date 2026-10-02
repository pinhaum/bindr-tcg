require "test_helper"

# T17 (decks) — importar uma lista do OPTCG Simulator num deck novo
# (DCK-24, DCK-26..30, DCK-32, DCK-37).
class DeckImportsTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  # O exemplo do dono (2026-10-01): 15 linhas separadas por CR, com um CR
  # final, Leader OP17-079 e 50 cartas. O mesmo de `list_text_test.rb`.
  OWNER_EXAMPLE = "1xOP17-079\r3xOP17-086\r2xOP17-084\r4xOP17-094\r4xOP17-081\r4xOP17-080\r4xOP17-087\r" \
                  "4xOP17-095\r4xOP17-082\r4xOP15-088\r4xOP17-119\r4xOP17-093\r4xOP17-096\r3xST14-017\r2xOP07-085\r"

  OWNER_ENTRIES = { "OP17-086" => 3, "OP17-084" => 2, "OP17-094" => 4, "OP17-081" => 4, "OP17-080" => 4,
                    "OP17-087" => 4, "OP17-095" => 4, "OP17-082" => 4, "OP15-088" => 4, "OP17-119" => 4,
                    "OP17-093" => 4, "OP17-096" => 4, "ST14-017" => 3, "OP07-085" => 2 }.freeze

  # card_number => [tipo, custo, nome]; todas pretas.
  OWNER_CARDS = {
    "OP17-079" => [ "leader", nil, "Monkey.D.Luffy" ],
    "OP17-086" => [ "character", 1, "Nami" ],
    "OP17-084" => [ "character", 1, "Tony Tony.Chopper" ],
    "OP17-094" => [ "character", 1, "Rodo" ],
    "OP17-081" => [ "character", 2, "Gerd" ],
    "OP17-080" => [ "character", 2, "Usopp" ],
    "OP17-087" => [ "character", 2, "Nico Robin" ],
    "OP17-095" => [ "character", 2, "Roronoa Zoro" ],
    "OP17-082" => [ "character", 2, "Sanji" ],
    "OP15-088" => [ "character", 5, "Pirates Docking Six" ],
    "OP17-119" => [ "character", 6, "Loki" ],
    "OP17-093" => [ "character", 8, "Monkey.D.Luffy" ],
    "OP17-096" => [ "event", 1, "I'm Luffy!! The Man Who Will Be King of the Pirates!!" ],
    "ST14-017" => [ "stage", 1, "Thousand Sunny" ],
    "OP07-085" => [ "character", 9, "Stussy" ]
  }.freeze

  setup do
    @user = User.create!(email: "deck-t17@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT17", name: "Decks T17", kind: "booster")
    OWNER_CARDS.each do |number, (card_type, cost, name)|
      Card.create!(card_set: @set, card_number: number, name: name, card_type: card_type, cost: cost,
                   colors: [ "Black" ])
    end
  end

  def sign_in
    post session_path, params: { email: @user.email, password: PASSWORD }
  end

  def import(list, name: nil)
    post deck_imports_path, params: { deck_import: { name: name, list: list }.compact }
  end

  def entries_of(deck)
    deck.entries.reload.includes(:card).to_h { |entry| [ entry.card.card_number, entry.quantity ] }
  end

  def errors_shown
    css_select("[role='alert'] li").map { |li| li.text.squish }
  end

  # --- Caminho feliz (DCK-24, DCK-26, DCK-27) ---

  test "o exemplo do dono importa num deck com Leader OP17-079 e 50 cartas, com o nome do Leader" do
    sign_in

    assert_difference -> { @user.decks.count }, 1 do
      import(OWNER_EXAMPLE)
    end

    deck = @user.decks.order(:id).last
    assert_redirected_to deck_path(deck)
    assert_equal "OP17-079", deck.leader.card_number
    assert_equal "Monkey.D.Luffy", deck.name
    assert_equal 50, deck.main_total
    assert_equal OWNER_ENTRIES, entries_of(deck)

    # T12 — o deck importado já fica em edição.
    follow_redirect!
    assert_select "main p", text: "Em edição"
  end

  test "com nome informado, o deck leva esse nome" do
    sign_in

    import(OWNER_EXAMPLE, name: "  Luffy preto  ")

    assert_equal "Luffy preto", @user.decks.order(:id).last.name
  end

  test "importar duas vezes cria dois decks e não altera o primeiro" do
    sign_in
    import(OWNER_EXAMPLE)
    first = @user.decks.order(:id).last
    before = [ first.reload.name, first.leader_card_id, entries_of(first), first.updated_at ]

    assert_difference -> { @user.decks.count }, 1 do
      import(OWNER_EXAMPLE, name: "Outro")
    end

    assert_equal before, [ first.reload.name, first.leader_card_id, entries_of(first), first.updated_at ]
    assert_not_equal first.id, @user.decks.order(:id).last.id
  end

  # --- Tudo ou nada (DCK-28) ---

  test "uma linha ruim entre linhas boas não cria deck nem entrada e lista Linha N: motivo" do
    sign_in

    assert_no_difference [ -> { Deck.count }, -> { DeckEntry.count } ] do
      import("1xOP17-079\nquatro Rodo\n4xOP17-094\n4xOP99-999\n2xOP17-086")
    end

    assert_response :unprocessable_entity
    assert_equal [ "Linha 2: formato inválido; use <N>x<código>, como 4xOP01-016",
                   "Linha 4: OP99-999 não existe no catálogo" ], errors_shown
    # O texto colado volta no campo, para o usuário corrigir.
    assert_select "textarea[name='deck_import[list]'][aria-invalid='true'][aria-describedby='deck-list-error']",
                  text: /quatro Rodo/
  end

  test "lista vazia ou só com linhas em branco dá 422 com A lista não tem nenhuma carta" do
    sign_in

    [ "", "\r\n  \n\r" ].each do |list|
      assert_no_difference -> { Deck.count } do
        import(list)
      end

      assert_response :unprocessable_entity
      assert_equal [ "A lista não tem nenhuma carta" ], errors_shown
    end
  end

  test "sem o campo da lista, dá 422 com A lista não tem nenhuma carta" do
    sign_in

    assert_no_difference -> { Deck.count } do
      post deck_imports_path, params: { deck_import: { name: "Sem lista" } }
    end

    assert_response :unprocessable_entity
    assert_equal [ "A lista não tem nenhuma carta" ], errors_shown
  end

  # --- Limite (DCK-29) ---

  test "texto acima de 200 linhas dá 422 com o limite na mensagem, sem criar deck" do
    sign_in

    assert_no_difference -> { Deck.count } do
      import(Array.new(201, "1xOP17-094").join("\n"))
    end

    assert_response :unprocessable_entity
    assert_equal [ "A lista pode ter no máximo 200 linhas" ], errors_shown
  end

  test "texto acima de 10.000 caracteres dá 422 com o limite na mensagem, sem criar deck" do
    sign_in

    assert_no_difference -> { Deck.count } do
      import("1xOP17-079" + (" " * 10_000))
    end

    assert_response :unprocessable_entity
    assert_equal [ "A lista pode ter no máximo 10.000 caracteres" ], errors_shown
  end

  # --- Deck fora das regras (DCK-30) ---

  test "lista aceita com 5 cópias de uma carta cria o deck, e a página mostra inválido" do
    sign_in

    assert_difference -> { @user.decks.count }, 1 do
      import("1xOP17-079\n5xOP17-094")
    end

    deck = @user.decks.order(:id).last
    assert_equal({ "OP17-094" => 5 }, entries_of(deck))
    follow_redirect!
    assert_select "h2#deck-status-title", text: "Status: inválido"
  end

  # Spec-precision gap: o DCK-24 não diz o que acontece sem nome e sem Leader.
  # Sem nome para dar ao deck, a validação do nome recusa, e nada é criado.
  test "sem nome e sem Leader, o deck não é criado e o formulário pede um nome" do
    sign_in

    assert_no_difference [ -> { Deck.count }, -> { DeckEntry.count } ] do
      import("4xOP17-094")
    end

    assert_response :unprocessable_entity
    assert_select "#deck-name-error li", text: "O nome não pode ficar vazio."
    assert_select "input[name='deck_import[name]'][aria-invalid='true'][aria-describedby='deck-name-error']"
  end

  # --- Ida e volta (DCK-32) ---

  test "exportar e reimportar dá um deck com o mesmo Leader e as mesmas entradas" do
    sign_in
    import(OWNER_EXAMPLE)
    original = @user.decks.order(:id).last

    get deck_path(original, format: :txt)
    import(response.body, name: "Reimportado")

    copy = @user.decks.order(:id).last
    assert_not_equal original.id, copy.id
    assert_equal original.leader_card_id, copy.leader_card_id
    assert_equal entries_of(original), entries_of(copy)
  end

  # --- Página e navegação ---

  test "a página de importação tem o formulário com nome opcional e textarea" do
    sign_in

    get new_deck_import_path

    assert_response :success
    assert_select "form[action='#{deck_imports_path}'][method='post']" do
      assert_select "input[name='deck_import[name]']:not([required])"
      assert_select "textarea[name='deck_import[list]']"
    end
  end

  test "a lista de decks tem o link Importar lista" do
    sign_in

    get decks_path

    assert_select "a[href='#{new_deck_import_path}']", text: "Importar lista"
  end

  # --- Sessão (DCK-37) ---

  test "sem sessão, importar redireciona para o login sem criar nada" do
    assert_no_difference [ -> { Deck.count }, -> { DeckEntry.count } ] do
      import(OWNER_EXAMPLE)
    end
    assert_redirected_to new_session_path

    get new_deck_import_path
    assert_redirected_to new_session_path
  end
end
