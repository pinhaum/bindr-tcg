require "csv"

module CollectionCsv
  # Serializa a coleção de um usuário em CSV (POR-01, POR-02, POR-13).
  #
  # **Leitura pura.** Nenhuma escrita na coleção acontece aqui, nem pode passar
  # a acontecer: a invariante da feature é que nada é gravado sem confirmação
  # explícita do usuário (Req. 10.5), e o export é justamente a metade sem
  # risco de perda.
  #
  # O contrato de colunas não é redeclarado — vem de `Format` (POR-04). Se cada
  # ponta mantivesse a sua lista, o arquivo que o app gera poderia deixar de
  # ser o arquivo que o app aceita.
  class Export
    def initialize(user)
      @user = user
    end

    # Devolve o CSV inteiro como `String` em UTF-8.
    #
    # A coleção de um usuário é pequena por natureza — é o que uma pessoa
    # possui — e o limite da feature é de 10.000 linhas (AD-008), então
    # materializar em memória é adequado e mantém o serviço trivial de testar.
    # Sem BOM: o `Format::BOM` existe para o import **tolerar** o que planilhas
    # escrevem, não para o export produzir um arquivo que o próprio parser
    # precise limpar.
    def to_csv
      CSV.generate(col_sep: Format::DELIMITER, encoding: Format::ENCODING) do |csv|
        csv << Format.header_row
        rows.each { |row| csv << row }
      end
    end

    private

    attr_reader :user

    # Uma única consulta, independente do número de linhas (POR-13). O `joins`
    # traz `card_number` e `name`, que vivem em `cards` e não em
    # `card_variants` — sem ele, cada linha viraria uma consulta.
    #
    # `pluck` e não `includes`: as quatro colunas do CSV são os únicos dados
    # necessários, e instanciar um objeto por linha para depois descartá-lo só
    # gastaria memória.
    #
    # A ordem é `(card_number, variant_code)` — o **par** que identifica a
    # variante no arquivo (Req. 10.1) — e é explícita porque a spec não a
    # define: sem `ORDER BY`, o Postgres pode devolver a mesma coleção em
    # ordens diferentes entre dois exports, e o usuário compara os arquivos em
    # planilha. Ordenar pela chave também agrupa as variantes da mesma carta,
    # que é como ele lê a lista.
    def rows
      CollectionItem
        .for_user(user)
        .owned
        .joins(card_variant: :card)
        .order("cards.card_number ASC", "card_variants.variant_code ASC")
        .pluck("cards.card_number", "card_variants.variant_code",
          "cards.name", "collection_items.quantity")
    end
  end
end
