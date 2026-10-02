# Lista do deck em texto, no formato do OPTCG Simulator: uma linha
# `<N>x<card_number>` por carta, com o Leader como `1x<card_number>`
# (DCK-25..29). Exemplo do dono: `1xOP17-079`, `4xOP17-094`, ...
#
# Só lê e escreve. Quem decide o que vira deck é o controller de importação,
# numa transação (design.md, DeckImportsController).
class Deck
  module ListText
    MAX_LINES = 200
    MAX_CHARS = 10_000
    EMPTY_LIST = "A lista não tem nenhuma carta".freeze

    # O exemplo do dono veio separado por CR; um `<textarea>` envia CRLF; colar
    # de um site costuma dar LF. A ordem da alternância importa: `\r\n` antes
    # de `\r`, senão o CRLF viraria duas quebras e uma linha em branco a mais.
    LINE_BREAK = /\r\n|\r|\n/
    LINE_FORMAT = /\A\s*(\d+)\s*x\s*([A-Za-z0-9-]+)\s*\z/i

    # `errors` é uma lista de `{ line:, message: }`, com o número da linha no
    # texto colado (contando as em branco, que é o que o usuário vê) ou `nil`
    # quando o problema é o texto inteiro. Com erro, `leader` e `entries` vêm
    # vazios: a importação é tudo ou nada (DCK-28), e devolver o que deu certo
    # convidaria o chamador a aplicar metade da lista.
    Result = Data.define(:leader, :entries, :errors)

    module_function

    def parse(text)
      text = text.to_s
      limit_error = limit_error(text)
      return failure([ { line: nil, message: limit_error } ]) if limit_error

      lines, errors = read_lines(text)
      # DCK-28 (emendado em 2026-10-02) — sem nenhuma linha de carta, não há
      # deck a criar. Só quando nenhuma linha foi recusada: com linhas ruins,
      # os motivos delas já dizem o que houve.
      return failure([ { line: nil, message: EMPTY_LIST } ]) if lines.empty? && errors.empty?

      cards = Card.where(card_number: lines.map { |line| line[:number] }.uniq).index_by(&:card_number)

      errors += lines.filter_map do |line|
        { line: line[:line], message: "#{line[:number]} não existe no catálogo" } unless cards.key?(line[:number])
      end
      found = lines.select { |line| cards.key?(line[:number]) }.group_by { |line| cards.fetch(line[:number]) }
      leaders, main = found.partition { |card, _| card.card_type == "leader" }

      errors += leader_errors(leaders) + total_errors(main)
      return failure(errors.sort_by { |error| error[:line] }) if errors.any?

      Result.new(leader: leaders.first&.first,
                 entries: main.to_h { |card, card_lines| [ card, card_lines.sum { |line| line[:quantity] } ] },
                 errors: [])
    end

    # DCK-29 — o limite é verificado antes de separar as linhas e de qualquer
    # consulta: ele existe para barrar entrada absurda, e processá-la primeiro
    # anularia o motivo.
    def limit_error(text)
      if text.length > MAX_CHARS
        "A lista pode ter no máximo #{number_with_delimiter(MAX_CHARS)} caracteres"
      elsif text.split(LINE_BREAK).size > MAX_LINES
        "A lista pode ter no máximo #{MAX_LINES} linhas"
      end
    end

    # Formato e quantidade não dependem do catálogo, então são verificados sem
    # banco. A linha em branco é ignorada, mas conta na numeração.
    def read_lines(text)
      lines = []
      errors = []
      text.split(LINE_BREAK).each.with_index(1) do |raw, number|
        next if raw.strip.empty?

        match = LINE_FORMAT.match(raw)
        if match.nil?
          errors << { line: number, message: "formato inválido; use <N>x<código>, como 4xOP01-016" }
        elsif !DeckEntry::QUANTITY_RANGE.cover?(match[1].to_i)
          errors << { line: number, message: "quantidade #{match[1].to_i} fora do limite de 1 a 50" }
        else
          lines << { line: number, quantity: match[1].to_i, number: match[2].upcase }
        end
      end
      [ lines, errors ]
    end

    # DCK-28 — no máximo um Leader, com quantidade 1. As linhas de um Leader
    # repetido já foram somadas, então `2xOP17-079` e duas linhas `1xOP17-079`
    # dão o mesmo erro.
    def leader_errors(leaders)
      first, *extra = leaders
      errors = extra.flat_map do |card, card_lines|
        card_lines.map do |line|
          { line: line[:line], message: "#{card.card_number} é um segundo Leader; a lista já tem #{first.first.card_number}" }
        end
      end
      return errors if first.nil?

      card, card_lines = first
      quantity = card_lines.sum { |line| line[:quantity] }
      return errors if quantity == 1

      errors + card_lines.map do |line|
        { line: line[:line], message: "o Leader #{card.card_number} aparece com quantidade #{quantity}; o Leader é 1" }
      end
    end

    # As linhas repetidas somam (DCK-27), e a soma também respeita o teto de 50
    # por carta do DCK-39, que o banco impõe: sem isto, `30x` + `30x` da mesma
    # carta passaria aqui e estouraria o CHECK na criação do deck.
    def total_errors(main)
      main.flat_map do |card, card_lines|
        total = card_lines.sum { |line| line[:quantity] }
        next [] if DeckEntry::QUANTITY_RANGE.cover?(total)

        card_lines.map do |line|
          { line: line[:line], message: "#{card.card_number} soma #{total} cópias nas linhas; o máximo é 50" }
        end
      end
    end

    # DCK-31 — Leader primeiro, depois as entradas na ordem da página do deck,
    # separadas por LF. ⚠️ VERIFICAR (spec, Assumptions): o exemplo do dono
    # usava CR, e a aceitação do LF pelo simulador fica para o teste manual da
    # T21. O `parse` aceita os três, então a ida e volta não depende disso.
    def format(deck)
      lines = deck.ordered_entries.map { |entry| "#{entry.quantity}x#{entry.card.card_number}" }
      lines.unshift("1x#{deck.leader.card_number}") if deck.leader
      lines.join("\n")
    end

    def failure(errors)
      Result.new(leader: nil, entries: {}, errors: errors)
    end

    def number_with_delimiter(number)
      ActiveSupport::NumberHelper.number_to_delimited(number, delimiter: ".")
    end
  end
end
