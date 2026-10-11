module CollectionCsv
  # Envio do CSV da coleção pela API (SPOR-36, SPOR-37): lê o arquivo, classifica
  # o que aconteceria e grava **a pré-visualização**, nada mais. Mesmas regras e
  # mesmas frases do `CollectionImportsController#create`, que fica intocado até
  # a `spa-troca` removê-lo; o teste de paridade fixa que as duas cópias não
  # divergem.
  #
  # Nada é gravado numa recusa, e `collection_items` nunca é tocada.
  class Upload
    MAX_BODY_BYTES = 12 * 1024 * 1024

    MISSING_FILE_MESSAGE = "Selecione o arquivo CSV da sua coleção para importar.".freeze

    BODY_TOO_LARGE_MESSAGE = "O arquivo é grande demais: o limite é de 8 MB. " \
      "Envie o CSV exportado da sua coleção, sem colunas ou textos extras.".freeze

    Result = Struct.new(:preview, :error) do
      def aceito?
        error.nil?
      end
    end

    def initialize(user, file, content_length)
      @user = user
      @file = file
      @content_length = content_length
    end

    def call
      return refuse(BODY_TOO_LARGE_MESSAGE) if @content_length.to_i > MAX_BODY_BYTES
      return refuse(MISSING_FILE_MESSAGE) unless @file.respond_to?(:read)

      parsed = Parser.new(utf8_content).call
      return refuse(parsed.erro) unless parsed.aceito?

      Result.new(
        CollectionImport.create!(
          user: @user,
          filename: display_name,
          linhas: Resolver.new(@user, parsed.linhas).call.linhas
        ),
        nil
      )
    end

    private

      # Os bytes do Rack chegam em ASCII-8BIT; quem decide se são UTF-8 válido é
      # o `Parser`, então só se reinterpreta, sem converter.
      def utf8_content
        @file.read.to_s.force_encoding(Encoding::UTF_8)
      end

      def refuse(message)
        Result.new(nil, message)
      end

      # `original_filename` é dado do cliente, só para exibição.
      def display_name
        raw = File.basename(@file.original_filename.to_s.tr("\\", "/"))
        clean = raw.gsub(/[^[:alnum:]._-]/, "_").delete_prefix(".").first(120)

        clean.presence || "colecao.csv"
      end
  end
end
