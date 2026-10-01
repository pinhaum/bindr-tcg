require "test_helper"

module Ingestion
  module Apitcg
    class NormalizeTest < ActiveSupport::TestCase
      FIXTURE = Rails.root.join("spec", "fixtures", "apitcg-subset.json")

      IMAGEM = "https://tcgplayer-cdn.tcgplayer.com/product/%s_in_1000x1000.jpg"

      def self.resultado
        @resultado ||= Normalize.call(FIXTURE.read)
      end

      setup { @resultado = self.class.resultado }

      def card(numero) = @resultado.cards.find { |c| c.card_number == numero }
      def variant(codigo) = @resultado.variants.find { |v| v.variant_code == codigo }
      def set(codigo) = @resultado.sets.find { |s| s.code == codigo }

      # Monta um snapshot sintético: `sets` e `cards` no formato da apitcg.
      def conjunto(id, code: nil, name: id, release: "2024-01-01")
        { "_id" => id, "name" => name, "release_date" => release }.tap { |s| s["code"] = code if code }
      end

      def produto(id, code, set_id, nome: "Carta", tcgplayer: id, atributos: {})
        {
          "_id" => id, "type" => "card", "name" => nome, "code" => code,
          "set" => { "_id" => set_id },
          "images" => [ { "large" => "https://tcgplayer-cdn.tcgplayer.com/product/#{id}.jpg" } ],
          "markets" => tcgplayer ? { "tcgplayer" => { "id" => tcgplayer.to_s } } : {},
          "attributes" => { "CardType" => "Character", "Rarity" => "C" }.merge(atributos)
        }
      end

      def normalizar(sets, cards) = Normalize.call({ "sets" => sets, "cards" => cards })

      def codigos_dos_sets(resultado) = resultado.sets.map(&:code).sort

      # ---------- fixture: contagens e descartes ----------

      test "a fixture rende 10 sets, 11 cartas e 13 variantes" do
        assert_equal 10, @resultado.sets.size
        assert_equal 11, @resultado.cards.size
        assert_equal 13, @resultado.variants.size
      end

      test "só entram os sets com variante, com o código normalizado" do
        assert_equal %w[EB01 OP-PR OP05 OP06 OP06-PRE OP07 OP07-PRE OP16 ST22 ST25],
                     codigos_dos_sets(@resultado)
      end

      test "as cartas são os números distintos das variantes" do
        assert_equal %w[EB01-001 OP03-091 OP05-033 OP06-081 OP06-096 OP07-020 OP07-051 OP09-043
                        OP16-077 ST22-014 ST25-003],
                     @resultado.cards.map(&:card_number).sort
      end

      test "SRC-11: só o produto sem code é descartado, com o _id e o motivo" do
        assert_equal [ { "_id" => 6117, "reason" => "sem code" } ], @resultado.discarded
      end

      test "SRC-10: DON!! não aparece em variantes, cartas nem descartes" do
        assert_nil variant("tcgplayer:624351")
        assert_not_includes @resultado.discarded.map { |d| d["_id"] }, 7547
        assert_not_includes @resultado.variants.map(&:rarity), "DON!!"
      end

      # ---------- fixture: variant_code, art_kind, imagem ----------

      test "SRC-09: variant_code é tcgplayer:<id> para todas as variantes da fixture" do
        assert_equal %w[tcgplayer:510722 tcgplayer:528579 tcgplayer:541058 tcgplayer:541644
                        tcgplayer:541710 tcgplayer:544523 tcgplayer:545841 tcgplayer:552062
                        tcgplayer:634230 tcgplayer:634289 tcgplayer:647709 tcgplayer:647710
                        tcgplayer:696064],
                     @resultado.variants.map(&:variant_code).sort
      end

      test "SRC-13: art_kind de cada variante da fixture" do
        esperado = {
          "tcgplayer:541058" => "alternate_art", # Absalom (Alternate Art)
          "tcgplayer:647709" => "base",          # A.O. (sem sufixo)
          "tcgplayer:647710" => "parallel",      # A.O. (Parallel)
          "tcgplayer:696064" => "base",
          "tcgplayer:545841" => "manga",         # Boa Hancock (051) (Parallel) (Manga): vale o último sufixo
          "tcgplayer:528579" => "base",          # Baby 5 (033): sufixo numérico
          "tcgplayer:634289" => "other",         # Alvida (Reprint)
          "tcgplayer:552062" => "promo",         # Aladine, set Pre-Release
          "tcgplayer:541644" => "base",
          "tcgplayer:541710" => "promo",
          "tcgplayer:544523" => "base",
          "tcgplayer:634230" => "base",
          "tcgplayer:510722" => "promo"          # Helmeppo (Store Championship...), set de promoção
        }
        assert_equal esperado, @resultado.variants.to_h { |v| [ v.variant_code, v.art_kind ] }
      end

      test "image_url é a imagem large e a raridade vem como texto" do
        assert_equal format(IMAGEM, "541058"), variant("tcgplayer:541058").image_url
        assert_equal "R", variant("tcgplayer:541058").rarity
        assert_equal "PR", variant("tcgplayer:510722").rarity
      end

      # ---------- fixture: sets ----------

      test "SRC-14: set de code nulo na fixture recebe o prefixo de maioria estrita" do
        assert_equal "The Time of Battle", set("OP16").name
        assert_equal "OP16", card("OP16-077").set_code
        assert_equal "OP16", variant("tcgplayer:696064").set_code
      end

      test "SRC-14: ST-22 vira ST22, EB-01 vira EB01 e OP07 PRE vira OP07-PRE" do
        assert_equal "ST-22: Starter Deck 22 Ace & Newgate", set("ST22").name
        assert_equal "Extra Booster: Memorial Collection", set("EB01").name
        assert_equal "500 Years in the Future Pre-Release Cards", set("OP07-PRE").name
      end

      test "SRC-14, SRC-24 e SRC-35: tipo, lançamento e tamanhos de cada set da fixture" do
        esperado = {
          "EB01" => [ "extra_booster", "2024-05-03", 1, 1 ],
          "OP-PR" => [ "promo", "2022-09-30", 1, 1 ],
          "OP05" => [ "booster", "2023-12-08", 1, 1 ],
          "OP06" => [ "booster", "2024-03-15", 2, 2 ],
          "OP06-PRE" => [ "promo", "2024-03-08", 1, 1 ],
          "OP07" => [ "booster", "2024-06-28", 1, 1 ],
          "OP07-PRE" => [ "promo", "2024-06-21", 1, 1 ],
          "OP16" => [ "booster", "2026-06-12", 1, 1 ],
          "ST22" => [ "starter", "2025-09-05", 1, 2 ],
          "ST25" => [ "starter", "2025-06-06", 2, 2 ]
        }
        obtido = @resultado.sets.to_h do |s|
          [ s.code, [ s.kind, s.released_on.to_s, s.base_set_size, s.total_set_size ] ]
        end
        assert_equal esperado, obtido
      end

      test "SRC-24: set de numeração própria conta só o prefixo e o de reimpressão conta todos os números" do
        assert_equal 2, set("OP06").base_set_size # OP06-081 e OP06-096
        assert_equal 2, set("ST25").base_set_size # ST25-003 e a reimpressão OP09-043: 1 de 2 não é maioria estrita
        assert_equal 1, set("ST22").base_set_size # duas variantes, um único número
        assert_equal 2, set("ST22").total_set_size
      end

      test "SRC-35: set sem nenhum número com o prefixo do código usa todos os números" do
        assert_equal 1, set("OP07-PRE").base_set_size # só OP07-020, e o código é OP07-PRE
      end

      # ---------- fixture: cartas ----------

      test "SRC-12: a carta vem da base do set de estreia, não da impressão promocional" do
        assert_equal "OP06", card("OP06-096").set_code
        assert_equal "OP07-PRE", card("OP07-020").set_code
        assert_equal "ST25", card("OP09-043").set_code
        assert_equal "OP-PR", card("OP03-091").set_code
      end

      test "o nome da carta sai sem nenhum sufixo entre parênteses" do
        assert_equal "Boa Hancock", card("OP07-051").name
        assert_equal "Absalom", card("OP06-081").name
        assert_equal "Baby 5", card("OP05-033").name
        assert_equal "Helmeppo", card("OP03-091").name
        assert_equal "\"Buddha\" Sengoku", card("OP16-077").name
        assert_equal "A.O.", card("ST22-014").name
      end

      test "counter nulo, zero e positivo são três coisas diferentes" do
        assert_nil card("OP07-051").counter
        assert_equal 0, card("OP03-091").counter
        assert_equal 1000, card("OP06-081").counter
        assert_equal 0, card("OP03-091").power
        assert_nil card("OP16-077").power
      end

      test "block_icon é nil em toda carta" do
        assert_equal [ nil ], @resultado.cards.map(&:block_icon).uniq
      end

      test "tipo, cores, atributos e traits vêm quebrados em ponto e vírgula" do
        oden = card("EB01-001")
        assert_equal "leader", oden.card_type
        assert_equal %w[Green Red], oden.colors
        assert_equal [ "Land of Wano", "Kouzuki Clan" ], oden.traits
        assert_equal 4, oden.life
        assert_nil oden.cost
        assert_equal [ "Slash", "Special" ], card("ST25-003").attributes_list
      end

      test "SRC-12: trigger_text recebe o trecho após [Trigger] e o efeito não o repete" do
        carta = card("OP06-096")
        assert_equal "Activate this card's [Counter] effect.", carta.trigger_text
        assert_equal "[Counter] You may add 1 card from the top of your Life cards to your hand.: " \
                     "Your Characters with a cost of 7 or less cannot be K.O.'d in battle during this turn.",
                     carta.effect_text
      end

      test "SRC-12: o efeito sai sem HTML, sem o disclaimer e com as quebras de linha" do
        assert_equal "[On K.O.] If your Leader has the \"Cross Guild\" type, play up to 1 Character card " \
                     "with a cost of 5 or less other than [Alvida] from your hand.",
                     card("OP09-043").effect_text
        assert_equal "[Blocker] (After your opponent declares an attack, you may rest this card to make " \
                     "it the new target of the attack.)\n\n[On K.O.] If your Leader has the [Fish-Man] type, " \
                     "play up to 1 [Fish-Man] or [Merfolk] type Character card with a cost of 3 or less from your hand.",
                     card("OP07-020").effect_text
        assert_equal "[On Play] Draw 2 cards and trash 1 card from your hand. Then, play up to 1 \"Cross Guild\" " \
                     "type Character card with a cost of 4 or less from your hand.\n\n[Once Per Turn] If your " \
                     "\"Cross Guild\" type Character would be removed from the field by your opponent's effect, " \
                     "you may trash 1 card from your hand instead.",
                     card("ST25-003").effect_text
        assert_equal "[Activate:Main] (1) (You may rest the specified number of DON!! cards in your cost area.) " \
                     "You may rest this Character: Play up to 1 [Donquixote Pirates] type Character card " \
                     "with a cost of 2 or less from your hand.",
                     card("OP05-033").effect_text
      end

      test "carta sem descrição fica com efeito e trigger nulos" do
        assert_nil card("ST22-014").effect_text
        assert_nil card("ST22-014").trigger_text
      end

      test "tipo de carta desconhecido levanta UnknownCardType" do
        sets = [ conjunto("s", code: "OP01") ]
        cards = [ produto(1, "OP01-001", "s", atributos: { "CardType" => "Spell" }) ]

        assert_raises(Normalize::UnknownCardType) { normalizar(sets, cards) }
      end

      test "aceita o snapshot como JSON ou como hash" do
        snapshot = JSON.parse(FIXTURE.read)

        assert_equal @resultado.variants.map(&:variant_code), Normalize.call(snapshot).variants.map(&:variant_code)
      end

      # ---------- sintéticos: variant_code, descartes, dedup ----------

      test "SRC-09: sem tcgplayer.id o variant_code é apitcg:<_id>" do
        resultado = normalizar([ conjunto("s", code: "OP01") ],
                               [ produto(4321, "OP01-001", "s", tcgplayer: nil),
                                 produto(4322, "OP01-002", "s", tcgplayer: 777) ])

        assert_equal %w[apitcg:4321 tcgplayer:777], resultado.variants.map(&:variant_code)
      end

      test "SRC-11: produto sem code vai para os descartes e o set vazio não aparece" do
        resultado = normalizar([ conjunto("s", code: "OP01"), conjunto("vazio", code: "OP02") ],
                               [ produto(9, nil, "vazio"), produto(10, "", "vazio"), produto(11, "OP01-001", "s") ])

        assert_equal [ { "_id" => 9, "reason" => "sem code" }, { "_id" => 10, "reason" => "sem code" } ],
                     resultado.discarded
        assert_equal [ "OP01" ], codigos_dos_sets(resultado)
        assert_equal 1, resultado.variants.size
      end

      test "SRC-10: DON!! com code preenchido também sai em silêncio" do
        resultado = normalizar([ conjunto("s", code: "OP01") ],
                               [ produto(1, "OP01-001", "s", atributos: { "CardType" => "DON!!" }),
                                 produto(2, "OP01-002", "s") ])

        assert_equal %w[tcgplayer:2], resultado.variants.map(&:variant_code)
        assert_empty resultado.discarded
      end

      test "produto cujo set não está na lista de sets é descartado com o motivo" do
        resultado = normalizar([ conjunto("s", code: "OP01") ],
                               [ produto(1, "OP01-001", "s"), produto(2, "OP01-002", "fantasma") ])

        assert_equal [ { "_id" => 2, "reason" => "set desconhecido" } ], resultado.discarded
        assert_equal %w[tcgplayer:1], resultado.variants.map(&:variant_code)
      end

      test "SRC-34: a mesma variante em dois sets fica no primeiro em que aparece" do
        sets = [ conjunto("a", code: "AA", release: "2024-01-01"), conjunto("b", code: "BB", release: "2025-01-01") ]
        cards = [ produto(1, "OP01-001", "a", tcgplayer: 10, atributos: { "Counterplus" => "1000" }),
                  produto(2, "OP01-001", "b", tcgplayer: 10, atributos: { "Counterplus" => "2000" }) ]

        resultado = normalizar(sets, cards)

        assert_equal [ [ "tcgplayer:10", "AA" ] ], resultado.variants.map { |v| [ v.variant_code, v.set_code ] }
        assert_equal [ "AA" ], codigos_dos_sets(resultado)
        assert_equal 1000, resultado.cards.first.counter # o duplicado do set mais recente não define a carta
        assert_equal "AA", resultado.cards.first.set_code
      end

      test "SRC-34: a ocorrência repetida não entra no tamanho do set de destino" do
        sets = [ conjunto("a", code: "OP01"), conjunto("b", code: "OP02") ]
        cards = [ produto(1, "OP01-001", "a", tcgplayer: 10),
                  produto(2, "OP01-001", "b", tcgplayer: 10),
                  produto(3, "OP02-001", "b", tcgplayer: 11) ]

        resultado = normalizar(sets, cards)

        assert_equal [ 1, 1 ], resultado.sets.map(&:total_set_size)
        assert_equal [ "OP01", "OP02" ], resultado.sets.map(&:code)
      end

      # ---------- sintéticos: impressão que define a carta (SRC-12) ----------

      test "SRC-12: a base do set de estreia vence a reimpressão mais recente que veio antes" do
        sets = [ conjunto("reimpressao", code: "ST01", release: "2024-01-01"),
                 conjunto("estreia", code: "OP01", release: "2020-01-01") ]
        cards = [ produto(1, "OP01-016", "reimpressao", atributos: { "Counterplus" => "1000" }),
                  produto(2, "OP01-016", "estreia", atributos: { "Counterplus" => "2000" }) ]

        carta = normalizar(sets, cards).cards.first

        assert_equal 2000, carta.counter
        assert_equal "OP01", carta.set_code
      end

      test "SRC-12: sem base no set de estreia vence a impressão do set mais recente" do
        sets = [ conjunto("r1", code: "ST01", release: "2023-01-01"),
                 conjunto("r2", code: "ST02", release: "2024-01-01"),
                 conjunto("estreia", code: "OP01", release: "2020-01-01") ]
        cards = [ produto(1, "OP01-016", "r1", atributos: { "Counterplus" => "1000" }),
                  produto(2, "OP01-016", "r2", nome: "Carta (Reprint)", atributos: { "Counterplus" => "2000" }),
                  produto(3, "OP01-016", "estreia", nome: "Carta (Parallel)", atributos: { "Counterplus" => "3000" }) ]

        carta = normalizar(sets, cards).cards.first

        assert_equal 2000, carta.counter
        assert_equal "ST02", carta.set_code
      end

      test "SRC-12: set sem release_date é o mais antigo" do
        sets = [ conjunto("a", code: "AA", release: nil), conjunto("b", code: "BB", release: "2019-05-05") ]
        cards = [ produto(1, "OP01-001", "b", atributos: { "Counterplus" => "1000" }),
                  produto(2, "OP01-001", "a", atributos: { "Counterplus" => "2000" }) ]

        assert_equal 1000, normalizar(sets, cards).cards.first.counter
      end

      test "SRC-12: empate de lançamento fica com o menor variant_code" do
        sets = [ conjunto("a", code: "AA", release: "2024-01-01"), conjunto("b", code: "BB", release: "2024-01-01") ]
        cards = [ produto(1, "OP01-001", "a", tcgplayer: 200, atributos: { "Counterplus" => "2000" }),
                  produto(2, "OP01-001", "b", tcgplayer: 100, atributos: { "Counterplus" => "1000" }) ]

        carta = normalizar(sets, cards).cards.first

        assert_equal 1000, carta.counter
        assert_equal "BB", carta.set_code
      end

      test "SRC-12: duas bases no set de estreia ficam com o menor variant_code" do
        sets = [ conjunto("estreia", code: "OP01") ]
        cards = [ produto(1, "OP01-001", "estreia", tcgplayer: 200, atributos: { "Counterplus" => "2000" }),
                  produto(2, "OP01-001", "estreia", tcgplayer: 100, nome: "Carta (001)",
                            atributos: { "Counterplus" => "1000" }) ]

        assert_equal 1000, normalizar(sets, cards).cards.first.counter
      end

      # ---------- sintéticos: art_kind (SRC-13) ----------

      test "SRC-13: set de promoção vira promo só quando não há sufixo de arte" do
        sets = [ conjunto("promo", code: "OP-PR", name: "One Piece Promotion Cards") ]
        nomes = {
          "Carta" => "promo",
          "Carta (Store Championship)" => "promo",
          "Carta (Parallel)" => "parallel",
          "Carta (Alternate Art)" => "alternate_art",
          "Carta (Manga)" => "manga",
          "Carta (Reprint)" => "promo"
        }
        cards = nomes.keys.each_with_index.map { |nome, i| produto(i + 1, "OP01-%03d" % (i + 1), "promo", nome: nome) }

        obtido = normalizar(sets, cards).variants.map(&:art_kind)

        assert_equal nomes.values, obtido
      end

      test "SRC-13: fora de set de promoção, a tabela de sufixos" do
        sets = [ conjunto("s", code: "OP01", name: "Romance Dawn") ]
        nomes = {
          "Carta" => "base",
          "Carta (054)" => "base",
          "Carta (OP01-016)" => "base",
          "Carta (Reprint)" => "other",
          "Carta (SP)" => "other",
          "Carta (Box Topper)" => "other",
          "Carta (PARALLEL)" => "parallel",
          "Carta (alternate art)" => "alternate_art",
          "Carta (054) (Parallel)" => "parallel",
          "Carta (Parallel) (Manga)" => "manga",
          "Carta (Manga) (Reprint)" => "other"
        }
        cards = nomes.keys.each_with_index.map { |nome, i| produto(i + 1, "OP01-%03d" % (i + 1), "s", nome: nome) }

        obtido = normalizar(sets, cards).variants.map(&:art_kind)

        assert_equal nomes.values, obtido
      end

      # ---------- sintéticos: código do set (SRC-14) ----------

      test "SRC-14: code presente tem o hífen entre letra e dígito removido e o espaço trocado por hífen" do
        sets = [ conjunto("a", code: "ST-01"), conjunto("b", code: "OP07 PRE"), conjunto("c", code: "OP15-EB04"),
                 conjunto("d", code: "PRB-01") ]
        cards = sets.each_with_index.map { |s, i| produto(i + 1, "XX-%03d" % (i + 1), s["_id"]) }

        assert_equal %w[OP07-PRE OP15-EB04 PRB01 ST01], codigos_dos_sets(normalizar(sets, cards))
      end

      test "SRC-14: code nulo com maioria estrita do prefixo usa esse prefixo" do
        sets = [ conjunto("one-piece-novo") ]
        cards = [ produto(1, "OP18-001", "one-piece-novo"), produto(2, "OP18-002", "one-piece-novo"),
                  produto(3, "OP17-099", "one-piece-novo") ]

        resultado = normalizar(sets, cards)

        assert_equal [ "OP18" ], codigos_dos_sets(resultado)
        assert_equal [ "OP18" ], resultado.variants.map(&:set_code).uniq
      end

      test "SRC-14: code nulo cujo prefixo já é código de outro set usa o slug sem one-piece-" do
        sets = [ conjunto("one-piece-booster", code: "OP01"), conjunto("one-piece-set-sail-deck-set") ]
        cards = [ produto(1, "OP01-001", "one-piece-booster"),
                  produto(2, "OP01-002", "one-piece-set-sail-deck-set"),
                  produto(3, "OP01-003", "one-piece-set-sail-deck-set") ]

        assert_equal %w[OP01 set-sail-deck-set], codigos_dos_sets(normalizar(sets, cards))
      end

      test "SRC-14: dois sets de code nulo com o mesmo prefixo: o primeiro fica com ele, o segundo com o slug" do
        sets = [ conjunto("one-piece-primeiro"), conjunto("one-piece-segundo") ]
        cards = [ produto(1, "OP20-001", "one-piece-primeiro"), produto(2, "OP20-002", "one-piece-segundo") ]

        assert_equal %w[OP20 segundo], codigos_dos_sets(normalizar(sets, cards))
      end

      test "SRC-14: code nulo sem maioria estrita usa o slug" do
        sets = [ conjunto("one-piece-evento") ]
        cards = [ produto(1, "OP01-001", "one-piece-evento"), produto(2, "ST02-001", "one-piece-evento") ]

        assert_equal [ "evento" ], codigos_dos_sets(normalizar(sets, cards))
      end

      test "SRC-14: a maioria do code nulo ignora DON!!, produto sem code e duplicata" do
        sets = [ conjunto("one-piece-a", code: "ST01"), conjunto("one-piece-b") ]
        cards = [ produto(1, "OP05-001", "one-piece-b"),
                  produto(2, "ST01-001", "one-piece-b", atributos: { "CardType" => "DON!!" }),
                  produto(3, "ST01-002", "one-piece-b", atributos: { "CardType" => "DON!!" }),
                  produto(4, nil, "one-piece-b"),
                  produto(5, "ST01-003", "one-piece-a", tcgplayer: 50),
                  produto(6, "ST01-003", "one-piece-b", tcgplayer: 50) ]

        assert_equal %w[OP05 ST01], codigos_dos_sets(normalizar(sets, cards))
      end

      test "SRC-14: released_on sai de release_date e fica nulo sem ela" do
        sets = [ conjunto("a", code: "OP01", release: "2024-06-28T00:00:00.000Z"), conjunto("b", code: "OP02", release: nil) ]
        cards = [ produto(1, "OP01-001", "a"), produto(2, "OP02-001", "b") ]

        resultado = normalizar(sets, cards)

        assert_equal [ Date.new(2024, 6, 28), nil ], resultado.sets.map(&:released_on)
      end

      # ---------- sintéticos: base_set_size (SRC-24, SRC-35) ----------

      test "SRC-24: prefixo em maioria estrita conta só os números do prefixo; total conta variantes" do
        sets = [ conjunto("s", code: "OP01") ]
        cards = [ produto(1, "OP01-001", "s"), produto(2, "OP01-001", "s", nome: "Carta (Parallel)"),
                  produto(3, "OP01-002", "s"), produto(4, "ST01-005", "s") ]

        resultado = normalizar(sets, cards).sets.first

        assert_equal 2, resultado.base_set_size
        assert_equal 4, resultado.total_set_size
      end

      test "SRC-24: prefixo sem maioria estrita (metade) conta todos os números distintos" do
        sets = [ conjunto("s", code: "ST02") ]
        cards = [ produto(1, "ST02-001", "s"), produto(2, "OP01-009", "s") ]

        assert_equal 2, normalizar(sets, cards).sets.first.base_set_size
      end

      test "SRC-35: set sem nenhum número com o prefixo do código usa todos os números e não divide por zero" do
        sets = [ conjunto("s", code: "ZZ99") ]
        cards = [ produto(1, "AA-001", "s"), produto(2, "AA-002", "s"), produto(3, "BB-001", "s") ]

        resultado = normalizar(sets, cards).sets.first

        assert_equal 3, resultado.base_set_size
        assert_equal 3, resultado.total_set_size
      end

      # ---------- sintéticos: limpeza do texto (SRC-12) ----------

      def efeito_de(descricao)
        resultado = normalizar([ conjunto("s", code: "OP01") ],
                               [ produto(1, "OP01-001", "s", atributos: { "Description" => descricao }) ])
        carta = resultado.cards.first
        [ carta.effect_text, carta.trigger_text ]
      end

      test "SRC-12: remove o span de DISCLAIMER inteiro, inclusive em várias linhas" do
        assert_equal [ "Texto.", nil ],
                     efeito_de("Texto.\r\n<br>\r\n<span style=\"color:red\">DISCLAIMER: reimpressão\nde outro set</span>")
      end

      test "SRC-12: span que não é disclaimer mantém o conteúdo" do
        assert_equal [ "A B C", nil ], efeito_de("A <span class=\"x\">B</span> C")
      end

      test "SRC-12: remove o link de errata inteiro e mantém o texto dos outros links" do
        assert_equal [ "Texto", nil ], efeito_de("Texto <a href=\"https://exemplo.com/errata_card/12\">Errata</a>")
        assert_equal [ "Veja regras agora", nil ],
                     efeito_de("Veja <a href=\"https://exemplo.com/regras\">regras</a> agora")
      end

      test "SRC-12: <br> e CRLF viram \\n e três ou mais quebras colapsam em uma linha em branco" do
        assert_equal [ "A\nB", nil ], efeito_de("A\r\nB")
        assert_equal [ "A\nB", nil ], efeito_de("A<br>B")
        assert_equal [ "A\n\nB", nil ], efeito_de("A\r\n<br>\r\nB")
        assert_equal [ "A\n\nB", nil ], efeito_de("A\r\n<br>\r\n<br>\r\n<br>\r\nB")
        assert_equal [ "A\n\nB", nil ], efeito_de("A\r<br>\nB")
      end

      test "SRC-12: remove tags de formatação e mantém o texto" do
        assert_equal [ "[Main] (regra) forte", nil ], efeito_de("[Main] <em>(regra)</em> <strong>forte</strong>")
      end

      test "SRC-12: o segundo [Trigger] fica dentro do trigger_text" do
        assert_equal [ "Efeito", "Um [Trigger] dois" ], efeito_de("Efeito\r\n<br>\r\n[Trigger] Um [Trigger] dois")
      end

      test "SRC-12: efeito vazio vira nil e o trigger continua" do
        assert_equal [ nil, "Só trigger" ], efeito_de("[Trigger] Só trigger")
      end

      test "SRC-12: descrição ausente, vazia ou só com quebras gera efeito e trigger nulos" do
        assert_equal [ nil, nil ], efeito_de(nil)
        assert_equal [ nil, nil ], efeito_de("")
        assert_equal [ nil, nil ], efeito_de("<br>\r\n<br>")
      end
    end
  end
end
