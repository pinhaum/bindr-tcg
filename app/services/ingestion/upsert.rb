module Ingestion
  # Estágio 3 de 3 (design.md §5.1). É o único que escreve no banco, e as
  # regras abaixo existem para impedir que uma falha da fonte externa vire
  # perda de dado do usuário (Req. 1.7):
  #
  # - **Não existe operação de delete.** Registro ausente da fonte é marcado
  #   pelo `last_seen_at`, nunca removido. Deletar uma variante apagaria o
  #   registro de coleção que a referencia.
  # - Upsert por chave natural (`card_number`; `card_id + variant_code`),
  #   nunca `create` cego — é o que dá a idempotência do Req. 1.4.
  # - Cada registro em transação própria: um erro isolado vai para
  #   `import_runs.error_log` e o laço continua (Req. 1.5).
  class Upsert
    MAX_LOGGED_ERRORS = 100

    def initialize(result, source:, revision:, clock: Time)
      @result = result
      @source = source
      @revision = revision
      @clock = clock
    end

    def call
      run = ImportRun.create!(source: @source, source_revision: @revision,
                              status: "running", started_at: @clock.current)
      @started_at = run.started_at
      @counts = { created: 0, updated: 0, failed: 0 }
      @errors = []

      @result.sets.each { |record| apply(record.code) { upsert_set(record) } }
      set_ids = CardSet.pluck(:code, :id).to_h

      @result.cards.each { |record| apply(record.card_number) { upsert_card(record, set_ids) } }
      card_ids = Card.pluck(:card_number, :id).to_h

      @result.variants.each { |record| apply(record.variant_code) { upsert_variant(record, card_ids, set_ids) } }

      finish(run)
    end

    private

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
        trigger_text: record.trigger_text, last_seen_at: @started_at
      )
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
                  image_url: record.image_url, last_seen_at: @started_at)
      outcome
    end

    def finish(run)
      run.update!(
        status: @counts[:failed].zero? ? "succeeded" : "failed",
        finished_at: @clock.current,
        created_count: @counts[:created],
        updated_count: @counts[:updated],
        failed_count: @counts[:failed],
        error_log: @errors.presence
      )
      run
    end
  end
end
