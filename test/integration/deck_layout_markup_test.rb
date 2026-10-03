require "test_helper"

# T20 da `decks` — as classes de alvo de toque e de espaçamento estão nos
# controles que o Done when nomeia. O teste de design (`deck_layout_test.rb`)
# prova que as classes têm 44px e 24px; este prova que os botões as usam.
class DeckLayoutMarkupTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "deck-t20@example.com", password: PASSWORD)
    set = CardSet.create!(code: "DT20", name: "Decks T20", kind: "booster")
    @leader = Card.create!(card_set: set, card_number: "DT20-001", name: "Leader T20", card_type: "leader",
                           colors: [ "Black" ])
    @card = Card.create!(card_set: set, card_number: "DT20-010", name: "Carta T20", card_type: "character",
                         colors: [ "Black" ])
    @deck = Deck.create!(user: @user, name: "Deck T20")
    @deck.entries.create!(card: @card, quantity: 2)
    post session_path, params: { email: @user.email, password: PASSWORD }
  end

  def button_classes(label)
    css_select("button, input[type=submit]").select { |b| (b.text.presence || b["value"]).to_s.strip == label }
                                            .map { |b| b["class"].to_s.split }
  end

  test "Editar este deck e os links de ação da página do deck" do
    get deck_path(@deck)

    assert_equal [ [ "deck__button" ] ], button_classes("Editar este deck")
    links = css_select("p.deck__actions a").map { |a| [ a.text, a["class"] ] }
    assert_equal [ [ "Exportar lista", "deck__action" ], [ "Renomear", "deck__action" ],
                   [ "Excluir", "deck__action" ], [ "Voltar aos baralhos", "deck__action" ] ], links
  end

  test "Excluir deck na confirmação" do
    get delete_deck_path(@deck)

    assert_equal [ [ "deck__button" ] ], button_classes("Excluir deck")
  end

  test "submit do nome ao criar, ao renomear e ao importar" do
    { new_deck_path => "Criar deck", edit_deck_path(@deck) => "Salvar nome",
      new_deck_import_path => "Importar lista" }.each do |path, label|
      get path
      assert_equal [ %w[auth__submit deck__submit] ], button_classes(label), path
    end
  end

  test "− e + no detalhe da carta comum e Usar como Leader no Leader" do
    post select_deck_path(@deck)

    get card_path(@card.card_number)
    controls = css_select("#deck_entry_card_#{@card.id} button.deck-controls__button")
    assert_equal [ "Remover uma cópia de Carta T20 do deck Deck T20", "Adicionar uma cópia de Carta T20 ao deck Deck T20" ],
                 controls.map { |b| b["aria-label"] }

    get card_path(@leader.card_number)
    assert_equal [ [ "deck-controls__button" ] ], button_classes("Usar como Leader")
  end
end
