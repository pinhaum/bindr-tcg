require "test_helper"

# T11 (decks) — renomear e excluir, com a exclusão confirmada em página
# própria (DCK-09, DCK-10, DCK-36, DCK-39).
class DeckRenameDeleteTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "deck-t11@example.com", password: PASSWORD)
    @other = User.create!(email: "deck-t11-outro@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "DT11", name: "Decks T11", kind: "booster")
    @leader = Card.create!(card_set: @set, card_number: "DT11-001", name: "Leader", card_type: "leader",
                           colors: [ "Black" ])
    @card = Card.create!(card_set: @set, card_number: "DT11-002", name: "Carta", card_type: "character",
                         colors: [ "Black" ])
    @variant = CardVariant.create!(card: @card, card_set: @set, variant_code: "tcgplayer:dt11-002", art_kind: "base")
    mark_catalog_present!
    @deck = create_deck(user: @user, name: "Original")
  end

  def create_deck(user:, name:)
    Deck.create!(user: user, name: name, leader: @leader).tap { |deck| deck.entries.create!(card: @card, quantity: 3) }
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def snapshot(deck)
    deck.reload
    [ deck.name, deck.leader_card_id, deck.entries.pluck(:card_id, :quantity) ]
  end

  # --- Renomear (DCK-10) ---

  test "renomear grava o nome novo e mantém Leader e entradas" do
    sign_in

    patch deck_path(@deck), params: { deck: { name: "Novo nome" } }

    assert_redirected_to deck_path(@deck)
    assert_equal [ "Novo nome", @leader.id, [ [ @card.id, 3 ] ] ], snapshot(@deck)
  end

  test "a página de renomear traz o formulário com o nome atual" do
    sign_in

    get edit_deck_path(@deck)

    assert_response :success
    assert_select "form[action='#{deck_path(@deck)}'] input[name='deck[name]'][value='Original']"
  end

  test "renomear com nome vazio dá 422 sem gravar" do
    sign_in

    patch deck_path(@deck), params: { deck: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", text: "O nome não pode ficar vazio."
    assert_equal [ "Original", @leader.id, [ [ @card.id, 3 ] ] ], snapshot(@deck)
  end

  test "renomear com 61 caracteres dá 422 sem gravar" do
    sign_in

    patch deck_path(@deck), params: { deck: { name: "a" * 61 } }

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", text: "O nome pode ter no máximo 60 caracteres."
    assert_equal "Original", @deck.reload.name
  end

  # --- Excluir (DCK-09) ---

  test "a página de confirmação mostra o pedido sem apagar nada" do
    sign_in

    assert_no_changes -> { [ Deck.count, DeckEntry.count ] } do
      get delete_deck_path(@deck)
    end

    assert_response :success
    assert_select "h1", text: "Excluir o deck “Original”?"
    assert_select "form[action='#{deck_path(@deck)}'] input[name='_method'][value='delete']"
  end

  test "DELETE apaga o deck e as entradas dele" do
    kept = create_deck(user: @user, name: "Fica")
    sign_in

    delete deck_path(@deck)

    assert_redirected_to decks_path
    assert_not Deck.exists?(@deck.id)
    assert_equal 0, DeckEntry.where(deck_id: @deck.id).count
    assert_equal [ "Fica", @leader.id, [ [ @card.id, 3 ] ] ], snapshot(kept)
  end

  test "excluir não muda nenhum collection_item nem wishlist_item" do
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 2)
    WishlistItem.create!(user: @user, card_variant: @variant, target_quantity: 4)
    sign_in

    assert_no_changes -> { CollectionItem.order(:id).pluck(:id, :user_id, :card_variant_id, :quantity) } do
      assert_no_changes -> { WishlistItem.order(:id).pluck(:id, :user_id, :card_variant_id, :target_quantity) } do
        delete deck_path(@deck)
      end
    end
    assert_not Deck.exists?(@deck.id)
  end

  # --- Isolamento (DCK-36) ---

  test "renomear deck de outro usuário dá 404 sem alterar nada" do
    sign_in(@other)

    patch deck_path(@deck), params: { deck: { name: "Roubado" } }

    assert_response :not_found
    assert_equal [ "Original", @leader.id, [ [ @card.id, 3 ] ] ], snapshot(@deck)
  end

  test "abrir a edição ou a confirmação de deck de outro usuário dá 404" do
    sign_in(@other)

    get edit_deck_path(@deck)
    assert_response :not_found

    get delete_deck_path(@deck)
    assert_response :not_found
  end

  test "excluir deck de outro usuário dá 404 sem apagar nada" do
    sign_in(@other)

    assert_no_changes -> { [ Deck.count, DeckEntry.count ] } do
      delete deck_path(@deck)
    end

    assert_response :not_found
  end

  # --- Sem sessão (DCK-37) ---

  test "sem sessão, renomear e excluir redirecionam para o login sem alterar nada" do
    patch deck_path(@deck), params: { deck: { name: "Anônimo" } }
    assert_redirected_to new_session_path

    delete deck_path(@deck)
    assert_redirected_to new_session_path

    [ edit_deck_path(@deck), delete_deck_path(@deck) ].each do |path|
      get path
      assert_redirected_to new_session_path
    end

    assert_equal [ "Original", @leader.id, [ [ @card.id, 3 ] ] ], snapshot(@deck)
  end
end
