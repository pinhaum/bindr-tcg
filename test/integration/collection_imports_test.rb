require "test_helper"

# T12 — upload do CSV de import: produz a pré-visualização e **nada mais**
# (POR-07, POR-12 / Req. 10.5, 6.4, 6.5).
#
# ## O que este arquivo existe para provar
#
# A invariante da feature inteira: **nenhuma escrita na coleção sem confirmação
# explícita do usuário**. A coleção é o único dado insubstituível do sistema —
# o catálogo é regenerável (AD-001) —, e o upload é o momento em que o sistema
# tem em mãos um arquivo que descreve mudanças nela. Ele precisa gravar a
# pré-visualização e **absolutamente mais nada**. Quem grava é a T14, depois da
# confirmação.
#
# Por isso o teste central não usa arquivo vazio nem arquivo só de rejeições:
# ele usa um arquivo que, **se aplicado, criaria registro novo, alteraria a
# quantidade de um registro existente e zeraria outro**. Um upload que escreva
# tem o que escrever, e é essa a única forma de a asserção discriminar.
#
# ## SPEC_DEVIATION — teste de integração no lugar de system test
#
# Não há navegador no container (registrado desde a `colecao`), então a
# verificação de UI é feita sobre o HTML renderizado e sobre a resposta HTTP,
# não por interação real. O recorte aqui é de **fluxo**: parser e resolvedor já
# estão provados por unidade em `test/services/collection_csv/`.
#
# ## O cenário é construído para discriminar
#
# Os dois usuários têm posses sobre **as mesmas** variantes, com quantidades
# diferentes. É o oposto do `collection_exports_test`, e de propósito: aqui o
# risco não é entregar a linha do outro, é **escrever** na coleção do outro. Com
# variantes disjuntas, uma escrita no dono errado falharia por variante
# inexistente e passaria por "não escreveu". Com as mesmas variantes, qualquer
# escrita no usuário errado é visível.
class CollectionImportsTest < ActionDispatch::IntegrationTest
  PASSWORD = "grand-line-12".freeze

  setup do
    @nami = User.create!(email: "nami-por12@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-por12@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OPp12", name: "Romance Dawn", kind: "booster",
                           base_set_size: 4, total_set_size: 4)

    @existente = variant("p12a", "Bell-mère")
    @zerada = variant("p12b", "Nefertari Vivi")
    @nova = variant("p12c", "Roronoa Zoro")

    # O "antes" de cada usuário. `@nova` fica deliberadamente sem registro para
    # @nami: é a linha que classificaria `:cria`.
    @item_existente = own(@nami, @existente, 2)
    @item_zerada = own(@nami, @zerada, 5)
    own(@zoro, @existente, 9)
    own(@zoro, @zerada, 9)
    own(@zoro, @nova, 9)
  end

  def variant(suffix, card_name)
    card = Card.create!(card_set: @set, card_number: "OP12-#{suffix}", name: card_name,
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: @set, variant_code: suffix,
                        rarity: "C", art_kind: "base")
  end

  def own(user, card_variant, quantity)
    CollectionItem.create!(user: user, card_variant: card_variant, quantity: quantity)
  end

  def sign_in(user = @nami)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # O arquivo que **mudaria** a coleção de @nami em três direções diferentes:
  # cria `@nova`, troca 2 por 7 em `@existente` e zera `@zerada`. Se o upload
  # escrevesse, este é o arquivo que deixaria rastro.
  def csv_que_mudaria_tudo
    linhas = [
      CollectionCsv::Format.header_row.join(","),
      "#{@nova.card.card_number},#{@nova.variant_code},#{@nova.card.name},4",
      "#{@existente.card.card_number},#{@existente.variant_code},#{@existente.card.name},7",
      "#{@zerada.card.card_number},#{@zerada.variant_code},#{@zerada.card.name},0"
    ]
    linhas.join("\n") + "\n"
  end

  def upload(conteudo, filename: "colecao.csv")
    Rack::Test::UploadedFile.new(
      StringIO.new(conteudo), "text/csv", original_filename: filename
    )
  end

  def post_arquivo(conteudo, filename: "colecao.csv", **extras)
    post collection_imports_path,
         params: { arquivo: upload(conteudo, filename: filename) }.merge(extras)
  end

  # O retrato completo da tabela de coleção. Comparar o retrato inteiro, e não
  # só a contagem, é o que pega a escrita que troca uma quantidade sem mudar o
  # número de linhas.
  def retrato_da_colecao
    CollectionItem.order(:id).pluck(:id, :user_id, :card_variant_id, :quantity)
  end

  # --- Sessão exigida: o anônimo não importa nada ---

  # A prova central de POR-12. O default de `ApplicationController` roda o
  # `before_action :require_authentication` **antes** da action, então nem a
  # leitura do arquivo chega a acontecer. Um `allow_unauthenticated_access`
  # acrescentado ao controller mata este teste.
  test "anônimo que envia arquivo é redirecionado e não grava nada" do
    antes = retrato_da_colecao

    assert_no_difference [ -> { CollectionItem.count }, -> { CollectionImport.count } ] do
      post_arquivo(csv_que_mudaria_tudo)
    end

    assert_redirected_to new_session_path
    assert_equal antes, retrato_da_colecao,
                 "o anônimo não pode tocar na coleção de ninguém"
  end

  test "anônimo não alcança o formulário de import" do
    get new_collection_import_path

    assert_redirected_to new_session_path
  end

  test "anônimo não alcança a pré-visualização de outra pessoa" do
    sign_in(@nami)
    post_arquivo(csv_que_mudaria_tudo)
    token = CollectionImport.for_user(@nami).last.token
    delete session_path

    get collection_import_path(token)

    assert_redirected_to new_session_path
    assert_not_includes response.body, token
  end

  # --- A invariante: o upload não altera a coleção ---

  # **O teste mais importante do arquivo.** O arquivo classificaria uma criação,
  # uma atualização e um zeramento; nada disso pode chegar a `collection_items`.
  test "enviar o arquivo não altera a coleção" do
    sign_in(@nami)

    assert_no_changes -> { @item_existente.reload.quantity } do
      assert_no_changes -> { @item_zerada.reload.quantity } do
        assert_no_changes -> { CollectionItem.count } do
          post_arquivo(csv_que_mudaria_tudo)
        end
      end
    end
  end

  # A asserção irmã da anterior, e o que ela não cobre: nem a linha de outro
  # usuário sobre as mesmas variantes pode se mexer, e nenhuma coluna de
  # nenhuma linha pode mudar.
  test "o upload deixa a tabela de coleção byte a byte como estava" do
    sign_in(@nami)
    antes = retrato_da_colecao

    post_arquivo(csv_que_mudaria_tudo)

    assert_equal antes, retrato_da_colecao,
                 "o upload é pré-visualização: nenhuma linha de coleção pode mudar"
  end

  # A prova do efeito **positivo**: a invariante é "não escreveu na coleção",
  # não "não fez nada". Sem esta asserção, um controller que ignorasse o
  # arquivo passaria em todas as anteriores.
  test "o upload cria a pré-visualização com as linhas classificadas" do
    sign_in(@nami)

    assert_difference -> { CollectionImport.count }, 1 do
      post_arquivo(csv_que_mudaria_tudo)
    end

    preview = CollectionImport.for_user(@nami).last
    classificacoes = preview.linhas_resolvidas.map(&:classificacao)

    assert_equal %i[cria atualiza zera], classificacoes,
                 "a pré-visualização guarda o que aconteceria, na ordem do arquivo"
    assert_equal "pendente", preview.status
    assert_not preview.expirada?
  end

  # O antes e o depois viajam guardados, e é o que a T13 vai mostrar e a T14
  # vai gravar. Guardar só a classificação faria a confirmação ter que reler o
  # arquivo — que é exatamente o que AD-007 evita.
  test "a pré-visualização guarda o antes e o depois de cada linha" do
    sign_in(@nami)

    post_arquivo(csv_que_mudaria_tudo)

    linhas = CollectionImport.for_user(@nami).last.linhas_resolvidas.index_by(&:card_variant_id)

    assert_nil linhas[@nova.id].quantidade_antes
    assert_equal 4, linhas[@nova.id].quantidade_depois
    assert_equal 2, linhas[@existente.id].quantidade_antes
    assert_equal 7, linhas[@existente.id].quantidade_depois
    assert_equal 5, linhas[@zerada.id].quantidade_antes
    assert_equal 0, linhas[@zerada.id].quantidade_depois
  end

  # Uma linha rejeitada pelo resolvedor chega à pré-visualização como rejeição,
  # em vez de abortar o lote (POR-06). Ela também não pode virar escrita.
  test "linha com variante inexistente vira rejeição na pré-visualização, sem escrita" do
    sign_in(@nami)
    conteudo = [
      CollectionCsv::Format.header_row.join(","),
      "OP12-inexistente,zzz,Carta Fantasma,3",
      "#{@existente.card.card_number},#{@existente.variant_code},#{@existente.card.name},7"
    ].join("\n") + "\n"
    antes = retrato_da_colecao

    post_arquivo(conteudo)

    linhas = CollectionImport.for_user(@nami).last.linhas_resolvidas

    assert_equal %i[rejeita atualiza], linhas.map(&:classificacao)
    assert_equal :variante_inexistente, linhas.first.motivo
    assert_equal antes, retrato_da_colecao
  end

  # --- Dono da pré-visualização: sai da sessão, nunca do request ---

  test "a pré-visualização criada pertence ao usuário da sessão" do
    sign_in(@nami)

    post_arquivo(csv_que_mudaria_tudo)

    assert_equal [ @nami.id ], CollectionImport.pluck(:user_id).uniq
  end

  # `?user_id=` do outro usuário não pode deslocar o dono. A consulta parte de
  # `Current.user`, então o parâmetro não tem por onde entrar (Req. 6.5).
  test "?user_id= de outro usuário não muda o dono da pré-visualização" do
    sign_in(@nami)

    post_arquivo(csv_que_mudaria_tudo, user_id: @zoro.id)

    assert_equal [ @nami.id ], CollectionImport.pluck(:user_id).uniq,
                 "o dono é o da sessão, não o do parâmetro"
    assert_empty CollectionImport.for_user(@zoro)
  end

  # As outras portas pelas quais alguém tentaria informar um usuário. Nenhuma
  # pode deslocar o dono, e nenhuma pode quebrar a resposta: parâmetro
  # desconhecido é ignorado, nunca causa erro (design.md §4.2).
  test "nenhuma forma de informar identificador desloca o dono" do
    sign_in(@nami)

    tentativas = [
      { user_id: @zoro.id },
      { user: @zoro.id },
      { id: @zoro.id },
      { user_id: @zoro.email },
      { user_id: [ @nami.id, @zoro.id ] },
      { user_id: { id: @zoro.id } },
      { collection_import: { user_id: @zoro.id } }
    ]

    tentativas.each do |extras|
      post_arquivo(csv_que_mudaria_tudo, **extras)

      assert_response :redirect, "#{extras.inspect} não pode quebrar a resposta"
      assert_equal [ @nami.id ], CollectionImport.pluck(:user_id).uniq,
                   "#{extras.inspect} deslocou o dono da pré-visualização"
    end
  end

  # Header em vez de parâmetro: mesma porta, roupa diferente.
  test "header de identificação de usuário não desloca o dono" do
    sign_in(@nami)

    post collection_imports_path,
         params: { arquivo: upload(csv_que_mudaria_tudo) },
         headers: { "X-User-Id" => @zoro.id.to_s }

    assert_equal [ @nami.id ], CollectionImport.pluck(:user_id).uniq
  end

  # --- Arquivo recusado pelo parser: nenhum staging, mensagem em português ---

  # Os três motivos de recusa do `Parser` (T8), cada um com a sua mensagem. A
  # asserção é sobre **conteúdo** da mensagem, não sobre a existência de uma
  # mensagem qualquer: o usuário precisa saber o que fazer com o arquivo dele.
  test "arquivo com cabeçalho errado não cria staging e explica o problema" do
    sign_in(@nami)

    assert_no_difference -> { CollectionImport.count } do
      post_arquivo("coluna_a,coluna_b\n1,2\n")
    end

    assert_response :unprocessable_entity
    assert_match(/não tem as colunas esperadas/i, response.body)
    assert_match(/card_number/, response.body)
  end

  test "arquivo separado por ponto e vírgula não cria staging e diz o delimitador" do
    sign_in(@nami)
    conteudo = [
      CollectionCsv::Format.header_row.join(";"),
      "#{@existente.card.card_number};#{@existente.variant_code};#{@existente.card.name};7"
    ].join("\n") + "\n"

    assert_no_difference -> { CollectionImport.count } do
      post_arquivo(conteudo)
    end

    assert_response :unprocessable_entity
    assert_match(/separado por/i, response.body)
  end

  test "arquivo acima do teto de linhas não cria staging e diz o limite" do
    sign_in(@nami)
    linhas = [ CollectionCsv::Format.header_row.join(",") ]
    (CollectionCsv::Parser::MAX_LINHAS + 1).times do |i|
      linhas << "OP12-#{i},x,Carta #{i},1"
    end

    assert_no_difference -> { CollectionImport.count } do
      post_arquivo(linhas.join("\n") + "\n")
    end

    assert_response :unprocessable_entity
    assert_match(/10\.000 linhas/, response.body)
  end

  test "arquivo vazio não cria staging e explica em português" do
    sign_in(@nami)

    assert_no_difference -> { CollectionImport.count } do
      post_arquivo("")
    end

    assert_response :unprocessable_entity
    assert_match(/vazio/i, response.body)
  end

  # Regressão da T12: o arquivo do Rack chega em ASCII-8BIT, e entregá-lo cru
  # ao `Parser` estourava `Encoding::CompatibilityError` no `delete_prefix(BOM)`
  # — **antes** de o parser chegar à sua própria verificação de codificação. O
  # usuário que salvou a planilha em Latin-1 recebia 500 no lugar da frase em
  # português que a T8 escreveu justamente para ele.
  test "arquivo em Latin-1 não cria staging e explica a codificação em português" do
    sign_in(@nami)
    conteudo = (CollectionCsv::Format.header_row.join(",") + "\n" +
      "#{@existente.card.card_number},#{@existente.variant_code},Bell-mère,7\n")
      .encode("ISO-8859-1")

    assert_no_difference -> { CollectionImport.count } do
      post_arquivo(conteudo)
    end

    assert_response :unprocessable_entity
    assert_match(/UTF-8/, response.body)
  end

  # A requisição sem campo de arquivo nenhum não pode virar 500: entrada
  # malformada é caso esperado, não excepcional.
  test "requisição sem arquivo não cria staging e responde com mensagem" do
    sign_in(@nami)

    assert_no_difference -> { CollectionImport.count } do
      post collection_imports_path
    end

    assert_response :unprocessable_entity
    assert_match(/arquivo/i, response.body)
  end

  # O teto de bytes da borda: o corpo grande demais é recusado sem virar
  # staging e sem virar exceção crua.
  test "corpo acima do teto de bytes não cria staging" do
    sign_in(@nami)
    gigante = CollectionCsv::Format.header_row.join(",") + "\n" +
      ("OP12-a,x,#{"A" * 1000},1\n" * 9_000)

    assert_operator gigante.bytesize, :>, CollectionCsv::Parser::MAX_BYTES

    assert_no_difference [ -> { CollectionImport.count }, -> { CollectionItem.count } ] do
      post_arquivo(gigante)
    end

    assert_response :unprocessable_entity
  end

  # --- A resposta identifica a pré-visualização, e só o dono a alcança ---

  # O critério: a resposta tem que apontar para **esta** pré-visualização, de
  # forma que a T14 saiba qual confirmar. O apontador é o token — não o id do
  # registro, que seria adivinhável, e não o id do usuário, que não cabe na URL.
  test "a resposta aponta para a pré-visualização recém-criada pelo token" do
    sign_in(@nami)

    post_arquivo(csv_que_mudaria_tudo)

    preview = CollectionImport.for_user(@nami).last

    assert_redirected_to collection_import_path(preview.token)
    follow_redirect!
    assert_response :success
  end

  # O token é o que separa uma pré-visualização da outra, e ele não é
  # adivinhável: 32 bytes urlsafe (T11). Um id sequencial na URL deixaria a
  # confirmação alheia a uma tentativa de distância.
  test "o apontador da resposta não é o id sequencial do registro" do
    sign_in(@nami)

    post_arquivo(csv_que_mudaria_tudo)

    preview = CollectionImport.for_user(@nami).last

    assert_no_match(/\A#{Regexp.escape(collection_import_path(preview.id))}\z/,
                    response.headers["Location"].to_s.sub(%r{\Ahttps?://[^/]+}, ""))
    assert_operator preview.token.length, :>=, 32
  end

  # A prova de que **só o dono** confirma: o token do outro usuário não resolve
  # nem para ler. É `find_by_token_for` (T11) que garante isso, e a resposta
  # não distingue token alheio de token inexistente — nada de oráculo.
  test "o token de outro usuário não abre a pré-visualização" do
    sign_in(@nami)
    post_arquivo(csv_que_mudaria_tudo)
    token_da_nami = CollectionImport.for_user(@nami).last.token

    delete session_path
    sign_in(@zoro)

    get collection_import_path(token_da_nami)
    status_alheio = response.status
    corpo_alheio = response.body

    get collection_import_path("token-que-nunca-existiu")

    # A comparação é de **status** e não de corpo byte a byte: em teste
    # `show_exceptions` é `:rescuable`, e a página de depuração do Rails carrega
    # ids de objeto que mudam a cada requisição — comparar corpos aqui seria
    # comparar ruído, e o teste falharia por uma razão que não é a que ele
    # investiga. Em produção o corpo é a página 404 estática, igual para os dois.
    assert_equal status_alheio, response.status,
                 "token alheio e inexistente respondem igual: a tabela não é oráculo"
    assert_response :not_found

    # O que o corpo não pode ter, em nenhum dos dois casos: o arquivo, as
    # linhas ou qualquer sinal de que aquele token existe para outra pessoa.
    assert_not_includes corpo_alheio, @existente.card.name
    assert_not_includes corpo_alheio, @nova.variant_code
  end

  test "abrir a pré-visualização não grava nada na coleção" do
    sign_in(@nami)
    post_arquivo(csv_que_mudaria_tudo)
    token = CollectionImport.for_user(@nami).last.token
    antes = retrato_da_colecao

    get collection_import_path(token)

    assert_response :success
    assert_equal antes, retrato_da_colecao
  end

  # --- A rota não aceita identificador de usuário ---

  # O segmento dinâmico que a rota **tem** é o token da pré-visualização, que
  # não identifica usuário nenhum: ele é um segredo por upload, resolvido
  # sempre dentro do escopo de `Current.user` por `find_by_token_for`. Nenhum
  # outro segmento pode existir, e é isso que este teste fixa.
  test "nenhuma rota de import aceita segmento além do token" do
    rotas = Rails.application.routes.routes.select do |rota|
      rota.defaults[:controller].to_s.split("/").last == "collection_imports"
    end

    assert_not_empty rotas, "a T12 entrega as rotas de import; se sumiram, a suíte precisa saber"

    rotas.each do |rota|
      assert_empty rota.path.required_names - [ "token" ],
                   "#{rota.path.spec} aceita #{rota.path.required_names.inspect}: " \
                   "nenhum identificador de usuário pode caber na URL do import"
    end
  end

  # A porta complementar: uma URL com id de usuário não pode **resolver** para
  # o import por nenhum caminho.
  #
  # `/collection/import/<id>/confirm` **saiu desta lista na T14**, e a razão
  # precisa ficar escrita para que a remoção não pareça um teste enfraquecido
  # para passar no gate. Aquele caminho servia de exemplo de "URL com id" só
  # enquanto a forma não existia; a T14 declarou
  # `POST /collection/import/:token/confirm`, e o que ocupa o segmento não é um
  # id de usuário — é o **token** da pré-visualização, 32 bytes urlsafe gerados
  # pela T11, um segredo por upload que não identifica ninguém.
  #
  # A garantia que este teste protege continua inteira e é verificada acima,
  # pelo teste que percorre as rotas do controller e exige
  # `required_names - ["token"]` vazio: nenhuma rota do import aceita
  # identificador de usuário. A prova de que o token alheio não grava e não
  # revela a existência é da T14, em
  # `test/integration/collection_import_commit_test.rb` — autorização, que
  # roteamento não resolve.
  test "uma URL com id de usuário não resolve para o import" do
    caminhos = [
      "/users/#{@zoro.id}/collection/import",
      "/collection/#{@zoro.id}/import",
      "/collection/import/users/#{@zoro.id}"
    ]

    caminhos.each do |caminho|
      reconhecida = begin
        Rails.application.routes.recognize_path(caminho, method: :post)
      rescue ActionController::RoutingError
        nil
      end

      assert_not_equal "collection_imports", reconhecida&.dig(:controller),
                       "#{caminho} não pode chegar ao import"
    end
  end

  # --- CSRF e nome de arquivo ---

  # A revisão de segurança da T10 pediu explicitamente que o controller **não**
  # desabilite a verificação de CSRF. Um `skip_before_action` mata este teste.
  test "o controller de import não desabilita a verificação de CSRF" do
    callbacks = CollectionImportsController._process_action_callbacks.map(&:filter)

    assert_includes callbacks, :verify_authenticity_token,
                    "a verificação de CSRF não pode ser desabilitada neste controller"
  end

  # O `original_filename` é dado do cliente e é guardado como **dado**, para
  # exibição, nunca como caminho. Um nome com travessia de diretório não pode
  # sobreviver na coluna nem virar arquivo em disco.
  test "nome de arquivo hostil é guardado sanitizado e não vira caminho" do
    sign_in(@nami)

    post_arquivo(csv_que_mudaria_tudo, filename: "../../etc/passwd.csv")

    preview = CollectionImport.for_user(@nami).last

    assert_not_includes preview.filename, "/"
    assert_not_includes preview.filename, ".."
    assert_not_empty preview.filename
  end

  # --- O formulário de upload ---

  test "o formulário de upload é alcançável pelo autenticado, em português" do
    sign_in(@nami)

    get new_collection_import_path

    assert_response :success
    assert_select "form[enctype='multipart/form-data'] input[type=file][name=arquivo]"
    assert_match(/importar/i, response.body)
  end
end
