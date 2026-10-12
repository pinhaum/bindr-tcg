require "test_helper"

module CollectionCsv
  # `Commit` testado direto, sem HTTP (STRO-31): a única escrita da portabilidade
  # e as garantias que antes só o HTML provava. A entrada é um staging montado à
  # mão, porque o `Commit` nunca vê o arquivo.
  class CommitTest < ActiveSupport::TestCase
    setup do
      @nami = User.create!(email: "nami-commit@exemplo.test", password: "grand-line-14")
      @zoro = User.create!(email: "zoro-commit@exemplo.test", password: "grand-line-14")
      @set = CardSet.create!(code: "OPc3", name: "Romance Dawn", kind: "booster")

      @existente = variant("a")
      @zerada = variant("b")
      @nova = variant("c")
      @igual = variant("d")

      own(@nami, @existente, 2)
      own(@nami, @zerada, 5)
      own(@nami, @igual, 3)

      [ @existente, @zerada, @nova, @igual ].each { |v| own(@zoro, v, 9) }
    end

    # --- Result ---

    test "o Result separa as contagens por classificação e lista as rejeitadas" do
      preview = staging(completo)

      resultado = Commit.new(@nami, preview.token).call

      assert resultado.reivindicada?
      assert_equal 1, resultado.criadas
      assert_equal 1, resultado.atualizadas
      assert_equal 1, resultado.zeradas
      assert_equal 1, resultado.inalteradas
      assert_equal 3, resultado.gravadas, "inalterada é gravada, mas não conta como mudança"
      assert_equal 1, resultado.rejeitadas
      assert_equal [ 4 ], resultado.rejeitadas_detalhadas.map(&:indice)
      assert_empty resultado.falhas, "sem falha, falhas é lista vazia"
    end

    test "as rejeitadas do Result são exatamente as linhas que não tocaram a coleção" do
      preview = staging(completo)
      antes = retrato(@nami)

      resultado = Commit.new(@nami, preview.token).call
      depois = retrato(@nami)

      assert_equal 1, resultado.rejeitadas
      assert_equal (antes.keys + [ @nova.id ]).sort, depois.keys.sort,
                   "a única posse nova é a da linha :cria; a rejeitada não deixou marca"
      assert_equal 4, CollectionItem.for_user(@nami).count,
                   "quatro linhas aceitas viram quatro registros; a quinta não entra"
    end

    # --- Linha rejeitada ---

    test "a linha rejeitada com variante resolvida não é gravada, por decisão do Commit" do
      preview = staging([
        linha(0, @nova, :cria, antes: nil, depois: 5),
        linha(1, @nova, :rejeita, antes: nil, depois: 1, motivo: :linha_duplicada)
      ])

      resultado = Commit.new(@nami, preview.token).call

      assert_equal 5, quantidade(@nami, @nova),
                   "a rejeitada pede 1; gravá-la sobrescreveria a vencedora"
      assert_equal 1, resultado.rejeitadas
      assert_empty resultado.falhas
    end

    test "a linha rejeitada sem quantidade não vira falha de constraint" do
      preview = staging([
        linha(0, @nova, :cria, antes: nil, depois: 5),
        linha(1, @nova, :rejeita, antes: nil, depois: nil, motivo: :quantidade_invalida)
      ])

      resultado = Commit.new(@nami, preview.token).call

      assert_empty resultado.falhas,
                   "se a rejeitada chegasse ao banco, o NOT NULL a derrubaria e apareceria aqui"
      assert_equal 1, resultado.gravadas
    end

    # --- Staging ---

    test "o staging é a única entrada: adulterá-lo muda o que é gravado" do
      preview = staging(completo)
      adulteradas = preview.linhas.map do |l|
        l["card_variant_id"] == @existente.id ? l.merge("quantidade_depois" => 42) : l
      end
      preview.update!(linhas: adulteradas)

      Commit.new(@nami, preview.token).call

      assert_equal 42, quantidade(@nami, @existente)
    end

    test "o Commit substitui a quantidade em vez de somar" do
      preview = staging([ linha(0, @existente, :atualiza, antes: 2, depois: 7) ])

      Commit.new(@nami, preview.token).call

      assert_equal 7, quantidade(@nami, @existente)
    end

    test "token inexistente ou de outro usuário devolve nil e não grava" do
      preview = staging(completo)
      antes = CollectionItem.order(:id).pluck(:id, :user_id, :quantity)

      assert_nil Commit.new(@nami, "token-que-nunca-existiu").call
      assert_nil Commit.new(@zoro, preview.token).call

      assert_equal antes, CollectionItem.order(:id).pluck(:id, :user_id, :quantity)
      assert_equal "pendente", preview.reload.status
    end

    test "a escrita não toca a coleção de outro usuário" do
      preview = staging(completo)
      zoro_antes = CollectionItem.for_user(@zoro).order(:id).pluck(:card_variant_id, :quantity)

      Commit.new(@nami, preview.token).call

      assert_equal zoro_antes,
                   CollectionItem.for_user(@zoro).order(:id).pluck(:card_variant_id, :quantity)
    end

    # --- Reivindicação ---

    test "a reivindicação é um único UPDATE condicional, sem SELECT antes" do
      preview = staging(completo)

      statements = sql_emitido { Commit.reivindicar(preview.id) }

      assert_equal 1, statements.size, statements.inspect
      sql = statements.first
      assert_match(/\AUPDATE collection_imports/i, sql)
      assert_match(/WHERE.*status\s*=\s*'pendente'/im, sql)
      assert_match(/WHERE.*expires_at\s*>\s*now\(\)/im, sql)
      assert_match(/RETURNING/i, sql)
    end

    test "a segunda reivindicação afeta zero linhas e a segunda chamada devolve não reivindicado" do
      preview = staging(completo)

      assert Commit.reivindicar(preview.id)
      assert_not Commit.reivindicar(preview.id)

      outra = staging(completo)
      Commit.new(@nami, outra.token).call
      CollectionItem.for_user(@nami).find_by(card_variant: @existente).update!(quantity: 8)
      depois_da_primeira = retrato(@nami)

      segunda = Commit.new(@nami, outra.token).call

      assert_not segunda.reivindicada?
      assert_equal 0, segunda.gravadas
      assert_equal 0, segunda.rejeitadas
      assert_empty segunda.rejeitadas_detalhadas
      assert_empty segunda.falhas
      assert_equal depois_da_primeira, retrato(@nami), "a segunda chamada não reaplica o staging"
    end

    test "pré-visualização vencida não é reivindicada nem grava" do
      preview = staging(completo)
      preview.update_column(:expires_at, 1.second.ago)
      antes = retrato(@nami)

      resultado = Commit.new(@nami, preview.token).call

      assert_not resultado.reivindicada?
      assert_equal antes, retrato(@nami)
      assert_equal "pendente", preview.reload.status
    end

    test "reivindicação e escrita ficam na mesma transação, com savepoint por linha" do
      preview = staging(completo)
      conexao = CollectionItem.connection

      eventos = []
      assinatura = lambda do |*, payload|
        next if payload[:name] == "SCHEMA"

        tipo =
          if payload[:sql] =~ /\AUPDATE collection_imports/i then :reivindica
          elsif payload[:sql] =~ /INSERT INTO collection_items/i then :escreve
          end
        eventos << [ tipo, conexao.open_transactions ] if tipo
      end

      ActiveSupport::Notifications.subscribed(assinatura, "sql.active_record") do
        Commit.new(@nami, preview.token).call
      end

      reivindicacoes = eventos.select { |t, _| t == :reivindica }
      escritas = eventos.select { |t, _| t == :escreve }

      assert_equal 1, reivindicacoes.size
      assert_equal 4, escritas.size
      assert_equal :reivindica, eventos.first.first, "nada é gravado antes da reivindicação"
      escritas.each do |_, profundidade|
        assert_operator profundidade, :>, reivindicacoes.first.last
      end
    end

    # --- Falha de linha ---

    test "uma linha que falha por erro do Active Record não desfaz as anteriores" do
      linhas = completo
      linhas[0].card_variant_id = 0
      preview = staging(linhas)

      resultado = Commit.new(@nami, preview.token).call

      assert_equal 7, quantidade(@nami, @existente)
      assert_equal 0, quantidade(@nami, @zerada)
      assert_equal "confirmado", preview.reload.status
      assert_equal 1, resultado.falhas.size
      assert_equal "ActiveRecord::InvalidForeignKey", resultado.falhas.first[:erro]
    end

    test "uma falha que não é do Active Record não desfaz as anteriores nem impede o fechamento" do
      preview = staging(completo)

      resultado = com_upsert_falhando_em(@zerada.id, RuntimeError.new("bug")) do
        Commit.new(@nami, preview.token).call
      end

      assert_equal 4, quantidade(@nami, @nova), "a linha anterior à que falhou continua gravada"
      assert_equal 7, quantidade(@nami, @existente)
      assert_equal 5, quantidade(@nami, @zerada), "a que falhou não gravou"
      assert_equal 3, quantidade(@nami, @igual), "a posterior continua sendo processada"
      assert_equal "confirmado", preview.reload.status
      assert_equal [ "RuntimeError" ], resultado.falhas.map { |f| f[:erro] }
    end

    test "um erro cru do driver do banco não desfaz as anteriores" do
      preview = staging(completo)

      resultado = com_upsert_falhando_em(@zerada.id, PG::Error.new("conexão perdida")) do
        Commit.new(@nami, preview.token).call
      end

      assert_equal 4, quantidade(@nami, @nova)
      assert_equal "confirmado", preview.reload.status
      assert_equal [ "PG::Error" ], resultado.falhas.map { |f| f[:erro] }
    end

    test "a linha que falhou não entra em contagem nenhuma" do
      preview = staging(completo)

      resultado = com_upsert_falhando_em(@nova.id, RuntimeError.new("bug")) do
        Commit.new(@nami, preview.token).call
      end

      assert_equal 0, resultado.criadas
      assert_equal 1, resultado.atualizadas
      assert_equal 1, resultado.zeradas
      assert_equal 1, resultado.inalteradas
      assert_equal 1, resultado.rejeitadas, "falha de gravação não é rejeição"
      assert_equal 1, resultado.falhas.size
      assert_equal @nova.variant_code, resultado.falhas.first[:variant_code]
    end

    test "SignalException propaga e não vira linha que falhou" do
      preview = staging(completo)

      assert_raises(SignalException) do
        com_upsert_falhando_em(@nova.id, SignalException.new("TERM")) do
          Commit.new(@nami, preview.token).call
        end
      end
    end

    # --- Teto ---

    test "um lote acima do teto levanta LoteGrandeDemais antes de gravar qualquer linha" do
      preview = staging(completo)
      antes = retrato(@nami)

      com_teto_de(1) do
        assert_raises(Commit::LoteGrandeDemais) { Commit.new(@nami, preview.token).call }
      end

      assert_equal antes, retrato(@nami)
      assert_equal "pendente", preview.reload.status
    end

    # --- Absorção ---

    test "o registro criado depois da prévia é absorvido pelo ON CONFLICT" do
      preview = staging([ linha(0, @nova, :cria, antes: nil, depois: 4) ])
      own(@nami, @nova, 1)

      resultado = Commit.new(@nami, preview.token).call

      assert_equal 4, quantidade(@nami, @nova)
      assert_empty resultado.falhas
    end

    test "o registro apagado depois da prévia é recriado" do
      preview = staging([ linha(0, @existente, :atualiza, antes: 2, depois: 7) ])
      CollectionItem.for_user(@nami).find_by(card_variant: @existente).destroy!

      resultado = Commit.new(@nami, preview.token).call

      assert_equal 7, quantidade(@nami, @existente)
      assert_empty resultado.falhas
    end

    private

      def variant(suffix)
        card = Card.create!(card_set: @set, card_number: "OP14-#{suffix}", name: "Carta #{suffix}",
                            card_type: "character", colors: [ "Red" ])
        CardVariant.create!(card: card, card_set: @set, variant_code: "c3#{suffix}",
                            rarity: "C", art_kind: "base")
      end

      def own(user, card_variant, quantity)
        CollectionItem.create!(user: user, card_variant: card_variant, quantity: quantity)
      end

      def linha(indice, variante, classificacao, antes:, depois:, motivo: nil)
        Resolver::Linha.new(
          indice: indice, card_number: variante.card.card_number,
          variant_code: variante.variant_code, card_name: variante.card.name,
          quantidade_bruta: depois.to_s, card_variant_id: variante.id,
          classificacao: classificacao, quantidade_antes: antes, quantidade_depois: depois,
          motivo: motivo, mensagem: nil
        )
      end

      # As cinco classificações: cria, atualiza, zera, inalterada e uma rejeição
      # por variante inexistente (sem `card_variant_id`).
      def completo
        rejeitada = Resolver::Linha.new(
          indice: 4, card_number: "OP14-zzz", variant_code: "zzz", card_name: "Inexistente",
          quantidade_bruta: "6", card_variant_id: nil, classificacao: :rejeita,
          quantidade_antes: nil, quantidade_depois: nil, motivo: :variante_inexistente,
          mensagem: "Não existe no catálogo."
        )
        [
          linha(0, @nova, :cria, antes: nil, depois: 4),
          linha(1, @existente, :atualiza, antes: 2, depois: 7),
          linha(2, @zerada, :zera, antes: 5, depois: 0),
          linha(3, @igual, :inalterada, antes: 3, depois: 3),
          rejeitada
        ]
      end

      def staging(linhas, user: @nami)
        CollectionImport.create!(user: user, filename: "colecao.csv", linhas: linhas.map(&:to_h))
      end

      def quantidade(user, card_variant)
        CollectionItem.for_user(user).find_by(card_variant: card_variant)&.quantity
      end

      def retrato(user)
        CollectionItem.for_user(user).pluck(:card_variant_id, :quantity).to_h
      end

      def sql_emitido(&block)
        statements = []
        assinatura = lambda do |*, payload|
          sql = payload[:sql]
          next if payload[:name] == "SCHEMA" || sql =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i

          statements << sql
        end
        ActiveSupport::Notifications.subscribed(assinatura, "sql.active_record", &block)
        statements
      end

      def com_teto_de(limite)
        original = Parser::MAX_LINHAS
        Parser.send(:remove_const, :MAX_LINHAS)
        Parser.const_set(:MAX_LINHAS, limite)
        yield
      ensure
        Parser.send(:remove_const, :MAX_LINHAS)
        Parser.const_set(:MAX_LINHAS, original)
      end

      # Faz o `upsert` de uma variante levantar `erro`; as demais seguem o
      # caminho real. É o único jeito de produzir falha que não é do AR.
      def com_upsert_falhando_em(card_variant_id, erro)
        original = Commit.instance_method(:upsert)
        Commit.define_method(:upsert) do |linha|
          raise erro if linha.card_variant_id == card_variant_id

          original.bind_call(self, linha)
        end
        yield
      ensure
        Commit.define_method(:upsert, original)
      end
  end
end
