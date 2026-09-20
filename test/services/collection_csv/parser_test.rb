require "test_helper"

module CollectionCsv
  # Leitura e validação do arquivo enviado pelo usuário (POR-04).
  #
  # Este serviço é a porta de entrada do import e a **primeira** peça da Fase 3,
  # cuja fronteira é deliberada: ao fim dela existe um import que sabe dizer o
  # que o arquivo contém e **ainda não tem como gravar nada**. Por isso o último
  # teste deste arquivo não é cerimônia — ele é a invariante da feature
  # (Req. 10.5) exercida no único lugar onde ela poderia começar a ser violada.
  #
  # Os testes de aceitação usam o CSV **real do export** (T5) em vez de uma
  # string literal: o núcleo do POR-04 é que o import aceita o formato do
  # export, e uma string literal provaria apenas que o parser aceita o que o
  # autor do teste imaginou que o export escreve.
  class ParserTest < ActiveSupport::TestCase
    # Cada teste cria os seus registros: o projeto não usa fixtures YAML e a
    # suíte roda em paralelo, então códigos precisam ser únicos por teste.
    def create_user(email:)
      User.create!(email: email, password: "senha-correta")
    end

    def create_variant(suffix:, card_name: "Roronoa Zoro")
      set = CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
      card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: card_name,
        card_type: "leader", colors: [ "Red" ])
      CardVariant.create!(card: card, card_set: set, variant_code: "OP01-#{suffix}",
        rarity: "L", art_kind: "base")
    end

    def own(user, variant, quantity)
      CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
    end

    # Monta um CSV no formato do contrato sem redeclarar a lista de colunas:
    # o cabeçalho vem de `Format`, como no export.
    def csv_com(linhas, cabecalho: Format.header_row, delimitador: Format::DELIMITER)
      ([ cabecalho ] + linhas).map { |linha| linha.join(delimitador) }.join("\n") + "\n"
    end

    def linha_valida(numero: "OP01-001", codigo: "OP01-001", nome: "Nami", quantidade: 3)
      [ numero, codigo, nome, quantidade.to_s ]
    end

    # --- Aceitação -------------------------------------------------------

    # Done when: um arquivo com cabeçalho correto e linhas válidas é aceito.
    test "arquivo com cabeçalho correto e linhas válidas é aceito" do
      resultado = Parser.new(csv_com([ linha_valida, linha_valida(numero: "OP01-002", codigo: "OP01-002") ])).call

      assert resultado.aceito?
      assert_nil resultado.erro
      assert_equal 2, resultado.linhas.size
    end

    # O núcleo do POR-04: "o import aceita o formato do export". O arquivo aqui
    # não é inventado — é o que o serviço da T5 produz de verdade.
    test "o arquivo produzido pelo export é aceito pelo parser" do
      user = create_user(email: "ida-e-volta@example.com")
      variante = create_variant(suffix: "p1", card_name: "Bell-mère")
      own(user, variante, 4)

      resultado = Parser.new(Export.new(user).to_csv).call

      assert resultado.aceito?
      assert_equal 1, resultado.linhas.size
      linha = resultado.linhas.first
      assert_equal variante.card.card_number, linha["card_number"]
      assert_equal variante.variant_code, linha["variant_code"]
      assert_equal "Bell-mère", linha["card_name"]
      assert_equal "4", linha["quantity"]
    end

    # Escape do export lido de volta idêntico: o nome com vírgula e aspas não
    # pode virar coluna a mais nem perder caractere na volta (POR-11).
    test "nome com vírgula e aspas escrito pelo export volta idêntico" do
      user = create_user(email: "escape@example.com")
      nome = 'Nami, a "Gata Ladra"'
      variante = create_variant(suffix: "p2", card_name: nome)
      own(user, variante, 1)

      resultado = Parser.new(Export.new(user).to_csv).call

      assert resultado.aceito?
      assert_equal nome, resultado.linhas.first["card_name"]
    end

    test "arquivo só com cabeçalho é aceito, com nenhuma linha de dado" do
      resultado = Parser.new(csv_com([])).call

      assert resultado.aceito?
      assert_empty resultado.linhas
    end

    # As colunas são resolvidas por nome: a linha devolvida é indexada pelo
    # nome da coluna, não pela posição em que ela apareceu no arquivo.
    test "as células são devolvidas indexadas pelo nome da coluna" do
      resultado = Parser.new(csv_com([ linha_valida(numero: "OP05-013", codigo: "OP05-013_p1",
        nome: "Sanji", quantidade: 7) ])).call

      linha = resultado.linhas.first
      assert_equal "OP05-013", linha["card_number"]
      assert_equal "OP05-013_p1", linha["variant_code"]
      assert_equal "Sanji", linha["card_name"]
      assert_equal "7", linha["quantity"]
    end

    # --- Cabeçalho por nome, BOM e ordem trocada -------------------------

    # Done when: o cabeçalho é resolvido por nome e sobrevive a BOM e a ordem
    # trocada (herdado da T4, exercitado aqui de ponta a ponta). Este teste é
    # o de ponta a ponta: não pergunta ao `Format` se reconhece o cabeçalho,
    # pergunta ao parser se a **célula certa** chega na chave certa.
    test "cabeçalho em ordem trocada resolve as células por nome, não por posição" do
      trocado = %w[quantity card_name variant_code card_number]
      resultado = Parser.new(csv_com([ [ "9", "Chopper", "OP02-018_p1", "OP02-018" ] ],
        cabecalho: trocado)).call

      assert resultado.aceito?
      linha = resultado.linhas.first
      assert_equal "OP02-018", linha["card_number"]
      assert_equal "OP02-018_p1", linha["variant_code"]
      assert_equal "Chopper", linha["card_name"]
      assert_equal "9", linha["quantity"]
    end

    # Edge Case da spec: "IF o arquivo vier com BOM (planilhas do Excel o
    # inserem), THEN o cabeçalho não pode deixar de ser reconhecido por causa
    # dele."
    test "arquivo com BOM do Excel é aceito e as células chegam nas chaves certas" do
      com_bom = Format::BOM + csv_com([ linha_valida(nome: "Franky") ])

      resultado = Parser.new(com_bom).call

      assert resultado.aceito?
      linha = resultado.linhas.first
      assert_equal "OP01-001", linha["card_number"]
      assert_equal "Franky", linha["card_name"]
    end

    test "arquivo com BOM e cabeçalho em ordem trocada ao mesmo tempo é aceito" do
      trocado = %w[quantity card_name variant_code card_number]
      com_bom = Format::BOM + csv_com([ [ "2", "Brook", "OP03-001", "OP03-001" ] ],
        cabecalho: trocado)

      resultado = Parser.new(com_bom).call

      assert resultado.aceito?
      linha = resultado.linhas.first
      assert_equal "OP03-001", linha["card_number"]
      assert_equal "2", linha["quantity"]
    end

    test "cabeçalho com espaço em volta e em outra caixa é reconhecido" do
      bagunçado = [ " Card_Number ", "VARIANT_CODE", " card_name", "Quantity " ]
      resultado = Parser.new(csv_com([ linha_valida ], cabecalho: bagunçado)).call

      assert resultado.aceito?
      assert_equal "OP01-001", resultado.linhas.first["card_number"]
    end

    # --- Recusa do arquivo inteiro ---------------------------------------

    # Done when: arquivo sem as colunas esperadas é recusado inteiro, com
    # mensagem em português, sem processar linha nenhuma.
    test "arquivo sem as colunas esperadas é recusado inteiro" do
      alheio = %w[card_number quantity comentario]
      resultado = Parser.new(csv_com([ [ "OP01-001", "3", "qualquer" ] ], cabecalho: alheio)).call

      refute resultado.aceito?
      assert_empty resultado.linhas
    end

    test "a recusa por coluna faltando nomeia as colunas que faltam, em português" do
      alheio = %w[card_number quantity]
      resultado = Parser.new(csv_com([ [ "OP01-001", "3" ] ], cabecalho: alheio)).call

      assert_includes resultado.erro, "variant_code"
      assert_includes resultado.erro, "card_name"
      assert_match(/faltam|falta/i, resultado.erro)
    end

    # "Recusado **inteiro**": não existe resultado parcial. Mesmo com cem
    # linhas perfeitamente formadas depois de um cabeçalho errado, nenhuma
    # delas volta.
    test "cabeçalho errado descarta até as linhas bem formadas que vêm depois" do
      alheio = %w[numero codigo nome quantidade]
      cem_linhas = Array.new(100) { |i| [ "OP01-%03d" % i, "OP01-%03d" % i, "Luffy", "1" ] }
      resultado = Parser.new(csv_com(cem_linhas, cabecalho: alheio)).call

      refute resultado.aceito?
      assert_empty resultado.linhas
    end

    test "arquivo completamente vazio é recusado com mensagem em português" do
      resultado = Parser.new("").call

      refute resultado.aceito?
      assert_empty resultado.linhas
      assert_match(/vazio/i, resultado.erro)
    end

    # Edge Case da spec: "IF o arquivo vier com `;` em vez de `,`, THEN ele é
    # recusado com mensagem que diz o delimitador esperado, em vez de importar
    # uma coluna só."
    test "arquivo delimitado por ponto e vírgula é recusado" do
      com_ponto_e_virgula = csv_com([ linha_valida ], delimitador: ";")
      resultado = Parser.new(com_ponto_e_virgula).call

      refute resultado.aceito?
      assert_empty resultado.linhas
    end

    test "a recusa do ponto e vírgula diz o delimitador esperado" do
      com_ponto_e_virgula = csv_com([ linha_valida ], delimitador: ";")
      resultado = Parser.new(com_ponto_e_virgula).call

      assert_includes resultado.erro, Format::DELIMITER
      assert_match(/vírgula/i, resultado.erro)
      assert_includes resultado.erro, ";"
    end

    # A mensagem do `;` é mais útil que a de "colunas faltando", mas não pode
    # sequestrar o caso de um arquivo de uma coluna só que simplesmente não é
    # o nosso: sem `;` no cabeçalho, a recusa volta a ser a genérica.
    test "arquivo de uma coluna só sem ponto e vírgula recebe a recusa por coluna faltando" do
      resultado = Parser.new(csv_com([ [ "OP01-001" ] ], cabecalho: [ "card_number" ])).call

      refute resultado.aceito?
      refute_match(/;/, resultado.erro)
      assert_includes resultado.erro, "variant_code"
    end

    # Done when: arquivo que não é CSV é recusado com mensagem em português e
    # sem stack trace. São dois caminhos diferentes no `CSV` do Ruby: texto
    # solto é **aceito em silêncio** como uma linha de uma coluna, e aspas
    # desbalanceadas levantam `CSV::MalformedCSVError`. Os dois precisam virar
    # a mesma recusa em português.
    test "texto solto que não é CSV é recusado com mensagem em português" do
      resultado = Parser.new("isto aqui não é um arquivo de coleção\n").call

      refute resultado.aceito?
      assert_empty resultado.linhas
      refute_empty resultado.erro
    end

    test "JSON enviado no lugar do CSV é recusado" do
      resultado = Parser.new(%({"cartas": [{"card_number": "OP01-001"}]}\n)).call

      refute resultado.aceito?
      assert_empty resultado.linhas
    end

    test "CSV malformado levanta recusa em vez de exceção" do
      malformado = %(card_number,variant_code,card_name,quantity\n"OP01-001,OP01-001,Nami,3\n)

      resultado = nil
      assert_nothing_raised { resultado = Parser.new(malformado).call }

      refute resultado.aceito?
      assert_empty resultado.linhas
      assert_match(/csv/i, resultado.erro)
    end

    # Bytes que não são UTF-8 fazem o `CSV` levantar `ArgumentError` cru. O
    # usuário precisa de uma frase, não de uma exceção de codificação.
    test "arquivo com bytes inválidos em UTF-8 é recusado com mensagem em português" do
      binario = "\xFF\xFE\x00\x01carta\xC3\x28".dup.force_encoding(Format::ENCODING)

      resultado = nil
      assert_nothing_raised { resultado = Parser.new(binario).call }

      refute resultado.aceito?
      assert_empty resultado.linhas
      assert_match(/UTF-8/i, resultado.erro)
    end

    # Done when: nenhuma mensagem de recusa carrega stack trace nem jargão de
    # exceção. É o usuário que lê isto, no meio de uma importação.
    test "nenhuma mensagem de recusa contém stack trace ou nome de classe de exceção" do
      recusas = [
        Parser.new("").call,
        Parser.new("isto aqui não é um arquivo de coleção\n").call,
        Parser.new(csv_com([ linha_valida ], delimitador: ";")).call,
        Parser.new(csv_com([ [ "OP01-001", "3" ] ], cabecalho: %w[card_number quantity])).call,
        Parser.new(%(card_number,variant_code,card_name,quantity\n"OP01-001,x,y,1\n)).call,
        Parser.new("\xFF\xFE\x00\x01".dup.force_encoding(Format::ENCODING)).call
      ]

      recusas.each do |resultado|
        refute resultado.aceito?
        refute_empty resultado.erro
        refute_match(/Error|Exception|\.rb:\d|backtrace|#<|CSV::/, resultado.erro)
      end
    end

    # --- Limite de linhas (AD-008) ---------------------------------------

    def csv_com_n_linhas(n)
      linhas = Array.new(n) { |i| [ "OP01-%05d" % i, "OP01-%05d" % i, "Luffy", "1" ] }
      csv_com(linhas)
    end

    # Done when: a fronteira é testada dos dois lados. 10.000 linhas de **dado**,
    # sem contar o cabeçalho (AD-008).
    test "arquivo com exatamente o limite de linhas de dado é aceito" do
      resultado = Parser.new(csv_com_n_linhas(Parser::MAX_LINHAS)).call

      assert resultado.aceito?
      assert_equal Parser::MAX_LINHAS, resultado.linhas.size
    end

    test "arquivo com uma linha a mais que o limite é recusado" do
      resultado = Parser.new(csv_com_n_linhas(Parser::MAX_LINHAS + 1)).call

      refute resultado.aceito?
      assert_empty resultado.linhas
    end

    test "o limite é de dez mil linhas de dado, sem contar o cabeçalho" do
      assert_equal 10_000, Parser::MAX_LINHAS
    end

    # Done when: a mensagem diz o limite. Um "arquivo muito grande" sem número
    # não diz ao usuário o que fazer com o arquivo dele.
    test "a recusa por tamanho diz o limite em número de linhas" do
      resultado = Parser.new(csv_com_n_linhas(Parser::MAX_LINHAS + 1)).call

      assert_includes resultado.erro, "10.000"
      assert_match(/linha/i, resultado.erro)
    end

    # Done when: o limite é verificado **antes** de qualquer resolução de
    # variante. A resolução é da T9 e ainda não existe; o que se prova aqui é
    # que o caminho de recusa por tamanho **não consulta o banco** — nem para
    # buscar variante, nem para nada. Se um dia a resolução entrar neste
    # serviço antes da contagem, este teste fica vermelho.
    test "a recusa por tamanho não emite nenhuma consulta ao catálogo" do
      grande = csv_com_n_linhas(Parser::MAX_LINHAS + 1)

      assert_equal 0, consultas { Parser.new(grande).call }
    end

    test "nem o caminho de aceitação consulta o catálogo — resolver variante é da T9" do
      create_variant(suffix: "q1")

      assert_equal 0, consultas { Parser.new(csv_com([ linha_valida ])).call }
    end

    # --- A invariante da feature -----------------------------------------

    # Done when: nenhum caminho deste serviço escreve no banco, provado com
    # `assert_no_changes` sobre `CollectionItem.count` e a quantidade de um
    # item existente.
    #
    # Esta é a invariante da feature (Req. 10.5) no ponto onde ela poderia
    # começar a ser violada: a coleção é o único dado insubstituível do
    # sistema. O parser lê o arquivo do usuário e não tem — nem pode passar a
    # ter — caminho de escrita.
    test "nenhum caminho do parser altera a coleção" do
      user = create_user(email: "invariante@example.com")
      variante = create_variant(suffix: "i1")
      item = own(user, variante, 5)

      entradas = [
        csv_com([ [ variante.card.card_number, variante.variant_code, "Nami", "99" ] ]),
        csv_com([ linha_valida ], delimitador: ";"),
        csv_com([ [ "OP01-001", "3" ] ], cabecalho: %w[card_number quantity]),
        csv_com_n_linhas(Parser::MAX_LINHAS + 1),
        "isto aqui não é um arquivo de coleção\n",
        "",
        "\xFF\xFE\x00\x01".dup.force_encoding(Format::ENCODING)
      ]

      assert_no_changes -> { CollectionItem.count } do
        assert_no_changes -> { item.reload.quantity } do
          entradas.each { |entrada| Parser.new(entrada).call }
        end
      end
    end

    # Uma linha com quantidade 99 no arquivo não vira 99 na coleção: o parser
    # devolve o que leu e para por aí. Gravar é da T14, e só depois da
    # confirmação explícita do usuário.
    test "a quantidade lida do arquivo fica no resultado e não chega na coleção" do
      user = create_user(email: "so-leitura@example.com")
      variante = create_variant(suffix: "i2")
      item = own(user, variante, 5)

      resultado = Parser.new(csv_com([ [ variante.card.card_number, variante.variant_code,
        "Nami", "99" ] ])).call

      assert_equal "99", resultado.linhas.first["quantity"]
      assert_equal 5, item.reload.quantity
    end

    private

    # Mesmo instrumento do Active Record usado no teste do export (T5): aqui o
    # número esperado é zero, e `assert_no_queries` não distingue a consulta de
    # schema que o primeiro acesso do worker emite.
    def consultas(&block)
      contador = 0
      assinatura = lambda do |_name, _start, _finish, _id, payload|
        contador += 1 unless payload[:name] == "SCHEMA" || payload[:cached]
      end
      ActiveSupport::Notifications.subscribed(assinatura, "sql.active_record", &block)
      contador
    end
  end
end
