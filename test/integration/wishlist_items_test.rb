require "test_helper"

# T13 — wishlist: marcar, listar, remover e sinalizar atendido (Req. 8.1–8.4 /
# COL-14..COL-17), história "P2: Wishlist", mais o critério 4 da história
# "P1: Isolamento entre usuários" (COL-05).
#
# **Este arquivo carrega o critério que a T7 não pôde cumprir.** O
# `SPEC_DEVIATION` no cabeçalho de `collection_authorization_test.rb` registra
# que "id de item de outro usuário devolve 404" pressupunha uma URL com id de
# item, e o desenho da posse (por `card_variant_id`) não tem nenhuma. A
# wishlist remove **por item**, logo `DELETE /wishlist/:id` existe de verdade —
# e o teste de 404 aqui não é encenado.
#
# O "Independent Test" da spec é o roteiro dos testes de atendimento: alvo 2,
# posse 1 (não atendido), posse 2 (atendido), remover.
class WishlistItemsTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "usopp-t13@example.com", password: PASSWORD)
    @outro = User.create!(email: "jinbe-t13@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "WLt13", name: "Romance Dawn", kind: "booster")

    @luffy = create_card(number: "WL13-a", name: "Monkey D. Luffy")
    @nami = create_card(number: "WL13-b", name: "Nami")

    @base = create_variant(@luffy, "WL13-a")
    @parallel = create_variant(@luffy, "WL13-a_p1")
    @outra_carta = create_variant(@nami, "WL13-b")
  end

  # A suíte roda em paralelo e o projeto não usa fixtures YAML: cada teste cria
  # os próprios registros, com chaves naturais distintas por arquivo para não
  # colidir entre workers.
  def create_card(number:, name:)
    Card.create!(card_set: @set, card_number: number, name: name,
      card_type: "character", colors: [ "Red" ], cost: 2, power: 3000)
  end

  def create_variant(card, code)
    CardVariant.create!(card: card, card_set: @set, variant_code: code,
      rarity: "C", art_kind: "base")
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # O texto de um item da lista, com o espaçamento normalizado: o ERB quebra
  # linha entre o número e a unidade e o navegador colapsa isso, então asserir
  # sobre o texto cru faria a asserção depender da indentação do template.
  def texto_dos_itens
    css_select(".wishlist-item").map { |node| node.text.squish }
  end

  # --- Req. 8.1 / COL-14: marcar com alvo maior que zero ---

  test "marcar uma variante como desejada com alvo inteiro maior que zero" do
    sign_in

    assert_difference -> { WishlistItem.count }, 1 do
      post wishlist_items_path, params: { card_variant_id: @base.id, target_quantity: 3 }
    end

    item = WishlistItem.sole
    assert_equal @user, item.user
    assert_equal @base, item.card_variant, "o desejo é por **variante**, não por carta"
    assert_equal 3, item.target_quantity
  end

  # O alvo inválido tem que virar mensagem em português, não 500 nem
  # `StatementInvalid` cru do `CHECK (target_quantity >= 1)`. A garantia real
  # continua sendo do banco (provada por SQL direto na T12); a validação do
  # model é o que permite **falar** com o usuário.
  test "alvo zero é recusado com mensagem em português, sem estourar" do
    sign_in

    assert_no_difference -> { WishlistItem.count } do
      post wishlist_items_path, params: { card_variant_id: @base.id, target_quantity: 0 }
    end

    follow_redirect!
    assert_response :success
    assert_select ".flash--alert", /[Nn]ão foi possível salvar o desejo/
  end

  test "alvo negativo é recusado do mesmo jeito" do
    sign_in

    assert_no_difference -> { WishlistItem.count } do
      post wishlist_items_path, params: { card_variant_id: @base.id, target_quantity: -2 }
    end

    follow_redirect!
    assert_select ".flash--alert", /[Nn]ão foi possível salvar o desejo/
  end

  # Alvo não numérico. O setter de um atributo integer do Active Record
  # converte `"abc"` em `0`, que a validação recusa — mas isso é inferência
  # sobre o type-casting, não fato, até haver teste. Achado da revisão de
  # testes: sem esta asserção, trocar a validação por uma que só olhasse o
  # sinal deixaria texto arbitrário passar.
  test "alvo não numérico é recusado sem estourar" do
    sign_in

    assert_no_difference -> { WishlistItem.count } do
      post wishlist_items_path, params: { card_variant_id: @base.id, target_quantity: "abacaxi" }
    end

    follow_redirect!
    assert_response :success
    assert_select ".flash--alert", /[Nn]ão foi possível salvar o desejo/
  end

  # Alvo ausente. Não há default para `target_quantity` (decisão da T12: zero é
  # proibido e qualquer outro número seria arbitrário), então a ausência tem que
  # virar mensagem, não `NOT NULL violation` crua.
  test "alvo ausente é recusado sem estourar" do
    sign_in

    assert_no_difference -> { WishlistItem.count } do
      post wishlist_items_path, params: { card_variant_id: @base.id }
    end

    follow_redirect!
    assert_response :success
    assert_select ".flash--alert", /[Nn]ão foi possível salvar o desejo/
  end

  # O comentário do controller promete que um id de variante inexistente é 404.
  # Sem esta asserção a promessa não é verificada, e trocar o `find` por
  # `find_by` deixaria `card_variant_id` nulo ou estouraria mais adiante.
  test "marcar variante inexistente devolve 404" do
    sign_in

    assert_no_difference -> { WishlistItem.count } do
      post wishlist_items_path, params: { card_variant_id: 999_999_999, target_quantity: 1 }
    end

    assert_response :not_found
  end

  # Req. 8.5 — um item por par (usuário, variante). Marcar de novo atualiza o
  # alvo em vez de criar uma segunda linha (o `UNIQUE` do banco não deixaria) e
  # sem estourar `RecordNotUnique` na cara do usuário.
  test "marcar a mesma variante de novo atualiza o alvo em vez de duplicar" do
    sign_in
    post wishlist_items_path, params: { card_variant_id: @base.id, target_quantity: 2 }

    assert_no_difference -> { WishlistItem.count } do
      post wishlist_items_path, params: { card_variant_id: @base.id, target_quantity: 5 }
    end

    assert_equal 5, WishlistItem.sole.target_quantity
  end

  # --- Req. 8.2 / COL-15: listar apenas os itens do usuário da sessão ---

  test "a lista traz apenas os itens do usuário da sessão" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    WishlistItem.create!(user: @outro, card_variant: @outra_carta, target_quantity: 4)

    sign_in
    get wishlist_items_path

    assert_response :success
    assert_select ".wishlist-item", 1
    assert_match(/Monkey D\. Luffy/, texto_dos_itens.first)
    assert_select ".wishlist-item", text: /Nami/, count: 0,
      message: "o item do outro usuário não pode aparecer nesta lista"
  end

  # O outro lado da mesma asserção: cada usuário vê a **sua** lista na mesma
  # variante desejada por ambos. Com desejos em variantes diferentes o teste
  # seria verde por acaso.
  test "dois usuários desejando a mesma variante veem cada um o seu alvo" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    WishlistItem.create!(user: @outro, card_variant: @base, target_quantity: 9)

    sign_in(@user)
    get wishlist_items_path
    assert_select ".wishlist-item__target", text: "2"
    assert_select ".wishlist-item__target", text: "9", count: 0

    sign_in(@outro)
    get wishlist_items_path
    assert_select ".wishlist-item__target", text: "9"
    assert_select ".wishlist-item__target", text: "2", count: 0
  end

  # --- Req. 8.3 / COL-16: "atendido" derivado, nunca persistido ---
  #
  # O roteiro do "Independent Test" da spec, nas três etapas que discriminam:
  # alvo 2 com posse 0, com posse 1 e com posse 2.

  test "alvo 2 e posse zero: não atendido, e o item aparece na lista" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)

    sign_in
    get wishlist_items_path

    assert_response :success
    # Este é o teste que o `INNER JOIN` mataria: desejar uma variante que nunca
    # se teve é o caso **normal** da wishlist, e é justamente quem não tem
    # nenhuma linha em `collection_items` que sumiria de um join interno.
    assert_select ".wishlist-item", 1,
      "item sem nenhuma posse registrada precisa continuar listado"
    assert_select ".wishlist-item__owned", text: "0"
    assert_select ".wishlist-item__status--fulfilled", 0
    assert_select ".wishlist-item__status--pending", text: /Faltam 2/
  end

  test "alvo 2 e posse 1: ainda não atendido" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 1)

    sign_in
    get wishlist_items_path

    assert_select ".wishlist-item__owned", text: "1"
    assert_select ".wishlist-item__status--fulfilled", 0,
      "1 de 2 não é atendido"
    assert_select ".wishlist-item__status--pending", text: /Faltam 1/
    assert_select ".wishlist-item--fulfilled", 0
  end

  test "alvo 2 e posse 2: atendido" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 2)

    sign_in
    get wishlist_items_path

    assert_select ".wishlist-item__owned", text: "2"
    assert_select ".wishlist-item__status--fulfilled", text: "Atendido"
    assert_select ".wishlist-item__status--pending", 0
  end

  # "atingir **ou exceder**" é o texto do critério: `>=`, não `=`. Com `=`
  # este teste morre e os dois de cima continuam verdes.
  test "posse acima do alvo também é atendido" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 7)

    sign_in
    get wishlist_items_path

    assert_select ".wishlist-item__status--fulfilled", text: "Atendido"
  end

  # Req. 7.3 — zero é linha existente, não ausência de linha. Uma linha zerada
  # não pode atender desejo nenhum, e uma derivação que testasse a **existência**
  # do registro em vez de comparar a quantidade marcaria este item como
  # atendido.
  test "posse registrada em zero não atende o desejo" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 1)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 0)

    sign_in
    get wishlist_items_path

    assert_select ".wishlist-item__owned", text: "0"
    assert_select ".wishlist-item__status--fulfilled", 0
  end

  # O join precisa casar o par completo (`user_id` **e** `card_variant_id`).
  # Sem o `user_id` na condição, a posse do outro usuário entraria na
  # comparação e atenderia o desejo deste — vazamento de leitura, Req. 6.5.
  test "a posse de outro usuário não atende o desejo deste" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    CollectionItem.create!(user: @outro, card_variant: @base, quantity: 9)

    sign_in(@user)
    get wishlist_items_path

    assert_select ".wishlist-item__owned", text: "0"
    assert_select ".wishlist-item__status--fulfilled", 0,
      "a coleção do outro usuário não pode atender o desejo deste"
  end

  # A posse de **outra variante da mesma carta** não atende: o desejo é por
  # impressão (design.md §3.1). Ter a base não é ter a parallel.
  test "posse de outra variante da mesma carta não atende o desejo" do
    WishlistItem.create!(user: @user, card_variant: @parallel, target_quantity: 1)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 4)

    sign_in
    get wishlist_items_path

    assert_select ".wishlist-item__owned", text: "0"
    assert_select ".wishlist-item__status--fulfilled", 0
  end

  # "Atendido" é derivado, nunca persistido: não existe coluna de flag, e a
  # afirmação vale contra o schema, não contra a intenção de quem escreveu o
  # model. Se alguém acrescentar `fulfilled`/`atendido` como coluna, este teste
  # denuncia.
  test "não existe coluna de atendimento persistida em wishlist_items" do
    colunas = WishlistItem.column_names

    assert_equal %w[id user_id card_variant_id target_quantity created_at updated_at].sort,
      colunas.sort,
      "\"atendido\" é derivado na consulta (Req. 8.3); uma coluna de flag ficaria " \
      "obsoleta no instante em que a posse mudasse"
  end

  # O mesmo, pelo lado do comportamento: mudar a posse muda o atendimento sem
  # nenhuma escrita na wishlist. Uma flag persistida ficaria para trás aqui.
  test "o atendimento acompanha a posse sem nenhuma escrita na wishlist" do
    item = WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 1)

    sign_in
    get wishlist_items_path
    assert_select ".wishlist-item__status--fulfilled", 0

    # Só a coleção muda. A wishlist não é tocada — nem pelo teste nem pelo app.
    assert_no_changes -> { item.reload.updated_at } do
      post increment_collection_item_path(card_variant_id: @base.id)
    end

    get wishlist_items_path
    assert_select ".wishlist-item__status--fulfilled", text: "Atendido"
  end

  # --- Edge case da spec: variante ausente da fonte continua listada ---
  #
  # "IF uma variante referenciada pela wishlist for marcada como ausente da
  # fonte, THEN o item continua listado — a ingestão não deleta (Req. 1.7)."
  #
  # A ingestão marca presença pelo `last_seen_at` (`Ingestion::Upsert`): quem
  # entrou na execução corrente recebe a marca nova, e quem não veio da fonte
  # fica com a marca antiga. Ausência é `last_seen_at` velho, **nunca** linha
  # removida — a FK `restrict` transformaria uma remoção em erro barulhento.
  test "item cuja variante ficou para trás na ingestão continua listado" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)

    # A variante desejada some da fonte: fica com a marca de uma execução
    # antiga enquanto a outra recebe a marca da execução corrente.
    @base.update!(last_seen_at: 3.months.ago)
    @outra_carta.update!(last_seen_at: Time.current)

    sign_in
    get wishlist_items_path

    assert_response :success
    assert_select ".wishlist-item", 1
    assert_match(/Monkey D\. Luffy/, texto_dos_itens.first)
    assert CardVariant.exists?(@base.id),
      "a ingestão não tem operação de delete (Req. 1.7): a variante é marcada, não removida"
  end

  # --- Req. 8.4 / COL-17: remover ---

  test "remover um item da lista de desejos" do
    item = WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)

    sign_in

    assert_difference -> { WishlistItem.count }, -1 do
      delete wishlist_item_path(item)
    end

    assert_redirected_to wishlist_items_path
    follow_redirect!
    assert_select ".wishlist-item", 0
    assert_select ".flash--notice", /[Rr]emovido/
  end

  # Remover o desejo **não** toca a coleção: são estados independentes, que é a
  # razão de a wishlist ser tabela própria (spec.md, "Modelagem da wishlist").
  test "remover o desejo não mexe na posse da variante" do
    item = WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 3)

    sign_in
    delete wishlist_item_path(item)

    assert_equal 3, CollectionItem.find_by(user: @user, card_variant: @base).quantity
  end

  # --- COL-05, critério 4: id de outro usuário devolve 404 ---
  #
  # O critério que a T7 registrou como `SPEC_DEVIATION` por não ter URL com id
  # de item. Aqui ela existe, e o teste é real.

  test "remover item de outro usuário devolve 404 e não remove nada" do
    alheio = WishlistItem.create!(user: @outro, card_variant: @base, target_quantity: 4)

    sign_in(@user)

    assert_no_difference -> { WishlistItem.count } do
      delete wishlist_item_path(alheio)
    end

    assert_response :not_found
    assert WishlistItem.exists?(alheio.id), "o item do outro usuário continua intacto"
  end

  # **404 e não 403**, e a distinção é o requisito inteiro: 403 significa "isto
  # existe e não é seu", que é exatamente a informação que o critério manda não
  # revelar. A resposta para id alheio tem que ser **indistinguível** da
  # resposta para id inexistente.
  test "id alheio e id inexistente respondem do mesmo jeito" do
    alheio = WishlistItem.create!(user: @outro, card_variant: @base, target_quantity: 4)

    sign_in(@user)

    delete wishlist_item_path(alheio)
    status_alheio = response.status

    delete wishlist_item_path(id: 999_999_999)
    status_inexistente = response.status

    assert_equal :not_found, Rack::Utils::SYMBOL_TO_STATUS_CODE.key(status_alheio)
    assert_equal status_inexistente, status_alheio,
      "403 revelaria que o item existe; a resposta precisa ser a mesma de um id que não existe"
  end

  # "Sem revelar a existência" é sobre a resposta inteira, não só sobre o
  # status: um handler que renderizasse o erro do Active Record vazaria o id ou
  # o e-mail do dono no corpo com um 404 perfeitamente correto na linha de
  # status. Achado da revisão de testes.
  test "o corpo do 404 não revela nada sobre o item alheio nem sobre o dono" do
    alheio = WishlistItem.create!(user: @outro, card_variant: @base, target_quantity: 4)

    sign_in(@user)
    delete wishlist_item_path(alheio)

    assert_response :not_found
    refute_includes response.body, @outro.email,
      "o 404 não pode identificar o dono do item"
    refute_includes response.body, alheio.target_quantity.to_s + " cópia",
      "o 404 não pode descrever o item alheio"
  end

  # Req. 6.5, critério 2 — um identificador de usuário no request é ignorado, e
  # o usuário continua sendo o da sessão. Não há caminho de `params` para o
  # usuário: `for_user` recusa um id com `ArgumentError`.
  test "user_id no request não desloca o dono do item criado" do
    sign_in(@user)

    post wishlist_items_path,
      params: { card_variant_id: @base.id, target_quantity: 2, user_id: @outro.id }

    assert_equal @user, WishlistItem.sole.user
  end

  test "user_id no request não expande a lista exibida" do
    WishlistItem.create!(user: @outro, card_variant: @outra_carta, target_quantity: 4)

    sign_in(@user)
    get wishlist_items_path, params: { user_id: @outro.id }

    assert_response :success
    assert_select ".wishlist-item", 0
  end

  # --- Req. 6.4 / COL-04: anônimo é redirecionado ---
  #
  # O controller **não** declara `allow_unauthenticated_access`: o default de
  # `ApplicationController` exige sessão, e o anônimo é barrado antes da action
  # rodar. O esperado é 302, nunca 200 com lista vazia.

  test "anônimo é redirecionado ao pedir a lista" do
    get wishlist_items_path

    assert_redirected_to new_session_path
  end

  test "anônimo não consegue marcar desejo" do
    assert_no_difference -> { WishlistItem.count } do
      post wishlist_items_path, params: { card_variant_id: @base.id, target_quantity: 2 }
    end

    assert_redirected_to new_session_path
  end

  test "anônimo não consegue remover desejo" do
    item = WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 2)

    assert_no_difference -> { WishlistItem.count } do
      delete wishlist_item_path(item)
    end

    assert_redirected_to new_session_path
    assert WishlistItem.exists?(item.id)
  end

  # --- A lista não faz N+1 ---
  #
  # `with_fulfillment` resolve posse pelo `LEFT JOIN` e variante e carta pelo
  # `includes`, tudo antes do loop. A asserção é de **constância**, não de
  # orçamento: o número de consultas com 2 itens tem que ser o mesmo que com 8.
  #
  # Um teto fixo ("no máximo N consultas") seria pior por duas razões. Ele
  # depende de quanto o layout e a sessão consultam, que não é assunto desta
  # task; e um N+1 real passaria por ele sempre que o teto fosse generoso o
  # bastante. Comparar duas listas de tamanhos diferentes isola exatamente o
  # que importa: consulta que **cresce com o número de itens**.
  test "a lista não consulta o banco uma vez por item" do
    semear_desejos(2, prefixo: "p")
    sign_in

    # A primeira medição é descartada: ela carrega o cache de esquema e a
    # sessão, que não têm nada a ver com o número de itens.
    contar_consultas { get wishlist_items_path }

    com_dois = contar_consultas { get wishlist_items_path }
    assert_select ".wishlist-item", 2

    semear_desejos(6, prefixo: "q")
    com_oito = contar_consultas { get wishlist_items_path }
    assert_select ".wishlist-item", 8

    assert_equal com_dois, com_oito,
      "quadruplicar os itens não pode aumentar o número de consultas: " \
      "#{com_dois} com 2 itens, #{com_oito} com 8"
  end

  def semear_desejos(quantidade, prefixo:)
    quantidade.times do |i|
      card = create_card(number: "WL13-#{prefixo}#{i}", name: "Carta #{prefixo}#{i}")
      variante = create_variant(card, "WL13-#{prefixo}#{i}")
      WishlistItem.create!(user: @user, card_variant: variante, target_quantity: i + 1)
      CollectionItem.create!(user: @user, card_variant: variante, quantity: i)
    end
  end

  def contar_consultas
    total = 0
    contador = ->(_name, _start, _finish, _id, payload) do
      total += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
    end

    ActiveSupport::Notifications.subscribed(contador, "sql.active_record") { yield }
    total
  end

  # --- Navegação ---

  test "o cabeçalho leva à lista de desejos para quem tem sessão" do
    sign_in
    get catalog_path

    assert_select "a[href=?]", wishlist_items_path, text: "Lista de desejos"
  end

  test "o anônimo não vê a entrada da lista de desejos" do
    get catalog_path

    assert_response :success
    assert_select "a[href=?]", wishlist_items_path, count: 0
  end
end
