require "test_helper"

# T14 — confirmação: a **única escrita** da feature de portabilidade
# (POR-08, POR-06, POR-12 / Req. 10.5, 10.3).
#
# ## O que este arquivo existe para provar
#
# Treze tasks foram construídas sob uma invariante: nenhuma escrita na coleção
# sem confirmação explícita. Parser, resolvedor, upload e pré-visualização não
# gravam nada, e cada um tem teste provando isso. **Aqui a escrita acontece**, e
# a coleção é o único dado insubstituível do sistema — o catálogo é regenerável
# a partir da fonte externa (AD-001), a coleção não. Um defeito neste caminho
# destrói trabalho que nenhuma reingestão reconstrói.
#
# Por isso a asserção central deste arquivo compara o resultado contra **a
# pré-visualização**, nunca contra o arquivo: o Req. 10.5 é "grava o que foi
# mostrado", e comparar contra o arquivo passaria alegremente por uma
# implementação que reparseia e chega a outro resultado. A prova de que não há
# reparse é estrutural e está em `nao_reparseia_o_arquivo_test`: o staging é a
# única entrada da escrita, e adulterá-lo muda o que é gravado.
#
# ## SPEC_DEVIATION — teste de integração no lugar de system test
#
# Não há navegador no container (registrado desde a `colecao`), então o fluxo é
# exercitado por requisição HTTP e o estado é verificado no banco, não por
# interação real do usuário. O recorte é de **fluxo e de efeito**: a mecânica
# da classificação já está provada por unidade em
# `test/services/collection_csv/resolver_test.rb`.
#
# ## SPEC_DEVIATION — concorrência real em vez de duas requisições paralelas
#
# O critério "duas confirmações da mesma pré-visualização não duplicam o efeito"
# tem duas metades, e elas precisam de instrumentos diferentes:
#
# - A **sequencial** (o usuário clica, volta e clica de novo) é exercitada por
#   duas requisições HTTP seguidas, que é exatamente o que acontece na vida.
# - A **simultânea** (duas abas, ou um duplo clique que o navegador despacha
#   duas vezes) não é reproduzível por `ActionDispatch::IntegrationTest`: a
#   suíte roda dentro de uma transação de teste, e duas threads na mesma
#   conexão não são duas transações. Ela é provada no nível em que o defeito
#   mora — o `UPDATE ... WHERE status = 'pendente'` — contando **linhas
#   afetadas**: a segunda tentativa de transição não casa o `WHERE` e afeta
#   zero linhas, que é precisamente o que faz a corrida ser perdida no banco em
#   vez de em Ruby.
class CollectionImportCommitTest < ActionDispatch::IntegrationTest
  PASSWORD = "grand-line-14".freeze

  setup do
    @nami = User.create!(email: "nami-por08@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-por08@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OPp14", name: "Romance Dawn", kind: "booster",
                           base_set_size: 4, total_set_size: 4)

    @existente = variant("p14a", "Bell-mère")
    @zerada = variant("p14b", "Nefertari Vivi")
    @nova = variant("p14c", "Roronoa Zoro")
    @igual = variant("p14d", "Monkey D. Luffy")

    # O "antes" de @nami, montado para que o arquivo produza as cinco
    # classificações do resolvedor de uma vez só.
    @item_existente = own(@nami, @existente, 2)
    @item_zerada = own(@nami, @zerada, 5)
    @item_igual = own(@nami, @igual, 3)

    # As **mesmas** variantes para @zoro, com quantidades diferentes. Com
    # variantes disjuntas, uma escrita no usuário errado falharia por variante
    # inexistente e passaria por "não escreveu"; com as mesmas variantes,
    # qualquer escrita no dono errado é visível.
    own(@zoro, @existente, 9)
    own(@zoro, @zerada, 9)
    own(@zoro, @nova, 9)
    own(@zoro, @igual, 9)
  end

  def variant(suffix, card_name)
    card = Card.create!(card_set: @set, card_number: "OP14-#{suffix}", name: card_name,
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

  # O arquivo que muda a coleção de @nami em quatro direções: cria `@nova`,
  # troca 2 por 7 em `@existente`, zera `@zerada` e deixa `@igual` como está.
  #
  # A **quinta** linha é rejeitada de propósito: uma variante que não existe no
  # catálogo. Sem ela, nada no arquivo exercitaria o caminho de `:rejeita`, e a
  # guarda que impede a linha rejeitada de chegar ao `INSERT` estaria escrita
  # sem estar provada — a mutação que acrescenta `:rejeita` às classificações
  # graváveis passaria por um arquivo que não tem nenhuma.
  def csv_completo
    linhas = [
      CollectionCsv::Format.header_row.join(","),
      "#{@nova.card.card_number},#{@nova.variant_code},#{@nova.card.name},4",
      "#{@existente.card.card_number},#{@existente.variant_code},#{@existente.card.name},7",
      "#{@zerada.card.card_number},#{@zerada.variant_code},#{@zerada.card.name},0",
      "#{@igual.card.card_number},#{@igual.variant_code},#{@igual.card.name},3",
      "OP14-inexistente,zzz,Carta Que Não Existe,6"
    ]
    linhas.join("\n") + "\n"
  end

  def upload(conteudo, filename: "colecao.csv")
    Rack::Test::UploadedFile.new(
      StringIO.new(conteudo), "text/csv", original_filename: filename
    )
  end

  # Sobe uma pré-visualização pelo caminho de produção — upload de verdade —
  # e devolve o registro de staging. A confirmação nunca recebe o arquivo, só
  # este token.
  def previsualizar(conteudo = csv_completo)
    post collection_imports_path, params: { arquivo: upload(conteudo) }
    CollectionImport.order(:id).last
  end

  def confirmar(token)
    post confirm_collection_import_path(token)
  end

  def retrato_da_colecao
    CollectionItem.order(:id).pluck(:id, :user_id, :card_variant_id, :quantity)
  end

  def quantidade(user, card_variant)
    CollectionItem.for_user(user).find_by(card_variant: card_variant)&.quantity
  end

  # O estado que a pré-visualização **prometeu**: para cada linha aceita, o par
  # (variante, quantidade_depois). É contra isto que o resultado é comparado —
  # nunca contra o arquivo.
  def promessa_da_previsualizacao(preview)
    preview.linhas_resolvidas.select(&:aceita?).to_h do |linha|
      [ linha.card_variant_id, linha.quantidade_depois ]
    end
  end

  # --- POR-08: grava exatamente o que a pré-visualização apresentou ---

  # A asserção central da task. A comparação é contra a **promessa**, derivada
  # do staging que a tela renderizou, e não contra o CSV: uma implementação que
  # reparseasse o arquivo e chegasse a outro resultado passaria por uma
  # comparação contra o arquivo e falha nesta.
  test "a confirmação grava exatamente o que a pré-visualização apresentou" do
    sign_in
    preview = previsualizar
    prometido = promessa_da_previsualizacao(preview)

    assert_equal 4, prometido.size,
                 "quatro das cinco linhas foram aceitas; a quinta é rejeitada e não promete nada"

    confirmar(preview.token)

    prometido.each do |card_variant_id, quantidade_prometida|
      item = CollectionItem.for_user(@nami).find_by(card_variant_id: card_variant_id)

      assert_not_nil item, "a variante #{card_variant_id} prometida não foi gravada"
      assert_equal quantidade_prometida, item.quantity,
                   "a variante #{card_variant_id} ficou com quantidade diferente da prevista"
    end
  end

  # As cinco classificações, verificadas uma a uma no estado final. O teste
  # acima compara com a promessa; este fixa **qual** promessa o produto faz,
  # para que uma classificação trocada no resolvedor não passe despercebida
  # por os dois lados da comparação mudarem juntos.
  test "cada classificação produz o efeito que a tela anunciou" do
    sign_in
    preview = previsualizar

    confirmar(preview.token)

    assert_equal 4, quantidade(@nami, @nova), ":cria passa a existir com a quantidade do arquivo"
    assert_equal 7, quantidade(@nami, @existente), ":atualiza substitui a quantidade"
    assert_equal 0, quantidade(@nami, @zerada), ":zera leva a posse a zero"
    assert_equal 3, quantidade(@nami, @igual), ":inalterada continua com o mesmo valor"
  end

  # `:rejeita` **nunca** vira escrita: é a linha que a tela mostrou com motivo,
  # e gravá-la contrariaria o que o usuário leu. A prova é de contagem — o
  # arquivo tem cinco linhas e a coleção de @nami recebe quatro —, porque a
  # linha rejeitada não tem `card_variant_id` para consultar diretamente.
  test "a linha rejeitada não vira escrita" do
    sign_in
    preview = previsualizar

    assert_equal 1, preview.linhas_resolvidas.count(&:rejeitada?),
                 "o arquivo traz uma linha rejeitada, senão este teste não discrimina nada"

    confirmar(preview.token)

    assert_equal 4, CollectionItem.for_user(@nami).count,
                 "quatro linhas aceitas viram quatro registros; a rejeitada não entra"
  end

  # A rejeição **com variante resolvida** é o caso que separa as duas guardas
  # do serviço, e é o único que prova a da classificação.
  #
  # A rejeição por variante inexistente não tem `card_variant_id`, então a
  # guarda de FK a barraria sozinha mesmo que a classificação fosse ignorada.
  # A linha **duplicada** (T9) é diferente: o resolvedor já resolveu a
  # variante e **depois** rejeitou a ocorrência perdedora, de modo que ela
  # chega ao commit com `card_variant_id` preenchido e uma
  # `quantidade_depois` que a tela anunciou como recusada. Gravá-la aplicaria
  # à coleção um valor que o usuário leu como "não vai valer".
  #
  # Aqui a primeira ocorrência pede 1 e a segunda pede 5; vale a última (T9).
  # Uma implementação que ignore a classificação grava as duas, e a ordem do
  # `ON CONFLICT` faria a **perdedora** sobrescrever a vencedora.
  test "a linha duplicada rejeitada não é gravada, mesmo tendo variante resolvida" do
    sign_in

    csv = [
      CollectionCsv::Format.header_row.join(","),
      "#{@nova.card.card_number},#{@nova.variant_code},#{@nova.card.name},5",
      "#{@nova.card.card_number},#{@nova.variant_code},#{@nova.card.name},1"
    ].join("\n") + "\n"

    preview = previsualizar(csv)
    perdedora = preview.linhas_resolvidas.find(&:rejeitada?)

    assert_not_nil perdedora, "a duplicata produz uma linha rejeitada"
    assert_equal :linha_duplicada, perdedora.motivo
    assert_not_nil perdedora.card_variant_id,
                   "a linha duplicada chega ao commit com variante resolvida — é isso que a torna perigosa"

    confirmar(preview.token)

    assert_equal 1, quantidade(@nami, @nova),
                 "vale a última ocorrência; gravar a rejeitada deixaria o valor da perdedora"
  end

  # A contrapartida do teste acima, e a razão de ela existir separada.
  #
  # O efeito na coleção **não** discrimina sozinho: a linha rejeitada chega com
  # `quantidade_depois` nula, e tentar gravá-la violaria o `NOT NULL` da
  # coluna — erro que o savepoint por linha engole, deixando a coleção idêntica
  # à do caminho correto. Uma implementação que ignore a classificação passaria
  # por todas as asserções de quantidade deste arquivo, **por acidente**, e a
  # guarda estaria escrita sem estar provada.
  #
  # O que separa os dois mundos é o `Result`: recusar por decisão não produz
  # falha, tropeçar na constraint produz. Esta é a asserção que mata a mutação.
  test "a linha rejeitada é recusada por decisão, não barrada por constraint" do
    sign_in

    csv = [
      CollectionCsv::Format.header_row.join(","),
      "#{@nova.card.card_number},#{@nova.variant_code},#{@nova.card.name},5",
      "#{@nova.card.card_number},#{@nova.variant_code},#{@nova.card.name},1",
      "OP14-inexistente,zzz,Carta Que Não Existe,6"
    ].join("\n") + "\n"

    preview = previsualizar(csv)
    resultado = CollectionCsv::Commit.new(@nami, preview.token).call

    assert resultado.reivindicada?
    assert_equal 1, resultado.gravadas, "só a ocorrência vencedora é gravada"
    assert_equal 2, resultado.rejeitadas, "a duplicata perdedora e a variante inexistente"
    assert_empty resultado.falhas,
                 "linha rejeitada não pode chegar ao banco: recusa é decisão, não erro de constraint"
  end

  # AD-006 é a decisão que torna o export idempotente na volta (POR-11).
  # Somar dobraria a coleção a cada ciclo de exportar-e-reimportar, e é o
  # defeito que este teste existe para impedir: 2 + 7 = 9 falha aqui.
  test "a quantidade resultante é a do arquivo, não a soma com a que já havia" do
    sign_in
    preview = previsualizar

    confirmar(preview.token)

    assert_equal 7, quantidade(@nami, @existente),
                 "AD-006: o import substitui a quantidade, nunca soma"
    assert_not_equal 9, quantidade(@nami, @existente),
                     "9 é a soma de 2 com 7 — somar dobraria a coleção a cada ida e volta"
  end

  # POR-12: a escrita parte de `Current.user` e não toca em mais ninguém. As
  # variantes são as mesmas do @zoro, de propósito.
  test "a confirmação não altera a coleção de outro usuário" do
    zoro_antes = CollectionItem.for_user(@zoro).order(:id).pluck(:card_variant_id, :quantity)

    sign_in
    preview = previsualizar
    confirmar(preview.token)

    assert_equal zoro_antes,
                 CollectionItem.for_user(@zoro).order(:id).pluck(:card_variant_id, :quantity),
                 "a coleção do outro usuário tem as mesmas variantes e não pode ter mudado"
  end

  # --- Req. 10.5: abandonar o fluxo não grava nada ---

  # A invariante da feature inteira, vista do outro lado: todo o caminho até a
  # tela de pré-visualização — upload, resolução, renderização — e nenhuma
  # escrita. É o que dá sentido ao botão de confirmar.
  test "abandonar o fluxo sem confirmar deixa a coleção exatamente como estava" do
    sign_in
    antes = retrato_da_colecao

    preview = previsualizar
    get collection_import_path(preview.token)

    assert_response :success
    assert_equal antes, retrato_da_colecao,
                 "ver a pré-visualização não pode gravar uma única linha"
    assert_equal "pendente", preview.reload.status
  end

  # --- POR-08: a confirmação exige a pré-visualização ---

  # Não há caminho que grave direto do arquivo. A prova é dupla: a rota de
  # confirmação não aceita arquivo, e mandar um junto não muda nada — o que é
  # gravado continua sendo o staging.
  test "a confirmação não aceita arquivo: o que grava é o staging, não o upload" do
    sign_in
    preview = previsualizar

    # Um arquivo hostil, que pediria 99 cópias de tudo, viajando na mesma
    # requisição de confirmação. Se algum caminho reparseasse o corpo, o 99
    # apareceria na coleção.
    hostil = [
      CollectionCsv::Format.header_row.join(","),
      "#{@existente.card.card_number},#{@existente.variant_code},#{@existente.card.name},99"
    ].join("\n") + "\n"

    post confirm_collection_import_path(preview.token),
         params: { arquivo: upload(hostil, filename: "hostil.csv") }

    assert_equal 7, quantidade(@nami, @existente),
                 "a confirmação grava o que o staging diz, e ignora qualquer arquivo na requisição"
  end

  # A outra metade: sem staging não há escrita. Um token que não existe não
  # pode virar um caminho de gravação por nenhuma rota.
  test "confirmar um token inexistente não grava nada" do
    sign_in
    antes = retrato_da_colecao

    confirmar("token-que-nunca-existiu")

    assert_response :not_found
    assert_equal antes, retrato_da_colecao
  end

  # A prova estrutural de que o arquivo não é reparseado: adulterar o staging
  # **depois** do upload muda o que é gravado. Se a confirmação lesse o
  # arquivo, o 42 seria ignorado e a coleção ficaria com o 7 do CSV.
  #
  # Este é o teste que uma implementação que chama `Parser` ou `Resolver` no
  # caminho da confirmação não sobrevive.
  test "o staging é a única entrada da escrita: adulterá-lo muda o que é gravado" do
    sign_in
    preview = previsualizar

    adulteradas = preview.linhas_resolvidas.map do |linha|
      linha.quantidade_depois = 42 if linha.card_variant_id == @existente.id
      linha
    end
    preview.update!(linhas: adulteradas)

    confirmar(preview.token)

    assert_equal 42, quantidade(@nami, @existente),
                 "o que é gravado vem do staging; reparsear o arquivo produziria 7"
  end

  # --- POR-12: pré-visualização alheia ---

  # Duas metades distintas no mesmo critério: não gravar é autorização; não
  # revelar a existência é não transformar a tabela num oráculo de tokens
  # válidos, um por requisição. O `find_by_token_for` da T11 devolve `nil`
  # indistintamente, e a resposta tem de ser a mesma do token inexistente.
  test "confirmar a pré-visualização de outro usuário não grava nada" do
    sign_in(@zoro)
    preview_do_zoro = previsualizar

    delete session_path
    sign_in(@nami)
    antes = retrato_da_colecao

    confirmar(preview_do_zoro.token)

    assert_response :not_found
    assert_equal antes, retrato_da_colecao,
                 "o token alheio não pode gravar nem na coleção de quem tentou"
    assert_equal "pendente", preview_do_zoro.reload.status,
                 "a pré-visualização alheia continua intacta e confirmável pelo dono"
  end

  # A comparação é de **status e exceção**, não do corpo byte a byte: em
  # `test` o Rails responde com a página de depuração, que carrega ids de
  # objeto e do frame variáveis entre requisições — ruído do ambiente, não do
  # produto. Em produção as duas viram o mesmo `404`, e é a indistinção do
  # desfecho que o critério pede.
  test "o token alheio responde igual ao token inexistente e não revela a existência" do
    sign_in(@zoro)
    preview_do_zoro = previsualizar

    delete session_path
    sign_in(@nami)

    alheio = desfecho_de { confirmar(preview_do_zoro.token) }
    inexistente = desfecho_de { confirmar("token-que-nunca-existiu") }

    assert_equal 404, inexistente.first, "o token inexistente é 404"
    assert_equal inexistente, alheio,
                 "responder diferente faria da rota um oráculo de tokens válidos"
  end

  # O desfecho que o usuário observa: o status e a **mensagem de erro**.
  #
  # O corpo inteiro não serve de comparação em `test`: o Rails responde com a
  # página de depuração, que cita o trecho do arquivo de teste que originou a
  # chamada — duas linhas diferentes do *próprio teste* produzem corpos
  # diferentes sem que nada do produto tenha mudado. Em produção as duas são a
  # mesma página de `404`.
  #
  # O que precisa ser indistinguível é o par (status, mensagem): é por ele que
  # um atacante separaria "existe, mas não é sua" de "não existe" e
  # transformaria a rota num oráculo de tokens válidos, um por requisição.
  def desfecho_de
    yield
    [ response.status, request.env["action_dispatch.exception"]&.message ]
  end

  # --- Edge Case: duas confirmações não duplicam o efeito ---

  # A metade sequencial: o usuário clica, volta e clica de novo. Como a
  # operação é substituição e não soma, a duplicação não apareceria na
  # quantidade — ela apareceria se a segunda confirmação reaplicasse o staging
  # sobre uma coleção que o usuário já editou depois da primeira. Por isso o
  # teste edita a coleção entre as duas confirmações: a segunda **não pode**
  # desfazer essa edição.
  test "duas confirmações da mesma pré-visualização não duplicam o efeito" do
    sign_in
    preview = previsualizar

    confirmar(preview.token)
    assert_equal 7, quantidade(@nami, @existente)

    # O usuário mexe na coleção depois de importar, pelo caminho normal.
    post increment_collection_item_path(@existente)
    assert_equal 8, quantidade(@nami, @existente)

    confirmar(preview.token)

    assert_equal 8, quantidade(@nami, @existente),
                 "a segunda confirmação não pode reaplicar o import sobre o que o usuário fez depois"
    assert_equal "confirmado", preview.reload.status
  end

  # A metade simultânea, no nível em que o defeito mora. A revisão de banco da
  # T11 reproduziu que `confirmavel?` (SELECT) seguido de
  # `update!(status:)` (UPDATE) deixa duas requisições passarem pela mesma
  # porta. A defesa é a transição num único `UPDATE ... WHERE status =
  # 'pendente' RETURNING`, e o que prova a defesa é a **contagem de linhas
  # afetadas**: a segunda tentativa não casa o `WHERE` e afeta zero.
  test "a transição de status é atômica: a segunda tentativa afeta zero linhas" do
    sign_in
    preview = previsualizar

    primeira = CollectionCsv::Commit.reivindicar(preview.id)
    segunda = CollectionCsv::Commit.reivindicar(preview.id)

    assert primeira, "a primeira confirmação toma a pré-visualização"
    assert_not segunda,
               "a segunda não pode tomar a mesma pré-visualização: o WHERE não casa"
  end

  # O desfecho acima é necessário e **não é suficiente**: um `SELECT` seguido
  # de `UPDATE` produz exatamente o mesmo `true`/`false` quando as duas
  # chamadas são sequenciais, e foi assim que a revisão de banco da T11
  # descreveu o defeito — "`SELECT` seguido de `UPDATE` é defeito **mesmo com
  # teste verde**". Como a corrida real não é reproduzível dentro da transação
  # de teste, o que se prova aqui é o **mecanismo**: a reivindicação precisa
  # emitir um único statement, e as duas guardas precisam viver no `WHERE`
  # dele.
  #
  # A verificação é sobre o SQL efetivamente enviado ao banco, não sobre a
  # constante: montar o statement em outro lugar, ou acrescentar um `SELECT`
  # antes, muda o que o `ActiveSupport::Notifications` vê.
  test "a reivindicação é um único UPDATE condicional, sem SELECT antes" do
    sign_in
    preview = previsualizar

    statements = []
    assinatura = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql]
      next if payload[:name] == "SCHEMA" || sql =~ /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i

      statements << sql
    end

    begin
      CollectionCsv::Commit.reivindicar(preview.id)
    ensure
      ActiveSupport::Notifications.unsubscribe(assinatura)
    end

    assert_equal 1, statements.size,
                 "a reivindicação é um statement só; um SELECT antes reabre a corrida: #{statements.inspect}"

    sql = statements.first

    assert_match(/\AUPDATE collection_imports/i, sql, "a reivindicação é um UPDATE, não uma leitura")
    assert_match(/WHERE.*status\s*=\s*'pendente'/im, sql,
                 "a guarda de status mora no WHERE do próprio UPDATE, não num if em Ruby")
    assert_match(/WHERE.*expires_at\s*>\s*now\(\)/im, sql,
                 "a guarda de prazo mora no mesmo WHERE, pelo mesmo motivo")
    assert_match(/RETURNING/i, sql,
                 "é o RETURNING que distingue tomei de outro-já-tinha-tomado")
  end

  # A escrita na coleção precisa estar **na mesma transação** da
  # reivindicação: é isso que impede que um erro depois da transição deixe a
  # pré-visualização consumida com a coleção pela metade.
  #
  # O observável é a **profundidade de transação aberta** no momento de cada
  # statement. `BEGIN`/`COMMIT` não servem aqui: a suíte já roda dentro de uma
  # transação de teste, então a transação do serviço sai como `SAVEPOINT` — e
  # um teste que exigisse `BEGIN` estaria medindo o `use_transactional_tests`,
  # não o produto. A profundidade, ao contrário, se comporta igual nos dois
  # ambientes.
  #
  # As três asserções, juntas, fecham o desenho: a transição acontece com
  # transação aberta; nenhuma escrita acontece antes dela; e cada escrita corre
  # **mais fundo** que a transição — que é a assinatura do savepoint por linha,
  # o que concilia a atomicidade do lote com o erro isolado do Req. 10.3.
  test "a reivindicação e a escrita ficam na mesma transação, com savepoint por linha" do
    sign_in
    preview = previsualizar

    eventos = []
    conexao = CollectionItem.connection
    assinatura = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA"

      tipo =
        if payload[:sql] =~ /\AUPDATE collection_imports/i then :reivindica
        elsif payload[:sql] =~ /INSERT INTO collection_items/i then :escreve
        end

      eventos << [ tipo, conexao.open_transactions ] if tipo
    end

    begin
      confirmar(preview.token)
    ensure
      ActiveSupport::Notifications.unsubscribe(assinatura)
    end

    reivindicacoes = eventos.select { |tipo, _| tipo == :reivindica }
    escritas = eventos.select { |tipo, _| tipo == :escreve }

    assert_equal 1, reivindicacoes.size, "uma reivindicação por confirmação"
    assert_equal 4, escritas.size, "as quatro linhas aceitas foram gravadas"

    profundidade_da_reivindicacao = reivindicacoes.first.last

    assert_operator profundidade_da_reivindicacao, :>=, 1,
                    "a transição de status corre com transação aberta"
    assert_equal :reivindica, eventos.first.first,
                 "nada é gravado na coleção antes de a pré-visualização ser reivindicada"

    escritas.each do |_, profundidade|
      assert_operator profundidade, :>, profundidade_da_reivindicacao,
                      "cada linha grava sob um savepoint próprio, dentro da transação do lote"
    end
  end

  # A confirmação de uma pré-visualização já confirmada não regride o status
  # nem reabre a escrita, mesmo que alguém force `status` de volta por SQL
  # direto — porque a segunda confirmação viria com o staging já consumido.
  # O que este teste fixa é o desfecho visível ao usuário.
  test "confirmar de novo responde sem estourar e não grava" do
    sign_in
    preview = previsualizar
    confirmar(preview.token)

    depois_da_primeira = retrato_da_colecao

    confirmar(preview.token)

    assert_response :redirect
    assert_equal depois_da_primeira, retrato_da_colecao
  end

  # Troca o teto de linhas graváveis pela duração do bloco. `remove_const` antes
  # de `const_set` evita o aviso de redefinição, e o `ensure` devolve o valor
  # real mesmo se a asserção falhar.
  def com_teto_de(limite)
    original = CollectionCsv::Parser::MAX_LINHAS
    CollectionCsv::Parser.send(:remove_const, :MAX_LINHAS)
    CollectionCsv::Parser.const_set(:MAX_LINHAS, limite)
    yield
  ensure
    CollectionCsv::Parser.send(:remove_const, :MAX_LINHAS)
    CollectionCsv::Parser.const_set(:MAX_LINHAS, original)
  end

  # Faz o `upsert` de **uma** variante levantar o erro dado, deixando as demais
  # seguirem o caminho real. Instrumentar o serviço é o único jeito de produzir
  # uma falha que não seja `ActiveRecordError` — a violação de FK que os testes
  # vizinhos usam não alcança essa classe de erro.
  def com_upsert_falhando_em(card_variant_id, erro)
    original = CollectionCsv::Commit.instance_method(:upsert)

    CollectionCsv::Commit.define_method(:upsert) do |linha|
      raise erro if linha.card_variant_id == card_variant_id

      original.bind_call(self, linha)
    end

    yield
  ensure
    CollectionCsv::Commit.define_method(:upsert, original)
  end

  # --- Req. 10.3 / POR-06: uma linha que falha não desfaz as anteriores ---

  # O mesmo espírito do erro isolado da ingestão (design.md §5.2): cada
  # registro vai em transação própria, o erro vai para o log e o loop continua.
  # Aqui a linha ruim é uma cuja variante foi apagada do catálogo entre a
  # pré-visualização e a confirmação — o único jeito honesto de produzir uma
  # falha de gravação sem instrumentar o serviço.
  test "uma linha que falha na gravação não desfaz as anteriores" do
    sign_in
    preview = previsualizar

    # A FK de `collection_items` é `ON DELETE RESTRICT`, então a variante só
    # sai do catálogo se ninguém a possuir. `@nova` é justamente a linha
    # `:cria`: ninguém tem registro dela ainda.
    variante_sumida = @nova.id
    CollectionItem.where(card_variant_id: variante_sumida).delete_all
    @nova.destroy!

    confirmar(preview.token)

    assert_equal 7, quantidade(@nami, @existente),
                 "a linha anterior à que falhou continua gravada"
    assert_equal 0, quantidade(@nami, @zerada),
                 "a linha posterior à que falhou continua sendo processada"
    assert_nil CollectionItem.for_user(@nami).find_by(card_variant_id: variante_sumida),
               "a linha que falhou não gravou nada"
  end

  test "a falha de uma linha não impede a confirmação de fechar" do
    sign_in
    preview = previsualizar

    CollectionItem.where(card_variant_id: @nova.id).delete_all
    @nova.destroy!

    confirmar(preview.token)

    assert_equal "confirmado", preview.reload.status,
                 "o lote fecha mesmo com linha falhando: o oposto perderia o lote inteiro"
  end

  # Achado CRITICAL da revisão de banco (autor ≠ revisor), reproduzido antes de
  # corrigir: os dois testes acima produzem falha por violação de FK, que é uma
  # `ActiveRecord::ActiveRecordError` — e o `rescue` original capturava
  # exatamente essa classe. Ficavam de fora **todos** os erros que não descendem
  # dela: `PG::Error` cru do driver (`PG::ConnectionBad.ancestors` não inclui
  # `ActiveRecordError`), `Timeout::Error`, e qualquer `RuntimeError` de um bug
  # de aplicação.
  #
  # Medido com o `rescue` estreito: com a primeira linha já gravada no savepoint
  # dela, um erro na segunda propagava pelo `each`, a transação externa fazia
  # ROLLBACK e a coleção ficava com **zero** linhas. Num lote de 10.000, uma
  # queda de conexão na linha 4.000 apagaria as 3.999 já gravadas.
  test "uma falha que não é do Active Record também não desfaz as anteriores" do
    sign_in
    preview = previsualizar
    falhada = @nova.id

    com_upsert_falhando_em(falhada, RuntimeError.new("bug de aplicação")) do
      confirmar(preview.token)
    end

    assert_equal 7, quantidade(@nami, @existente),
                 "a linha anterior à que falhou continua gravada"
    assert_equal 0, quantidade(@nami, @zerada),
                 "a linha posterior à que falhou continua sendo processada"
    assert_nil CollectionItem.for_user(@nami).find_by(card_variant_id: falhada),
               "a linha que falhou não gravou nada"
    assert_equal "confirmado", preview.reload.status,
                 "o lote fecha: o oposto devolveria a pré-visualização ao estado pendente " \
                 "com parte da coleção já gravada"
  end

  # `PG::Error` é o caso que motivou o achado: é o que chega numa queda de
  # conexão com o banco no meio do lote, e é o mais caro de perder.
  test "um erro cru do driver do banco não desfaz as anteriores" do
    sign_in
    preview = previsualizar
    falhada = @nova.id

    com_upsert_falhando_em(falhada, PG::Error.new("conexão perdida")) do
      confirmar(preview.token)
    end

    assert_equal 7, quantidade(@nami, @existente)
    assert_equal "confirmado", preview.reload.status
  end

  # O `rescue` alargado não pode engolir o que precisa derrubar o processo:
  # `SignalException`, `SystemExit` e `NoMemoryError` não são `StandardError`, e
  # virar "mais uma linha que falhou" esconderia um desligamento em curso.
  test "sinal de desligamento não é tratado como linha que falhou" do
    sign_in
    preview = previsualizar

    assert_raises(SystemExit) do
      com_upsert_falhando_em(@nova.id, SystemExit.new) do
        confirmar(preview.token)
      end
    end
  end

  # Achado HIGH da mesma revisão: o teto de AD-008 vive em `Parser::MAX_LINHAS`,
  # que atua no upload, e entre ele e esta escrita está um `jsonb` **sem `CHECK`
  # de tamanho**. Um staging maior chegando aqui por qualquer outro caminho —
  # manutenção, migração de dado, o limite do parser mudando sozinho — viraria
  # 30.000+ statements numa requisição HTTP sem nada reclamar.
  test "um lote acima do teto é recusado antes de gravar qualquer linha" do
    sign_in
    preview = previsualizar
    excedente = preview.linhas.first.merge("indice" => 99)
    preview.update!(linhas: preview.linhas + [ excedente ])

    antes = CollectionItem.for_user(@nami).sum(:quantity)

    # Baixar o teto é mais honesto do que montar 10.001 linhas: o que se prova
    # é a guarda, não a aritmética do número. O valor real continua fixado pelo
    # teste do `Parser`, que é o dono de AD-008.
    com_teto_de(1) do
      assert_raises(CollectionCsv::Commit::LoteGrandeDemais) do
        CollectionCsv::Commit.new(@nami, preview.token).call
      end
    end

    assert_equal antes, CollectionItem.for_user(@nami).sum(:quantity),
                 "o teto precisa barrar antes da escrita, não no meio dela"
    assert_equal "pendente", preview.reload.status,
                 "um lote recusado não consome a pré-visualização"
  end

  # --- POR-06: a escrita é `ON CONFLICT`, não ler-em-Ruby-e-escrever-depois ---

  # O *lost update* que a T6 da `colecao` resolveu, do lado do import. A prova
  # é de mecanismo e não de efeito: uma variante cujo registro é **criado
  # entre** a leitura em Ruby e a escrita faz `INSERT` cego estourar
  # `RecordNotUnique` e `find_or_initialize_by` + `save` perder a atualização.
  # `ON CONFLICT` absorve os dois casos.
  test "a escrita absorve o registro criado depois da pré-visualização" do
    sign_in
    preview = previsualizar

    # `@nova` foi classificada `:cria` — não havia registro. Entre a
    # pré-visualização e a confirmação, o usuário incrementa pela grade do
    # catálogo e o registro passa a existir.
    post increment_collection_item_path(@nova)
    assert_equal 1, quantidade(@nami, @nova)

    confirmar(preview.token)

    assert_equal 4, quantidade(@nami, @nova),
                 "o `ON CONFLICT` transforma a criação em atualização; um INSERT cego estouraria"
    assert_response :redirect
  end

  # A contrapartida: uma linha `:atualiza` cujo registro **sumiu** entre a
  # pré-visualização e a confirmação. `UPDATE` puro afetaria zero linhas e a
  # promessa da tela não se cumpriria; `ON CONFLICT` a partir de `INSERT`
  # grava.
  test "a escrita recria o registro apagado depois da pré-visualização" do
    sign_in
    preview = previsualizar

    @item_existente.destroy!
    assert_nil quantidade(@nami, @existente)

    confirmar(preview.token)

    assert_equal 7, quantidade(@nami, @existente),
                 "a escrita parte de INSERT: um UPDATE puro não teria o que atualizar"
  end

  # --- Edge Case: sessão expirada entre a pré-visualização e a confirmação ---

  test "sessão expirada entre pré-visualização e confirmação não grava e leva à autenticação" do
    sign_in
    preview = previsualizar
    antes = retrato_da_colecao

    delete session_path

    confirmar(preview.token)

    assert_redirected_to new_session_path
    assert_equal antes, retrato_da_colecao,
                 "sem sessão não há escrita — o default do ApplicationController roda antes da action"
    assert_equal "pendente", preview.reload.status,
                 "a pré-visualização continua confirmável quando o dono voltar"
  end

  # A pré-visualização vencida é o outro relógio da mesma história: o arquivo
  # descrito já não é o que o usuário viu, então confirmá-la não pode gravar.
  test "pré-visualização expirada não grava" do
    sign_in
    preview = previsualizar
    antes = retrato_da_colecao

    preview.update_column(:expires_at, 1.second.ago)

    confirmar(preview.token)

    assert_equal antes, retrato_da_colecao,
                 "fora do prazo o arquivo descrito já não é o que a tela mostrou"
    assert_equal "pendente", preview.reload.status
  end

  # --- A rota existe como helper, não como caminho literal ---

  # A T13 escreveu o destino do formulário como caminho literal porque o helper
  # ainda não existia. Este teste fixa que a T14 o declarou e que a tela aponta
  # para ele — um `NameError` aqui é o sintoma de a rota ter sumido.
  test "a tela de pré-visualização aponta para a rota de confirmação" do
    sign_in
    preview = previsualizar

    get collection_import_path(preview.token)

    assert_response :success
    assert_select "form[action=?][method=?]",
                  confirm_collection_import_path(preview.token), "post"
  end
end
