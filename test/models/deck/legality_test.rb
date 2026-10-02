require "test_helper"

# T4 (decks) — `Deck::Legality` e os predicados de `Card` sobre `effect_text`.
# Os valores esperados vêm do spec: os textos de motivo seguem os exemplos do
# DCK-15, e os `effect_text` são os reais do snapshot
# `apitcg-20261001T231649Z.json`, já normalizados como o Normalize grava
# (`normalize.rb:263-273`), lidos da base de dev gerada por esse snapshot.
#
# A função é pura: as cartas são `Card.new`, sem banco.
class Deck::LegalityTest < ActiveSupport::TestCase
  OP01_075 = "Under the rules of this game, you may have any number of this card in your deck.\n\n" \
             "[Blocker] (After your opponent declares an attack, you may rest this card to make it the new target of the attack.)"
  OP12_001 = "Under the rules of this game, you cannot include cards with a cost of 5 or more in your deck.\n\n" \
             "[Activate: Main] [Once Per Turn] You may reveal 2 Events from your hand: Up to 1 of your Characters " \
             "with 4000 base power or less gains +2000 power during this turn."
  OP13_079 = "Under the rules of this game, you cannot include Events with a cost of 2 or more in your deck and at the " \
             "start of the game, play up to 1 [Mary Geoise] type Stage card from your deck.\n\n" \
             "[Activate: Main] [Once Per Turn] You may trash 1 of your [Celestial Dragons] type Characters or 1 card " \
             "from your hand: Draw 1 card."
  P_117 = "Under the rules of this game, you can only include \"East Blue\" type cards in your deck and when your deck " \
          "is reduced to 0, you win the game instead of losing.\n\n" \
          "[DON!! x1] When this Leader's attack deals damage to your opponent's Life, you may trash 1 card from the top " \
          "of your deck."
  OP15_058 = "Under the rules of this game, your DON!! deck consists of 6 cards.\n\n" \
             "[Activate: Main] [Once Per Turn] If it is your second turn or later, add up to 1 DON!! card from your " \
             "DON!! deck and set it as active, and add up to 4 additional DON!! cards and rest them. Then, give up to " \
             "4 rested DON!! cards to 1 of your Characters."

  def leader(colors: [ "Black" ], number: "OP99-001", effect_text: nil)
    Card.new(card_number: number, card_type: "leader", colors: colors, effect_text: effect_text)
  end

  def card(number, colors: [ "Black" ], effect_text: nil)
    Card.new(card_number: number, card_type: "character", colors: colors, effect_text: effect_text)
  end

  # `total` cartas distintas-ish: blocos de 4 cópias e o resto numa última.
  def entries_totaling(total, colors: [ "Black" ], prefix: "OP98")
    (total / 4).times.map { |i| [ card(format("#{prefix}-%03d", i + 1), colors: colors), 4 ] }
      .then { |list| (total % 4).zero? ? list : list << [ card("#{prefix}-999", colors: colors), total % 4 ] }
  end

  def call(leader:, entries:)
    Deck::Legality.call(leader: leader, entries: entries)
  end

  # Done when / DCK-12: Leader com 50 cartas das cores dele, nenhuma acima de 4.
  test "Leader com 50 cartas das cores dele e até 4 cópias é válido, sem motivos" do
    result = call(leader: leader, entries: entries_totaling(50))

    assert_equal :valid, result.status
    assert_empty result.reasons
    assert_empty result.warnings
  end

  # Done when / DCK-14, DCK-15: 49 cartas → incompleto, com quantas faltam.
  # O texto segue o exemplo "Faltam 3 cartas para 50" do DCK-15.
  test "com 47 cartas o deck é incompleto e diz que faltam 3" do
    result = call(leader: leader, entries: entries_totaling(47))

    assert_equal :incomplete, result.status
    assert_equal [ "Faltam 3 cartas para 50" ], result.reasons
  end

  test "com 49 cartas o deck é incompleto e diz que falta 1" do
    result = call(leader: leader, entries: entries_totaling(49))

    assert_equal :incomplete, result.status
    assert_equal [ "Falta 1 carta para 50" ], result.reasons
  end

  # Done when / DCK-14: sem Leader → incompleto, com o motivo do Leader.
  test "sem Leader o deck é incompleto, com o motivo do Leader" do
    result = call(leader: nil, entries: entries_totaling(50))

    assert_equal :incomplete, result.status
    assert_equal [ "O deck não tem Leader" ], result.reasons
  end

  # Done when / DCK-13: 51 cartas → inválido.
  test "com 51 cartas o deck é inválido" do
    result = call(leader: leader, entries: entries_totaling(51))

    assert_equal :invalid, result.status
    assert_equal [ "O deck tem 51 cartas; o máximo é 50" ], result.reasons
  end

  # Done when / DCK-13, DCK-15: 5 cópias → inválido, com o texto do exemplo.
  test "com 5 cópias de uma carta o deck é inválido e nomeia a carta" do
    entries = entries_totaling(45) << [ card("OP01-016"), 5 ]
    result = call(leader: leader, entries: entries)

    assert_equal :invalid, result.status
    assert_equal [ "OP01-016 tem 5 cópias; o máximo é 4" ], result.reasons
  end

  # Done when / DCK-13, DCK-15: carta de cor fora do Leader → inválido, com o
  # texto do exemplo "OP02-001 é vermelha e o Leader é preto".
  test "carta de cor fora do Leader torna o deck inválido e nomeia a carta" do
    entries = entries_totaling(49) << [ card("OP02-001", colors: [ "Red" ]), 1 ]
    result = call(leader: leader(colors: [ "Black" ]), entries: entries)

    assert_equal :invalid, result.status
    assert_equal [ "OP02-001 é vermelha e o Leader é preto" ], result.reasons
  end

  # Done when: 51 cartas e sem Leader → inválido, com os dois motivos.
  test "com 51 cartas e sem Leader o deck é inválido e mostra os dois motivos" do
    result = call(leader: nil, entries: entries_totaling(51))

    assert_equal :invalid, result.status
    assert_equal [ "O deck não tem Leader", "O deck tem 51 cartas; o máximo é 50" ], result.reasons
  end

  # Done when / DCK-42: sem Leader, carta de qualquer cor não gera motivo de cor.
  test "sem Leader não há motivo de cor" do
    entries = entries_totaling(48, colors: [ "Red" ]) << [ card("OP02-002", colors: [ "Green", "Yellow" ]), 2 ]
    result = call(leader: nil, entries: entries)

    assert_equal :incomplete, result.status
    assert_equal [ "O deck não tem Leader" ], result.reasons
  end

  # Done when / DCK-16: multicolorida com uma cor fora gera motivo.
  test "multicolorida com uma cor fora do Leader gera motivo" do
    entries = entries_totaling(49) << [ card("OP05-002", colors: [ "Black", "Red" ]), 1 ]
    result = call(leader: leader(colors: [ "Black" ]), entries: entries)

    assert_equal :invalid, result.status
    assert_equal [ "OP05-002 é preta e vermelha e o Leader é preto" ], result.reasons
  end

  # Done when / DCK-16: multicolorida com todas as cores no Leader não gera.
  test "multicolorida com todas as cores no Leader é aceita" do
    entries = entries_totaling(44, colors: [ "Red" ]) +
              [ [ card("OP05-003", colors: [ "Red", "Black" ]), 4 ], [ card("OP05-004", colors: [ "Black" ]), 2 ] ]
    result = call(leader: leader(colors: [ "Black", "Red" ]), entries: entries)

    assert_equal :valid, result.status
    assert_empty result.reasons
  end

  # Done when / DCK-43: o texto real de OP01-075 aceita 8 cópias sem motivo.
  test "carta com any number of this card aceita 8 cópias" do
    pacifista = card("OP01-075", colors: [ "Blue" ], effect_text: OP01_075)
    entries = entries_totaling(42, colors: [ "Blue" ]) << [ pacifista, 8 ]
    result = call(leader: leader(colors: [ "Blue" ]), entries: entries)

    assert_equal :valid, result.status
    assert_empty result.reasons
  end

  test "carta sem a frase com 8 cópias gera motivo" do
    entries = entries_totaling(42, colors: [ "Blue" ]) << [ card("OP01-076", colors: [ "Blue" ]), 8 ]
    result = call(leader: leader(colors: [ "Blue" ]), entries: entries)

    assert_equal :invalid, result.status
    assert_equal [ "OP01-076 tem 8 cópias; o máximo é 4" ], result.reasons
  end

  # Done when / DCK-44: Leader com regra própria gera aviso com a frase, e o
  # status continua `valid` num deck de 50 cartas.
  test "Leader com regra própria gera aviso com a frase e o status continua válido" do
    {
      [ "OP12-001", [ "Red" ], OP12_001 ] =>
        "Under the rules of this game, you cannot include cards with a cost of 5 or more in your deck.",
      [ "OP13-079", [ "Black" ], OP13_079 ] =>
        "Under the rules of this game, you cannot include Events with a cost of 2 or more in your deck and at the " \
        "start of the game, play up to 1 [Mary Geoise] type Stage card from your deck.",
      [ "P-117", [ "Blue" ], P_117 ] =>
        "Under the rules of this game, you can only include \"East Blue\" type cards in your deck and when your " \
        "deck is reduced to 0, you win the game instead of losing."
    }.each do |(number, colors, text), rule|
      result = call(leader: leader(number: number, colors: colors, effect_text: text),
                    entries: entries_totaling(50, colors: colors))

      assert_equal :valid, result.status, number
      assert_empty result.reasons, number
      assert_equal [ rule ], result.warnings, number
    end
  end

  # Done when / DCK-44: "Under the rules of this game" que não fala do deck
  # (OP15-058) não gera aviso, nem Leader sem a frase.
  test "Leader sem regra de montagem não gera aviso" do
    [ OP15_058, "[Activate: Main] Draw 1 card.", nil ].each do |text|
      result = call(leader: leader(colors: [ "Purple" ], effect_text: text),
                    entries: entries_totaling(50, colors: [ "Purple" ]))

      assert_equal :valid, result.status
      assert_empty result.warnings, text.inspect
    end
  end

  # Design (Efeitos de carta): a comparação ignora caixa e normaliza espaços.
  test "os predicados ignoram caixa e espaços" do
    unlimited = card("OP16-042", effect_text: "UNDER THE RULES of this game,\n you may have  any number of this card in your deck.")
    rule = leader(effect_text: "under the rules of this game,  you CANNOT include\ncards with a cost of 5 or more in your deck.")

    assert unlimited.unlimited_copies?
    assert_not card("OP16-043", effect_text: OP12_001).unlimited_copies?
    assert_equal "under the rules of this game, you CANNOT include cards with a cost of 5 or more in your deck.",
                 rule.own_deck_rule
  end

  # Done when / DCK-11: nenhum status é gravado.
  test "decks não tem coluna de status" do
    assert_empty Deck.column_names.grep(/status|valid|legal/)
  end

  # What (T4): `Deck#legality` delega a `Deck::Legality` sobre as entradas do deck.
  test "Deck#legality calcula o status das entradas gravadas" do
    user = User.create!(email: "legality@example.com", password: "senha-correta")
    set = CardSet.create!(code: "LG01", name: "Legality", kind: "booster")
    black_leader = Card.create!(card_set: set, card_number: "LG01-001", name: "Leader", card_type: "leader",
                                colors: [ "Black" ])
    red = Card.create!(card_set: set, card_number: "LG01-002", name: "Vermelha", card_type: "character",
                       colors: [ "Red" ])
    deck = Deck.create!(user: user, name: "Deck", leader: black_leader)
    deck.entries.create!(card: red, quantity: 5)

    result = deck.reload.legality

    assert_equal :invalid, result.status
    assert_equal [ "Faltam 45 cartas para 50", "LG01-002 tem 5 cópias; o máximo é 4",
                   "LG01-002 é vermelha e o Leader é preto" ], result.reasons
  end
end
