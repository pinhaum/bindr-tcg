module Ingestion
  # Estágio 3 de 3 (design.md §5.1). É o único que escreve no banco, e as
  # regras abaixo existem para impedir que uma falha da fonte externa vire
  # perda de dado do usuário (Req. 1.7):
  #
  # - **Não existe operação de delete.** Registro ausente da fonte é marcado
  #   pelo `last_seen_at`, nunca removido. Deletar uma variante apagaria o
  #   registro de coleção que a referencia.
  # - **`last_seen_at` só avança em run `succeeded`** (SRC-16): é gravado no
  #   `finish`, na mesma transação do status e sob o lock de presença, a partir
  #   dos ids acumulados em memória. Run `failed` não muda a presença de ninguém.
  # - Upsert por chave natural (`card_number`; `card_id + variant_code`),
  #   nunca `create` cego — é o que dá a idempotência do Req. 1.4.
  # - Cada registro em transação própria: um erro isolado vai para
  #   `import_runs.error_log` e o laço continua (Req. 1.5).
  class Upsert
    MAX_LOGGED_ERRORS = 100

    # A origem do dado vem de `snapshot:` (arquivo; a revisão gravada é o nome e
    # o SHA-256 dele) ou de `revision:` (fonte que já tem identificador próprio).
    def initialize(result, source:, revision: nil, snapshot: nil, clock: Time)
      raise ArgumentError, "informe exatamente um entre revision: e snapshot:" if revision.nil? == snapshot.nil?

      @result = result
      @source = source
      @revision = revision || snapshot_revision(snapshot)
      @clock = clock
    end

    def call
      run = ImportRun.create!(source: @source, source_revision: @revision,
                              status: "running", started_at: @clock.current)
      @started_at = run.started_at
      @counts = { created: 0, updated: 0, failed: 0 }
      @errors = []
      @seen_card_ids = []
      @seen_variant_ids = []

      @result.sets.each { |record| apply(record.code) { upsert_set(record) } }
      set_ids = CardSet.pluck(:code, :id).to_h

      @result.cards.each { |record| apply(record.card_number) { upsert_card(record, set_ids) } }
      card_ids = Card.pluck(:card_number, :id).to_h

      @result.variants.each { |record| apply(record.variant_code) { upsert_variant(record, card_ids, set_ids) } }

      finish(run)
    end

    private

    # SRC-06: `<arquivo> sha256:<hex>`.
    def snapshot_revision(snapshot)
      "#{File.basename(snapshot)} sha256:#{Digest::SHA256.file(snapshot).hexdigest}"
    end

    # Transação por registro. Envolver o laço inteiro faria um único registro
    # defeituoso descartar a importação toda — o oposto do Req. 1.5.
    def apply(identifier)
      outcome = ActiveRecord::Base.transaction(requires_new: true) { yield }
      @counts[outcome] += 1
    rescue StandardError => e
      @counts[:failed] += 1
      # O erro é contado sempre; só o detalhe é limitado, para um payload
      # inteiro corrompido não estourar a coluna.
      return unless @errors.size < MAX_LOGGED_ERRORS

      # Chaves e valores como String pura: o jsonb é lido de volta assim, e
      # `e.message` pode ser um objeto que não serializa direto.
      @errors << { "identifier" => identifier.to_s, "error" => e.class.name, "message" => e.message.to_s }
    end

    def upsert_set(record)
      row = CardSet.find_or_initialize_by(code: record.code)
      outcome = row.new_record? ? :created : :updated
      row.update!(name: record.name, kind: record.kind, released_on: record.released_on,
                  base_set_size: record.base_set_size, total_set_size: record.total_set_size)
      outcome
    end

    def upsert_card(record, set_ids)
      set_id = set_ids.fetch(record.set_code) { raise ActiveRecord::RecordNotFound, "set #{record.set_code} ausente" }

      row = Card.find_or_initialize_by(card_number: record.card_number)
      outcome = row.new_record? ? :created : :updated
      row.update!(
        set_id: set_id, name: record.name, card_type: record.card_type,
        colors: record.colors, cost: record.cost, life: record.life, power: record.power,
        counter: record.counter, attributes_list: record.attributes_list, traits: record.traits,
        block_icon: record.block_icon, effect_text: record.effect_text,
        trigger_text: record.trigger_text
      )
      @seen_card_ids << row.id
      outcome
    end

    def upsert_variant(record, card_ids, set_ids)
      card_id = card_ids.fetch(record.card_number) do
        raise ActiveRecord::RecordNotFound, "carta #{record.card_number} ausente"
      end
      set_id = set_ids.fetch(record.set_code) { raise ActiveRecord::RecordNotFound, "set #{record.set_code} ausente" }

      # Chave natural: (card_id, variant_code). O set NÃO entra na chave —
      # P-029_r1 é distribuída em dois sets e viraria duplicata.
      row = CardVariant.find_or_initialize_by(card_id: card_id, variant_code: record.variant_code)
      outcome = row.new_record? ? :created : :updated
      row.update!(set_id: set_id, rarity: record.rarity, art_kind: record.art_kind,
                  image_url: record.image_url, **price_attributes(record))
      @seen_variant_ids << row.id
      outcome
    end

    # PRC-01, PRC-02: o preço vale a partir do instante em que este import
    # começou, o mesmo que vira `last_seen_at`. Sem preço na fonte, os três
    # campos vão a nulo juntos, como exige a `CHECK` do banco (AD-022). A
    # variante ausente do snapshot nem passa por aqui e mantém o preço (PRC-04).
    def price_attributes(record)
      { price_amount: record.price_amount, price_currency: record.price_currency,
        price_observed_at: record.price_amount && @started_at }
    end

    # Descartes (SRC-11) não são falha: entram no log depois dos erros reais, que
    # têm prioridade no teto, e não contam em `failed_count` nem no status.
    def logged_entries
      discards = (@result.respond_to?(:discarded) ? @result.discarded : []).map do |discard|
        { "identifier" => discard["_id"].to_s, "error" => "discarded", "message" => discard["reason"].to_s }
      end

      (@errors + discards.first(MAX_LOGGED_ERRORS - @errors.size)).presence
    end

    # Status e presença mudam juntos, ou nenhum dos dois. O lock serializa com o
    # `Remap`, que lê a presença para decidir o que mover. A presença vai antes do
    # status: uma falha ao gravar o run desfaz também o `last_seen_at`.
    def finish(run)
      ImportRun.transaction do
        ImportRun.lock_presence!

        status = @counts[:failed].zero? ? "succeeded" : "failed"
        if status == "succeeded"
          Card.where(id: @seen_card_ids).update_all(last_seen_at: @started_at)
          CardVariant.where(id: @seen_variant_ids).update_all(last_seen_at: @started_at)
        end

        run.update!(
          status: status,
          finished_at: @clock.current,
          created_count: @counts[:created],
          updated_count: @counts[:updated],
          failed_count: @counts[:failed],
          error_log: logged_entries
        )
      end
      run
    end
  end
end
