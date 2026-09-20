require "test_helper"

# T11 abre a metade de import pela tabela que a sustenta: o staging que guarda
# a pré-visualização entre o upload (T12) e a confirmação (T14), decidido em
# AD-007.
#
# Os testes de constraint vão ao banco por **SQL direto**, no padrão de
# `collection_item_test.rb` e `wishlist_item_test.rb`, porque a afirmação que
# interessa não é "o Active Record valida" — é "o banco recusa". A pergunta
# central da task é a última deste arquivo: **apagar uma pré-visualização não
# pode tocar na coleção**. O staging é descartável; a coleção não (design.md
# §5.2), e uma cascata mal colocada inverteria essa relação em silêncio.
class CollectionImportTest < ActiveSupport::TestCase
  def connection
    ActiveRecord::Base.connection
  end

  # `select_value` passa pelo cache de consulta do Active Record: repetir o
  # mesmo INSERT literal devolveria o resultado memoizado sem ir ao banco, e o
  # teste de constraint nunca veria a violação. Mesma razão de
  # `collection_item_test.rb`.
  def insert_returning_id(sql)
    connection.uncached { connection.select_value(sql) }
  end

  def create_user(email:)
    User.create!(email: email, password: "senha-correta")
  end

  # Cada teste cria os seus registros: o projeto não usa fixtures YAML e a
  # suíte roda em paralelo, então códigos precisam ser únicos por teste.
  def create_variant(suffix:)
    set = CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: "OP01-#{suffix}",
      rarity: "L", art_kind: "base")
  end

  def linha(indice: 0, classificacao: :cria, card_variant_id: 1)
    {
      "indice" => indice,
      "card_number" => "OP01-001",
      "variant_code" => "OP01-001",
      "card_name" => "Roronoa Zoro",
      "quantidade_bruta" => "2",
      "card_variant_id" => card_variant_id,
      "classificacao" => classificacao.to_s,
      "quantidade_antes" => nil,
      "quantidade_depois" => 2,
      "motivo" => nil,
      "mensagem" => nil
    }
  end

  def create_import(user:, **attrs)
    CollectionImport.create!({
      user: user,
      filename: "colecao.csv",
      linhas: [ linha ],
      expires_at: 1.hour.from_now
    }.merge(attrs))
  end

  # --- Schema: o campo de expiração e o dono ------------------------------

  # Done when: a tabela tem `user_id` com FK sem cascata para a coleção e um
  # campo de expiração. Este teste fixa a presença das duas colunas no banco;
  # o comportamento de cada uma está nos testes seguintes.
  test "a tabela tem dono e expiração declarados como NOT NULL no banco" do
    obrigatorias = connection.select_rows(<<~SQL).to_h
      SELECT column_name, is_nullable
      FROM information_schema.columns
      WHERE table_name = 'collection_imports'
        AND column_name IN ('user_id', 'expires_at')
    SQL

    assert_equal({ "user_id" => "NO", "expires_at" => "NO" }, obrigatorias)
  end

  test "um registro sem expiração é recusado pelo banco" do
    user = create_user(email: "sem-expiracao@example.com")

    error = assert_raises(ActiveRecord::NotNullViolation) do
      connection.uncached do
        connection.execute(<<~SQL)
          INSERT INTO collection_imports (user_id, filename, linhas, token, created_at, updated_at)
          VALUES (#{user.id}, 'x.csv', '[]'::jsonb, 'token-sem-prazo', now(), now())
        SQL
      end
    end
    assert_match(/expires_at/, error.message)
  end

  # --- Constraints provadas contra o banco --------------------------------

  # Done when: as constraints são provadas contra o banco por SQL direto, não
  # só por validação de model.
  #
  # O estado é a máquina inteira do staging: quem confirmou não confirma de
  # novo (Edge Case: "duas confirmações da mesma pré-visualização"). Um valor
  # fora da lista significaria um registro que nenhuma parte do código sabe
  # tratar, e o `CHECK` impede que um `UPDATE` direto o crie.
  test "um estado fora da lista é recusado pelo banco" do
    user = create_user(email: "estado-invalido@example.com")

    error = assert_raises(ActiveRecord::StatementInvalid) do
      connection.uncached do
        connection.execute(<<~SQL)
          INSERT INTO collection_imports (user_id, filename, linhas, token, status, expires_at, created_at, updated_at)
          VALUES (#{user.id}, 'x.csv', '[]'::jsonb, 'token-estado', 'inventado',
                  now() + interval '1 hour', now(), now())
        SQL
      end
    end
    assert_match(/collection_imports_status_check/, error.message)
  end

  test "o estado de um registro existente não pode ser trocado por um inválido" do
    import = create_import(user: create_user(email: "estado-update@example.com"))

    error = assert_raises(ActiveRecord::StatementInvalid) do
      connection.uncached do
        connection.execute("UPDATE collection_imports SET status = 'qualquer' WHERE id = #{import.id}")
      end
    end
    assert_match(/collection_imports_status_check/, error.message)
  end

  # O token é o que a T12 devolve e a T14 recebe. Dois registros com o mesmo
  # token fariam a confirmação escolher entre duas pré-visualizações — e uma
  # delas poderia ser de outro usuário. A unicidade é do banco, não do
  # `SecureRandom`: colisão de `SecureRandom` é improvável, não impossível, e
  # o índice transforma o improvável em erro em vez de em confusão silenciosa.
  test "o token é único no banco" do
    primeiro = create_import(user: create_user(email: "token-1@example.com"))
    segundo_user = create_user(email: "token-2@example.com")

    error = assert_raises(ActiveRecord::RecordNotUnique) do
      insert_returning_id(<<~SQL)
        INSERT INTO collection_imports (user_id, filename, linhas, token, status, expires_at, created_at, updated_at)
        VALUES (#{segundo_user.id}, 'x.csv', '[]'::jsonb, '#{primeiro.token}', 'pendente',
                now() + interval '1 hour', now(), now())
        RETURNING id
      SQL
    end
    assert_match(/index_collection_imports_on_token/, error.message)
  end

  # Achado da revisão de banco desta task: `t.references` cria um índice de
  # `(user_id)` sozinho, que é **prefixo estrito** do composto `(user_id,
  # token)` — o Postgres serve qualquer busca por dono a partir do composto.
  # Dois índices onde um basta custam escrita em todo INSERT sem atender
  # nenhuma consulta que o outro não atenda. Este teste fixa o conjunto para
  # que o índice redundante não volte por hábito num `t.references` futuro.
  test "a tabela não tem índice redundante sobre user_id sozinho" do
    indices = connection.select_values(<<~SQL)
      SELECT indexname FROM pg_indexes WHERE tablename = 'collection_imports'
    SQL

    assert_equal %w[
      collection_imports_pkey
      index_collection_imports_on_expires_at
      index_collection_imports_on_token
      index_collection_imports_on_user_id_and_token
    ], indices.sort
  end

  # --- As FKs e a invariante da feature -----------------------------------

  # Done when: teste prova que **nenhuma FK desta tabela cascateia para
  # `collection_items`** — apagar uma pré-visualização não pode tocar na
  # coleção.
  #
  # A forma mais direta de provar: a tabela **não referencia**
  # `collection_items` nem `card_variants`. Sem aresta não há cascata
  # possível, e nenhuma FK futura pode aparecer sem este teste ficar vermelho.
  # A ligação com a coleção é o `card_variant_id` **dentro do jsonb**, que não
  # é FK justamente por isso: a T14 o resolve no momento da escrita, e um
  # ponteiro solto num documento não arrasta nada por efeito colateral.
  test "a tabela não tem foreign key para collection_items nem para card_variants" do
    referenciadas = connection.select_values(<<~SQL)
      SELECT confrelid::regclass::text
      FROM pg_constraint
      WHERE contype = 'f'
        AND conrelid::regclass::text = 'collection_imports'
    SQL

    assert_equal [ "users" ], referenciadas.sort
  end

  test "nenhuma foreign key de collection_imports usa delete em cascata" do
    cascading = connection.select_values(<<~SQL)
      SELECT conname
      FROM pg_constraint
      WHERE contype = 'f'
        AND confdeltype <> 'r'
        AND conrelid::regclass::text = 'collection_imports'
    SQL

    assert_empty cascading,
                 "FK de collection_imports sem ON DELETE RESTRICT: #{cascading.join(', ')}"
  end

  # A prova pelo comportamento, e não só pelo catálogo do Postgres: apagar a
  # pré-visualização deixa a coleção exatamente como estava. É a invariante da
  # feature reduzida a uma asserção.
  test "apagar uma pré-visualização não altera a coleção do usuário" do
    user = create_user(email: "destroy-preserva@example.com")
    variant = create_variant(suffix: "d1")
    item = CollectionItem.create!(user: user, card_variant: variant, quantity: 3)
    import = create_import(user: user, linhas: [ linha(card_variant_id: variant.id) ])

    assert_no_changes -> { [ CollectionItem.count, item.reload.quantity ] } do
      import.destroy!
    end
  end

  # `dependent: :destroy` no staging, ao contrário do
  # `restrict_with_exception` de `collection_items`: a assimetria é
  # deliberada. O staging é derivado e descartável — reenviar o arquivo o
  # reconstrói —, então encerrar a conta o encerra junto, como acontece com
  # `sessions`. A coleção continua barrando o delete, e é ela que precisa
  # barrar.
  test "apagar o usuário leva o staging junto mas continua barrado pela coleção" do
    user = create_user(email: "delete-user@example.com")
    import = create_import(user: user)

    item = CollectionItem.create!(user: user, card_variant: create_variant(suffix: "d2"), quantity: 1)
    assert_raises(ActiveRecord::DeleteRestrictionError) { user.destroy! }
    assert CollectionImport.exists?(import.id), "o staging não pode sumir num destroy que foi barrado"

    item.destroy!
    user.destroy!
    assert_not CollectionImport.exists?(import.id)
  end

  # --- Autorização: o contrato de `for_user` ------------------------------

  # Done when: `for_user` com o mesmo contrato de `CollectionItem.for_user`.
  test "for_user devolve apenas as pré-visualizações do usuário informado" do
    dono = create_user(email: "dono-import@example.com")
    outro = create_user(email: "outro-import@example.com")
    meu = create_import(user: dono)
    create_import(user: outro)

    assert_equal [ meu.id ], CollectionImport.for_user(dono).pluck(:id)
  end

  test "for_user com nil devolve relação vazia sem levantar erro" do
    create_import(user: create_user(email: "anon-import@example.com"))

    assert_empty CollectionImport.for_user(nil)
  end

  # O ponto do tipo exigido, idêntico ao de `CollectionItem.for_user`: um id
  # vindo do request não pode virar consulta silenciosamente.
  # `for_user(params[:user_id])` tem de explodir, não devolver o staging de
  # outra pessoa.
  test "for_user recusa um id no lugar do objeto User" do
    user = create_user(email: "id-recusado-import@example.com")

    assert_raises(ArgumentError) { CollectionImport.for_user(user.id) }
    assert_raises(ArgumentError) { CollectionImport.for_user(user.id.to_s) }
  end

  # --- Isolamento entre usuários ------------------------------------------

  # Done when: teste prova que uma pré-visualização de outro usuário **não é
  # legível** por este, e que a tentativa **não revela a existência dela**.
  #
  # As duas metades são distintas e as duas importam. Não ser legível é
  # autorização; não revelar a existência é não distinguir "existe e não é sua"
  # de "não existe" — a diferença entre `403` e `404` vaza a existência de um
  # token por resposta, e o token é o que a T14 aceita.
  test "a pré-visualização de outro usuário não é legível pelo token" do
    dono = create_user(email: "isolamento-dono@example.com")
    intruso = create_user(email: "isolamento-intruso@example.com")
    alheia = create_import(user: dono)

    assert_nil CollectionImport.find_by_token_for(intruso, alheia.token)
    assert_equal alheia.id, CollectionImport.find_by_token_for(dono, alheia.token).id
  end

  test "buscar o token alheio é indistinguível de buscar um token inexistente" do
    dono = create_user(email: "indistinguivel-dono@example.com")
    intruso = create_user(email: "indistinguivel-intruso@example.com")
    alheia = create_import(user: dono)

    alheio = CollectionImport.find_by_token_for(intruso, alheia.token)
    inexistente = CollectionImport.find_by_token_for(intruso, "token-que-nunca-existiu")

    assert_nil alheio
    assert_nil inexistente
    assert_equal inexistente.inspect, alheio.inspect,
                 "o token alheio e o inexistente precisam produzir o mesmo resultado"
  end

  test "o token de outro usuário não é confirmável" do
    dono = create_user(email: "confirmavel-dono@example.com")
    intruso = create_user(email: "confirmavel-intruso@example.com")
    alheia = create_import(user: dono)

    assert_not CollectionImport.for_user(intruso).exists?(alheia.id)
    assert alheia.reload.confirmavel?, "a pré-visualização continua válida para o dono"
  end

  # --- Expiração -----------------------------------------------------------

  # Done when: teste prova que registro expirado não é confirmável.
  test "uma pré-visualização expirada não é confirmável" do
    import = create_import(user: create_user(email: "expirada@example.com"),
      expires_at: 1.second.ago)

    assert import.expirada?
    assert_not import.confirmavel?
  end

  test "uma pré-visualização dentro do prazo e pendente é confirmável" do
    import = create_import(user: create_user(email: "vigente@example.com"))

    assert_not import.expirada?
    assert import.confirmavel?
  end

  # A confirmação é única: o Edge Case da spec diz que duas confirmações da
  # mesma pré-visualização não podem duplicar o efeito. A T14 usa isto; aqui
  # fica fixado que confirmar tira o registro do estado confirmável.
  test "uma pré-visualização já confirmada não é confirmável de novo" do
    import = create_import(user: create_user(email: "ja-confirmada@example.com"))

    assert import.confirmavel?
    import.update!(status: "confirmado")
    assert_not import.confirmavel?
  end

  test "o escopo vigente exclui as expiradas e o expiradas traz só elas" do
    user = create_user(email: "escopos@example.com")
    vigente = create_import(user: user, expires_at: 1.hour.from_now)
    expirada = create_import(user: user, expires_at: 1.minute.ago)

    assert_equal [ vigente.id ], CollectionImport.for_user(user).vigentes.pluck(:id)
    assert_equal [ expirada.id ], CollectionImport.for_user(user).expiradas.pluck(:id)
  end

  # Done when: existe caminho de limpeza dos registros expirados, com teste.
  test "a limpeza apaga as expiradas de todos os usuários e preserva as vigentes" do
    um = create_user(email: "limpeza-um@example.com")
    outro = create_user(email: "limpeza-outro@example.com")
    expirada_de_um = create_import(user: um, expires_at: 2.hours.ago)
    expirada_de_outro = create_import(user: outro, expires_at: 1.minute.ago)
    vigente = create_import(user: um, expires_at: 1.hour.from_now)

    assert_equal 2, CollectionImport.limpar_expiradas

    assert_not CollectionImport.exists?(expirada_de_um.id)
    assert_not CollectionImport.exists?(expirada_de_outro.id)
    assert CollectionImport.exists?(vigente.id)
  end

  # A limpeza é varredura global — não parte de `Current.user`, e é a única
  # consulta desta tabela que não parte. É legítimo porque ela **não lê** dado
  # de ninguém: apaga por prazo e devolve uma contagem. Este teste existe para
  # que a exceção continue sendo só essa.
  test "a limpeza não toca na coleção de ninguém" do
    user = create_user(email: "limpeza-colecao@example.com")
    item = CollectionItem.create!(user: user, card_variant: create_variant(suffix: "l1"), quantity: 7)
    create_import(user: user, expires_at: 1.hour.ago)

    assert_no_changes -> { [ CollectionItem.count, item.reload.quantity ] } do
      CollectionImport.limpar_expiradas
    end
  end

  # --- O que a tabela guarda ----------------------------------------------

  # A confirmação (T14) grava **o que a pré-visualização mostrou**, sem
  # reparsear (Req. 10.5 / AD-007). Isso só vale se as linhas voltarem do banco
  # idênticas às que entraram — inclusive `nil` distinto de zero, que é a
  # diferença entre `:cria` e `:atualiza` no resolvedor.
  test "as linhas voltam do jsonb com os mesmos valores que entraram" do
    user = create_user(email: "roundtrip@example.com")
    variant = create_variant(suffix: "r1")
    original = [
      linha(indice: 0, classificacao: :cria, card_variant_id: variant.id),
      linha(indice: 1, classificacao: :atualiza, card_variant_id: variant.id)
        .merge("quantidade_antes" => 0, "quantidade_depois" => 5)
    ]
    import = create_import(user: user, linhas: original)

    assert_equal original, import.reload.linhas
    assert_nil import.linhas.first["quantidade_antes"],
               "nil não pode virar zero: é o que distingue :cria de :atualiza"
  end

  # `linhas_resolvidas` devolve o que a T13 renderiza e a T14 grava, no mesmo
  # tipo que o resolvedor produziu — quem consome não precisa saber que o meio
  # de transporte foi jsonb, nem lembrar que as chaves viraram string.
  test "linhas_resolvidas reconstrói os Struct do resolvedor" do
    user = create_user(email: "resolvidas@example.com")
    variant = create_variant(suffix: "r2")
    import = create_import(user: user,
      linhas: [ linha(indice: 3, classificacao: :zera, card_variant_id: variant.id) ])

    resolvida = import.linhas_resolvidas.sole

    assert_instance_of CollectionCsv::Resolver::Linha, resolvida
    assert_equal 3, resolvida.indice
    assert_equal :zera, resolvida.classificacao, "a classificação volta como símbolo, não como texto"
    assert_equal variant.id, resolvida.card_variant_id
    assert resolvida.aceita?
  end

  test "linhas_resolvidas devolve a rejeição com motivo como símbolo" do
    user = create_user(email: "resolvidas-rejeita@example.com")
    rejeitada = linha(classificacao: :rejeita, card_variant_id: nil)
      .merge("motivo" => "variante_inexistente",
             "mensagem" => CollectionCsv::Resolver::MENSAGENS[:variante_inexistente])
    import = create_import(user: user, linhas: [ rejeitada ])

    resolvida = import.linhas_resolvidas.sole

    assert resolvida.rejeitada?
    assert_equal :variante_inexistente, resolvida.motivo
    assert_equal CollectionCsv::Resolver::MENSAGENS[:variante_inexistente], resolvida.mensagem
  end

  # O caminho de ida: guardar o resultado do resolvedor sem que o chamador
  # precise converter Struct em Hash à mão. É o que a T12 chama.
  test "linhas aceita os Struct do resolvedor e os persiste" do
    user = create_user(email: "de-resolver@example.com")
    variant = create_variant(suffix: "r3")
    resultado = CollectionCsv::Resolver::Linha.new(indice: 0, card_number: "OP01-r3",
      variant_code: "OP01-r3", card_name: "Roronoa Zoro", quantidade_bruta: "2",
      card_variant_id: variant.id, classificacao: :cria, quantidade_depois: 2)

    import = CollectionImport.create!(user: user, filename: "c.csv", linhas: [ resultado ],
      expires_at: 1.hour.from_now)

    assert_equal :cria, import.reload.linhas_resolvidas.sole.classificacao
  end

  # --- Defaults ------------------------------------------------------------

  test "uma pré-visualização nasce pendente e com token gerado" do
    import = CollectionImport.create!(user: create_user(email: "defaults@example.com"),
      filename: "colecao.csv", linhas: [], expires_at: 1.hour.from_now)

    assert_equal "pendente", import.status
    assert_predicate import.token, :present?
    assert_operator import.token.length, :>=, 24, "o token precisa ser impraticável de adivinhar"
  end

  test "dois registros criados pelo app recebem tokens diferentes" do
    user = create_user(email: "dois-tokens@example.com")

    assert_not_equal create_import(user: user).token, create_import(user: user).token
  end

  # A expiração tem default de aplicação para que nenhum chamador possa criar
  # um staging sem prazo por esquecimento — o `NOT NULL` recusaria, mas a
  # recusa viraria erro 500 em vez de um prazo razoável.
  test "sem prazo informado a expiração recebe o default da aplicação" do
    import = CollectionImport.create!(user: create_user(email: "default-prazo@example.com"),
      filename: "colecao.csv", linhas: [])

    assert_in_delta CollectionImport::VALIDADE.from_now.to_f, import.expires_at.to_f, 5
  end
end
