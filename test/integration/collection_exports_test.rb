require "test_helper"
require "csv"

# T6 — rota e action de export, com sessão exigida (POR-03 / Req. 6.4, 6.5).
#
# O recorte é **HTTP**, não serialização: o conteúdo do arquivo já está provado
# por unidade em `test/services/collection_csv/export_test.rb` (T5) e o contrato
# de colunas em `format_test.rb` (T4). Aqui prova-se o que só a resposta pode
# provar — que o anônimo não recebe arquivo nenhum, que o corpo entregue é o da
# coleção de quem está na sessão, que o navegador é instruído a baixar em vez de
# exibir, e que o acento sobrevive à travessia HTTP e não só ao `CSV.generate`.
#
# ## O cenário é construído para discriminar
#
# Os dois usuários possuem variantes **disjuntas**, e o nome da carta de cada um
# é diferente. Com qualquer carta em comum, um vazamento de usuário poderia
# passar despercebido: a asserção seria satisfeita pela linha errada. Aqui
# qualquer troca de dono muda o conjunto inteiro de linhas.
class CollectionExportsTest < ActionDispatch::IntegrationTest
  PASSWORD = "grand-line-88".freeze

  setup do
    @nami = User.create!(email: "nami-por6@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-por6@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OPp6x", name: "Romance Dawn", kind: "booster",
                           base_set_size: 4, total_set_size: 4)

    # O acento vive no dado de `@nami` de propósito: é o mesmo registro que o
    # teste de codificação lê, então uma resposta que corrompesse o UTF-8
    # derrubaria também a asserção de conteúdo.
    @da_nami = variant("p6n1", "Bell-mère")
    @outra_da_nami = variant("p6n2", "Nefertari Vivi")
    @do_zoro = variant("p6z1", "Roronoa Zoro")

    own(@nami, @da_nami, 3)
    own(@nami, @outra_da_nami, 1)
    own(@zoro, @do_zoro, 2)
  end

  # A suíte roda em paralelo e o projeto não usa fixtures YAML: cada arquivo
  # cria os próprios registros, com chaves naturais distintas para não colidir
  # entre workers.
  def variant(suffix, card_name)
    card = Card.create!(card_set: @set, card_number: "OP06-#{suffix}", name: card_name,
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: @set, variant_code: suffix,
                        rarity: "C", art_kind: "base")
  end

  def own(user, card_variant, quantity)
    CollectionItem.create!(user: user, card_variant: card_variant, quantity: quantity)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def sign_out
    delete session_path
  end

  # As linhas de dado do corpo da resposta, lidas pelo mesmo parser que o import
  # usará. Ler por parser e não por `include?` é o que impede uma asserção de
  # passar por acaso quando o nome de uma carta é substring de outra coisa.
  def linhas_do_corpo
    CSV.parse(response.body, headers: true, col_sep: CollectionCsv::Format::DELIMITER)
  end

  # --- Sessão exigida: o anônimo não recebe arquivo ---

  # A prova central de POR-03. O default de `ApplicationController` roda o
  # `before_action :require_authentication` **antes** da action, então nenhuma
  # consulta à coleção chega a acontecer. Um `allow_unauthenticated_access`
  # acrescentado ao controller mata este teste.
  test "anônimo é redirecionado para a autenticação e não recebe arquivo" do
    get collection_export_path

    assert_redirected_to new_session_path
    assert_nil response.headers["Content-Disposition"],
               "um redirect não pode vir com instrução de download"
  end

  # O critério irmão do anterior, e o que ele não cobre: não basta o status ser
  # 302, o **corpo** não pode conter linha de coleção nenhuma. Um controller que
  # renderizasse o CSV e só depois redirecionasse deixaria o dado no corpo.
  test "o corpo da resposta anônima não contém nenhuma linha de coleção" do
    get collection_export_path

    corpo = response.body
    assert_not_includes corpo, "Bell-mère"
    assert_not_includes corpo, "Nefertari Vivi"
    assert_not_includes corpo, "Roronoa Zoro"
    assert_not_includes corpo, @da_nami.variant_code
    assert_not_includes corpo, @do_zoro.variant_code
    assert_not_includes corpo, CollectionCsv::Format.header_row.join(CollectionCsv::Format::DELIMITER),
                        "nem o cabeçalho do formato: a action não chegou a rodar"
  end

  # Seguir o redirect leva à tela de login, não ao arquivo. Fecha a porta de uma
  # implementação que redirecionasse para a própria rota de export.
  test "seguir o redirect do anônimo leva à autenticação, não ao arquivo" do
    get collection_export_path
    follow_redirect!

    assert_response :success
    assert_no_match(/text\/csv/, response.media_type)
  end

  # --- Resposta autenticada: tipo, download e nome de arquivo ---

  test "a resposta autenticada é CSV e vem como anexo com nome de arquivo" do
    sign_in(@nami)

    get collection_export_path

    assert_response :success
    assert_equal "text/csv", response.media_type
    disposition = response.headers["Content-Disposition"]
    assert_match(/\Aattachment;/, disposition,
                 "o arquivo é para baixar, não para o navegador exibir")
    assert_match(/filename=/, disposition)
    assert_match(/\.csv/, disposition)
  end

  # O nome do arquivo não pode carregar dado do usuário. É o critério de
  # privacidade da task: um arquivo baixado circula em pasta de downloads,
  # anexo de e-mail e print de tela.
  test "o nome do arquivo não carrega e-mail nem id do usuário" do
    sign_in(@nami)

    get collection_export_path

    disposition = response.headers["Content-Disposition"]
    assert_not_includes disposition, @nami.email
    assert_not_includes disposition, @nami.id.to_s
  end

  # --- O conteúdo entregue é o da coleção de `Current.user` ---

  test "o corpo entregue é a coleção do usuário da sessão" do
    sign_in(@nami)

    get collection_export_path

    tabela = linhas_do_corpo
    assert_equal CollectionCsv::Format::COLUMNS, tabela.headers
    assert_equal [ @da_nami.variant_code, @outra_da_nami.variant_code ].sort,
                 tabela.map { |linha| linha["variant_code"] }.sort
    assert_equal [ "1", "3" ], tabela.map { |linha| linha["quantity"] }.sort
  end

  # A direção oposta, em teste próprio: nenhuma linha de `@zoro` aparece para
  # `@nami`. As posses são disjuntas, então um recorte de usuário perdido
  # acrescenta linha em vez de deixar o conjunto intacto.
  test "a coleção de outro usuário não aparece no arquivo entregue" do
    sign_in(@nami)

    get collection_export_path

    codigos = linhas_do_corpo.map { |linha| linha["variant_code"] }
    assert_not_includes codigos, @do_zoro.variant_code
    assert_not_includes response.body, "Roronoa Zoro"
  end

  # Trocar de sessão na mesma conexão troca o dono do arquivo. Um controller que
  # memorizasse o usuário em vida mais longa que a requisição devolveria o
  # arquivo do primeiro na segunda requisição.
  test "trocar de sessão na mesma conexão troca o dono do arquivo" do
    sign_in(@nami)
    get collection_export_path
    assert_equal 2, linhas_do_corpo.size

    sign_out

    sign_in(@zoro)
    get collection_export_path

    tabela = linhas_do_corpo
    assert_equal 1, tabela.size
    assert_equal @do_zoro.variant_code, tabela.first["variant_code"]
  end

  # --- Req. 6.5: nada vindo do request desloca o dono ---

  # O parâmetro é inócuo **por desenho**: não existe caminho que o leia. A
  # asserção é a igualdade byte a byte entre o arquivo com e sem parâmetro — um
  # `?user_id=` que valesse mudaria o corpo inteiro, já que as posses são
  # disjuntas.
  test "?user_id= de outro usuário não muda o arquivo entregue" do
    sign_in(@nami)

    get collection_export_path
    sem_parametro = response.body

    get collection_export_path(user_id: @zoro.id)

    assert_response :success
    assert_equal sem_parametro, response.body,
                 "o arquivo é o do usuário da sessão, não o do parâmetro"
  end

  # As outras portas pelas quais alguém tentaria informar um usuário. Nenhuma
  # pode deslocar o dono, e nenhuma pode quebrar a resposta: parâmetro
  # desconhecido é ignorado, nunca causa erro.
  test "nenhuma forma de informar identificador desloca o dono do arquivo" do
    sign_in(@nami)

    get collection_export_path
    esperado = response.body

    tentativas = [
      { user_id: @zoro.id },
      { user: @zoro.id },
      { id: @zoro.id },
      { user_id: @zoro.email },
      { user_id: [ @nami.id, @zoro.id ] },
      { user_id: { id: @zoro.id } }
    ]

    tentativas.each do |params|
      get collection_export_path, params: params

      assert_response :success, "#{params.inspect} não pode quebrar o download"
      assert_equal esperado, response.body, "#{params.inspect} deslocou o dono do arquivo"
    end
  end

  # Cabeçalho é request tanto quanto query string, e é a porta que um teste de
  # `params` não cobre.
  test "cabeçalho de requisição informando usuário não desloca o dono do arquivo" do
    sign_in(@nami)

    get collection_export_path
    esperado = response.body

    get collection_export_path, headers: { "X-User-Id" => @zoro.id.to_s, "X-User" => @zoro.email }

    assert_response :success
    assert_equal esperado, response.body
  end

  # --- Prova estrutural: o caminho errado não existe, em vez de não ser usado ---

  # Nenhum identificador de usuário cabe na URL do export — é o que torna
  # `?user_id=` inócuo por desenho e não por checagem. Acrescentar um segmento
  # dinâmico à rota quebra esta asserção e obriga quem o fizer a enfrentar a
  # decisão (Req. 6.5).
  #
  # O casamento é por **sufixo** e não por igualdade: uma rota futura sob
  # namespace (`api/collection_exports`) apontaria para a mesma feature e
  # escaparia de um `== "collection_exports"`.
  test "nenhuma rota de export aceita segmento dinâmico" do
    rotas = Rails.application.routes.routes.select do |rota|
      rota.defaults[:controller].to_s.split("/").last == "collection_exports"
    end

    assert_not_empty rotas, "a T6 entrega a rota de export; se sumiu, a suíte precisa saber"

    rotas.each do |rota|
      assert_empty rota.path.required_names,
                   "#{rota.path.spec} aceita #{rota.path.required_names.inspect}: " \
                   "nenhum identificador pode caber na URL do export"
    end
  end

  # A porta complementar: não basta a rota declarada hoje não ter segmento —
  # uma URL com id não pode **resolver** para o export por nenhum caminho.
  #
  # O `rescue` devolve `nil` em vez de engolir em silêncio, e a asserção roda
  # sempre: não reconhecer a URL e reconhecê-la como outra coisa são os dois
  # resultados aceitáveis, chegar ao export não é. Com o `rescue` vazio o teste
  # não teria asserção nenhuma e passaria mesmo que a rota com id existisse.
  test "uma URL com id de usuário não resolve para o export" do
    caminhos = [
      "#{collection_export_path}/#{@zoro.id}",
      "/collection_exports/#{@zoro.id}",
      "/collection/#{@zoro.id}/export"
    ]

    caminhos.each do |caminho|
      destino = begin
        Rails.application.routes.recognize_path(caminho, method: :get)
      rescue ActionController::RoutingError
        nil
      end

      assert_not_equal "collection_exports", destino&.fetch(:controller, nil),
                       "#{caminho} não pode chegar ao export"
    end
  end

  # --- POR-01: o acento sobrevive à travessia HTTP ---

  # O teste de unidade da T5 prova que `CSV.generate` preserva o acento. O que
  # ele **não** pode provar é que o acento chega íntegro ao cliente: a resposta
  # passa por `send_data`, por declaração de charset e pela codificação do corpo
  # do Rack. Uma resposta sem charset declarado, ou com o corpo forçado a
  # ASCII-8BIT, corrompe o nome sem que nenhum teste de serviço perceba.
  test "o acento sobrevive à resposta HTTP, não só à serialização" do
    sign_in(@nami)

    get collection_export_path

    corpo = response.body.dup.force_encoding(Encoding::UTF_8)
    assert corpo.valid_encoding?, "o corpo entregue precisa ser UTF-8 válido"
    assert_includes corpo, "Bell-mère"
    assert_equal "Bell-mère",
                 CSV.parse(corpo, headers: true,
                                  col_sep: CollectionCsv::Format::DELIMITER)
                    .find { |linha| linha["variant_code"] == @da_nami.variant_code }["card_name"]
  end

  # O charset declarado no `Content-Type` é o que diz ao cliente como ler os
  # bytes. Sem ele, uma planilha configurada em Latin-1 lê `Bell-mère`.
  test "o Content-Type declara UTF-8" do
    sign_in(@nami)

    get collection_export_path

    assert_match(/charset=utf-8/i, response.headers["Content-Type"])
  end

  # --- Invariante da feature: o export não escreve na coleção (Req. 10.5) ---

  # O export é leitura pura. Um `update`/`create` que entrasse no controller por
  # descuido — registrar "último export", marcar item como exportado — violaria
  # a invariante da feature mesmo sem intenção de dano.
  test "baixar o arquivo não altera nem cria nenhum registro de coleção" do
    sign_in(@nami)
    antes = CollectionItem.order(:id).pluck(:id, :user_id, :card_variant_id, :quantity)

    assert_no_difference -> { CollectionItem.count } do
      get collection_export_path
    end

    assert_response :success
    assert_equal antes, CollectionItem.order(:id).pluck(:id, :user_id, :card_variant_id, :quantity),
                 "o export é leitura pura: nenhuma quantidade pode mudar"
  end
end
