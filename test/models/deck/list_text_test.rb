require "test_helper"

# T6 e T7 (decks) — `Deck::ListText`, o formato do OPTCG Simulator.
#
# O exemplo do dono (2026-10-01) é a entrada principal: 15 linhas separadas por
# CR, com um CR final, Leader OP17-079 e 50 cartas no deck principal. A fixture
# reproduz as 15 cartas com o tipo, a cor e o custo reais do banco de dev
# (snapshot `apitcg-20261001T231649Z.json`).
class Deck::ListTextTest < ActiveSupport::TestCase
  OWNER_EXAMPLE = "1xOP17-079\r3xOP17-086\r2xOP17-084\r4xOP17-094\r4xOP17-081\r4xOP17-080\r4xOP17-087\r" \
                  "4xOP17-095\r4xOP17-082\r4xOP15-088\r4xOP17-119\r4xOP17-093\r4xOP17-096\r3xST14-017\r2xOP07-085\r"

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
    @set = CardSet.create!(code: "LT17", name: "List Text", kind: "booster")
    @cards = OWNER_CARDS.to_h do |number, (card_type, cost, name)|
      [ number, Card.create!(card_set: @set, card_number: number, name: name, card_type: card_type, cost: cost,
                             colors: [ "Black" ]) ]
    end
  end

  def card(number)
    @cards.fetch(number)
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

  def as_numbers(entries)
    entries.to_h { |entry_card, quantity| [ entry_card.card_number, quantity ] }
  end

  # --- T6: parse --------------------------------------------------------------

  # Done when / DCK-25, DCK-26: o exemplo do dono vira 1 Leader + 50 cartas.
  test "o exemplo do dono vira o Leader OP17-079 e 50 cartas" do
    result = Deck::ListText.parse(OWNER_EXAMPLE)

    assert_empty result.errors
    assert_equal card("OP17-079"), result.leader
    assert_equal 50, result.entries.values.sum
    assert_equal 14, result.entries.size
    assert_equal({ "OP17-086" => 3, "OP17-084" => 2, "OP17-094" => 4, "OP17-081" => 4, "OP17-080" => 4,
                   "OP17-087" => 4, "OP17-095" => 4, "OP17-082" => 4, "OP15-088" => 4, "OP17-119" => 4,
                   "OP17-093" => 4, "OP17-096" => 4, "ST14-017" => 3, "OP07-085" => 2 },
                 as_numbers(result.entries))
  end

  # Done when / DCK-25: CR, LF, CRLF e a mistura dão o mesmo resultado.
  test "CR, LF, CRLF e a mistura deles dão o mesmo resultado" do
    lines = OWNER_EXAMPLE.split("\r")
    expected = Deck::ListText.parse(OWNER_EXAMPLE)
    mixed = lines.each_with_index.map { |line, i| line + [ "\r", "\n", "\r\n" ][i % 3] }.join

    [ lines.join("\n"), lines.join("\r\n"), mixed ].each do |text|
      result = Deck::ListText.parse(text)

      assert_empty result.errors, text.inspect
      assert_equal expected.leader, result.leader
      assert_equal as_numbers(expected.entries), as_numbers(result.entries)
    end
  end

  # Done when / DCK-25: linhas em branco e espaços nas bordas e ao redor do `x`
  # são ignorados; a caixa do `card_number` não importa.
  test "linhas em branco, espaços e caixa são ignorados" do
    result = Deck::ListText.parse("\n  1 x op17-079  \r\n\r\n\t4X OP17-094\n   \n2 xop17-086\n")

    assert_empty result.errors
    assert_equal card("OP17-079"), result.leader
    assert_equal({ "OP17-094" => 4, "OP17-086" => 2 }, as_numbers(result.entries))
  end

  # Done when / DCK-27: linhas repetidas somam numa entrada.
  test "linhas repetidas somam numa entrada" do
    result = Deck::ListText.parse("1xOP17-079\n2xOP17-094\n1xOP17-086\n2xop17-094")

    assert_empty result.errors
    assert_equal({ "OP17-094" => 4, "OP17-086" => 1 }, as_numbers(result.entries))
  end

  # Done when / DCK-28: cada recusa traz o número da linha e o motivo em
  # português, e nada é devolvido (tudo ou nada).
  test "formato errado é recusado com o número da linha" do
    result = Deck::ListText.parse("1xOP17-079\nquatro Rodo\n4xOP17-094")

    assert_equal [ { line: 2, message: "formato inválido; use <N>x<código>, como 4xOP01-016" } ], result.errors
    assert_nil result.leader
    assert_empty result.entries
  end

  test "card_number inexistente é recusado com o número da linha" do
    result = Deck::ListText.parse("1xOP17-079\n\n4xOP99-999")

    assert_equal [ { line: 3, message: "OP99-999 não existe no catálogo" } ], result.errors
    assert_empty result.entries
  end

  test "quantidade 0 e 51 são recusadas com o número da linha" do
    result = Deck::ListText.parse("0xOP17-094\n51xOP17-086\n50xOP17-081")

    assert_equal [ { line: 1, message: "quantidade 0 fora do limite de 1 a 50" },
                   { line: 2, message: "quantidade 51 fora do limite de 1 a 50" } ], result.errors
    assert_empty result.entries
  end

  test "dois Leaders são recusados" do
    other_leader = Card.create!(card_set: @set, card_number: "OP17-001", name: "Outro", card_type: "leader",
                                colors: [ "Red" ])
    result = Deck::ListText.parse("1xOP17-079\n4xOP17-094\n1x#{other_leader.card_number}")

    assert_equal [ { line: 3, message: "OP17-001 é um segundo Leader; a lista já tem OP17-079" } ], result.errors
    assert_nil result.leader
  end

  test "Leader com quantidade 2 é recusado" do
    result = Deck::ListText.parse("2xOP17-079\n4xOP17-094")

    assert_equal [ { line: 1, message: "o Leader OP17-079 aparece com quantidade 2; o Leader é 1" } ], result.errors
    assert_nil result.leader
  end

  test "todas as linhas ruins aparecem juntas, na ordem do texto" do
    result = Deck::ListText.parse("2xOP17-079\nlixo\n4xOP99-999\n0xOP17-094")

    assert_equal [ 1, 2, 3, 4 ], result.errors.map { |error| error[:line] }
  end

  # DCK-39 — a soma das linhas repetidas também respeita o teto de 50.
  test "linhas repetidas que somam mais de 50 são recusadas" do
    result = Deck::ListText.parse("30xOP17-094\n30xOP17-094")

    assert_equal [ { line: 1, message: "OP17-094 soma 60 cópias nas linhas; o máximo é 50" },
                   { line: 2, message: "OP17-094 soma 60 cópias nas linhas; o máximo é 50" } ], result.errors
  end

  # Done when / DCK-29: 201 linhas ou 10.001 caracteres são recusados sem
  # consultar o banco.
  test "texto com 201 linhas é recusado sem consultar o banco" do
    result = nil
    queries = capture_queries { result = Deck::ListText.parse(Array.new(201, "1xOP17-094").join("\n")) }

    assert_empty queries
    assert_equal [ { line: nil, message: "A lista pode ter no máximo 200 linhas" } ], result.errors
    assert_empty result.entries
  end

  test "texto com 10.001 caracteres é recusado sem consultar o banco" do
    result = nil
    queries = capture_queries { result = Deck::ListText.parse("1xOP17-094\n" + (" " * (10_001 - 11))) }

    assert_empty queries
    assert_equal [ { line: nil, message: "A lista pode ter no máximo 10.000 caracteres" } ], result.errors
  end

  test "200 linhas e 10.000 caracteres ainda são aceitos" do
    assert_empty Deck::ListText.parse(([ "1xOP17-094" ] + Array.new(199, " ")).join("\n")).errors
    assert_empty Deck::ListText.parse("1xOP17-094\n" + (" " * (10_000 - 11))).errors
  end

  # Done when: a busca das cartas é uma consulta só, qualquer que seja o
  # número de linhas.
  test "a busca das cartas é uma consulta só" do
    assert_equal 1, capture_queries { Deck::ListText.parse("1xOP17-079\n4xOP17-094") }.size
    assert_equal 1, capture_queries { Deck::ListText.parse(OWNER_EXAMPLE) }.size
  end
end
