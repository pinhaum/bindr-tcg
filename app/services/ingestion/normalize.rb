module Ingestion
  # Estágio 2 de 3 (design.md §5.1).
  #
  # **Todo** conhecimento sobre o formato da optcgjson vive aqui e em nenhum
  # outro lugar. Trocar de fonte de dados deve significar escrever um
  # normalizador novo, nada mais — nem o Upsert nem os modelos podem conhecer
  # nomes de campo externos como `cardClass`, `feature` ou `isParallel`.
  class Normalize
    # A fonte entrega números como string ou null (`"5000"`, `null`), nunca
    # como inteiro. Converter aqui é o que mantém o resto do sistema livre do
    # formato externo.
    SET_KINDS = {
      "booster" => "booster",
      "premium_booster" => "premium_booster",
      "starter" => "starter",
      "extra_booster" => "extra_booster",
      "promo" => "promo"
    }.freeze

    CARD_TYPES = {
      "LEADER" => "leader",
      "CHARACTER" => "character",
      "EVENT" => "event",
      "STAGE" => "stage"
    }.freeze

    NormalizedSet = Struct.new(:code, :name, :kind, :released_on, :base_set_size, :total_set_size,
                               keyword_init: true)

    NormalizedCard = Struct.new(:card_number, :set_code, :name, :card_type, :colors, :cost, :life,
                                :power, :counter, :attributes_list, :traits, :block_icon,
                                :effect_text, :trigger_text, keyword_init: true)

    NormalizedVariant = Struct.new(:variant_code, :card_number, :set_code, :rarity, :art_kind,
                                   :image_url, keyword_init: true)

    Result = Struct.new(:sets, :cards, :variants, keyword_init: true)

    class UnknownCardType < StandardError; end

    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = payload.is_a?(String) ? JSON.parse(payload) : payload
    end

    def call
      sets = []
      cards = {}
      variants = {}

      raw_sets(@payload["data"]).each do |raw_set|
        sets << normalize_set(raw_set)
        set_code = raw_set["code"]

        Array(raw_set["cards"]).each do |raw_card|
          card = normalize_card(raw_card, set_code)
          # A mesma carta aparece uma vez por impressão. A primeira ocorrência
          # define o set de estreia; as seguintes não a sobrescrevem.
          cards[card.card_number] ||= card

          variant = normalize_variant(raw_card, set_code)
          # Caso P-029_r1: a mesma variante é distribuída em dois sets. A
          # chave é o `variant_code`, global, e não o par com o set — senão a
          # promo vira duas variantes e o usuário ganha uma carta fantasma.
          variants[variant.variant_code] ||= variant
        end
      end

      Result.new(sets: sets, cards: cards.values, variants: variants.values)
    end

    private

    # `AllSets.json` entrega `data` como objeto indexado pelo código do set
    # (`{"OP01": {...}}`); os arquivos por set e a fixture derivada entregam uma
    # lista. As duas formas trazem o mesmo objeto de set, então aqui elas
    # convergem — e a diferença não vaza para nenhum outro estágio.
    def raw_sets(data)
      case data
      when Hash then data.values
      else Array(data)
      end
    end

    def normalize_set(raw)
      NormalizedSet.new(
        code: raw["code"],
        name: raw["name"],
        kind: SET_KINDS.fetch(raw["type"], "other"),
        released_on: parse_date(raw["releaseDate"]),
        base_set_size: to_integer(raw["baseSetSize"]),
        total_set_size: to_integer(raw["totalSetSize"])
      )
    end

    def normalize_card(raw, set_code)
      NormalizedCard.new(
        card_number: raw["number"],
        set_code: set_code,
        name: raw["name"],
        card_type: card_type(raw["cardClass"]),
        colors: clean_list(raw["color"]),
        cost: to_integer(raw["cost"]),
        life: to_integer(raw["life"]),
        power: to_integer(raw["power"]),
        # `counter` nulo é "não tem counter", nunca counter 0 (design.md §3.3).
        # `to_integer` preserva nil justamente para não introduzir a sentinela.
        counter: to_integer(raw["counter"]),
        # `attribute` pode vir `["?"]` — valor real da fonte (carta Imu), não
        # lixo. Entra como texto; nada aqui pode rejeitá-lo.
        attributes_list: clean_list(raw["attribute"]),
        traits: normalize_traits(raw["feature"]),
        block_icon: to_integer(raw["blockIcon"]),
        # Req. 5.4 — o detalhe da carta preserva quebras de linha. Por isso
        # estes dois campos NÃO passam pela normalização de espaços em branco
        # que os rótulos curtos usam.
        effect_text: presence_preserving_newlines(raw["effect"]),
        trigger_text: presence_preserving_newlines(raw["trigger"])
      )
    end

    def normalize_variant(raw, set_code)
      NormalizedVariant.new(
        # AD-001: `variant_code` vem pronto da fonte. Nunca derivado por hash —
        # é o que garante estabilidade entre execuções e, com ela, o vínculo
        # da coleção do usuário.
        variant_code: raw["id"],
        card_number: raw["number"],
        set_code: set_code,
        rarity: presence(raw["rarity"]),
        art_kind: art_kind(raw),
        image_url: presence(raw["imageUrl"])
      )
    end

    # A fonte só distingue base de parallel. Classificar além disso seria
    # inventar informação que ela não tem.
    def art_kind(raw)
      return "parallel" if raw["isParallel"]

      raw["id"] == raw["number"] ? "base" : "other"
    end

    def card_type(value)
      CARD_TYPES.fetch(value.to_s.upcase) do
        raise UnknownCardType, "tipo de carta desconhecido na fonte: #{value.inspect}"
      end
    end

    # Req. 4.1 e design.md §3.3 — sem isto, "Straw Hat Crew" e
    # "Straw hat crew" viram traits distintos e o filtro por trait fica furado.
    #
    # A normalização é de **espaçamento**, mais deduplicação insensível a
    # caixa; a grafia da fonte é preservada. Title Case foi testado contra o
    # catálogo completo e reprovado: corromperia 10 traits reais
    # ("Former CP9" -> "Former Cp9", "Kingdom of GERMA" -> "Kingdom Of Germa",
    # "Land of Wano" -> "Land Of Wano") para resolver uma única colisão de
    # caixa que existe de fato na fonte (SMILE/Smile). A comparação para o
    # filtro tem de ser insensível a caixa — não a exibição.
    def normalize_traits(values)
      clean_list(values).uniq { |trait| trait.downcase }
    end

    def clean_list(values)
      Array(values).filter_map { |value| presence(value) }.uniq
    end

    # Para rótulos curtos (nome, raridade, cor, trait): colapsa espaçamento
    # interno, porque " Straw  Hat Crew " e "Straw Hat Crew" têm de ser o
    # mesmo trait.
    def presence(value)
      normalized = value.to_s.strip.gsub(/[ \t]+/, " ")
      normalized.empty? ? nil : normalized
    end

    # Para texto longo: só remove o entorno, mantendo as quebras internas.
    def presence_preserving_newlines(value)
      normalized = value.to_s.strip
      normalized.empty? ? nil : normalized
    end

    def to_integer(value)
      return nil if value.nil?

      text = value.to_s.strip
      return nil if text.empty?

      Integer(text, exception: false)
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end
  end
end
