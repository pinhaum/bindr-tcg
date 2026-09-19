require "test_helper"

module Ingestion
  # Req. 11.5 — o pipeline de ingestão tem teste automatizado com fixture
  # fixa, sem rede. Nenhum teste deste arquivo faz requisição: a entrada é o
  # arquivo versionado em `spec/fixtures/`.
  class NormalizeTest < ActiveSupport::TestCase
    FIXTURE = Rails.root.join("spec", "fixtures", "optcgjson-subset.json")

    def self.resultado
      @resultado ||= Normalize.call(FIXTURE.read)
    end

    setup { @resultado = self.class.resultado }

    def card(numero) = @resultado.cards.find { |c| c.card_number == numero }
    def variant(codigo) = @resultado.variants.find { |v| v.variant_code == codigo }

    # A fixture tem 679 registros de carta, 376 `number` distintos e 678 `id`
    # distintos (P-029_r1 aparece duas vezes). Os três números conferidos
    # juntos provam o eixo Card ≠ CardVariant, que é a decisão central do
    # modelo (design.md §3.1).
    test "separa cartas de variantes conforme a fonte" do
      assert_equal 5, @resultado.sets.size
      assert_equal 376, @resultado.cards.size
      assert_equal 678, @resultado.variants.size
    end

    # Done when: `variant_code` = campo `id` da fonte, sem hash derivado.
    # AD-001 — é o que garante estabilidade entre execuções.
    test "variant_code é o id da fonte, não um valor derivado" do
      assert_equal "OP01-001", variant("OP01-001").variant_code
      assert_equal "OP01-001_p1", variant("OP01-001_p1").variant_code
      assert_equal "OP01-001", variant("OP01-001_p1").card_number
    end

    test "duas impressões da mesma carta apontam para o mesmo card_number" do
      base = variant("OP01-001")
      parallel = variant("OP01-001_p1")

      assert_equal base.card_number, parallel.card_number
      refute_equal base.variant_code, parallel.variant_code
      assert_equal 1, @resultado.cards.count { |c| c.card_number == "OP01-001" }
    end

    # Caso-limite do ADR 001: P-029_r1 é distribuída em PRB01 e ST16. Se
    # virasse duas variantes, o usuário veria uma carta fantasma na coleção.
    test "variante presente em dois sets gera um único registro" do
      duplicadas = @resultado.variants.count { |v| v.variant_code == "P-029_r1" }

      assert_equal 1, duplicadas
    end

    # Done when: `counter` nulo preservado como NULL.
    # design.md §3.3 — nunca 0 como sentinela.
    test "counter ausente vira nil e nunca 0" do
      sem_counter = card("OP01-001")

      assert_nil sem_counter.counter
      refute_equal 0, sem_counter.counter
    end

    test "counter presente vira inteiro" do
      com_counter = @resultado.cards.find { |c| !c.counter.nil? }

      assert_kind_of Integer, com_counter.counter
      assert_operator com_counter.counter, :>, 0
    end

    # A fonte entrega números como string. Se escapassem sem conversão, as
    # faixas do Req. 4.2 comparariam texto: "10" < "2".
    test "campos numéricos da fonte viram Integer" do
      lider = card("OP01-001")

      assert_equal 5, lider.life
      assert_equal 5000, lider.power
      assert_equal 1, lider.block_icon
      assert_nil lider.cost, "Leader não tem cost na fonte"
    end

    test "nenhuma carta escapa com número em formato de texto" do
      numericos = @resultado.cards.flat_map { |c| [ c.cost, c.life, c.power, c.counter, c.block_icon ] }

      assert_empty numericos.grep(String)
    end

    # Done when: trata `attribute: "?"` sem falhar.
    # Caso Imu (OP13-079), verificado na fixture.
    test "attribute '?' é preservado como valor, não descartado nem erro" do
      imu = card("OP13-079")

      assert_equal [ "?" ], imu.attributes_list
    end

    # Done when: `traits` normalizados em caixa e espaçamento.
    # design.md §3.3 — sem isso o filtro por trait fica furado.
    test "traits variando em caixa e espaçamento colapsam em um único valor" do
      payload = {
        "data" => [ {
          "code" => "TST", "name" => "Teste", "type" => "booster",
          "baseSetSize" => 1, "totalSetSize" => 1,
          "cards" => [ {
            "id" => "TST-001", "number" => "TST-001", "name" => "X", "rarity" => "C",
            "cardClass" => "CHARACTER", "color" => [ "Red" ],
            "feature" => [ "Straw Hat Crew", "straw hat crew", "  Straw   Hat  Crew  " ],
            "attribute" => [], "isParallel" => false
          } ]
        } ]
      }

      traits = Normalize.call(payload).cards.first.traits

      assert_equal [ "Straw Hat Crew" ], traits
    end

    # A grafia da fonte é preservada: normalizar caixa destruiria traits reais
    # como "Former CP9" e "Kingdom of GERMA" (medido no catálogo completo na
    # T9) para resolver uma única colisão que existe de fato.
    test "a grafia do trait vinda da fonte é preservada" do
      payload = {
        "data" => [ {
          "code" => "TST", "name" => "Teste", "type" => "booster",
          "cards" => [ {
            "id" => "TST-001", "number" => "TST-001", "name" => "X", "rarity" => "C",
            "cardClass" => "CHARACTER", "color" => [ "Red" ],
            "feature" => [ "Former CP9", "Kingdom of GERMA", "Land of Wano" ],
            "attribute" => [], "isParallel" => false
          } ]
        } ]
      }

      traits = Normalize.call(payload).cards.first.traits

      assert_equal [ "Former CP9", "Kingdom of GERMA", "Land of Wano" ], traits
    end

    test "trait já em caixa alta é preservado" do
      film = @resultado.cards.find { |c| c.traits.include?("FILM") }

      assert film, "a fixture tem cartas com o trait FILM"
      refute_includes film.traits, "Film"
    end

    # Req. 5.4 — o detalhe da carta preserva quebras de linha do efeito.
    test "quebras de linha do texto de efeito são preservadas" do
      payload = {
        "data" => [ {
          "code" => "TST", "name" => "Teste", "type" => "booster",
          "cards" => [ {
            "id" => "TST-001", "number" => "TST-001", "name" => "X", "rarity" => "C",
            "cardClass" => "EVENT", "color" => [ "Red" ],
            "effect" => "  [Main] Primeira linha.\nSegunda linha.  ",
            "attribute" => [], "feature" => [], "isParallel" => false
          } ]
        } ]
      }

      efeito = Normalize.call(payload).cards.first.effect_text

      assert_equal "[Main] Primeira linha.\nSegunda linha.", efeito
    end

    # O vocabulário interno é o do modelo, não o da fonte: nada abaixo do
    # Normalize pode ver "CHARACTER" ou "cardClass".
    test "cardClass da fonte vira o vocabulário interno do modelo" do
      assert_equal "leader", card("OP01-001").card_type
      assert_equal %w[character event leader stage], @resultado.cards.map(&:card_type).uniq.sort
    end

    test "tipo de carta desconhecido falha explicitamente em vez de virar outro tipo" do
      payload = {
        "data" => [ {
          "code" => "TST", "name" => "Teste", "type" => "booster",
          "cards" => [ {
            "id" => "TST-001", "number" => "TST-001", "name" => "X", "rarity" => "C",
            "cardClass" => "DON", "color" => [ "Red" ],
            "attribute" => [], "feature" => [], "isParallel" => false
          } ]
        } ]
      }

      assert_raises(Normalize::UnknownCardType) { Normalize.call(payload) }
    end

    # Req. 4.5 — multicoloridas entram no filtro de cada cor, o que exige que
    # as duas cores cheguem ao array.
    test "carta multicolorida preserva todas as cores" do
      multicolor = @resultado.cards.find { |c| c.colors.size > 1 }

      assert multicolor, "a fixture tem carta multicolorida"
      assert_operator multicolor.colors.size, :>=, 2
    end

    # Req. 9.5 — o denominador do progresso por set é `baseSetSize` (AD-003).
    test "o set carrega baseSetSize e totalSetSize como inteiros" do
      op01 = @resultado.sets.find { |s| s.code == "OP01" }

      assert_equal 121, op01.base_set_size
      assert_equal 154, op01.total_set_size
      assert_equal "booster", op01.kind
    end

    # O AllSets.json real entrega `data` como objeto indexado pelo código do
    # set; a fixture é uma lista. Descoberto ao rodar a carga real na T9: a
    # forma de objeto derrubava o Normalize com TypeError.
    test "aceita data como objeto indexado por código de set" do
      set = { "code" => "TST", "name" => "Teste", "type" => "booster", "cards" => [] }

      como_objeto = Normalize.call({ "data" => { "TST" => set } })
      como_lista = Normalize.call({ "data" => [ set ] })

      assert_equal 1, como_objeto.sets.size
      assert_equal como_lista.sets.map(&:code), como_objeto.sets.map(&:code)
    end

    test "tipo de set desconhecido vira 'other' em vez de derrubar a ingestão" do
      payload = { "data" => [ { "code" => "TST", "name" => "T", "type" => "mystery_box", "cards" => [] } ] }

      assert_equal "other", Normalize.call(payload).sets.first.kind
    end

    # A fonte marca parallel explicitamente; classificar além disso seria
    # inventar informação.
    test "isParallel da fonte determina art_kind" do
      assert_equal "base", variant("OP01-001").art_kind
      assert_equal "parallel", variant("OP01-001_p1").art_kind
    end

    test "toda variante mantém a imagem própria da impressão" do
      base = variant("OP01-001")
      parallel = variant("OP01-001_p1")

      assert base.image_url.present?
      refute_equal base.image_url, parallel.image_url
    end

    # Req. 1.9/1.10 dependem de o Normalize não tocar a rede: a entrada é o
    # payload já baixado pelo Fetch.
    test "normaliza a fixture inteira sem levantar exceção" do
      assert_equal 679 - 1, @resultado.variants.size
      assert(@resultado.variants.all? { |v| v.variant_code.present? && v.card_number.present? })
    end
  end
end
