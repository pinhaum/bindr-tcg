module Ingestion
  # Aponta coleção e wishlist para as variantes da fonte atual (SRC-19..SRC-23).
  #
  # Escreve sobre dado insubstituível, e por isso é ato explícito
  # (`ingestion:remap`), nunca efeito colateral da ingestão. As regras:
  #
  # - Só se move item cuja variante está **ausente** da fonte e que tem
  #   **exatamente um** candidato presente: mesma carta, mesmo código de set e
  #   mesma classe de arte (`base` com `base`; qualquer outro `art_kind` com
  #   qualquer outro que não `base`).
  # - Zero candidatos, mais de um, ou colisão (dois itens do mesmo usuário no
  #   mesmo candidato, ou o usuário já com item nele) deixam o item onde está e
  #   o põem no relatório. Somar quantidades seria escrever um número que o
  #   usuário nunca registrou.
  # - Coleção e wishlist são conjuntos separados: a colisão é por usuário
  #   dentro de cada um.
  # - Todos os movimentos numa única transação, e só `card_variant_id` muda.
  #   O índice único `(user_id, card_variant_id)` é a última barreira.
  #
  # Idempotente por construção: o item movido aponta para variante presente e
  # sai do universo da passada seguinte.
  class Remap
    class NoSucceededRun < StandardError; end

    NO_SUCCEEDED_RUN_MESSAGE = "nenhuma ingestão concluída; rode ingestion:import antes".freeze

    REASONS = { none: "sem candidato", ambiguous: "ambíguo", collision: "colisão" }.freeze

    Report = Struct.new(:moved, :skipped, keyword_init: true)

    def self.call = new.call

    def call
      raise NoSucceededRun, NO_SUCCEEDED_RUN_MESSAGE unless ImportRun.exists?(status: "succeeded")

      skipped = []
      moves = [ CollectionItem, WishlistItem ].flat_map { |model| plan(model, skipped) }
      # Antes de mover: trocado o `card_variant_id`, a associação do item passa
      # a apontar para a variante nova.
      moved = moves.map { |item, target| moved_entry(item, target) }

      ActiveRecord::Base.transaction do
        moves.each { |item, target| move(item, target) }
      end

      Report.new(moved: moved, skipped: skipped)
    end

    private

    # Devolve os pares `[item, variante nova]` a mover e acrescenta a
    # `skipped` os que ficam. Nada é escrito aqui.
    def plan(model, skipped)
      items = model.where.not(card_variant_id: CardVariant.present.select(:id))
                   .includes(card_variant: [ :card, :card_set ]).to_a
      return [] if items.empty?

      candidates = candidates_for(items)
      resolved = items.map { |item| [ item, candidates.fetch(candidate_key(item.card_variant), []) ] }

      singles = resolved.select { |_, found| found.size == 1 }
      targets = singles.group_by { |item, found| [ item.user_id, found.first.id ] }
      occupied = model.where(card_variant_id: singles.map { |_, found| found.first.id })
                      .pluck(:user_id, :card_variant_id).to_set

      resolved.filter_map do |item, found|
        reason = skip_reason(item, found, targets, occupied)
        next [ item, found.first ] if reason.nil?

        skipped << skipped_entry(item, reason)
        nil
      end
    end

    def candidates_for(items)
      CardVariant.present.where(card_id: items.map { |item| item.card_variant.card_id }.uniq)
                 .includes(:card_set).group_by { |variant| candidate_key(variant) }
    end

    def candidate_key(variant) = [ variant.card_id, variant.card_set.code, variant.art_kind == "base" ]

    def skip_reason(item, found, targets, occupied)
      return :none if found.empty?
      return :ambiguous if found.size > 1

      key = [ item.user_id, found.first.id ]
      :collision if targets.fetch(key).size > 1 || occupied.include?(key)
    end

    def move(item, target)
      item.update_columns(card_variant_id: target.id)
    end

    def moved_entry(item, target)
      { card_number: item.card_variant.card.card_number, old_variant_code: item.card_variant.variant_code,
        new_variant_code: target.variant_code }
    end

    def skipped_entry(item, reason)
      { card_number: item.card_variant.card.card_number, old_variant_code: item.card_variant.variant_code,
        reason: REASONS.fetch(reason) }
    end
  end
end
