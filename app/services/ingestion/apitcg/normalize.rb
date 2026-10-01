module Ingestion
  module Apitcg
    # Estágio 2 de 3 (design.md §5.1).
    #
    # **Todo** conhecimento sobre o formato da apitcg vive aqui e em nenhum
    # outro lugar. Trocar de fonte de dados deve significar escrever um
    # normalizador novo, nada mais.
    class Normalize
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

      Result = Struct.new(:sets, :cards, :variants, :discarded, keyword_init: true)

      class UnknownCardType < StandardError; end

      # Uma impressão aceita: produto elegível, já com variant_code, código do set
      # e art_kind resolvidos.
      Entry = Struct.new(:product, :variant_code, :card_number, :set_code, :raw_set, :art_kind,
                         keyword_init: true)

      def self.call(snapshot) = new(snapshot).call

      def initialize(snapshot)
        @snapshot = snapshot.is_a?(String) ? JSON.parse(snapshot) : snapshot
      end

      def call
        sets_by_id = @snapshot["sets"].index_by { |raw_set| raw_set["_id"] }
        products, discarded = select_products
        set_codes = build_set_codes(sets_by_id, products)
        entries = build_entries(products, sets_by_id, set_codes, discarded)

        cards = entries.group_by(&:card_number).map do |_, impressions|
          defining = defining_entry(impressions)
          normalize_card(defining.product, defining.set_code)
        end

        sets = sets_by_id.values.filter_map do |raw_set|
          set_entries = entries.select { |entry| entry.raw_set.equal?(raw_set) }
          normalize_set(raw_set, set_codes[raw_set["_id"]], set_entries) if set_entries.any?
        end

        variants = entries.map { |entry| normalize_variant(entry) }

        Result.new(sets: sets, cards: cards, variants: variants, discarded: discarded)
      end

      private

      # SRC-10, SRC-11, SRC-36 e SRC-34: DON!! sai em silêncio, produto sem `code`
      # ou sem `CardType` vai para os descartes e a mesma variante em dois sets
      # fica no primeiro em que aparece. Roda antes de qualquer cálculo para que carta, código de set e
      # tamanho do set nunca enxerguem a ocorrência repetida.
      def select_products
        discarded = []
        seen = Set.new

        products = @snapshot["cards"].filter_map do |product|
          next if product["type"] != "card"
          next if product.dig("attributes", "CardType") == "DON!!"

          if product["code"].blank?
            discarded << { "_id" => product["_id"], "reason" => "sem code" }
            next
          end

          if product.dig("attributes", "CardType").blank?
            discarded << { "_id" => product["_id"], "reason" => "sem CardType" }
            next
          end

          product if seen.add?(extract_variant_code(product))
        end

        [ products, discarded ]
      end

      def build_entries(products, sets_by_id, set_codes, discarded)
        products.filter_map do |product|
          raw_set = sets_by_id[product.dig("set", "_id")]
          set_code = raw_set && set_codes[raw_set["_id"]]

          unless set_code
            discarded << { "_id" => product["_id"], "reason" => "set desconhecido" }
            next
          end

          Entry.new(
            product: product,
            variant_code: extract_variant_code(product),
            card_number: product["code"],
            set_code: set_code,
            raw_set: raw_set,
            art_kind: extract_art_kind(product["name"], promo_set: promo_set?(raw_set["name"]))
          )
        end
      end

      # SRC-14, em duas passadas: normaliza os `code` presentes e depois deriva os
      # nulos pelo prefixo de maioria estrita, se nenhum outro set já usar esse
      # código; senão, pelo `_id` sem o prefixo `one-piece-`.
      def build_set_codes(sets_by_id, products)
        with_code, without_code = sets_by_id.values.partition { |raw_set| raw_set["code"].present? }
        codes = with_code.to_h { |raw_set| [ raw_set["_id"], normalize_set_code(raw_set["code"]) ] }
        used = codes.values.to_set

        numbers_by_set = products.group_by { |product| product.dig("set", "_id") }
                                 .transform_values { |list| list.map { |product| product["code"] }.uniq }

        without_code.each do |raw_set|
          candidate = majority_prefix(numbers_by_set.fetch(raw_set["_id"], []))
          code = candidate && !used.include?(candidate) ? candidate : raw_set["_id"].delete_prefix("one-piece-")
          used.add(code)
          codes[raw_set["_id"]] = code
        end

        codes
      end

      def normalize_set_code(code)
        code.gsub(/([A-Za-z])-(\d)/, '\1\2').gsub(/\s+/, "-")
      end

      # Prefixo é tudo antes do primeiro `-` (`OP01-001` → `OP01`, `EB01-001` → `EB01`).
      def extract_prefix(card_number)
        card_number.to_s.split("-").first.to_s
      end

      def majority_prefix(numbers)
        numbers.group_by { |number| extract_prefix(number) }
               .find { |_, group| group.size * 2 > numbers.size }&.first
      end

      # SRC-12: a base do set de estreia (código do set igual ao prefixo do número);
      # sem ela, a impressão do set com `released_on` mais recente; empate pelo
      # menor `variant_code`.
      def defining_entry(impressions)
        prefix = extract_prefix(impressions.first.card_number)
        debut = impressions.select { |entry| entry.set_code == prefix && entry.art_kind == "base" }
        return debut.min_by(&:variant_code) if debut.any?

        impressions.min_by do |entry|
          released_on = parse_date(entry.raw_set["release_date"])
          [ -(released_on&.jd || 0), entry.variant_code ]
        end
      end

      # SRC-24 e SRC-35: o prefixo do código conta só quando for maioria estrita
      # entre os números distintos do set; senão contam todos os números distintos.
      # Sem nenhum número com o prefixo a comparação é falsa e não há divisão.
      def normalize_set(raw_set, set_code, set_entries)
        numbers = set_entries.map(&:card_number).uniq
        own = numbers.count { |number| extract_prefix(number) == set_code }

        NormalizedSet.new(
          code: set_code,
          name: raw_set["name"],
          kind: determine_set_kind(set_code, raw_set["name"]),
          released_on: parse_date(raw_set["release_date"]),
          base_set_size: own * 2 > numbers.size ? own : numbers.size,
          total_set_size: set_entries.size
        )
      end

      # O tipo vem do prefixo de letras do código normalizado.
      def determine_set_kind(code, name)
        return "promo" if promo_set?(name)

        {
          "OP" => "booster",
          "ST" => "starter",
          "EB" => "extra_booster",
          "PRB" => "premium_booster"
        }.fetch(code[/\A[A-Za-z]+/], "other")
      end

      def promo_set?(set_name)
        set_name.to_s.match?(/promo|pre-release|release event/i)
      end

      # SRC-09
      def extract_variant_code(raw_product)
        tcgplayer_id = raw_product.dig("markets", "tcgplayer", "id")
        tcgplayer_id.present? ? "tcgplayer:#{tcgplayer_id}" : "apitcg:#{raw_product['_id']}"
      end

      def normalize_card(raw_product, set_code)
        attributes = raw_product["attributes"] || {}
        effect_text, trigger_text = extract_effect_and_trigger(attributes["Description"])

        NormalizedCard.new(
          card_number: raw_product["code"],
          set_code: set_code,
          name: clean_card_name(raw_product["name"]),
          card_type: card_type(attributes["CardType"]),
          colors: clean_list(attributes["Color"]&.split(";")),
          cost: to_integer(attributes["Cost"]),
          life: to_integer(attributes["Life"]),
          power: to_integer(attributes["Power"]),
          counter: extract_counter(attributes["Counterplus"]),
          attributes_list: clean_list(attributes["Attribute"]&.split(";")),
          traits: normalize_traits(attributes["Subtypes"]&.split(";")),
          block_icon: nil,
          effect_text: effect_text,
          trigger_text: trigger_text
        )
      end

      def normalize_variant(entry)
        NormalizedVariant.new(
          variant_code: entry.variant_code,
          card_number: entry.card_number,
          set_code: entry.set_code,
          rarity: presence(entry.product.dig("attributes", "Rarity")),
          art_kind: entry.art_kind,
          image_url: entry.product.dig("images", 0, "large")
        )
      end

      def clean_card_name(name)
        # Remove todos os sufixos entre parênteses iterativamente
        loop do
          new_name = name.gsub(/\s*\([^)]*\)\s*$/, "").strip
          break if new_name == name
          name = new_name
        end
        name
      end

      # SRC-13: último sufixo entre parênteses, comparação exata sem caixa. Os três
      # sufixos de arte vencem tudo; depois, o set de promoção; a seguir, sem
      # sufixo, sufixo numérico ou igual a um card_number (`OP01-016`) é base e
      # qualquer outro (Reprint, SP, Box Topper...) é other.
      def extract_art_kind(name, promo_set: false)
        suffix = name[/\(([^)]+)\)\s*\z/, 1]&.downcase

        case suffix
        when "parallel" then "parallel"
        when "alternate art" then "alternate_art"
        when "manga" then "manga"
        else
          if promo_set then "promo"
          elsif suffix.nil? || suffix.match?(/\A\d+\z/) || suffix.match?(/\A[a-z]+\d*-\d+\z/) then "base"
          else "other"
          end
        end
      end

      # SRC-12: remove o disclaimer e o link de errata inteiros, converte `<br>` e
      # quebras de linha em `\n`, descarta as demais tags e separa o trecho após o
      # primeiro `[Trigger]` (um segundo `[Trigger]` fica dentro do trigger_text).
      def extract_effect_and_trigger(description)
        return [ nil, nil ] if description.blank?

        text = description
          .gsub(%r{<span\b[^>]*>.*?</span>}mi) { |span| span.match?(/disclaimer/i) ? "" : span }
          .gsub(%r{<a\b[^>]*href="[^"]*errata_card[^"]*"[^>]*>.*?</a>}mi, "")
          .gsub(%r{<br\s*/?>}i, "\n")
          .gsub(/\r\n?/, "\n")
          .gsub(/<[^>]+>/, "")

        effect, trigger = text.split("[Trigger]", 2)
        [ clean_block(effect), clean_block(trigger) ]
      end

      # Colapsa 3+ quebras em uma linha em branco.
      def clean_block(text)
        presence(text.to_s.gsub(/\n{3,}/, "\n\n"))
      end

      def extract_counter(counterplus_value)
        # Counterplus é a chave real; nil ≠ 0
        return nil if counterplus_value.blank?

        to_integer(counterplus_value)
      end

      def card_type(value)
        CARD_TYPES.fetch(value.to_s.upcase) do
          raise UnknownCardType, "tipo de carta desconhecido na fonte: #{value.inspect}"
        end
      end

      def normalize_traits(values)
        clean_list(values).uniq { |trait| trait.downcase }
      end

      def clean_list(values)
        Array(values).filter_map { |value| presence(value) }.uniq
      end

      def presence(value)
        normalized = value.to_s.strip.gsub(/[ \t]+/, " ")
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
end
