# Status do deck pelas regras de montagem (DCK-11..16, DCK-42..44), confirmadas
# na T1 nas Comprehensive Rules v1.2.1: 5-1-2-1 (1 Leader), 5-1-2-2 (só cores
# do Leader), 5-1-2-3 (até 4 cópias por `card_number`), 5-1-2-4 (efeito de
# carta substitui a regra) e 2-3-5 (multicolorida tem todas as cores).
#
# Função pura: não lê o banco nem grava nada. O status é calculado a cada
# leitura e nunca persistido (DCK-11), pela mesma razão da wishlist "atendida":
# uma flag gravada fica obsoleta na alteração seguinte.
class Deck
  module Legality
    MAIN_SIZE = 50
    MAX_COPIES = 4

    # `status` é `:valid`, `:incomplete` ou `:invalid`. `reasons` são os
    # motivos em português, com o `card_number` envolvido (DCK-15). `warnings`
    # são as frases de regra própria do Leader, que o app mostra e não verifica
    # (DCK-44).
    Result = Data.define(:status, :reasons, :warnings)

    # Nome da cor no feminino ("a carta é vermelha") e no masculino ("o Leader
    # é preto"), como no exemplo do DCK-15. Cor fora da tabela aparece crua em
    # vez de levantar erro: a fonte pode trazer uma cor nova.
    COLOR_NAMES = {
      "Red" => %w[vermelha vermelho],
      "Green" => %w[verde verde],
      "Blue" => %w[azul azul],
      "Purple" => %w[roxa roxo],
      "Black" => %w[preta preto],
      "Yellow" => %w[amarela amarelo]
    }.freeze

    module_function

    # `leader` é um `Card` ou `nil`; `entries` é uma lista de pares
    # `[Card, Integer]` do deck principal.
    def call(leader:, entries:)
      copies = entries.each_with_object(Hash.new(0)) { |(card, quantity), sum| sum[card] += quantity }
      total = copies.values.sum

      invalid = over_size_reasons(total) + copy_reasons(copies) + color_reasons(leader, copies.keys)
      incomplete = incomplete_reasons(leader, total)

      status = if invalid.any? then :invalid
      elsif incomplete.any? then :incomplete
      else :valid
      end

      # Os dois grupos aparecem juntos: um deck com 51 cartas e sem Leader
      # mostra os dois motivos (design.md, Deck::Legality).
      Result.new(status: status, reasons: incomplete + invalid,
                 warnings: [ leader&.own_deck_rule ].compact)
    end

    def incomplete_reasons(leader, total)
      reasons = []
      reasons << "O deck não tem Leader" if leader.nil?
      missing = MAIN_SIZE - total
      if missing == 1
        reasons << "Falta 1 carta para #{MAIN_SIZE}"
      elsif missing.positive?
        reasons << "Faltam #{missing} cartas para #{MAIN_SIZE}"
      end
      reasons
    end

    def over_size_reasons(total)
      return [] if total <= MAIN_SIZE

      [ "O deck tem #{total} cartas; o máximo é #{MAIN_SIZE}" ]
    end

    # DCK-43 — a carta com "any number of this card" fica fora do limite de 4.
    def copy_reasons(copies)
      copies.filter_map do |card, quantity|
        next if quantity <= MAX_COPIES || card.unlimited_copies?

        "#{card.card_number} tem #{quantity} cópias; o máximo é #{MAX_COPIES}"
      end
    end

    # DCK-16 — todas as cores da carta precisam estar no Leader (2-3-5 com
    # 5-1-2-2). DCK-42 — sem Leader, não há regra de cor.
    def color_reasons(leader, cards)
      return [] if leader.nil?

      cards.filter_map do |card|
        next if (card.colors - leader.colors).empty?

        "#{card.card_number} é #{color_list(card.colors, 0)} e o Leader é #{color_list(leader.colors, 1)}"
      end
    end

    def color_list(colors, gender)
      colors.map { |color| COLOR_NAMES.fetch(color, [ color.downcase ] * 2)[gender] }.join(" e ")
    end
  end
end
