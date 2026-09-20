require "test_helper"

module CollectionCsv
  # O contrato de colunas do CSV de coleção vive em um único lugar (POR-01,
  # POR-04). Export e import leem a mesma definição: se as duas listas
  # pudessem divergir, o arquivo que o app gera deixaria de ser o arquivo que
  # o app aceita — e o usuário descobriria isso no meio de uma importação, não
  # aqui.
  class FormatTest < ActiveSupport::TestCase
    # Done when: as quatro colunas e a sua ordem estão definidas em um único
    # lugar (Req. 10.1).
    test "as colunas são as quatro da spec, nesta ordem" do
      assert_equal %w[card_number variant_code card_name quantity], Format::COLUMNS
    end

    # Done when: a lista do export é idêntica à que o import espera. Uma
    # mudança em uma delas quebra este teste, não o usuário.
    test "o cabeçalho escrito pelo export é exatamente o que o import exige" do
      assert_equal Format.header_row, Format::COLUMNS
      assert_equal Format::COLUMNS, Format.required_columns
    end

    test "a lista de colunas é congelada, para não ser mutada em tempo de execução" do
      assert Format::COLUMNS.frozen?
      assert Format::COLUMNS.all?(&:frozen?)
    end

    # Edge Case da spec: "WHEN o arquivo tiver cabeçalho em ordem diferente,
    # THEN as colunas são resolvidas por nome, não por posição."
    test "cabeçalho em ordem trocada é reconhecido" do
      embaralhado = %w[quantity card_name variant_code card_number]

      assert Format.header?(embaralhado)
      assert_equal Format::COLUMNS.sort, Format.normalize_header(embaralhado).sort
    end

    test "cabeçalho em ordem trocada preserva a ordem do arquivo, não a da spec" do
      embaralhado = %w[quantity card_name variant_code card_number]

      assert_equal embaralhado, Format.normalize_header(embaralhado)
    end

    # Edge Case da spec: "IF o arquivo vier com BOM (planilhas do Excel o
    # inserem), THEN o cabeçalho não pode deixar de ser reconhecido por causa
    # dele."
    test "cabeçalho com BOM do Excel é reconhecido" do
      com_bom = [ "﻿card_number", "variant_code", "card_name", "quantity" ]

      assert Format.header?(com_bom)
      assert_equal Format::COLUMNS, Format.normalize_header(com_bom)
    end

    test "BOM é removido apenas da primeira célula, e o resto do nome sobrevive" do
      assert_equal "card_number", Format.normalize_column("﻿card_number")
      assert_equal "card_number", Format.normalize_column("card_number")
    end

    test "cabeçalho com BOM e ordem trocada ao mesmo tempo é reconhecido" do
      com_bom_e_trocado = [ "﻿quantity", "card_number", "card_name", "variant_code" ]

      assert Format.header?(com_bom_e_trocado)
      assert_equal %w[quantity card_number card_name variant_code],
                   Format.normalize_header(com_bom_e_trocado)
    end

    test "cabeçalho tolera espaço em volta e diferença de caixa" do
      bagunçado = [ " Card_Number ", "VARIANT_CODE", "card_name ", " Quantity" ]

      assert Format.header?(bagunçado)
      assert_equal Format::COLUMNS, Format.normalize_header(bagunçado)
    end

    test "cabeçalho a que falta uma coluna obrigatória não é reconhecido" do
      Format::COLUMNS.each do |faltante|
        incompleto = Format::COLUMNS - [ faltante ]

        refute Format.header?(incompleto), "aceitou cabeçalho sem `#{faltante}`"
        assert_equal [ faltante ], Format.missing_columns(incompleto)
      end
    end

    test "cabeçalho com coluna extra continua sendo reconhecido" do
      assert Format.header?(Format::COLUMNS + [ "set_code" ])
      assert_empty Format.missing_columns(Format::COLUMNS + [ "set_code" ])
    end

    test "cabeçalho nulo ou vazio não é reconhecido e não levanta erro" do
      refute Format.header?(nil)
      refute Format.header?([])
      assert_equal Format::COLUMNS, Format.missing_columns(nil)
    end

    # A detecção e a recusa do `;` são da T8. Aqui o formato só precisa expor
    # o delimitador esperado de forma consultável, para que a T8 não tenha que
    # redeclarar a vírgula em outro lugar.
    test "o delimitador esperado é a vírgula e é consultável" do
      assert_equal ",", Format::DELIMITER
      assert Format::DELIMITER.frozen?
    end

    test "a codificação esperada é UTF-8 e é consultável" do
      assert_equal "UTF-8", Format::ENCODING
    end
  end
end
