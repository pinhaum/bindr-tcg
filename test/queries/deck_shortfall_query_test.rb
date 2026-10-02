require "test_helper"

# T5 (decks) — `DeckShortfallQuery`: pedida, possuída e faltante por carta,
# para um deck e para todos os decks do usuário (DCK-20..23, DCK-33).
class DeckShortfallQueryTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "falta@example.com", password: "senha-correta")
    @set = CardSet.create!(code: "SF01", name: "Shortfall", kind: "booster")
    @leader = create_card("SF01-001", card_type: "leader")
    @card = create_card("SF01-002")
    @base = CardVariant.create!(card: @card, card_set: @set, variant_code: "tcgplayer:sf-base", art_kind: "base")
    @parallel = CardVariant.create!(card: @card, card_set: @set, variant_code: "tcgplayer:sf-par", art_kind: "parallel")
    mark_catalog_present!
  end

  def create_card(number, card_type: "character")
    Card.create!(card_set: @set, card_number: number, name: "Carta #{number}", card_type: card_type,
                 colors: [ "Black" ])
  end

  def create_deck(user: @user, name: "Deck", leader: nil, entries: {})
    Deck.create!(user: user, name: name, leader: leader).tap do |deck|
      entries.each { |card, quantity| deck.entries.create!(card: card, quantity: quantity) }
    end
  end

  def own(variant, quantity, user: @user)
    CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
  end

  def row_for(rows, card)
    rows.find { |row| row.card.id == card.id }
  end

  def capture_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s.in?([ "SCHEMA", "TRANSACTION" ])
      next if payload[:sql].to_s.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      queries << payload[:sql]
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # Done when (Independent Test do P1) / DCK-20, DCK-21: 2 da base + 1 da
  # parallel, deck pedindo 4 → pedida 4, possuída 3, falta 1.
  test "possuída soma todas as variantes da carta" do
    own(@base, 2)
    own(@parallel, 1)
    deck = create_deck(entries: { @card => 4 })

    row = row_for(DeckShortfallQuery.new(@user, deck: deck).call, @card)

    assert_equal [ 4, 3, 1 ], [ row.required, row.owned, row.missing ]
    assert_equal "SF01-002", row.card.card_number
    assert_equal [ deck.id ], row.deck_ids
  end

  # What (T5): o Leader conta como 1.
  test "o Leader conta como uma cópia pedida" do
    deck = create_deck(leader: @leader, entries: { @card => 2 })

    rows = DeckShortfallQuery.new(@user, deck: deck).call

    assert_equal [ [ "SF01-001", 1, 0, 1 ], [ "SF01-002", 2, 0, 2 ] ],
                 rows.map { |row| [ row.card.card_number, row.required, row.owned, row.missing ] }
  end

  # Done when / DCK-20: variante ausente da fonte também conta como possuída.
  test "variante ausente da fonte conta como possuída" do
    gone = CardVariant.create!(card: @card, card_set: @set, variant_code: "tcgplayer:sf-gone", art_kind: "base",
                               last_seen_at: CATALOG_SEEN_AT - 1.day)
    assert_not_includes CardVariant.present, gone

    own(gone, 3)
    deck = create_deck(entries: { @card => 4 })

    row = row_for(DeckShortfallQuery.new(@user, deck: deck).call, @card)

    assert_equal [ 4, 3, 1 ], [ row.required, row.owned, row.missing ]
  end

  # Done when: possuir mais que o pedido dá falta 0, nunca negativo.
  test "possuir mais que o pedido dá falta zero" do
    own(@base, 7)
    deck = create_deck(entries: { @card => 4 })

    row = row_for(DeckShortfallQuery.new(@user, deck: deck).call, @card)

    assert_equal [ 4, 7, 0 ], [ row.required, row.owned, row.missing ]
  end

  # Done when / DCK-33: dois decks pedindo 4 e 2, com 1 possuída → falta 3 e
  # os dois decks.
  test "sem deck, vale o maior uso entre os decks do usuário" do
    own(@base, 1)
    four = create_deck(name: "Quatro", entries: { @card => 4 })
    two = create_deck(name: "Dois", entries: { @card => 2 })

    row = row_for(DeckShortfallQuery.new(@user).call, @card)

    assert_equal [ 4, 1, 3 ], [ row.required, row.owned, row.missing ]
    assert_equal [ four.id, two.id ].sort, row.deck_ids
  end

  # Com `deck:`, só aquele deck conta, mesmo que outro peça mais.
  test "com deck, só aquele deck conta" do
    create_deck(name: "Quatro", entries: { @card => 4 })
    two = create_deck(name: "Dois", entries: { @card => 2 })

    row = row_for(DeckShortfallQuery.new(@user, deck: two).call, @card)

    assert_equal [ 2, 0, 2 ], [ row.required, row.owned, row.missing ]
    assert_equal [ two.id ], row.deck_ids
  end

  # Done when: a coleção de outro usuário não conta.
  test "a coleção de outro usuário não conta" do
    other = User.create!(email: "outro@example.com", password: "senha-correta")
    own(@base, 4, user: other)
    deck = create_deck(entries: { @card => 4 })

    row = row_for(DeckShortfallQuery.new(@user, deck: deck).call, @card)

    assert_equal [ 4, 0, 4 ], [ row.required, row.owned, row.missing ]
  end

  # Isolamento (Req. 6.5): os decks de outro usuário não entram, nem quando o
  # deck dele é passado em `deck:`.
  test "decks de outro usuário não entram" do
    other = User.create!(email: "dono-alheio@example.com", password: "senha-correta")
    alien = create_deck(user: other, entries: { @card => 4 })

    assert_empty DeckShortfallQuery.new(@user).call
    assert_empty DeckShortfallQuery.new(@user, deck: alien).call
  end

  # Done when: `user` nil devolve vazio.
  test "usuário nil devolve vazio" do
    create_deck(entries: { @card => 4 })

    assert_equal [], DeckShortfallQuery.new(nil).call
  end

  test "id no lugar do usuário levanta ArgumentError" do
    assert_raises(ArgumentError) { DeckShortfallQuery.new(@user.id) }
  end

  # Done when / DCK-23: mudar a coleção muda o resultado na chamada seguinte,
  # sem gravar nada.
  test "a falta acompanha a coleção sem gravar nada" do
    deck = create_deck(entries: { @card => 4 })
    query = DeckShortfallQuery.new(@user, deck: deck)

    first = nil
    writes = capture_queries { first = row_for(query.call, @card) }.grep(/\A\s*(INSERT|UPDATE|DELETE)/i)
    assert_equal 4, first.missing
    assert_empty writes

    own(@base, 3)

    assert_equal 1, row_for(query.call, @card).missing
  end

  # Done when: uma consulta só, com 1 deck e com 3.
  test "roda numa consulta só com 1 e com 3 decks" do
    own(@base, 1)
    other_card = create_card("SF01-003")
    one = create_deck(leader: @leader, entries: { @card => 4 })

    single = capture_queries { DeckShortfallQuery.new(@user, deck: one).call }
    assert_equal 1, single.size

    create_deck(name: "B", leader: @leader, entries: { @card => 2, other_card => 3 })
    create_deck(name: "C", entries: { other_card => 1 })

    all = []
    all_queries = capture_queries { all = DeckShortfallQuery.new(@user).call }

    assert_equal 1, all_queries.size
    assert_equal 3, all.size
    # A carta vem instanciada pela mesma consulta: ler o nome não custa outra.
    assert_empty(capture_queries { all.each { |row| row.card.name } })
  end
end
