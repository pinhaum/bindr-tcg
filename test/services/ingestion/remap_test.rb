require "test_helper"

module Ingestion
  # T5 (fonte-apitcg) — SRC-19..SRC-23: mover coleção e wishlist das variantes
  # ausentes para o candidato único presente (mesma carta, mesmo código de set,
  # mesma classe de arte), numa transação só.
  #
  # O cenário é o da troca de fonte: um run `succeeded` antigo (optcgjson), cujas
  # variantes ficaram ausentes, e um novo (apitcg), cujas variantes estão
  # presentes. Nenhum teste daqui apaga item nem muda quantidade: o que se mede
  # é para onde `card_variant_id` aponta depois.
  class RemapTest < ActiveSupport::TestCase
    OLD_RUN_AT = Time.utc(2026, 9, 1, 12)
    NEW_RUN_AT = Time.utc(2026, 9, 29, 12)
    PASSWORD = "log-pose-77".freeze

    setup do
      ImportRun.create!(source: "optcgjson", source_revision: "antiga", status: "succeeded", started_at: OLD_RUN_AT)
      ImportRun.create!(source: "apitcg", source_revision: "apitcg-nova.json", status: "succeeded",
                        started_at: NEW_RUN_AT)

      @nami = User.create!(email: "nami-remap@example.com", password: PASSWORD)
      @zoro = User.create!(email: "zoro-remap@example.com", password: PASSWORD)

      @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
      @st01 = CardSet.create!(code: "ST01", name: "Straw Hat Crew", kind: "starter")

      # Um candidato base e um não-base, cada um único na sua classe.
      @luffy = card("OP01-001")
      @luffy_old_base = variant(@luffy, "OP01-001", @op01, "base", OLD_RUN_AT)
      @luffy_old_parallel = variant(@luffy, "OP01-001_p1", @op01, "parallel", OLD_RUN_AT)
      @luffy_new_base = variant(@luffy, "tcgplayer:11", @op01, "base", NEW_RUN_AT)
      @luffy_new_alt = variant(@luffy, "tcgplayer:12", @op01, "alternate_art", NEW_RUN_AT)
    end

    def card(number)
      Card.create!(set_id: @op01.id, card_number: number, name: "Carta #{number}", card_type: "character",
                   colors: [ "Red" ])
    end

    def variant(card, code, set, art_kind, seen)
      CardVariant.create!(card: card, set_id: set.id, variant_code: code, rarity: "C", art_kind: art_kind,
                          last_seen_at: seen)
    end

    def own(user, variant, quantity) = CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)

    def want(user, variant, target) = WishlistItem.create!(user: user, card_variant: variant, target_quantity: target)

    def skipped_reasons(report)
      report.skipped.to_h { |entry| [ entry[:old_variant_code], entry[:reason] ] }
    end

    def totals
      [ CollectionItem.count, WishlistItem.count, CollectionItem.sum(:quantity), WishlistItem.sum(:target_quantity) ]
    end

    # --- SRC-19 / SRC-20: candidato único é movido, com a quantidade intacta ---

    test "item de coleção com candidato único vai para a variante nova com a mesma quantidade" do
      item = own(@nami, @luffy_old_base, 3)

      Remap.call

      item.reload
      assert_equal @luffy_new_base.id, item.card_variant_id
      assert_equal 3, item.quantity
    end

    test "item de wishlist com candidato único vai para a variante nova com o mesmo alvo" do
      item = want(@nami, @luffy_old_base, 4)

      Remap.call

      item.reload
      assert_equal @luffy_new_base.id, item.card_variant_id
      assert_equal 4, item.target_quantity
    end

    test "o relatório lista o movimento com card_number e os dois variant_code" do
      own(@nami, @luffy_old_base, 1)

      report = Remap.call

      assert_equal [ { card_number: "OP01-001", old_variant_code: "OP01-001", new_variant_code: "tcgplayer:11" } ],
                   report.moved
      assert_empty report.skipped
    end

    # --- SRC-19: classe de arte ---

    test "item base não casa com candidato não-base" do
      zoro = card("OP01-025")
      old_base = variant(zoro, "OP01-025", @op01, "base", OLD_RUN_AT)
      variant(zoro, "tcgplayer:21", @op01, "alternate_art", NEW_RUN_AT)
      item = own(@nami, old_base, 1)

      report = Remap.call

      assert_equal old_base.id, item.reload.card_variant_id
      assert_equal({ "OP01-025" => "sem candidato" }, skipped_reasons(report))
    end

    test "item não-base não casa com candidato base" do
      zoro = card("OP01-025")
      old_parallel = variant(zoro, "OP01-025_p1", @op01, "parallel", OLD_RUN_AT)
      variant(zoro, "tcgplayer:21", @op01, "base", NEW_RUN_AT)
      item = own(@nami, old_parallel, 1)

      report = Remap.call

      assert_equal old_parallel.id, item.reload.card_variant_id
      assert_equal({ "OP01-025_p1" => "sem candidato" }, skipped_reasons(report))
    end

    test "item não-base antigo casa com qualquer não-base novo" do
      item = own(@nami, @luffy_old_parallel, 2)

      Remap.call

      assert_equal @luffy_new_alt.id, item.reload.card_variant_id
      assert_equal 2, item.quantity
    end

    test "candidato em outro código de set não conta" do
      nami_card = card("OP01-016")
      old_st01 = variant(nami_card, "ST01-007", @st01, "base", OLD_RUN_AT)
      variant(nami_card, "tcgplayer:31", @op01, "base", NEW_RUN_AT)
      item = own(@nami, old_st01, 1)

      report = Remap.call

      assert_equal old_st01.id, item.reload.card_variant_id
      assert_equal({ "ST01-007" => "sem candidato" }, skipped_reasons(report))
    end

    # --- SRC-21: sem candidato, ambíguo, colisão ---

    test "zero candidatos: sem candidato, e o item fica" do
      usopp = card("OP01-004")
      old = variant(usopp, "OP01-004", @op01, "base", OLD_RUN_AT)
      item = own(@nami, old, 1)

      report = Remap.call

      assert_equal old.id, item.reload.card_variant_id
      assert_equal [ { card_number: "OP01-004", old_variant_code: "OP01-004", reason: "sem candidato" } ],
                   report.skipped
    end

    test "mais de um candidato: ambíguo, e o item fica" do
      variant(@luffy, "tcgplayer:13", @op01, "base", NEW_RUN_AT)
      item = own(@nami, @luffy_old_base, 1)

      report = Remap.call

      assert_equal @luffy_old_base.id, item.reload.card_variant_id
      assert_equal({ "OP01-001" => "ambíguo" }, skipped_reasons(report))
    end

    test "dois itens do mesmo usuário no mesmo candidato: colisão para os dois" do
      old_manga = variant(@luffy, "OP01-001_p2", @op01, "manga", OLD_RUN_AT)
      parallel_item = own(@nami, @luffy_old_parallel, 1)
      manga_item = own(@nami, old_manga, 2)

      report = Remap.call

      assert_equal @luffy_old_parallel.id, parallel_item.reload.card_variant_id
      assert_equal old_manga.id, manga_item.reload.card_variant_id
      assert_equal({ "OP01-001_p1" => "colisão", "OP01-001_p2" => "colisão" }, skipped_reasons(report))
      assert_empty report.moved
    end

    test "item já existente do usuário no candidato: colisão, e nada se soma" do
      existing = own(@nami, @luffy_new_base, 5)
      old_item = own(@nami, @luffy_old_base, 3)

      report = Remap.call

      assert_equal @luffy_old_base.id, old_item.reload.card_variant_id
      assert_equal 3, old_item.quantity
      assert_equal 5, existing.reload.quantity
      assert_equal({ "OP01-001" => "colisão" }, skipped_reasons(report))
    end

    test "a colisão é por usuário: itens de usuários diferentes no mesmo candidato são movidos" do
      nami_item = own(@nami, @luffy_old_base, 1)
      zoro_item = own(@zoro, @luffy_old_base, 2)

      report = Remap.call

      assert_equal @luffy_new_base.id, nami_item.reload.card_variant_id
      assert_equal @luffy_new_base.id, zoro_item.reload.card_variant_id
      assert_equal 2, report.moved.size
      assert_empty report.skipped
    end

    test "coleção e wishlist são conjuntos separados: um item em cada não colide" do
      collection_item = own(@nami, @luffy_old_base, 1)
      wishlist_item = want(@nami, @luffy_new_base, 2)

      Remap.call

      assert_equal @luffy_new_base.id, collection_item.reload.card_variant_id
      assert_equal @luffy_new_base.id, wishlist_item.reload.card_variant_id
    end

    # --- SRC-22: idempotente ---

    test "a segunda execução seguida não move nada" do
      own(@nami, @luffy_old_base, 1)
      want(@zoro, @luffy_old_parallel, 1)

      primeira = Remap.call
      segunda = Remap.call

      assert_equal 2, primeira.moved.size
      assert_empty segunda.moved
      assert_empty segunda.skipped
    end

    # --- SRC-23: sem run succeeded ---

    test "sem run succeeded, levanta a mensagem de SRC-23 e nada é movido" do
      item = own(@nami, @luffy_old_base, 1)
      ImportRun.update_all(status: "failed")

      erro = assert_raises(Remap::NoSucceededRun) { Remap.call }

      assert_equal "nenhuma ingestão concluída; rode ingestion:import antes", erro.message
      assert_equal @luffy_old_base.id, item.reload.card_variant_id
    end

    # --- Transação única: falha no meio desfaz tudo ---

    test "falha forçada no meio da aplicação desfaz todos os movimentos" do
      primeiro = own(@nami, @luffy_old_base, 1)
      segundo = own(@zoro, @luffy_old_base, 1)
      remap = Remap.new
      chamadas = 0
      original = remap.method(:move)
      remap.define_singleton_method(:move) do |item, target|
        chamadas += 1
        raise ActiveRecord::StatementInvalid, "falha forçada" if chamadas == 2

        original.call(item, target)
      end

      assert_raises(ActiveRecord::StatementInvalid) { remap.call }

      assert_equal 2, chamadas, "a falha precisa vir depois de um movimento aplicado"
      assert_equal @luffy_old_base.id, primeiro.reload.card_variant_id
      assert_equal @luffy_old_base.id, segundo.reload.card_variant_id
    end

    # --- T19: lacunas da revisão do lote A ---

    test "outro usuário já com item no candidato não gera colisão" do
      own(@zoro, @luffy_new_base, 4)
      item = own(@nami, @luffy_old_base, 1)

      report = Remap.call

      assert_equal @luffy_new_base.id, item.reload.card_variant_id
      assert_empty report.skipped
    end

    test "falha no movimento da wishlist desfaz também o movimento de coleção já aplicado" do
      colecao = own(@nami, @luffy_old_base, 1)
      desejo = want(@zoro, @luffy_old_base, 1)
      remap = Remap.new
      original = remap.method(:move)
      remap.define_singleton_method(:move) do |item, target|
        raise ActiveRecord::StatementInvalid, "falha forçada" if item.is_a?(WishlistItem)

        original.call(item, target)
      end

      assert_raises(ActiveRecord::StatementInvalid) { remap.call }

      assert_equal @luffy_old_base.id, colecao.reload.card_variant_id
      assert_equal @luffy_old_base.id, desejo.reload.card_variant_id
    end

    test "run succeeded antigo seguido de um failed mais recente: o remap prossegue" do
      ImportRun.create!(source: "apitcg", source_revision: "apitcg-falhou.json", status: "failed",
                        started_at: NEW_RUN_AT + 1.day)
      item = own(@nami, @luffy_old_base, 1)

      Remap.call

      assert_equal @luffy_new_base.id, item.reload.card_variant_id
    end

    test "dois itens de wishlist do mesmo usuário no mesmo candidato: colisão para os dois" do
      old_manga = variant(@luffy, "OP01-001_p2", @op01, "manga", OLD_RUN_AT)
      paralelo = want(@nami, @luffy_old_parallel, 1)
      manga = want(@nami, old_manga, 2)

      report = Remap.call

      assert_equal @luffy_old_parallel.id, paralelo.reload.card_variant_id
      assert_equal old_manga.id, manga.reload.card_variant_id
      assert_equal({ "OP01-001_p1" => "colisão", "OP01-001_p2" => "colisão" }, skipped_reasons(report))
    end

    test "item de wishlist já existente do usuário no candidato: colisão, e o alvo não se soma" do
      existente = want(@nami, @luffy_new_base, 5)
      antigo = want(@nami, @luffy_old_base, 3)

      report = Remap.call

      assert_equal @luffy_old_base.id, antigo.reload.card_variant_id
      assert_equal 3, antigo.target_quantity
      assert_equal 5, existente.reload.target_quantity
      assert_equal({ "OP01-001" => "colisão" }, skipped_reasons(report))
    end

    test "dois candidatos não-base: ambíguo, e o item fica" do
      variant(@luffy, "tcgplayer:14", @op01, "manga", NEW_RUN_AT)
      item = own(@nami, @luffy_old_parallel, 1)

      report = Remap.call

      assert_equal @luffy_old_parallel.id, item.reload.card_variant_id
      assert_equal({ "OP01-001_p1" => "ambíguo" }, skipped_reasons(report))
    end

    test "a segunda execução repete os pulados, não move nada e o movido fica na variante nova" do
      movido = own(@nami, @luffy_old_base, 1)
      usopp = card("OP01-004")
      own(@nami, variant(usopp, "OP01-004", @op01, "base", OLD_RUN_AT), 1)

      primeira = Remap.call
      segunda = Remap.call

      assert_equal [ { card_number: "OP01-004", old_variant_code: "OP01-004", reason: "sem candidato" } ],
                   primeira.skipped
      assert_equal primeira.skipped, segunda.skipped
      assert_empty segunda.moved
      assert_equal @luffy_new_base.id, movido.reload.card_variant_id
    end

    test "item em variante presente fica intocado, e o movido só muda card_variant_id" do
      presente = own(@nami, @luffy_new_alt, 2)
      movido = own(@zoro, @luffy_old_base, 3)
      antes_presente = presente.reload.attributes
      antes_movido = movido.reload.attributes

      travel 1.hour do
        Remap.call
      end

      assert_equal antes_presente, presente.reload.attributes
      assert_equal antes_movido.merge("card_variant_id" => @luffy_new_base.id), movido.reload.attributes
    end

    # --- T18: plano dentro da transação ---

    def captured_sql
      queries = []
      assinante = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| queries << payload[:sql] }
      yield
      queries
    ensure
      ActiveSupport::Notifications.unsubscribe(assinante)
    end

    test "os itens elegíveis são lidos com FOR UPDATE em ordem de id, depois do lock de presença" do
      own(@nami, @luffy_old_base, 1)
      want(@nami, @luffy_old_base, 1)

      queries = captured_sql { Remap.call }

      lock = queries.index { |sql| sql.include?("pg_advisory_xact_lock(#{ImportRun::PRESENCE_LOCK_KEY})") }
      %w[collection_items wishlist_items].each do |table|
        leitura = queries.index { |sql| sql.match?(/FROM "#{table}".*ORDER BY "#{table}"."id" ASC.*FOR UPDATE\z/m) }
        refute_nil leitura, "#{table} precisa ser lido com FOR UPDATE em ordem de id"
        refute_nil lock, "o lock de presença precisa ser tomado"
        assert_operator lock, :<, leitura, "o lock de presença vem antes do plano"
      end
    end

    test "item criado no candidato depois do plano: ConcurrentChange, e nada fica movido" do
      primeiro = own(@zoro, @luffy_old_base, 1)
      segundo = own(@nami, @luffy_old_base, 2)
      remap = Remap.new
      original = remap.method(:move)
      remap.define_singleton_method(:move) do |item, target|
        # O usuário cria, por fora do plano, um item na variante de destino.
        CollectionItem.create!(user_id: item.user_id, card_variant_id: target.id, quantity: 9) if item.user_id == segundo.user_id
        original.call(item, target)
      end

      erro = assert_raises(Remap::ConcurrentChange) { remap.call }

      assert_equal "a coleção mudou durante o remapeamento; rode ingestion:remap de novo", erro.message
      assert_equal @luffy_old_base.id, primeiro.reload.card_variant_id
      assert_equal @luffy_old_base.id, segundo.reload.card_variant_id
      assert_equal 2, CollectionItem.count, "o rollback desfaz também o item criado dentro da transação"
    end

    # Fora de transação o `pg_advisory_xact_lock` soltaria na hora, sem proteger
    # nada. O teste sempre roda dentro de uma, daí o `transaction_open?` falso.
    test "lock_presence! fora de transação é recusado" do
      conexao = ImportRun.connection
      conexao.define_singleton_method(:transaction_open?) { false }

      erro = assert_raises(ArgumentError) { ImportRun.lock_presence! }

      assert_equal "lock_presence! exige transação aberta", erro.message
    ensure
      conexao.singleton_class.remove_method(:transaction_open?)
    end

    # --- Req. 1.7: nada apagado, nenhuma quantidade alterada ---

    test "contagens e somas de coleção e wishlist são idênticas antes e depois" do
      own(@nami, @luffy_old_base, 3)
      own(@zoro, @luffy_old_parallel, 2)
      own(@zoro, @luffy_new_base, 7)
      want(@nami, @luffy_old_parallel, 4)
      usopp = card("OP01-004")
      own(@nami, variant(usopp, "OP01-004", @op01, "base", OLD_RUN_AT), 1)

      antes = totals
      Remap.call

      assert_equal antes, totals
    end
  end
end
