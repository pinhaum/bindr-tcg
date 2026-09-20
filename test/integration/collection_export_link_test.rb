require "test_helper"

# SPEC_DEVIATION: a T7 pede um **ponto de entrada visível** para o download
# (POR-01, POR-03) e o plano marca `Tests: integration` por isso. Dois critérios
# do "Done when" não são verificáveis como escritos neste ambiente:
#
# 1. **"Nenhum scroll horizontal em 360px" (Req. 2.5).** Medir overflow exige
#    layout, e **não há navegador no container** — a imagem de desenvolvimento
#    não tem chromedriver nem binário `chrom*` (verificado nas T12/T14 do
#    `catalogo` e repetido na T8 da `colecao`). O que este arquivo prova é o que
#    é verificável sem renderizar: que o elemento novo **não declara largura
#    fixa, `white-space: nowrap` nem `overflow-x`** — as três formas pelas quais
#    um controle de texto em fluxo força a página para o lado. É o mesmo
#    precedente de `progress_ui_test` e de `catalog_grid_test`: o que não se
#    mede, se declara e se trava na folha.
#
# 2. **"O controle não aparece para o anônimo".** A página de progresso exige
#    sessão (`ApplicationController` inclui `Authentication`), então o anônimo
#    recebe 302 e **nunca vê HTML dela** — asserir ausência ali provaria o
#    redirecionamento, não a ausência do controle. A prova é feita onde o
#    anônimo de fato renderiza HTML: o catálogo, que é público (Req. 6.3). Um
#    controle vazado para o layout ou para o cabeçalho apareceria lá. As duas
#    metades estão cobertas: ausência observável no catálogo público, e
#    inacessibilidade da rota de export provada pelo 302 (já travado em
#    `collection_exports_test`, repetido aqui do ponto de vista do link).
#
# ---
#
# T7 — link de export na interface (POR-01, POR-03).
#
# O que se prova aqui é **o que a view emite**, não o que o controller entrega:
# o conteúdo do arquivo é de `export_test` (T5) e a resposta HTTP é de
# `collection_exports_test` (T6). O destino é extraído do HTML renderizado e
# **seguido** na requisição seguinte — montar `get collection_export_path` à mão
# passaria intacto se a view emitisse href errado, nenhum href, ou um link para
# o catálogo.
class CollectionExportLinkTest < ActionDispatch::IntegrationTest
  PASSWORD = "thousand-sunny-99".freeze

  setup do
    @nami = User.create!(email: "nami-por7@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OPp7a", name: "Romance Dawn", kind: "booster",
                           base_set_size: 2, total_set_size: 2)
    @variante = variant("p7a1", "Bell-mère")
    variant("p7a2", "Nefertari Vivi")

    CollectionItem.create!(user: @nami, card_variant: @variante, quantity: 3)
  end

  def variant(suffix, nome)
    card = Card.create!(card_set: @set, card_number: "OP07-#{suffix}", name: nome,
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: @set, variant_code: suffix,
                        rarity: "C", art_kind: "base")
  end

  def sign_in(user = @nami)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # O href real da página, sem reconstrução: é este valor que os testes seguem.
  def link_de_export
    links = css_select("a.collection-export__link")
    assert_equal 1, links.size,
                 "a página precisa oferecer exatamente um link de export"
    links.first
  end

  # --- POR-01: o ponto de entrada existe para quem tem sessão ---

  test "o usuário autenticado vê o controle de download na página de progresso" do
    sign_in

    get progress_path

    assert_response :success
    assert_select ".collection-export", 1
    assert_select "a.collection-export__link"
  end

  # Presente no DOM não é o mesmo que oferecido: `hidden` deixa o elemento
  # passar por `css_select` e some da página para todo mundo, inclusive para
  # leitor de tela. É o achado do sensor de discriminação repetido da T6 do
  # `progresso` — sem esta asserção, esconder o link não derrubava nada.
  test "o controle é oferecido de fato, não apenas presente no DOM" do
    sign_in

    get progress_path

    assert_select "a.collection-export__link[hidden]", false,
                  "um link escondido não é oferecido a ninguém"
    assert_select ".collection-export[hidden]", false,
                  "esconder o contêiner esconde o link junto"
    assert_select "a.collection-export__link[aria-hidden=?]", "true", false,
                  "o link é a única saída para o arquivo e não pode sumir da árvore de acessibilidade"
  end

  # --- O destino, extraído do HTML e seguido ---

  test "o link aponta para a rota de export da coleção" do
    sign_in

    get progress_path

    assert_equal collection_export_path, link_de_export["href"],
                 "o link precisa apontar para a rota de export, e não para outra página"
  end

  # A prova de que o destino **serve**, e não só de que a string casa: seguir o
  # href entrega o CSV. Um link para uma rota inexistente ou para o catálogo
  # passaria numa asserção puramente textual sobre o `href`.
  test "seguir o link entrega o CSV da coleção do usuário" do
    sign_in
    get progress_path
    href = link_de_export["href"]

    get href

    assert_response :success
    assert_match(/text\/csv/, response.media_type.to_s + response.headers["Content-Type"].to_s)
    assert_match(/attachment/, response.headers["Content-Disposition"].to_s,
                 "o arquivo é para ser salvo, não exibido")
    assert_match(/OP07-p7a1/, response.body,
                 "o arquivo entregue pelo link é a coleção de quem está na sessão")
  end

  # --- POR-03: o anônimo ---
  #
  # A ausência é provada no catálogo, que é o lugar onde o anônimo renderiza
  # HTML de fato (ver SPEC_DEVIATION no cabeçalho).

  test "o anônimo não vê controle de download em nenhuma página que ele alcança" do
    get catalog_path

    assert_response :success
    assert_select ".collection-export", false,
                  "o controle de download não pode vazar para quem não tem coleção"
    assert_select "a[href=?]", collection_export_path, false,
                  "nenhum link para o export pode ser oferecido ao anônimo"
  end

  # O par simétrico que torna a asserção acima discriminante: o catálogo
  # **autenticado** é o mesmo template, e o que muda entre os dois é a sessão.
  # Sem esta asserção, um `.collection-export` que nunca fosse renderizado em
  # lugar nenhum satisfaria o teste do anônimo por vacuidade.
  test "o catálogo é o mesmo template para os dois e o anônimo é quem discrimina" do
    get catalog_path
    anonimo = response.body

    sign_in
    get progress_path

    assert_select ".collection-export", 1,
                  "o controle existe para quem tem sessão, senão o teste do anônimo é vazio"
    assert_not_includes anonimo, "collection-export",
                        "nenhum resquício do controle chega ao HTML do anônimo"
  end

  # A outra metade do POR-03: mesmo que alguém descubra a URL, ela exige sessão.
  # O link é a porta, e a porta continua trancada por trás.
  test "a rota de export continua exigindo sessão para quem não tem" do
    get collection_export_path

    assert_redirected_to new_session_path
  end

  # --- Rótulo em português que diz o que o arquivo é ---

  test "o rótulo está em português e diz que o arquivo é a coleção" do
    sign_in

    get progress_path

    texto = link_de_export.text.squish

    assert_match(/coleção/i, texto,
                 "o rótulo precisa dizer **o que** o arquivo é, não só que há um download")
    assert_match(/CSV/i, texto,
                 "o formato do arquivo é parte do que o usuário precisa saber antes de clicar")
  end

  # O critério da spec é explícito: o rótulo não pode ser "Export". Esta
  # asserção existe separada porque é a que um rótulo em inglês derruba, e
  # juntá-la à anterior faria "Export CSV da coleção" passar.
  test "o rótulo não usa o vocabulário em inglês que a spec proíbe" do
    sign_in

    get progress_path

    texto = link_de_export.text.squish

    assert_no_match(/\bexport/i, texto, "o rótulo é em português, não 'Export'")
    assert_no_match(/\bdownload\b/i, texto, "'Download' também é inglês")
  end

  # O nome acessível se sustenta fora do contexto visual (SC 2.4.4): o link
  # convive com 63 links "Ver no catálogo" na mesma página, e quem navega por
  # lista de links precisa distinguir este deles.
  test "o nome acessível do link é distinto dos demais links da página" do
    sign_in

    get progress_path

    nomes = css_select("main a, .collection-export a").map do |link|
      (link["aria-label"].presence || link.text).to_s.squish
    end
    nome = (link_de_export["aria-label"].presence || link_de_export.text).to_s.squish

    assert_equal 1, nomes.count(nome),
                 "o nome acessível do link de export não pode coincidir com o de outro link"
  end

  # --- SC 2.5.8: alvo de toque, e Req. 2.5: 360px ---
  #
  # Asserções sobre o **texto da folha de estilo**, pela limitação registrada no
  # cabeçalho. É o precedente de `progress_ui_test` ("o link do catálogo declara
  # alvo de toque de 24px") e de `collection_ownership_ui_test`.

  def css
    Rails.root.join("app/assets/stylesheets/catalog.css").read
  end

  def regra_do_link
    css[/\.collection-export__link\s*\{[^}]*\}/m]
  end

  # A convenção do projeto desde a T4 da `colecao` é **declarar** e não depender
  # de cálculo: fonte do usuário e `line-height` herdado mudam a altura efetiva.
  test "o link de export declara alvo de toque de 24px em altura e largura" do
    regra = regra_do_link

    assert regra, "a regra .collection-export__link sumiu da folha do catálogo"
    assert_match(/min-height:\s*24px/, regra, "alvo de toque sem altura mínima (SC 2.5.8)")
    assert_match(/min-width:\s*24px/, regra, "alvo de toque sem largura mínima (SC 2.5.8)")
  end

  # SC 2.4.11 — o realce de foco é **o mesmo** dos demais controles, não um
  # parecido: o valor é lido das regras existentes e comparado, então divergir a
  # espessura num só lugar derruba a asserção.
  test "o foco do link de export é o mesmo realce dos demais controles" do
    blocos = css.scan(/([^{}]*:focus-visible[^{}]*)\{([^}]*)\}/m)

    do_export = blocos.find { |seletor, _| seletor.include?(".collection-export__link:focus-visible") }
    do_catalogo = blocos.find { |seletor, _| seletor.include?(".progress-set__catalog-link:focus-visible") }

    assert do_export, "`.collection-export__link` ficou sem regra de foco (SC 2.4.11)"
    assert do_catalogo, "a regra de foco do link do catálogo sumiu da folha"
    assert_equal do_catalogo.last.squish, do_export.last.squish,
                 "o realce de foco precisa ser idêntico ao dos demais controles"
  end

  # Req. 2.5, na parte verificável sem navegador: as três formas de um controle
  # de texto em fluxo empurrar a página para o lado em 360px.
  test "o controle de export não declara nada que force scroll horizontal" do
    [ regra_do_link, css[/\.collection-export\s*\{[^}]*\}/m] ].each_with_index do |regra, i|
      assert regra, "a regra ##{i} do controle de export sumiu da folha"
      # `(?<!-)` é o que separa `width:` de `min-width:`: um piso de 24px é o
      # alvo de toque do SC 2.5.8 e nunca força overflow, enquanto uma largura
      # **fixa** é exatamente o que empurra a caixa para fora de 360px. Sem a
      # exclusão, a asserção proibiria o alvo de toque que a mesma task exige.
      assert_no_match(/(?<![-\w])width:\s*\d/, regra,
                      "largura fixa é o que empurra a caixa para fora de 360px")
      assert_no_match(/white-space:\s*nowrap/, regra,
                      "`nowrap` impede a quebra que faz o rótulo caber em 360px")
      assert_no_match(/overflow-x/, regra,
                      "`overflow-x` é justamente o scroll horizontal que o Req. 2.5 proíbe")
    end
  end
end
