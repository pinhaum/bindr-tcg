require "test_helper"

module CollectionCsv
  # Resolução de variante pelo par e classificação de cada linha (POR-05,
  # POR-06, POR-13).
  #
  # Esta é a última peça da Fase 3, cuja fronteira é deliberada: ao fim dela o
  # import sabe dizer **exatamente o que aconteceria** com a coleção e ainda
  # não tem como gravar nada. O resolvedor classifica; quem grava é a T14,
  # depois da confirmação explícita do usuário (Req. 10.5). Por isso o último
  # teste deste arquivo não é cerimônia — ele é a invariante da feature
  # exercida no ponto onde ela poderia começar a ser violada.
  #
  # A chave de resolução é o **par** `card_number` + `variant_code`, nunca o
  # nome e nunca o `variant_code` sozinho: o índice único do schema é
  # `(card_id, variant_code)`, por carta e não global. Dois dos testes abaixo
  # existem só para segurar essa distinção, que é a que torna o arquivo do
  # export reimportável depois de uma reingestão (AD-001).
  class ResolverTest < ActiveSupport::TestCase
    # Cada teste cria os seus registros: o projeto não usa fixtures YAML e a
    # suíte roda em paralelo, então códigos precisam ser únicos por teste.
    def create_user(email:)
      User.create!(email: email, password: "senha-correta")
    end

    def create_set(suffix)
      CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
    end

    def create_card(suffix:, name: "Roronoa Zoro", set: nil)
      set ||= create_set(suffix)
      Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: name,
        card_type: "leader", colors: [ "Red" ])
    end

    def create_variant(suffix:, card_name: "Roronoa Zoro", variant_code: nil, card: nil)
      card ||= create_card(suffix: suffix, name: card_name)
      CardVariant.create!(card: card, card_set: card.card_set,
        variant_code: variant_code || "OP01-#{suffix}",
        rarity: "L", art_kind: "base", last_seen_at: Time.current)
    end

    def own(user, variant, quantity)
      CollectionItem.create!(user: user, card_variant: variant, quantity: quantity)
    end

    # Linha no formato que o `Parser` entrega: hash indexado pelas colunas do
    # contrato (T4), nunca por posição.
    def linha(variante_ou_numero, codigo = nil, nome: "Nami", quantidade: 3)
      numero = if variante_ou_numero.is_a?(CardVariant)
        codigo ||= variante_ou_numero.variant_code
        variante_ou_numero.card.card_number
      else
        variante_ou_numero
      end

      { "card_number" => numero, "variant_code" => codigo,
        "card_name" => nome, "quantity" => quantidade.to_s }
    end

    def resolver(user, linhas)
      Resolver.new(user, linhas).call
    end

    # --- Resolução pelo par ----------------------------------------------

    # Done when: a variante é resolvida pelo **par**, nunca pelo nome — uma
    # linha cujo `card_name` diverge do catálogo resolve na mesma variante e
    # não é rejeitada.
    #
    # O catálogo é regenerável (AD-001): o nome muda sem o usuário fazer nada,
    # e um import que resolvesse por nome quebraria sozinho na reingestão.
    test "resolve pelo par mesmo quando o nome da linha diverge do catálogo" do
      user = create_user(email: "nome-diverge@example.com")
      variante = create_variant(suffix: "n1", card_name: "Nami")

      resultado = resolver(user, [ linha(variante, nome: "Nome Completamente Outro") ])

      item = resultado.linhas.sole
      assert_predicate item, :aceita?
      assert_equal variante.id, item.card_variant_id
      assert_equal :cria, item.classificacao
    end

    # Done when: um `variant_code` válido **sob outra carta** não resolve na
    # variante errada — o par é a chave, não o `variant_code` sozinho.
    #
    # O `UNIQUE` do schema é `(card_id, variant_code)`: o mesmo sufixo `_p1`
    # existe sob centenas de cartas. Resolver só pelo código casaria com a
    # primeira que aparecesse e gravaria na carta errada.
    test "variant_code válido sob outra carta não resolve na variante errada" do
      user = create_user(email: "codigo-cruzado@example.com")
      set = create_set("x1")
      uma = create_card(suffix: "x1", name: "Nami", set: set)
      outra = create_card(suffix: "x2", name: "Usopp", set: set)
      CardVariant.create!(card: uma, card_set: set, variant_code: "_p1",
        rarity: "R", art_kind: "parallel", last_seen_at: Time.current)
      da_outra = CardVariant.create!(card: outra, card_set: set, variant_code: "_p1",
        rarity: "R", art_kind: "parallel", last_seen_at: Time.current)

      resultado = resolver(user, [ linha(outra.card_number, "_p1") ])

      assert_equal da_outra.id, resultado.linhas.sole.card_variant_id
    end

    # O outro lado da mesma moeda: o par existe como duas metades válidas, mas
    # a combinação não existe. Isso é rejeição, não resolução aproximada.
    test "par inexistente não cai na carta certa com código de outra" do
      user = create_user(email: "par-inexistente@example.com")
      set = create_set("y1")
      uma = create_card(suffix: "y1", name: "Nami", set: set)
      outra = create_card(suffix: "y2", name: "Usopp", set: set)
      CardVariant.create!(card: uma, card_set: set, variant_code: "_p9",
        rarity: "R", art_kind: "parallel", last_seen_at: Time.current)
      CardVariant.create!(card: outra, card_set: set, variant_code: "_p8",
        rarity: "R", art_kind: "parallel", last_seen_at: Time.current)

      resultado = resolver(user, [ linha(outra.card_number, "_p9") ])

      item = resultado.linhas.sole
      assert_predicate item, :rejeitada?
      assert_nil item.card_variant_id
      assert_equal :variante_inexistente, item.motivo
    end

    # --- Rejeição isolada não aborta o lote (POR-05, POR-06) --------------

    # Done when: linha com variante inexistente é rejeitada com motivo e as
    # demais continuam sendo processadas (Req. 10.3).
    test "variante inexistente é rejeitada com motivo e as demais são processadas" do
      user = create_user(email: "inexistente@example.com")
      existente = create_variant(suffix: "e1")

      resultado = resolver(user, [
        linha("OP99-999", "OP99-999"),
        linha(existente, quantidade: 2)
      ])

      rejeitada, aceita = resultado.linhas
      assert_predicate rejeitada, :rejeitada?
      assert_equal :variante_inexistente, rejeitada.motivo
      assert rejeitada.mensagem.present?, "a rejeição precisa dizer o motivo em português"
      assert_predicate aceita, :aceita?
      assert_equal existente.id, aceita.card_variant_id
      assert_equal 2, aceita.quantidade_depois
    end

    # Done when: linha com quantidade inválida (negativa, não inteira, texto)
    # é rejeitada com motivo, sem interromper o lote.
    test "quantidade inválida é rejeitada com motivo sem interromper o lote" do
      user = create_user(email: "quantidade-invalida@example.com")
      variante = create_variant(suffix: "q1")
      valida = create_variant(suffix: "q2", card_name: "Usopp")

      invalidas = [ "-1", "1.5", "três", "", nil, " " ]
      linhas = invalidas.map.with_index do |valor, indice|
        { "card_number" => variante.card.card_number,
          "variant_code" => variante.variant_code,
          "card_name" => "Nami-#{indice}", "quantity" => valor }
      end
      resultado = resolver(user, linhas + [ linha(valida, quantidade: 4) ])

      resultado.linhas.take(invalidas.size).each_with_index do |item, indice|
        assert_predicate item, :rejeitada?, "#{invalidas[indice].inspect} deveria ser rejeitada"
        assert_equal :quantidade_invalida, item.motivo
        assert item.mensagem.present?
      end
      assert_predicate resultado.linhas.last, :aceita?
      assert_equal 4, resultado.linhas.last.quantidade_depois
    end

    # A fronteira do válido, do lado de dentro: zero e um inteiro grande são
    # quantidades legítimas, e espaço em volta não torna o número inválido.
    test "zero, inteiro positivo e número com espaço em volta são quantidades válidas" do
      user = create_user(email: "quantidade-valida@example.com")
      variantes = %w[v1 v2 v3].map { |s| create_variant(suffix: s) }
      linhas = [
        linha(variantes[0], quantidade: 0),
        linha(variantes[1], quantidade: 7),
        { "card_number" => variantes[2].card.card_number,
          "variant_code" => variantes[2].variant_code,
          "card_name" => "Nami", "quantity" => " 2 " }
      ]

      resultado = resolver(user, linhas)

      assert(resultado.linhas.none?(&:rejeitada?), "nenhuma destas quantidades é inválida")
      assert_equal [ 0, 7, 2 ], resultado.linhas.map(&:quantidade_depois)
    end

    # --- Classificação: cria, atualiza, rejeita (AD-006) ------------------

    # Done when: a classificação distingue cria, atualiza e rejeita, e
    # "atualiza" traz o valor **antes** e **depois** (AD-006: substituir).
    #
    # O antes e o depois não são conforto de interface: são o que a
    # pré-visualização do Req. 10.5 mostra para que a confirmação seja
    # informada. Sem o "antes", o usuário confirma uma substituição sem saber
    # o que está substituindo.
    test "classifica cria, atualiza e rejeita, com antes e depois na atualização" do
      user = create_user(email: "classificacao@example.com")
      nova = create_variant(suffix: "c1")
      possuida = create_variant(suffix: "c2", card_name: "Usopp")
      own(user, possuida, 2)

      resultado = resolver(user, [
        linha(nova, quantidade: 1),
        linha(possuida, quantidade: 5),
        linha("OP98-998", "OP98-998")
      ])

      criada, atualizada, rejeitada = resultado.linhas

      assert_equal :cria, criada.classificacao
      assert_nil criada.quantidade_antes
      assert_equal 1, criada.quantidade_depois

      assert_equal :atualiza, atualizada.classificacao
      assert_equal 2, atualizada.quantidade_antes
      assert_equal 5, atualizada.quantidade_depois

      assert_equal :rejeita, rejeitada.classificacao
    end

    # AD-006 é **substituir**, não somar e não tomar o maior valor. Uma
    # quantidade menor que a atual é uma correção legítima (o usuário vendeu
    # cópias) e precisa passar.
    test "substituir e não somar: quantidade menor que a atual é o valor final" do
      user = create_user(email: "substitui@example.com")
      possuida = create_variant(suffix: "s1")
      own(user, possuida, 9)

      item = resolver(user, [ linha(possuida, quantidade: 3) ]).linhas.sole

      assert_equal :atualiza, item.classificacao
      assert_equal 9, item.quantidade_antes
      assert_equal 3, item.quantidade_depois
    end

    # Uma linha que repete a quantidade já possuída não é mudança. Distinguir
    # isso de "atualiza" é o que torna a ida-e-volta do POR-11 **legível**: ao
    # reimportar o próprio export, a pré-visualização diz "nada muda" em vez de
    # anunciar N atualizações que não alteram nada.
    test "quantidade igual à atual é classificada como inalterada, não como atualização" do
      user = create_user(email: "inalterada@example.com")
      possuida = create_variant(suffix: "i1")
      own(user, possuida, 4)

      item = resolver(user, [ linha(possuida, quantidade: 4) ]).linhas.sole

      assert_equal :inalterada, item.classificacao
      assert_equal 4, item.quantidade_antes
      assert_equal 4, item.quantidade_depois
      refute_predicate item, :rejeitada?
    end

    # --- Quantidade zero (Req. 7.3 + AD-006) ------------------------------

    # Done when: quantidade zero é classificada segundo o Req. 7.3 e a AD-006,
    # de forma explícita na classificação.
    #
    # Zero significa "não possuo" e é **representável** (Req. 7.3): o registro
    # existe com `quantity = 0`. Sob AD-006 (substituir), uma linha com zero
    # sobre uma variante possuída **zera a posse** — que é destrutivo e não
    # pode se esconder dentro de "atualiza". Daí a classificação própria: a
    # pré-visualização da T13 consegue destacar exatamente as linhas que
    # apagam posse.
    test "zero sobre variante possuída zera a posse e tem classificação própria" do
      user = create_user(email: "zera@example.com")
      possuida = create_variant(suffix: "z1")
      own(user, possuida, 6)

      item = resolver(user, [ linha(possuida, quantidade: 0) ]).linhas.sole

      assert_equal :zera, item.classificacao
      assert_equal 6, item.quantidade_antes
      assert_equal 0, item.quantidade_depois
      refute_predicate item, :rejeitada?
    end

    # Zero sobre variante não possuída não apaga nada — não há posse para
    # apagar. Ele cria o registro que representa "não possuo" (Req. 7.3), e
    # misturá-lo com o caso destrutivo acima esconderia do usuário qual é qual.
    test "zero sobre variante não possuída não é destrutivo e não vira zera" do
      user = create_user(email: "zero-sem-posse@example.com")
      variante = create_variant(suffix: "z2")

      item = resolver(user, [ linha(variante, quantidade: 0) ]).linhas.sole

      assert_equal :cria, item.classificacao
      assert_nil item.quantidade_antes
      assert_equal 0, item.quantidade_depois
    end

    # Zero sobre um registro que já está zerado não muda nada: é inalterada,
    # não "zera". Classificar como destrutivo o que não destrói nada treinaria
    # o usuário a ignorar o destaque.
    test "zero sobre registro já zerado é inalterada" do
      user = create_user(email: "zero-sobre-zero@example.com")
      variante = create_variant(suffix: "z3")
      own(user, variante, 0)

      item = resolver(user, [ linha(variante, quantidade: 0) ]).linhas.sole

      assert_equal :inalterada, item.classificacao
      assert_equal 0, item.quantidade_antes
    end

    # --- Linha duplicada (Edge Case da spec) ------------------------------

    # Done when: a mesma variante em duas linhas do arquivo é tratada de forma
    # explícita, e a última **não vence em silêncio**.
    #
    # O tratamento escolhido: a **última** linha vale (AD-006 é substituir, e
    # é ela que reflete a última intenção do usuário), e as anteriores são
    # **rejeitadas com motivo próprio**. Rejeitar a última seria arbitrário;
    # aplicar as duas é impossível sob `UNIQUE (user_id, card_variant_id)`; e
    # deixar a última vencer sem dizer nada é exatamente o que o Edge Case
    # proíbe. Como rejeição, a linha perdedora aparece na pré-visualização da
    # T13 pelo mesmo caminho que qualquer outra rejeição, com o seu motivo.
    test "variante repetida: a última vale e as anteriores são rejeitadas com motivo" do
      user = create_user(email: "duplicada@example.com")
      variante = create_variant(suffix: "d1")

      resultado = resolver(user, [
        linha(variante, quantidade: 1),
        linha(variante, quantidade: 2),
        linha(variante, quantidade: 3)
      ])

      primeira, segunda, ultima = resultado.linhas

      [ primeira, segunda ].each do |perdedora|
        assert_predicate perdedora, :rejeitada?
        assert_equal :linha_duplicada, perdedora.motivo
        assert perdedora.mensagem.present?
      end
      assert_predicate ultima, :aceita?
      assert_equal 3, ultima.quantidade_depois
    end

    # A duplicata é do **par**, não do `card_number`: duas variantes da mesma
    # carta são objetos de coleção distintos (design.md §3.1) e as duas linhas
    # são legítimas.
    test "duas variantes da mesma carta não são duplicata" do
      user = create_user(email: "mesma-carta@example.com")
      card = create_card(suffix: "m1", name: "Nami")
      base = create_variant(suffix: "m1", card: card, variant_code: "OP01-m1")
      parallel = create_variant(suffix: "m1p", card: card, variant_code: "OP01-m1_p1")

      resultado = resolver(user, [
        linha(base, quantidade: 1),
        linha(parallel, quantidade: 2)
      ])

      assert(resultado.linhas.none?(&:rejeitada?))
      assert_equal [ base.id, parallel.id ], resultado.linhas.map(&:card_variant_id)
    end

    # --- Variante ausente da fonte (Req. 1.7) -----------------------------

    # Done when: variante marcada como ausente da fonte continua importável.
    #
    # A ingestão **não deleta** (Req. 1.7): a ausência é representada por um
    # `last_seen_at` velho em `card_variants`, deixado para trás enquanto o
    # presente é remarcado (`Ingestion::Upsert`). Não há coluna booleana de
    # ausência e não há linha removida — logo, o resolvedor não pode filtrar
    # por essa marca, e este teste é o que segura isso: um filtro por
    # `last_seen_at` recente apagaria do import justamente as cartas antigas
    # que o usuário mais precisa registrar.
    test "variante marcada como ausente da fonte continua importável" do
      user = create_user(email: "ausente@example.com")
      ausente = create_variant(suffix: "a1")
      presente = create_variant(suffix: "a2", card_name: "Usopp")
      ausente.update!(last_seen_at: 3.months.ago)
      presente.update!(last_seen_at: Time.current)

      resultado = resolver(user, [
        linha(ausente, quantidade: 2),
        linha(presente, quantidade: 1)
      ])

      assert(resultado.linhas.none?(&:rejeitada?), "a ausência da fonte não torna a variante inválida")
      assert_equal ausente.id, resultado.linhas.first.card_variant_id
      assert_equal 2, resultado.linhas.first.quantidade_depois
    end

    # `last_seen_at` nunca preenchido (variante que nenhuma ingestão remarcou)
    # também importa: `NULL` não é sentinela de inválido.
    test "variante com last_seen_at nulo continua importável" do
      user = create_user(email: "sem-marca@example.com")
      variante = create_variant(suffix: "a3")
      variante.update!(last_seen_at: nil)

      item = resolver(user, [ linha(variante, quantidade: 1) ]).linhas.sole

      assert_predicate item, :aceita?
      assert_equal variante.id, item.card_variant_id
    end

    # --- Isolamento entre usuários (Req. 6.5) -----------------------------

    # O "antes" sai da coleção de **quem está importando**. A posse de outro
    # usuário sobre a mesma variante não pode aparecer como valor anterior —
    # seria vazamento de dado alheio na pré-visualização, além de classificação
    # errada.
    test "o valor anterior vem da coleção do próprio usuário, não da de outro" do
      importador = create_user(email: "importador@example.com")
      outro = create_user(email: "outro-usuario@example.com")
      variante = create_variant(suffix: "u1")
      own(outro, variante, 8)

      item = resolver(importador, [ linha(variante, quantidade: 1) ]).linhas.sole

      assert_equal :cria, item.classificacao
      assert_nil item.quantidade_antes
    end

    # Req. 6.5 por construção: o serviço recebe o **objeto** `User`. Um id
    # vindo do request não chega a virar consulta — `for_user` levanta.
    test "recebe o objeto User e recusa um id" do
      user = create_user(email: "objeto@example.com")
      variante = create_variant(suffix: "o1")

      assert_raises(ArgumentError) { resolver(user.id, [ linha(variante) ]) }
    end

    # --- Custo (POR-13) ---------------------------------------------------

    # Done when: a resolução **não emite uma consulta por linha**, medido.
    #
    # Dois cenários de tamanhos diferentes e a igualdade afirmada, em vez de um
    # número absoluto: um resolvedor N+1 passa num teste que mede uma vez só.
    test "o número de consultas não cresce com o número de linhas" do
      user = create_user(email: "custo@example.com")
      variantes = (1..12).map { |n| create_variant(suffix: "k#{n}") }
      variantes.first(6).each { |v| own(user, v, 1) }

      poucas = variantes.first(2).map { |v| linha(v, quantidade: 2) }
      muitas = variantes.map { |v| linha(v, quantidade: 2) }

      custo_poucas = count_queries { resolver(user, poucas) }
      custo_muitas = count_queries { resolver(user, muitas) }

      assert_equal custo_poucas, custo_muitas,
        "o custo cresceu de #{custo_poucas} para #{custo_muitas} consultas ao passar " \
        "de #{poucas.size} para #{muitas.size} linhas — há consulta por linha"
      assert_operator custo_muitas, :<=, 4,
        "a resolução do lote inteiro deve caber em poucas consultas"
    end

    # Um lote sem nenhuma linha não vai ao banco: não há par a resolver.
    test "lote vazio devolve resultado vazio" do
      user = create_user(email: "vazio@example.com")

      resultado = resolver(user, [])

      assert_empty resultado.linhas
    end

    # --- A invariante da feature (Req. 10.5) ------------------------------

    # Done when: **nenhum caminho deste serviço escreve no banco** — provado
    # com `assert_no_changes`.
    #
    # Esta é a invariante da feature no ponto onde ela poderia começar a ser
    # violada: a coleção é o único dado insubstituível do sistema — o catálogo
    # é regenerável (AD-001). O resolvedor diz **o que aconteceria**; quem
    # grava é a T14, depois da confirmação explícita do usuário. Um resolvedor
    # que gravasse estaria errado mesmo com todos os outros testes verdes.
    test "nenhum caminho do resolvedor altera a coleção" do
      user = create_user(email: "invariante@example.com")
      possuida = create_variant(suffix: "w1")
      nova = create_variant(suffix: "w2", card_name: "Usopp")
      item = own(user, possuida, 5)

      lotes = [
        [ linha(possuida, quantidade: 99) ],
        [ linha(possuida, quantidade: 0) ],
        [ linha(nova, quantidade: 3) ],
        [ linha(nova, quantidade: 1), linha(nova, quantidade: 2) ],
        [ linha("OP97-997", "OP97-997") ],
        [ linha(possuida, quantidade: "-1") ],
        [ linha(possuida, quantidade: "texto") ],
        []
      ]

      assert_no_changes -> { CollectionItem.count } do
        assert_no_changes -> { item.reload.quantity } do
          assert_no_changes -> { CardVariant.count } do
            lotes.each { |lote| resolver(user, lote) }
          end
        end
      end
    end

    private

    # `assert_queries_count` afirma um número fixo; aqui o que interessa é
    # comparar dois cenários, então o mesmo instrumento do Active Record é
    # usado para **contar**. Mesmo padrão do `export_test.rb` (T5).
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
