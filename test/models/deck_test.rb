require "test_helper"

# T3 (decks) — o model `Deck`: nome, Leader, ordem das entradas e total do
# deck principal. As constraints do banco estão em `deck_schema_test.rb`; aqui
# a afirmação é sobre o que o model diz ao formulário e devolve à página.
class DeckTest < ActiveSupport::TestCase
  def create_user(email:)
    User.create!(email: email, password: "senha-correta")
  end

  # Cada teste usa um sufixo próprio: a suíte roda em paralelo.
  def create_card(number:, card_type: "character", cost: nil)
    set = CardSet.find_or_create_by!(code: "DT#{number[0, 4]}") { |s| s.name = "Deck Test", s.kind = "booster" }
    Card.create!(card_set: set, card_number: number, name: "Carta #{number}",
      card_type: card_type, cost: cost, colors: [ "Black" ])
  end

  # Done when: nome com espaços nas bordas é gravado sem eles.
  test "o nome é gravado sem os espaços das bordas" do
    deck = Deck.create!(user: create_user(email: "strip@example.com"), name: "  Luffy Preto  ")

    assert_equal "Luffy Preto", deck.reload.name
  end

  # Done when / DCK-39: nome vazio é inválido, com mensagem em português.
  test "nome vazio é inválido com mensagem em português" do
    user = create_user(email: "vazio@example.com")

    [ "", "   ", nil ].each do |name|
      deck = Deck.new(user: user, name: name)

      assert_not deck.valid?, "nome #{name.inspect} deveria ser inválido"
      assert_equal [ "não pode ficar vazio" ], deck.errors[:name]
    end
  end

  # Done when / DCK-39: nome de 61 caracteres é inválido; 60 é aceito.
  test "nome de 61 caracteres é inválido com mensagem em português" do
    user = create_user(email: "longo@example.com")
    deck = Deck.new(user: user, name: "a" * 61)

    assert_not deck.valid?
    assert_equal [ "pode ter no máximo 60 caracteres" ], deck.errors[:name]
    assert Deck.new(user: user, name: "a" * 60).valid?
  end

  # Done when: Leader que não é `leader` é inválido.
  test "Leader que não é carta Leader é inválido" do
    user = create_user(email: "leader-errado@example.com")
    character = create_card(number: "DT01-001", card_type: "character")
    deck = Deck.new(user: user, name: "Deck", leader: character)

    assert_not deck.valid?
    assert_equal [ "precisa ser uma carta Leader" ], deck.errors[:leader]
  end

  test "Leader carta Leader é válido, e o deck pode não ter Leader" do
    user = create_user(email: "leader-certo@example.com")
    leader = create_card(number: "DT01-002", card_type: "leader")

    assert Deck.new(user: user, name: "Com Leader", leader: leader).valid?
    assert Deck.new(user: user, name: "Sem Leader").valid?
  end

  # Done when: `ordered_entries` devolve character, event e stage, nessa ordem;
  # dentro de cada tipo, custo crescente com nulos por último e depois
  # `card_number`.
  test "ordered_entries agrupa por tipo e ordena por custo, nulos por último, e card_number" do
    deck = Deck.create!(user: create_user(email: "ordem@example.com"), name: "Ordem")
    cards = [
      create_card(number: "DT02-010", card_type: "stage", cost: 1),
      create_card(number: "DT02-009", card_type: "event", cost: 2),
      create_card(number: "DT02-008", card_type: "character", cost: nil),
      create_card(number: "DT02-007", card_type: "character", cost: 5),
      create_card(number: "DT02-006", card_type: "event", cost: 1),
      create_card(number: "DT02-005", card_type: "character", cost: 2),
      create_card(number: "DT02-004", card_type: "character", cost: 2),
      create_card(number: "DT02-003", card_type: "character", cost: 0)
    ]
    cards.each { |card| deck.entries.create!(card: card, quantity: 1) }

    assert_equal %w[DT02-003 DT02-004 DT02-005 DT02-007 DT02-008 DT02-006 DT02-009 DT02-010],
                 deck.reload.ordered_entries.map { |entry| entry.card.card_number }
  end

  # Done when: `main_total` soma as quantidades das entradas e não conta o
  # Leader.
  test "main_total soma as entradas e não conta o Leader" do
    leader = create_card(number: "DT03-001", card_type: "leader")
    deck = Deck.create!(user: create_user(email: "total@example.com"), name: "Total", leader: leader)
    deck.entries.create!(card: create_card(number: "DT03-002"), quantity: 4)
    deck.entries.create!(card: create_card(number: "DT03-003"), quantity: 3)

    assert_equal 7, deck.reload.main_total
  end

  test "main_total de um deck sem entradas é zero" do
    assert_equal 0, Deck.create!(user: create_user(email: "zero@example.com"), name: "Vazio").main_total
  end

  # What (T3): `User has_many :decks, dependent: :restrict_with_exception`.
  # Apagar a conta não leva o deck por efeito colateral.
  test "usuário com deck não é apagado" do
    user = create_user(email: "restrict@example.com")
    Deck.create!(user: user, name: "Fica")

    assert_raises(ActiveRecord::DeleteRestrictionError) { user.destroy }
    assert_equal 1, Deck.where(user: user).count
  end
end
