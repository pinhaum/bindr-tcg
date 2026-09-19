require "test_helper"

module Ingestion
  class UpsertTest < ActiveSupport::TestCase
    FIXTURE = Rails.root.join("spec", "fixtures", "optcgjson-subset.json")
    REVISION = "5669eab51096629faf90dbf0dc903128cff80a98".freeze

    def normalized(payload = FIXTURE.read) = Normalize.call(payload)

    def ingest(result = normalized, revision: REVISION)
      Upsert.new(result, source: "optcgjson", revision: revision).call
    end

    def minimal_payload(cards:)
      { "data" => [ { "code" => "TST", "name" => "Teste", "type" => "booster",
                      "baseSetSize" => 1, "totalSetSize" => 1, "cards" => cards } ] }
    end

    def raw_card(id:, number: nil, name: "Carta", card_class: "CHARACTER")
      { "id" => id, "number" => number || id, "name" => name, "rarity" => "C",
        "cardClass" => card_class, "color" => [ "Red" ], "attribute" => [], "feature" => [],
        "isParallel" => false, "imageUrl" => "https://exemplo/#{id}.png" }
    end

    # Done when: upsert por `card_number` e por `(card_id, variant_code)`,
    # nunca create cego. Req. 1.2 e 1.3.
    test "segunda execução atualiza a carta existente em vez de duplicar" do
      ingest(normalized(minimal_payload(cards: [ raw_card(id: "TST-001", name: "Nome Antigo") ])))

      assert_equal 1, Card.count
      assert_equal "Nome Antigo", Card.sole.name

      ingest(normalized(minimal_payload(cards: [ raw_card(id: "TST-001", name: "Nome Novo") ])))

      assert_equal 1, Card.count, "a carta foi duplicada em vez de atualizada"
      assert_equal "Nome Novo", Card.sole.name
    end

    test "segunda execução atualiza a variante existente em vez de duplicar" do
      ingest(normalized(minimal_payload(cards: [ raw_card(id: "TST-001") ])))
      variante = CardVariant.sole

      ingest(normalized(minimal_payload(cards: [ raw_card(id: "TST-001") ])))

      assert_equal 1, CardVariant.count
      assert_equal variante.id, CardVariant.sole.id, "a variante foi recriada, quebrando o vínculo da coleção"
    end

    # Done when: mesma variante em dois sets não gera duplicata (P-029_r1).
    test "variante distribuída em dois sets vira um único registro" do
      ingest

      assert_equal 1, CardVariant.where(variant_code: "P-029_r1").count
    end

    # Req. 1.2/1.3 sobre a fixture inteira: 376 cartas e 678 variantes.
    test "a fixture completa entra com as contagens da fonte" do
      run = ingest

      assert_equal 376, Card.count
      assert_equal 678, CardVariant.count
      assert_equal 5, CardSet.count
      assert_equal "succeeded", run.status
    end

    # Done when: resumo com início, fim, status, criados, atualizados,
    # falhados e revisão utilizada. Req. 1.6 e 1.10.
    test "o resumo registra início, fim, status e as três contagens" do
      run = ingest(normalized(minimal_payload(cards: [ raw_card(id: "TST-001") ])))

      assert_not_nil run.started_at
      assert_not_nil run.finished_at
      assert_operator run.finished_at, :>=, run.started_at
      assert_equal "succeeded", run.status
      assert_equal 3, run.created_count, "1 set + 1 carta + 1 variante"
      assert_equal 0, run.updated_count
      assert_equal 0, run.failed_count
    end

    test "o resumo registra a revisão da fonte utilizada" do
      run = ingest(normalized(minimal_payload(cards: [ raw_card(id: "TST-001") ])))

      assert_equal REVISION, run.source_revision
      assert_equal "optcgjson", run.source
    end

    test "a segunda execução conta atualizações, não criações" do
      payload = normalized(minimal_payload(cards: [ raw_card(id: "TST-001") ]))
      ingest(payload)

      run = ingest(payload)

      assert_equal 0, run.created_count
      assert_equal 3, run.updated_count
    end

    # Done when: erro em um registro vai para `import_runs.error_log` e o
    # loop continua. Req. 1.5 — o erro não pode ser engolido nem abortar tudo.
    test "erro em um registro é logado e os demais continuam sendo gravados" do
      result = normalized(minimal_payload(cards: [
        raw_card(id: "TST-001"), raw_card(id: "TST-002"), raw_card(id: "TST-003")
      ]))
      # Uma carta sem nome viola a validação do model: é o defeito isolado.
      result.cards[1].name = nil

      run = ingest(result)

      # Duas falhas, não uma: a carta TST-002 é rejeitada pela validação e a
      # variante dela não tem mais a que se ligar. Esse encadeamento é o
      # comportamento certo — o errado seria a variante virar órfã ou se
      # prender a outra carta.
      assert_equal 2, run.failed_count
      assert_equal 2, Card.count, "as outras duas cartas tinham de ter sido gravadas"
      assert_equal 2, CardVariant.count
      assert_equal "failed", run.status
    end

    test "o error_log identifica o registro que falhou e o motivo" do
      result = normalized(minimal_payload(cards: [ raw_card(id: "TST-001"), raw_card(id: "TST-002") ]))
      result.cards[0].name = nil

      run = ingest(result)
      entrada = run.error_log.find { |e| e["error"] == "ActiveRecord::RecordInvalid" }

      assert_equal "TST-001", entrada["identifier"]
      assert_match(/Name/i, entrada["message"])

      # A variante órfã é registrada à parte, com o próprio identificador:
      # um erro encadeado não pode desaparecer atrás do erro que o causou.
      orfa = run.error_log.find { |e| e["identifier"] == "TST-001" && e["error"] != "ActiveRecord::RecordInvalid" }

      assert_equal "ActiveRecord::RecordNotFound", orfa["error"]
    end

    test "execução sem falha não deixa error_log preenchido" do
      run = ingest(normalized(minimal_payload(cards: [ raw_card(id: "TST-001") ])))

      assert_nil run.error_log
    end

    # Req. 1.5 — a transação é por registro. Se fosse uma só, o registro
    # defeituoso levaria os bons junto.
    test "a falha de um registro não desfaz os registros já gravados" do
      result = normalized(minimal_payload(cards: [ raw_card(id: "TST-001"), raw_card(id: "TST-002") ]))
      result.cards[1].name = nil

      ingest(result)

      assert_equal "TST-001", Card.sole.card_number
      assert_equal 1, CardVariant.count
    end

    # Done when (T3/design.md §5.2): a ingestão marca o que viu, para poder
    # sinalizar o ausente sem deletar.
    test "cada registro gravado recebe a marca da execução" do
      run = ingest(normalized(minimal_payload(cards: [ raw_card(id: "TST-001") ])))

      assert_equal run.started_at.to_i, Card.sole.last_seen_at.to_i
      assert_equal run.started_at.to_i, CardVariant.sole.last_seen_at.to_i
    end

    test "o set de estreia da carta vem do primeiro set em que ela aparece" do
      ingest

      promo = Card.find_by(card_number: "P-029")

      assert_equal "PRB01", promo.card_set.code
    end
  end
end
