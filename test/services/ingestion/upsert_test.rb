require "test_helper"

module Ingestion
  class UpsertTest < ActiveSupport::TestCase
    FIXTURE = Rails.root.join("spec", "fixtures", "apitcg-subset.json")
    REVISION = "apitcg-teste".freeze

    # Relógio monotônico (AD-009): o de parede deste host anda para trás, o que
    # inverte a ordem entre marcas de duas execuções sem que a ingestão tenha
    # errado. Cada leitura é estritamente maior que a anterior.
    class RelogioCrescente
      def initialize(inicio = Time.current.change(usec: 0), passo: 1.second)
        @proximo = inicio
        @passo = passo
      end

      def current
        instante = @proximo
        @proximo += @passo
        instante
      end
    end

    # Snapshot sintético no formato da apitcg: um set `TST` e os produtos dados.
    def snapshot(*produtos, sets: [ conjunto ])
      { "sets" => sets, "cards" => produtos }
    end

    def conjunto(id = "one-piece-teste", code: "TST", release: "2024-01-01")
      { "_id" => id, "name" => id, "code" => code, "release_date" => release }
    end

    def produto(id, code = nil, nome: "Carta", set_id: "one-piece-teste", tcgplayer: id)
      {
        "_id" => id, "type" => "card", "name" => nome, "code" => code || format("TST-%03d", id),
        "set" => { "_id" => set_id },
        "images" => [ { "large" => "https://tcgplayer-cdn.tcgplayer.com/product/#{id}.jpg" } ],
        "markets" => { "tcgplayer" => { "id" => tcgplayer.to_s } },
        "attributes" => { "CardType" => "Character", "Rarity" => "C" }
      }
    end

    def normalized(snapshot) = Apitcg::Normalize.call(snapshot)

    def ingest(result, clock: Time, revision: REVISION)
      Upsert.new(result, source: "apitcg", revision: revision, clock: clock).call
    end

    def variante(tcgplayer) = CardVariant.find_by!(variant_code: "tcgplayer:#{tcgplayer}")

    def presentes = CardVariant.present.order(:id).pluck(:id)

    # Troca um método de classe só durante o bloco; o minitest/mock não existe
    # nesta versão do Minitest.
    def substituir(alvo, nome, corpo)
      original = alvo.method(nome)
      alvo.define_singleton_method(nome, &corpo)
      yield
    ensure
      alvo.define_singleton_method(nome, original)
    end

    # Upsert por `card_number` e por `(card_id, variant_code)`, nunca create
    # cego. Req. 1.2 e 1.3.
    test "segunda execução atualiza a carta existente em vez de duplicar" do
      ingest(normalized(snapshot(produto(1, nome: "Nome Antigo"))))

      assert_equal 1, Card.count
      assert_equal "Nome Antigo", Card.sole.name

      ingest(normalized(snapshot(produto(1, nome: "Nome Novo"))))

      assert_equal 1, Card.count, "a carta foi duplicada em vez de atualizada"
      assert_equal "Nome Novo", Card.sole.name
    end

    test "segunda execução atualiza a variante existente em vez de duplicar" do
      ingest(normalized(snapshot(produto(1))))
      existente = CardVariant.sole

      ingest(normalized(snapshot(produto(1))))

      assert_equal 1, CardVariant.count
      assert_equal existente.id, CardVariant.sole.id, "a variante foi recriada, quebrando o vínculo da coleção"
    end

    # A mesma impressão (mesmo tcgplayer.id) listada em dois sets vira um único
    # registro: o normalizador a mantém no primeiro set em que aparece.
    test "variante distribuída em dois sets vira um único registro" do
      outro = conjunto("one-piece-outro", code: "OUT")
      ingest(normalized(snapshot(
        produto(1, "TST-001", tcgplayer: 500),
        produto(2, "TST-001", set_id: "one-piece-outro", tcgplayer: 500),
        sets: [ conjunto, outro ]
      )))

      assert_equal 1, CardVariant.where(variant_code: "tcgplayer:500").count
      assert_equal 1, CardVariant.count
    end

    # Req. 1.2/1.3 sobre a fixture inteira.
    test "a fixture completa entra com as contagens da fonte" do
      run = ingest(normalized(FIXTURE.read))

      assert_equal 11, Card.count
      assert_equal 13, CardVariant.count
      assert_equal 10, CardSet.count
      assert_equal "succeeded", run.status
    end

    # Req. 1.6 e 1.10: início, fim, status, as três contagens e a revisão.
    test "o resumo registra início, fim, status e as três contagens" do
      run = ingest(normalized(snapshot(produto(1))), clock: RelogioCrescente.new)

      assert_not_nil run.started_at
      assert_operator run.finished_at, :>, run.started_at
      assert_equal "succeeded", run.status
      assert_equal 3, run.created_count, "1 set + 1 carta + 1 variante"
      assert_equal 0, run.updated_count
      assert_equal 0, run.failed_count
    end

    test "o resumo registra a revisão da fonte utilizada" do
      run = ingest(normalized(snapshot(produto(1))))

      assert_equal REVISION, run.source_revision
      assert_equal "apitcg", run.source
    end

    test "a segunda execução conta atualizações, não criações" do
      resultado = normalized(snapshot(produto(1)))
      ingest(resultado)

      run = ingest(resultado)

      assert_equal 0, run.created_count
      assert_equal 3, run.updated_count
    end

    # Req. 1.5: o erro de um registro vai para `import_runs.error_log` e o laço
    # continua — não pode ser engolido nem abortar tudo.
    test "erro em um registro é logado e os demais continuam sendo gravados" do
      result = normalized(snapshot(produto(1), produto(2), produto(3)))
      # Uma carta sem nome viola a validação do model: é o defeito isolado.
      result.cards[1].name = nil

      run = ingest(result)

      # Duas falhas, não uma: a carta TST-002 é rejeitada e a variante dela não
      # tem mais a que se ligar. Esse encadeamento é o comportamento certo — o
      # errado seria a variante virar órfã ou se prender a outra carta.
      assert_equal 2, run.failed_count
      assert_equal 2, Card.count, "as outras duas cartas tinham de ter sido gravadas"
      assert_equal 2, CardVariant.count
      assert_equal "failed", run.status
    end

    test "o error_log identifica o registro que falhou e o motivo" do
      result = normalized(snapshot(produto(1), produto(2)))
      result.cards[0].name = nil

      run = ingest(result)
      entrada = run.error_log.find { |e| e["error"] == "ActiveRecord::RecordInvalid" }

      assert_equal "TST-001", entrada["identifier"]
      assert_match(/Name/i, entrada["message"])

      # A variante órfã é registrada à parte, com o próprio identificador: um
      # erro encadeado não pode desaparecer atrás do erro que o causou.
      orfa = run.error_log.find { |e| e["identifier"] == "tcgplayer:1" }

      assert_equal "ActiveRecord::RecordNotFound", orfa["error"]
    end

    test "execução sem falha nem descarte não deixa error_log preenchido" do
      run = ingest(normalized(snapshot(produto(1))))

      assert_nil run.error_log
    end

    # Req. 1.5: a transação é por registro. Se fosse uma só, o registro
    # defeituoso levaria os bons junto.
    test "a falha de um registro não desfaz os registros já gravados" do
      result = normalized(snapshot(produto(1), produto(2)))
      result.cards[1].name = nil

      ingest(result)

      assert_equal "TST-001", Card.sole.card_number
      assert_equal 1, CardVariant.count
    end

    # SRC-12: o set de estreia da carta vem da impressão base do set cujo código
    # é o prefixo do número, mesmo que outro set a liste primeiro.
    test "o set de estreia da carta vem da base do set com o prefixo do número" do
      promo = conjunto("one-piece-promocao", code: "OP-PR", release: "2025-06-01")
      ingest(normalized(snapshot(
        produto(1, "TST-001", nome: "Carta (Promo)", set_id: "one-piece-promocao"),
        produto(2, "TST-001"),
        sets: [ promo, conjunto ]
      )))

      assert_equal "TST", Card.sole.card_set.code
    end

    # SRC-11: descarte não é falha.
    test "SRC-11: run só com descartes termina succeeded e os registra no error_log" do
      sem_code = produto(900).merge("code" => nil)
      run = ingest(normalized(snapshot(produto(1), sem_code)))

      assert_equal "succeeded", run.status
      assert_equal 0, run.failed_count
      assert_equal [ { "identifier" => "900", "error" => "discarded", "message" => "sem code" } ],
                   run.error_log
    end

    # SRC-36: produto sem CardType é descarte, não falha.
    test "SRC-36: produto sem CardType e produto sem code terminam succeeded com failed_count 0 e dois descartes" do
      sem_tipo = produto(901)
      sem_tipo["attributes"] = { "Rarity" => "C" }
      sem_code = produto(900).merge("code" => nil)

      run = ingest(normalized(snapshot(produto(1), sem_code, sem_tipo)))

      assert_equal "succeeded", run.status
      assert_equal 0, run.failed_count
      assert_equal [ { "identifier" => "900", "error" => "discarded", "message" => "sem code" },
                     { "identifier" => "901", "error" => "discarded", "message" => "sem CardType" } ],
                   run.error_log.sort_by { |e| e["identifier"] }
      assert_equal 1, CardVariant.count
    end

    test "SRC-11: a fixture termina succeeded com o descarte do produto sem code" do
      run = ingest(normalized(FIXTURE.read))

      assert_equal "succeeded", run.status
      assert_equal [ { "identifier" => "6117", "error" => "discarded", "message" => "sem code" } ],
                   run.error_log
    end

    test "SRC-11: erro real continua levando a failed e vem antes dos descartes no error_log" do
      sem_code = produto(900).merge("code" => nil)
      result = normalized(snapshot(produto(1), sem_code))
      result.cards[0].name = nil

      run = ingest(result)

      assert_equal "failed", run.status
      assert_equal 2, run.failed_count, "só o erro real conta: carta e variante; o descarte não"
      assert_equal %w[ActiveRecord::RecordInvalid ActiveRecord::RecordNotFound discarded],
                   run.error_log.map { |e| e["error"] }
    end

    test "SRC-11: o teto do error_log não deixa descartes esconderem erros reais" do
      result = normalized(snapshot(*(1..60).map { |n| produto(n) }, produto(900).merge("code" => nil)))
      result.cards.each { |c| c.name = nil }

      run = ingest(result)

      assert_equal 120, run.failed_count
      assert_equal Upsert::MAX_LOGGED_ERRORS, run.error_log.size
      assert_empty run.error_log.select { |e| e["error"] == "discarded" }
    end

    test "SRC-11: só descartes também respeitam o teto do error_log" do
      sem_code = (1..Upsert::MAX_LOGGED_ERRORS + 1).map { |n| produto(1000 + n).merge("code" => nil) }

      run = ingest(normalized(snapshot(produto(1), *sem_code)))

      assert_equal "succeeded", run.status
      assert_equal Upsert::MAX_LOGGED_ERRORS, run.error_log.size
    end

    # SRC-06: a origem do snapshot é o nome do arquivo e o SHA-256 do conteúdo.
    test "SRC-06: source_revision é o nome do arquivo e o sha256 conferido contra ele" do
      run = Upsert.new(normalized(FIXTURE.read), source: "apitcg", snapshot: FIXTURE).call

      hex = Digest::SHA256.file(FIXTURE).hexdigest

      assert_match(/\A[0-9a-f]{64}\z/, hex)
      assert_equal "apitcg-subset.json sha256:#{hex}", run.source_revision
    end

    test "SRC-06: snapshot aceita String além de Pathname" do
      run = Upsert.new(normalized(FIXTURE.read), source: "apitcg", snapshot: FIXTURE.to_s).call

      assert_equal "apitcg-subset.json sha256:#{Digest::SHA256.file(FIXTURE).hexdigest}", run.source_revision
    end

    test "SRC-06: exige exatamente um entre revision: e snapshot:" do
      resultado = normalized(snapshot(produto(1)))

      assert_raises(ArgumentError) { Upsert.new(resultado, source: "apitcg") }
      assert_raises(ArgumentError) do
        Upsert.new(resultado, source: "apitcg", revision: "x", snapshot: FIXTURE)
      end
    end

    # SRC-16: a presença é gravada no fechamento do run `succeeded`.
    test "SRC-16: run succeeded grava last_seen_at = started_at em toda carta e variante aplicada" do
      run = ingest(normalized(snapshot(produto(1), produto(2), produto(3))), clock: RelogioCrescente.new)

      assert_equal "succeeded", run.status
      assert_equal 3, Card.count
      assert_equal 3, CardVariant.count
      assert_equal [ run.started_at ], Card.distinct.pluck(:last_seen_at)
      assert_equal [ run.started_at ], CardVariant.distinct.pluck(:last_seen_at)
    end

    test "SRC-16: o que o run succeeded não viu mantém a marca antiga" do
      relogio = RelogioCrescente.new
      primeiro = ingest(normalized(snapshot(produto(1), produto(2))), clock: relogio)
      segundo = ingest(normalized(snapshot(produto(2))), clock: relogio)

      assert_equal primeiro.started_at, variante(1).last_seen_at
      assert_equal segundo.started_at, variante(2).last_seen_at
      assert_equal primeiro.started_at, Card.find_by!(card_number: "TST-001").last_seen_at
    end

    test "SRC-16: run failed depois de um succeeded não muda a presença de ninguém" do
      relogio = RelogioCrescente.new
      primeiro = ingest(normalized(snapshot(produto(1), produto(2))), clock: relogio)
      antes = presentes

      result = normalized(snapshot(produto(1), produto(3), produto(4)))
      result.cards.find { |c| c.card_number == "TST-004" }.name = nil
      segundo = ingest(result, clock: relogio)

      assert_equal "failed", segundo.status
      assert_nil variante(3).last_seen_at, "variante criada no run failed nasce fora da fonte"
      assert_equal primeiro.started_at, variante(1).last_seen_at,
                   "variante reaplicada num run failed mantém a marca do último succeeded"
      assert_equal primeiro.started_at, Card.find_by!(card_number: "TST-001").last_seen_at
      assert_nil Card.find_by!(card_number: "TST-003").last_seen_at
      assert_equal antes, presentes
      assert_not_includes presentes, variante(3).id
    end

    test "SRC-16: falha ao gravar o status no finish não deixa last_seen_at avançado" do
      criar = lambda do |**atributos|
        ImportRun.new(**atributos).tap(&:save!).tap do |run|
          run.define_singleton_method(:update!) { |*| raise ActiveRecord::StatementInvalid, "falha forçada" }
        end
      end

      substituir(ImportRun, :create!, criar) do
        assert_raises(ActiveRecord::StatementInvalid) { ingest(normalized(snapshot(produto(1)))) }
      end

      assert_equal 1, CardVariant.count, "os dados do registro continuam gravados, como antes"
      assert_nil CardVariant.sole.last_seen_at
      assert_nil Card.sole.last_seen_at
    end

    test "SRC-16: finish toma o lock de presença dentro de uma transação" do
      original = ImportRun.method(:lock_presence!)
      profundidades = []
      base = ImportRun.connection.open_transactions
      espia = lambda do
        profundidades << ImportRun.connection.open_transactions
        original.call
      end

      substituir(ImportRun, :lock_presence!, espia) { ingest(normalized(snapshot(produto(1)))) }

      assert_equal 1, profundidades.size
      assert_operator profundidades.first, :>, base, "lock_presence! rodou fora da transação do finish"
    end

    # ---------- preço (T3 da `precos`: PRC-01, PRC-02, PRC-04, PRC-07) ----------

    def com_preco(produto, market)
      produto["markets"]["tcgplayer"]["prices"] = { "market" => market }
      produto
    end

    def preco(tcgplayer)
      v = variante(tcgplayer)
      [ v.price_amount, v.price_currency, v.price_observed_at ]
    end

    test "PRC-01: grava valor, USD e a data em que o import começou" do
      run = ingest(normalized(snapshot(com_preco(produto(1), 1.7))), clock: RelogioCrescente.new)

      assert_equal [ BigDecimal("1.7"), "USD", run.started_at ], preco(1)
    end

    test "PRC-01: o import seguinte troca o valor e a data" do
      relogio = RelogioCrescente.new
      ingest(normalized(snapshot(com_preco(produto(1), 1.7))), clock: relogio)
      segundo = ingest(normalized(snapshot(com_preco(produto(1), 2.25))), clock: relogio)

      assert_equal [ BigDecimal("2.25"), "USD", segundo.started_at ], preco(1)
    end

    test "PRC-02: o produto que perdeu o market deixa a variante sem preço" do
      relogio = RelogioCrescente.new
      ingest(normalized(snapshot(com_preco(produto(1), 1.7))), clock: relogio)
      ingest(normalized(snapshot(produto(1))), clock: relogio)

      assert_equal [ nil, nil, nil ], preco(1)
    end

    test "PRC-02: market inválido não falha o registro" do
      run = ingest(normalized(snapshot(com_preco(produto(1), "1.70"))), clock: RelogioCrescente.new)

      assert_equal "succeeded", run.status
      assert_equal 0, run.failed_count
      assert_equal [ nil, nil, nil ], preco(1)
    end

    test "PRC-04: a variante ausente da fonte mantém o último preço e a data dele" do
      relogio = RelogioCrescente.new
      primeiro = ingest(normalized(snapshot(com_preco(produto(1), 1.7), com_preco(produto(2), 3))), clock: relogio)
      ingest(normalized(snapshot(com_preco(produto(2), 4))), clock: relogio)

      assert_equal [ BigDecimal("1.7"), "USD", primeiro.started_at ], preco(1)
    end

    test "PRC-07: o mesmo snapshot duas vezes dá os mesmos preços e não toca na coleção" do
      dados = normalized(snapshot(com_preco(produto(1), 1.7), produto(2)))
      relogio = RelogioCrescente.new
      ingest(dados, clock: relogio)
      dono = User.create!(email: "colecionador@exemplo.test", password_digest: "x")
      item = CollectionItem.create!(user: dono, card_variant: variante(1), quantity: 3)

      ingest(dados, clock: relogio)

      assert_equal [ BigDecimal("1.7"), "USD" ], preco(1).first(2)
      assert_equal [ nil, nil ], preco(2).first(2)
      assert_equal 3, item.reload.quantity
      assert_equal variante(1).id, item.card_variant_id
    end
  end
end
