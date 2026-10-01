require "json"

module Ingestion
  module Apitcg
    # Compara dois snapshots da apitcg pelo `_id` do produto e informa
    # quantos produtos presentes nos dois mudaram de `markets.tcgplayer.id` (SRC-31).
    # Sem banco e sem rede.
    #
    # Produto presente só de um lado não conta como mudança. Produto sem
    # `tcgplayer.id` nos dois lados não é mudança; id presente num lado e
    # ausente no outro conta como mudança (pois é uma alteração do estado).
    class CompareSnapshots
      Result = Struct.new(:common, :changed, :changes, :only_in_a, :only_in_b, keyword_init: true)

      def self.call(a_path, b_path)
        new(a_path, b_path).call
      end

      def initialize(a_path, b_path)
        @a_path = Pathname(a_path)
        @b_path = Pathname(b_path)
      end

      def call
        a_data = load_snapshot(@a_path)
        b_data = load_snapshot(@b_path)

        a_cards = index_cards(a_data["cards"] || [])
        b_cards = index_cards(b_data["cards"] || [])

        common_ids = a_cards.keys & b_cards.keys
        only_in_a_count = a_cards.size - common_ids.size
        only_in_b_count = b_cards.size - common_ids.size

        changes = []
        changed_count = 0

        common_ids.each do |_id|
          a_tcgplayer_id = a_cards[_id]
          b_tcgplayer_id = b_cards[_id]

          if a_tcgplayer_id != b_tcgplayer_id
            changed_count += 1
            changes << { _id: _id, from: a_tcgplayer_id, to: b_tcgplayer_id }
          end
        end

        Result.new(
          common: common_ids.size,
          changed: changed_count,
          changes: changes,
          only_in_a: only_in_a_count,
          only_in_b: only_in_b_count
        )
      end

      private

      def load_snapshot(path)
        content = File.read(path)
        JSON.parse(content)
      rescue => e
        raise "não conseguiu ler #{path}: #{e.message}"
      end

      def index_cards(cards)
        index = {}
        cards.each do |card|
          _id = card["_id"]
          next if _id.nil?

          # Extrai o tcgplayer.id do aninhamento markets.tcgplayer.id, ou nil se ausente.
          tcgplayer_id = card.dig("markets", "tcgplayer", "id")
          index[_id] = tcgplayer_id
        end
        index
      end
    end
  end
end
