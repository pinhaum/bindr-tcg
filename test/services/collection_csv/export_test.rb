require "test_helper"
require "csv"

module CollectionCsv
  # Serialização da coleção de um usuário em CSV (POR-01, POR-02, POR-13).
  #
  # O export é a metade sem risco de perda da feature — leitura pura, nenhuma
  # escrita na coleção — e é o que **define** o arquivo que o import terá de
  # aceitar. Por isso os testes de escape abaixo não conferem a string gerada
  # contra uma string literal: eles fazem a ida e a volta pelo mesmo parser
  # (`CSV`) que o import usará. Um escape que só "parece certo" a olho nu, mas
  # que o parser lê diferente, passaria num teste literal e quebraria a
  # ida-e-volta do POR-11.
  class ExportTest < ActiveSupport::TestCase
    def create_user(email:)
      User.create!(email: email, password: "senha-correta")
    end

    # Cada teste cria os seus registros: o projeto não usa fixtures YAML e a
    # suíte roda em paralelo, então códigos precisam ser únicos por teste.
    def create_variant(suffix:, card_name: "Roronoa Zoro", variant_code: nil)
      set = CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
      card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: card_name,
        card_type: "leader", colors: [ "Red" ])
      CardVariant.create!(card: card, card_set: set,
        variant_code: variant_code || "OP01-#{suffix}",
        rarity: "L", art_kind: "base")
    end

    def own(user, variant, quantity)
      CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
    end

    def parse(csv)
      CSV.parse(csv, headers: true)
    end

    # Done when: o CSV tem linha de cabeçalho e uma linha por variante
    # possuída, com as quatro colunas preenchidas (POR-01, POR-02).
    test "escreve cabeçalho e uma linha por variante possuída, com as quatro colunas" do
      user = create_user(email: "cabecalho@example.com")
      variante = create_variant(suffix: "h1", card_name: "Nami")
      own(user, variante, 3)

      tabela = parse(Export.new(user).to_csv)

      assert_equal Format::COLUMNS, tabela.headers
      assert_equal 1, tabela.size
      linha = tabela.first
      assert_equal variante.card.card_number, linha["card_number"]
      assert_equal variante.variant_code, linha["variant_code"]
      assert_equal "Nami", linha["card_name"]
      assert_equal "3", linha["quantity"]
    end

    # O cabeçalho vem do dono do contrato (T4), não de uma lista redeclarada
    # aqui: export e import leem a mesma definição (POR-04).
    test "o cabeçalho é exatamente o do contrato de colunas" do
      user = create_user(email: "contrato@example.com")

      primeira_linha = Export.new(user).to_csv.lines.first

      assert_equal Format.header_row, CSV.parse_line(primeira_linha)
    end

    # Done when: variante com `quantity = 0` não aparece, e o resultado é o
    # mesmo de não haver registro (Req. 7.3).
    #
    # Exportar um zero corromperia a ida-e-volta (POR-11): o import
    # **substitui** a quantidade (AD-006), então um zero exportado apagaria uma
    # quantidade real no destino.
    test "variante com quantidade zero não aparece no arquivo" do
      user = create_user(email: "zero@example.com")
      own(user, create_variant(suffix: "z1"), 0)
      possuida = create_variant(suffix: "z2", card_name: "Usopp")
      own(user, possuida, 2)

      tabela = parse(Export.new(user).to_csv)

      assert_equal [ possuida.card.card_number ], tabela.map { |l| l["card_number"] }
    end

    test "quantidade zero produz o mesmo arquivo que não haver registro nenhum" do
      com_zero = create_user(email: "com-zero@example.com")
      sem_registro = create_user(email: "sem-registro@example.com")
      own(com_zero, create_variant(suffix: "z3"), 0)

      assert_equal Export.new(sem_registro).to_csv, Export.new(com_zero).to_csv
    end

    # Done when: usuário sem nenhuma variante possuída produz arquivo com
    # cabeçalho e nenhuma linha de dado — não arquivo vazio, não erro.
    test "coleção vazia produz cabeçalho e nenhuma linha de dado" do
      user = create_user(email: "vazio@example.com")

      csv = Export.new(user).to_csv

      refute_empty csv
      assert_equal Format.header_row, CSV.parse_line(csv)
      assert_equal 0, parse(csv).size
    end

    # Done when: nome com acento sai íntegro e o arquivo é UTF-8.
    test "nome com acento sai íntegro e o arquivo é UTF-8" do
      user = create_user(email: "acento@example.com")
      own(user, create_variant(suffix: "a1", card_name: "Bell-mère"), 1)

      csv = Export.new(user).to_csv

      assert_equal Encoding::UTF_8, csv.encoding
      assert csv.valid_encoding?
      assert_equal "Bell-mère", parse(csv).first["card_name"]
    end

    # Done when: nome com vírgula ou aspas é escapado de forma que o próprio
    # parser do import o leia de volta idêntico.
    #
    # A vírgula é o delimitador do formato (`Format::DELIMITER`): um nome que a
    # contenha e não seja escapado vira duas colunas, e o arquivo deixa de ter
    # quatro campos por linha.
    test "nome com vírgula é escapado e volta idêntico pelo parser" do
      user = create_user(email: "virgula@example.com")
      nome = "Nami, a Navegadora"
      own(user, create_variant(suffix: "v1", card_name: nome), 1)

      tabela = parse(Export.new(user).to_csv)

      assert_equal 1, tabela.size
      assert_equal nome, tabela.first["card_name"]
      assert_equal 4, CSV.parse(Export.new(user).to_csv).last.size
    end

    test "nome com aspas é escapado e volta idêntico pelo parser" do
      user = create_user(email: "aspas@example.com")
      nome = 'Sanji "Perna Preta"'
      own(user, create_variant(suffix: "q1", card_name: nome), 1)

      assert_equal nome, parse(Export.new(user).to_csv).first["card_name"]
    end

    test "nome com vírgula, aspas e quebra de linha ao mesmo tempo volta idêntico" do
      user = create_user(email: "misto@example.com")
      nome = %(Franky, o "Super"\nCarpinteiro)
      own(user, create_variant(suffix: "m1", card_name: nome), 1)

      assert_equal nome, parse(Export.new(user).to_csv).first["card_name"]
    end

    # Done when: a serialização usa um número de consultas que não cresce com o
    # número de linhas (POR-13).
    #
    # A asserção é a **igualdade** entre dois cenários de tamanhos diferentes,
    # não um número medido uma vez: um export com N+1 consultas também passaria
    # num teste que só afirmasse "é igual a 7" para o cenário pequeno.
    test "o número de consultas não cresce com o número de linhas" do
      pequeno = create_user(email: "pequeno@example.com")
      own(pequeno, create_variant(suffix: "p1"), 1)

      grande = create_user(email: "grande@example.com")
      10.times { |i| own(grande, create_variant(suffix: "g#{i}"), i + 1) }

      consultas_pequeno = count_queries { Export.new(pequeno).to_csv }
      consultas_grande = count_queries { Export.new(grande).to_csv }

      assert_equal 10, parse(Export.new(grande).to_csv).size
      assert_equal consultas_pequeno, consultas_grande,
        "o export cresceu de #{consultas_pequeno} para #{consultas_grande} consultas " \
        "entre 1 e 10 linhas — há N+1"
    end

    # Done when: dois usuários com posses distintas produzem arquivos
    # distintos, cada um só com o seu (Req. 6.5).
    test "dois usuários produzem arquivos distintos, cada um só com o seu" do
      luffy = create_user(email: "luffy@example.com")
      zoro = create_user(email: "zoro@example.com")
      dele = create_variant(suffix: "i1", card_name: "Monkey D. Luffy")
      dela = create_variant(suffix: "i2", card_name: "Roronoa Zoro")
      compartilhada = create_variant(suffix: "i3", card_name: "Going Merry")
      own(luffy, dele, 1)
      own(luffy, compartilhada, 4)
      own(zoro, dela, 2)

      do_luffy = parse(Export.new(luffy).to_csv)
      do_zoro = parse(Export.new(zoro).to_csv)

      refute_equal Export.new(luffy).to_csv, Export.new(zoro).to_csv
      assert_equal [ compartilhada.card.card_number, dele.card.card_number ].sort,
        do_luffy.map { |l| l["card_number"] }.sort
      assert_equal [ dela.card.card_number ], do_zoro.map { |l| l["card_number"] }
      refute_includes do_zoro.map { |l| l["card_number"] }, compartilhada.card.card_number
    end

    # Req. 6.5 por construção: o serviço recebe o **objeto** `User`. Um id
    # vindo do request não chega a virar consulta — `for_user` levanta.
    test "recebe o objeto User e recusa um id" do
      user = create_user(email: "objeto@example.com")

      assert_raises(ArgumentError) { Export.new(user.id).to_csv }
    end

    # A ordem do arquivo é determinística: o usuário compara exports entre si
    # em planilha, e uma ordem deixada ao acaso do banco faria dois exports da
    # mesma coleção parecerem diferentes.
    test "a ordem das linhas é determinística e não depende da ordem de inserção" do
      um = create_user(email: "ordem-um@example.com")
      outro = create_user(email: "ordem-outro@example.com")
      variantes = [ "o1", "o2", "o3" ].map { |s| create_variant(suffix: s) }

      variantes.each { |v| own(um, v, 1) }
      variantes.reverse_each { |v| own(outro, v, 1) }

      assert_equal Export.new(um).to_csv, Export.new(outro).to_csv
      assert_equal parse(Export.new(um).to_csv).map { |l| l["card_number"] }.sort,
        parse(Export.new(um).to_csv).map { |l| l["card_number"] }
    end

    private

    # `assert_queries_count` afirma um número fixo; aqui o que interessa é
    # comparar dois cenários, então o mesmo instrumento do Active Record é
    # usado para **contar**.
    def count_queries(&block)
      contador = 0
      assinatura = lambda do |_name, _start, _finish, _id, payload|
        contador += 1 unless payload[:name] == "SCHEMA" || payload[:cached]
      end
      ActiveSupport::Notifications.subscribed(assinatura, "sql.active_record", &block)
      contador
    end
  end
end
