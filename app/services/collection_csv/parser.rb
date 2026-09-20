require "csv"

module CollectionCsv
  # Lê o arquivo enviado pelo usuário, valida formato e tamanho, e devolve as
  # linhas ou a recusa do arquivo inteiro (POR-04, Req. 10.2/10.3).
  #
  # **Leitura pura, e isso é a invariante da feature, não um detalhe.** Nenhuma
  # escrita na coleção acontece aqui, nem pode passar a acontecer: nada é
  # gravado sem confirmação explícita do usuário (Req. 10.5), e a coleção é o
  # único dado insubstituível do sistema — o catálogo é regenerável (AD-001).
  # Este serviço sequer toca no banco: resolver variante é da T9, gravar é da
  # T14, e há teste que conta consultas para manter assim.
  #
  # O contrato de colunas não é redeclarado — vem de `Format` (T4). Se cada
  # ponta mantivesse a sua lista, o arquivo que o app gera poderia deixar de
  # ser o arquivo que o app aceita.
  #
  # **Recusa é sempre do arquivo inteiro.** Não existe resultado parcial: um
  # cabeçalho errado descarta até as linhas bem formadas que vêm depois. Um
  # import que aproveitasse "o que deu" escreveria na coleção do usuário uma
  # interpretação que ele não pediu.
  class Parser
    # AD-008: 10.000 linhas de **dado**, sem contar o cabeçalho. O teto natural
    # do domínio hoje é 4917 variantes — uma coleção que possuísse todas as
    # impressões existentes —, então isto é folga de pouco mais de 2×. Limite em
    # número de linhas, e não em bytes, porque é a unidade que o usuário entende
    # e a que determina o custo real: uma linha = uma resolução de variante.
    MAX_LINHAS = 10_000

    # Objeto de resultado em vez de exceção ou de par `[linhas, erro]`: a recusa
    # é um desfecho **esperado** deste serviço (arquivo do usuário é entrada
    # hostil por natureza), não um caso excepcional, e quem chama — o controller
    # da T10 — precisa ramificar em `aceito?` sem `rescue`. Um par posicional
    # sobreviveria, mas obriga cada chamador a lembrar a ordem; nomear os dois
    # campos custa cinco linhas e elimina a classe inteira de erro.
    Result = Struct.new(:linhas, :erro) do
      def aceito?
        erro.nil?
      end
    end

    def initialize(conteudo)
      @conteudo = conteudo.to_s
    end

    def call
      # A codificação é verificada **primeiro** porque bytes inválidos fazem
      # `String#strip` levantar `ArgumentError` — antes de qualquer `rescue`
      # em volta do parse. Sem isto, o binário virava exceção crua no lugar da
      # frase em português.
      return recusa(MENSAGEM_CODIFICACAO) unless conteudo.valid_encoding?
      return recusa(MENSAGEM_VAZIO) if conteudo.strip.empty?

      tabela = parse
      return recusa(MENSAGEM_CSV_INVALIDO) if tabela.nil?

      recusa_de_formato(tabela.headers) || recusa_de_tamanho(tabela) ||
        Result.new(tabela.map { |linha| normalizar(linha) }.freeze, nil)
    end

    private

    attr_reader :conteudo

    MENSAGEM_VAZIO = "O arquivo enviado está vazio. Envie o CSV exportado da sua coleção.".freeze

    MENSAGEM_CSV_INVALIDO = "Não foi possível ler o arquivo como CSV. " \
      "Envie o arquivo exportado da sua coleção, sem alterar a estrutura das colunas.".freeze

    MENSAGEM_CODIFICACAO = "O arquivo não está em UTF-8. " \
      "Salve a planilha como CSV UTF-8 e envie novamente.".freeze

    def parse
      # O BOM que planilhas do Excel escrevem no início do arquivo gruda na
      # primeira célula do cabeçalho. `Format.normalize_column` também o
      # removeria, mas tirá-lo aqui mantém o valor bruto da célula limpo para
      # quem lê `linhas` depois.
      texto = conteudo.delete_prefix(Format::BOM)

      # `headers: true` resolve as colunas **por nome**, nunca por posição
      # (Edge Case da spec): o cabeçalho pode vir em qualquer ordem.
      #
      # Materializar a tabela inteira em memória é deliberado: o limite de
      # 10.000 linhas (AD-008) existe justamente para pôr teto no custo, e ler
      # em fluxo só para descobrir na milésima linha que o cabeçalho estava
      # errado complicaria o caminho de recusa sem economizar nada que importe.
      CSV.parse(texto, headers: true, col_sep: Format::DELIMITER,
        header_converters: ->(cabecalho) { Format.normalize_column(cabecalho) })
    rescue CSV::MalformedCSVError
      nil
    end

    # A recusa por `;` vem antes da genérica porque é a mais útil: o usuário
    # salvou a planilha com o separador da localidade dele e precisa saber
    # disso, em vez de ler que "faltam três colunas" num arquivo onde elas
    # estão todas lá (Edge Case da spec).
    #
    # A distinção entre "arquivo com `;`" e "arquivo de uma coluna só que não é
    # o nosso" é feita pelo próprio cabeçalho: só quando a única coluna lida
    # contém `;` e, separada por ele, produz as colunas exigidas é que o
    # diagnóstico do delimitador é certo. Um arquivo de uma coluna qualquer cai
    # na mensagem genérica, que para ele é a correta.
    def recusa_de_formato(cabecalho)
      return nil if Format.header?(cabecalho)

      if delimitado_por_ponto_e_virgula?(cabecalho)
        recusa("O arquivo está separado por \";\" em vez de \"#{Format::DELIMITER}\". " \
          "Salve a planilha como CSV separado por vírgula e envie novamente.")
      else
        recusa("O arquivo não tem as colunas esperadas: faltam #{faltantes(cabecalho)}. " \
          "Envie o CSV exportado da sua coleção.")
      end
    end

    def delimitado_por_ponto_e_virgula?(cabecalho)
      celulas = Array(cabecalho)
      return false unless celulas.size == 1 && celulas.first.to_s.include?(";")

      Format.header?(celulas.first.to_s.split(";"))
    end

    def faltantes(cabecalho)
      Format.missing_columns(cabecalho).join(", ")
    end

    # O limite é verificado **antes** de qualquer resolução de variante
    # (AD-008): recusar aqui custa uma contagem, e não 10.001 consultas ao
    # catálogo. A mensagem diz o número, porque "arquivo muito grande" não diz
    # ao usuário o que fazer com o arquivo dele.
    def recusa_de_tamanho(tabela)
      return nil if tabela.size <= MAX_LINHAS

      recusa("O arquivo tem #{formatar(tabela.size)} linhas de dados e o limite é de " \
        "#{formatar(MAX_LINHAS)} linhas. Divida a importação em arquivos menores.")
    end

    def formatar(numero)
      numero.to_s.reverse.scan(/\d{1,3}/).join(".").reverse
    end

    # Só as colunas do contrato: uma coluna extra no arquivo do usuário é
    # ignorada em vez de recusada — ela não impede o import de fazer o que
    # prometeu, e planilhas ganham colunas de anotação com facilidade.
    def normalizar(linha)
      Format::COLUMNS.index_with { |coluna| linha[coluna] }.freeze
    end

    def recusa(mensagem)
      Result.new([].freeze, mensagem)
    end
  end
end
