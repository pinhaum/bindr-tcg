module CollectionCsv
  # Dono único do contrato de colunas do CSV de coleção (Req. 10.1, POR-01,
  # POR-04).
  #
  # Export e import leem daqui, e só daqui. Se cada um mantivesse a sua própria
  # lista, o arquivo que o app gera poderia deixar de ser o arquivo que o app
  # aceita sem que nenhum teste percebesse — o usuário é que descobriria, no
  # meio de uma importação.
  #
  # A chave que identifica a variante é o **par** `card_number` +
  # `variant_code`: o índice único do schema é `(card_id, variant_code)`, por
  # carta e não global. `card_name` é informativo e nunca chave — o catálogo é
  # regenerável, logo o nome muda sem o usuário fazer nada.
  module Format
    COLUMNS = %w[card_number variant_code card_name quantity].map(&:freeze).freeze

    # Fixado e documentado em vez de detectado: aceitar dois delimitadores no
    # import exige detecção, que erra. A recusa de um arquivo com `;` é da T8;
    # aqui o valor só precisa ser consultável para que ela não o redeclare.
    DELIMITER = ",".freeze

    ENCODING = "UTF-8".freeze

    # O BOM que planilhas do Excel escrevem no início do arquivo. Ele gruda na
    # primeira célula do cabeçalho e faria `"﻿card_number"` deixar de
    # casar com `"card_number"`.
    BOM = "﻿".freeze

    class << self
      # A linha de cabeçalho que o export escreve — a mesma lista que o import
      # exige, por construção.
      def header_row
        COLUMNS
      end

      def required_columns
        COLUMNS
      end

      # Colunas resolvidas por nome, nunca por posição: o cabeçalho pode vir em
      # qualquer ordem, com BOM, com espaço em volta ou em outra caixa.
      def normalize_header(header)
        Array(header).map { |cell| normalize_column(cell) }
      end

      def normalize_column(cell)
        cell.to_s.delete_prefix(BOM).strip.downcase
      end

      def header?(header)
        missing_columns(header).empty?
      end

      def missing_columns(header)
        COLUMNS - normalize_header(header)
      end
    end
  end
end
