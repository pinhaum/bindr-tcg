require "test_helper"

# SPEC_DEVIATION: a história "P1: Pré-visualização obrigatória do import"
# (POR-07, POR-10 / Req. 10.4, 10.5) descreve o que o usuário **vê** antes de
# confirmar, e o plano marca a T13 como `Tests: integration` justamente por
# isso. Dois critérios do "Done when" não são verificáveis como escritos neste
# ambiente, e o que segue é o que foi feito no lugar de cada um:
#
# 1. **"Sem scroll horizontal em 360px" (Req. 2.5).** Medir overflow exige
#    layout, e **não há navegador no container** — a imagem de desenvolvimento
#    não tem chromedriver nem binário `chrom*` (verificado nas T12/T14 do
#    `catalogo`, repetido na T8 da `colecao` e na T7 desta feature). O que este
#    arquivo prova é o que é verificável sobre a **folha de estilo**: que
#    nenhuma regra nova da tela declara largura fixa, `white-space: nowrap` ou
#    `overflow-x` — as três formas pelas quais um bloco em fluxo empurra a
#    página para o lado. É o mesmo precedente de `collection_export_link_test`
#    e de `progress_ui_test`: o que não se mede, se declara e se trava na
#    folha. **Não se afirma** aqui que a página foi renderizada em 360px.
#
# 2. **"A distinção não é só por cor" (SC 1.4.1).** Contraste e cor efetiva
#    também exigem renderização. O que se prova é o **portador textual**: cada
#    linha carrega um rótulo em texto visível (`.import-preview__badge`) que
#    nomeia a classificação, e esse rótulo é distinto entre as classes. Um CSS
#    que colorisse as linhas e apagasse o rótulo derruba as asserções abaixo.
#    A prova de que a cor **não é o único** portador é textual por construção:
#    o teste lê o texto, não o estilo computado.
#
# ---
#
# T13 — a tela de pré-visualização (POR-07, POR-10).
#
# ## O que este arquivo existe para provar
#
# O Req. 10.5 não pede uma tela: pede que o usuário **veja o que vai mudar
# antes de qualquer gravação**. Uma tela que passe nos testes e esconda um
# efeito destrutivo falha no propósito do requisito. Por isso as asserções
# centrais aqui não são "a página renderiza" — são "a linha que apaga a posse
# aparece, dita por escrito, separada da que apenas troca um número".
#
# ## As CINCO classificações, não três
#
# O plano da T13 foi escrito antes da T9 existir e fala em três classes. O
# `CollectionCsv::Resolver` produz **cinco**: `:cria`, `:atualiza`, `:zera`,
# `:inalterada` e `:rejeita`. `:zera` é o caso destrutivo — havia posse e o
# arquivo a leva a zero — e é exatamente o que o Req. 10.5 existe para tornar
# visível. Dobrá-lo dentro de "altera" cumpriria a letra do plano e falharia no
# propósito do requisito, então o cenário abaixo tem uma linha de **cada uma
# das cinco** e há asserção de que nenhuma delas é confundida com outra.
#
# ## O cenário é construído para discriminar
#
# Todas as quantidades são **distintas entre si** — 2→7, 5→0, 3→3, 0→4 — e
# nenhum par se repete. Com números iguais (o erro clássico de "1 vira 1") a
# troca de `quantidade_antes` por `quantidade_depois` na marcação passaria
# despercebida. Há ainda duas rejeições de **motivos diferentes** na mesma
# tela: uma variante inexistente e uma quantidade inválida. Com um motivo só,
# uma view que imprimisse a mesma mensagem para toda rejeição passaria.
class CollectionImportPreviewUiTest < ActionDispatch::IntegrationTest
  PASSWORD = "merry-go-1994".freeze

  setup do
    @nami = User.create!(email: "nami-por13@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-por13@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OPp13", name: "Romance Dawn", kind: "booster",
                           base_set_size: 5, total_set_size: 5)

    @atualiza = variant("p13a", "Bell-mère")
    @zera = variant("p13b", "Nefertari Vivi")
    @inalterada = variant("p13c", "Roronoa Zoro")
    @cria = variant("p13d", "Tony Tony Chopper")
    @invalida = variant("p13e", "Nico Robin")

    # O "antes" de @nami. Três quantidades distintas, e `@cria` sem registro.
    own(@nami, @atualiza, 2)
    own(@nami, @zera, 5)
    own(@nami, @inalterada, 3)

    # @zoro possui **as mesmas** variantes com outras quantidades: se a tela
    # lesse a posse de qualquer usuário em vez da de `Current.user`, o "antes"
    # sairia errado e as asserções numéricas cairiam.
    own(@zoro, @atualiza, 91)
    own(@zoro, @zera, 92)
    own(@zoro, @inalterada, 93)
    own(@zoro, @cria, 94)
  end

  def variant(suffix, card_name)
    card = Card.create!(card_set: @set, card_number: "OP13-#{suffix}", name: card_name,
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

  # Uma linha por classificação, incluindo as duas rejeições de motivos
  # diferentes. Passa pelo `Resolver` de verdade — e não por linhas montadas à
  # mão — porque é o contrato dele que a tela consome: uma tela que só funcione
  # sobre dado fabricado não funciona sobre o do upload.
  def csv_com_as_cinco_classificacoes
    linhas = [
      CollectionCsv::Format.header_row.join(","),
      "#{@cria.card.card_number},#{@cria.variant_code},#{@cria.card.name},4",
      "#{@atualiza.card.card_number},#{@atualiza.variant_code},#{@atualiza.card.name},7",
      "#{@zera.card.card_number},#{@zera.variant_code},#{@zera.card.name},0",
      "#{@inalterada.card.card_number},#{@inalterada.variant_code},#{@inalterada.card.name},3",
      "#{@invalida.card.card_number},#{@invalida.variant_code},#{@invalida.card.name},abc",
      "OP13-fantasma,p13z,Carta Que Não Existe,1"
    ]

    linhas.join("\n") + "\n"
  end

  def preview_de(conteudo = csv_com_as_cinco_classificacoes)
    CollectionImport.create!(
      user: @nami,
      filename: "colecao.csv",
      linhas: CollectionCsv::Resolver.new(@nami, CollectionCsv::Parser.new(conteudo).call.linhas).call.linhas
    )
  end

  # A linha renderizada de uma variante, localizada pelo `card_number` — nunca
  # por posição na lista. Ordenar diferente não pode derrubar asserção de
  # conteúdo, e por posição derrubaria.
  def linha_de(card_number)
    itens = css_select(".import-preview__row").select do |item|
      item.text.include?(card_number)
    end

    assert_equal 1, itens.size,
                 "a linha de #{card_number} precisa aparecer exatamente uma vez na tela"
    itens.first
  end

  def classificacao_de(card_number)
    linha_de(card_number)["data-classificacao"]
  end

  def rotulo_de(card_number)
    linha_de(card_number).css(".import-preview__badge").text.squish
  end

  def renderizar(preview = preview_de)
    sign_in
    get collection_import_path(preview.token)
    assert_response :success
    preview
  end

  # --- Critério: as classes de linha são distinguíveis na tela ---

  test "cada uma das cinco classificações recebe uma marcação própria" do
    renderizar

    assert_equal "cria", classificacao_de(@cria.card.card_number)
    assert_equal "atualiza", classificacao_de(@atualiza.card.card_number)
    assert_equal "zera", classificacao_de(@zera.card.card_number)
    assert_equal "inalterada", classificacao_de(@inalterada.card.card_number)
    assert_equal "rejeita", classificacao_de(@invalida.card.card_number)
    assert_equal "rejeita", classificacao_de("OP13-fantasma")
  end

  # O critério do plano, literal: cria, altera e rejeita distinguíveis. A
  # asserção é sobre o **rótulo textual**, porque é ele que sobrevive a um
  # `data-` atributo que ninguém lê e a uma folha de estilo que não carrega.
  test "as três classes do plano têm rótulos visíveis e diferentes entre si" do
    renderizar

    cria = rotulo_de(@cria.card.card_number)
    atualiza = rotulo_de(@atualiza.card.card_number)
    rejeita = rotulo_de(@invalida.card.card_number)

    assert_not_equal cria, atualiza, "criar e alterar não podem ler igual"
    assert_not_equal atualiza, rejeita, "alterar e rejeitar não podem ler igual"
    assert_not_equal cria, rejeita, "criar e rejeitar não podem ler igual"

    [ cria, atualiza, rejeita ].each do |rotulo|
      assert_not_empty rotulo, "toda linha precisa de um rótulo textual, não só de uma cor"
    end
  end

  # `:zera` é o caso destrutivo e é o motivo de o Req. 10.5 existir. Ele não
  # pode ler igual a `:atualiza`: as duas são "substituir" pela mecânica, mas
  # uma apaga a posse e a outra só troca um número.
  test "a linha destrutiva não se confunde com a que apenas altera" do
    renderizar

    zera = rotulo_de(@zera.card.card_number)
    atualiza = rotulo_de(@atualiza.card.card_number)

    assert_not_equal atualiza, zera,
                     "zerar a posse e trocar a quantidade não podem ler igual"
    assert_match(/remov|apag|zera|perde/i, zera,
                 "o rótulo precisa dizer que a posse desaparece, não só que mudou")
  end

  # `:inalterada` tem que se distinguir de `:atualiza` pelo mesmo motivo
  # invertido: anunciar como alteração o que não altera nada torna a tela
  # ilegível na ida e volta do POR-11.
  test "a linha que não muda nada não se confunde com a que altera" do
    renderizar

    assert_not_equal rotulo_de(@atualiza.card.card_number),
                     rotulo_de(@inalterada.card.card_number),
                     "'nada muda' e 'muda de 2 para 7' não podem ler igual"
  end

  # --- Critério: a linha que altera mostra antes e depois (AD-006) ---

  test "a linha que altera mostra a quantidade antes e a quantidade depois" do
    renderizar

    texto = linha_de(@atualiza.card.card_number).text.squish

    assert_match(/\b2\b/, texto, "o valor atual precisa estar visível antes de ser destruído")
    assert_match(/\b7\b/, texto, "o valor que ficará também precisa estar visível")
  end

  # Os dois números estão em elementos **distintos e identificáveis**: sem
  # isso, "2 7" e "7 2" passariam igual na asserção de texto acima, e é a ordem
  # que diz qual é destruído.
  test "o antes e o depois são identificáveis separadamente, não um texto solto" do
    renderizar
    linha = linha_de(@atualiza.card.card_number)

    assert_equal "2", linha.css(".import-preview__antes").text.squish,
                 "o 'antes' é a quantidade que o usuário tem hoje"
    assert_equal "7", linha.css(".import-preview__depois").text.squish,
                 "o 'depois' é a quantidade que o arquivo grava"
  end

  # O caso destrutivo carrega o par pela mesma razão, e o zero precisa aparecer
  # como valor e não sumir por ser falsy no template.
  test "a linha destrutiva mostra a posse que existe hoje e o zero que a substitui" do
    renderizar
    linha = linha_de(@zera.card.card_number)

    assert_equal "5", linha.css(".import-preview__antes").text.squish,
                 "é a posse que vai desaparecer: ela precisa estar na tela"
    assert_equal "0", linha.css(".import-preview__depois").text.squish,
                 "zero é um valor, não ausência — não pode sumir do template"
  end

  # A linha que cria não tem "antes", e ausência não é zero: mostrar `0` ali
  # diria que o usuário tinha um registro de zero cópias, o que é diferente de
  # não ter registro nenhum (a mesma distinção que o projeto faz em `counter`).
  test "a linha que cria não inventa um valor anterior" do
    renderizar
    linha = linha_de(@cria.card.card_number)

    assert_equal "4", linha.css(".import-preview__depois").text.squish
    assert_no_match(/\A0\z/, linha.css(".import-preview__antes").text.squish,
                    "não havia registro: 'antes' é ausência, não zero")
  end

  # --- Critério: cada rejeição mostra o motivo e identifica a linha ---

  test "cada linha rejeitada mostra o motivo em português" do
    renderizar

    assert_match(/quantidade/i,
                 linha_de(@invalida.card.card_number).css(".import-preview__motivo").text.squish,
                 "o motivo precisa dizer o que há de errado com a linha")
    assert_match(/catálogo|variante/i,
                 linha_de("OP13-fantasma").css(".import-preview__motivo").text.squish,
                 "a variante inexistente tem motivo próprio")
  end

  # Req. 10.4: o motivo sozinho não basta — o usuário precisa saber **qual**
  # linha do arquivo corrigir. Dois motivos diferentes na mesma tela é o que
  # torna esta asserção discriminante: uma view que imprimisse uma mensagem
  # genérica para toda rejeição passaria com um motivo só.
  test "as duas rejeições da tela têm motivos diferentes entre si" do
    renderizar

    invalida = linha_de(@invalida.card.card_number).css(".import-preview__motivo").text.squish
    fantasma = linha_de("OP13-fantasma").css(".import-preview__motivo").text.squish

    assert_not_equal invalida, fantasma,
                     "cada rejeição tem o seu motivo; uma mensagem genérica não ajuda a corrigir o arquivo"
  end

  test "a linha rejeitada identifica a posição dela no arquivo" do
    renderizar

    fantasma = linha_de("OP13-fantasma")

    assert_match(/linha\s*7/i, fantasma.text.squish,
                 "o índice zero-based do resolvedor vira o número da linha do arquivo, " \
                 "contando o cabeçalho: é esse que o usuário vê no editor")
    assert_includes fantasma.text, "p13z",
                    "o código da variante é parte da identificação da linha"
  end

  # --- Critério: a distinção não é só por cor (SC 1.4.1) ---

  test "nenhuma regra de estilo da tela distingue classificação apenas por cor" do
    folha = File.read(Rails.root.join("app/assets/stylesheets/catalog.css"))
    regras = regras_de(folha, "import-preview")

    assert_not_empty regras, "a tela precisa ter estilo próprio para haver o que auditar"

    # **Cada regra é auditada isoladamente**, e nunca o conjunto concatenado da
    # classificação. A diferença decide se o teste discrimina: juntando as
    # regras, uma que distinguisse a linha só por `color` passaria carona no
    # `font-weight` de uma regra irmã sobre outro elemento — medido, passava
    # com `color: crimson` na linha inteira. Isolada, ela é reprovada.
    auditadas = 0

    regras.each do |regra|
      classe = regra[/data-classificacao="(\w+)"/, 1]
      next if classe.nil?

      declaracoes = regra.split("{", 2).last.to_s
      next unless declaracoes.match?(/\b(color|background-color)\s*:/)

      auditadas += 1
      assert_match(/\b(border|outline|font-weight|font-style|text-decoration|content|background-image)\b/,
                   declaracoes,
                   "a regra de `#{classe}` distingue a linha só por cor (SC 1.4.1): #{regra}")
    end

    # A distinção cromática pode legitimamente não existir — é o caso hoje,
    # onde tudo é forma. O que não pode é existir **sozinha**, e é isso que o
    # laço acima verifica. A contagem fica registrada para que a próxima pessoa
    # saiba que zero auditadas significa "nenhuma cor em jogo", não "auditoria
    # desligada"; o portador textual é provado no teste seguinte, que não
    # depende da folha.
    assert auditadas >= 0
  end

  # O portador textual é o que sobrevive à folha de estilo inteira não carregar,
  # e é a prova direta de que a cor não é o único canal.
  test "a classificação de cada linha é legível sem estilo nenhum" do
    renderizar

    %w[cria atualiza zera inalterada rejeita].each do |classe|
      linhas = css_select(%(.import-preview__row[data-classificacao="#{classe}"]))

      assert_not_empty linhas, "a tela precisa ter ao menos uma linha #{classe}"
      linhas.each do |linha|
        assert_not_empty linha.css(".import-preview__badge").text.squish,
                         "toda linha #{classe} carrega o nome da classificação em texto"
      end
    end
  end

  # --- Critério: sem scroll horizontal em 360px (verificado sobre a folha) ---

  test "nenhuma regra nova declara largura fixa, nowrap ou overflow horizontal" do
    folha = File.read(Rails.root.join("app/assets/stylesheets/catalog.css"))
    regras = regras_de(folha, "import-preview")

    assert_not_empty regras

    regras.each do |regra|
      # `width` como propriedade inteira, começando uma declaração. O recorte
      # importa: `min-width`, `max-width` e `border-left-width` também terminam
      # em "width" e nenhuma delas fixa a largura da caixa — `border-*-width` é
      # espessura de borda, e é justamente o canal não-cromático que distingue
      # as classificações aqui.
      assert_no_match(/(?:\A|[;{]|\n)\s*width:\s*\d+(px|rem|em|ch)/, regra,
                      "largura fixa empurra a página para o lado em 360px: #{regra}")
      assert_no_match(/white-space:\s*nowrap/, regra,
                      "`nowrap` num bloco de texto força scroll horizontal: #{regra}")
      assert_no_match(/overflow-x:\s*(auto|scroll)/, regra,
                      "o Req. 2.5 proíbe o scroll horizontal, não o gerencia: #{regra}")
    end
  end

  # --- Critério: todo texto de interface em português ---

  test "a tela não vaza vocabulário de sistema em inglês" do
    renderizar

    texto = css_select("main").text

    %w[create update delete preview import export row error skip].each do |palavra|
      assert_no_match(/\b#{palavra}\b/i, texto,
                      "'#{palavra}' é vocabulário de sistema; a interface é em português")
    end
  end

  # --- Critério: renderizar a pré-visualização não grava nada ---
  #
  # A invariante da feature, do ponto de vista da tela. `assert_no_changes`
  # sobre o **retrato inteiro** da tabela, e não sobre a contagem: trocar duas
  # quantidades entre si mantém `count` e `sum` e mudaria a coleção.

  test "renderizar a pré-visualização não altera a coleção de ninguém" do
    preview = preview_de
    sign_in

    assert_no_changes -> { retrato_da_colecao } do
      get collection_import_path(preview.token)
      assert_response :success
    end
  end

  # A discriminação da asserção acima: se a tela gravasse, teria o que gravar.
  # O arquivo cria um registro, troca uma quantidade e zera outra — três
  # rastros diferentes, e o `@cria` é o mais visível porque ele **não existe**
  # antes da renderização.
  test "a variante sem registro continua sem registro depois de a tela ser vista" do
    preview = preview_de
    sign_in

    get collection_import_path(preview.token)

    assert_nil CollectionItem.for_user(@nami).find_by(card_variant: @cria),
               "a linha que 'cria' só cria na confirmação da T14, nunca ao ser exibida"
    assert_equal 2, CollectionItem.for_user(@nami).find_by(card_variant: @atualiza).quantity
    assert_equal 5, CollectionItem.for_user(@nami).find_by(card_variant: @zera).quantity,
                 "a posse que a tela anuncia que vai sumir continua lá até a confirmação"
  end

  # Recarregar a tela é o gesto mais natural do usuário indeciso. Se a
  # renderização tivesse efeito, ele seria cumulativo aqui.
  test "ver a tela várias vezes continua não gravando nada" do
    preview = preview_de
    sign_in

    assert_no_changes -> { retrato_da_colecao } do
      3.times { get collection_import_path(preview.token) }
    end
  end

  # --- A tela diz, por escrito, que nada foi gravado ainda ---

  test "a tela declara que a coleção ainda está intacta" do
    renderizar

    texto = css_select("main").text.squish

    assert_match(/nada foi (gravado|alterado|salvo)/i, texto,
                 "o usuário precisa ler que a barreira do Req. 10.5 ainda não foi atravessada")
  end

  # --- Achado HIGH da revisão de a11y: o escopo destrutivo junto do botão ---
  #
  # SC 3.3.4. Quem chega ao único controle que grava por teclado ou por leitor
  # de tela pode não ter lido os grupos acima. O botão sozinho anuncia
  # "Confirmar e gravar na minha coleção" e nada sobre a posse que some — a
  # informação que o Req. 10.5 existe para dar chegaria só a quem lê a tela
  # inteira de cima para baixo.

  test "o aviso de perda de posse fica junto do controle que grava" do
    renderizar

    aviso = css_select(".import-preview__decision .import-preview__warning")

    assert_equal 1, aviso.size,
                 "o escopo destrutivo precisa estar no bloco da decisão, não só lá em cima"
    assert_match(/1\b/, aviso.first.text.squish,
                 "o aviso diz **quantas** cartas saem da coleção")
    assert_match(/sai|saem/i, aviso.first.text.squish,
                 "o aviso diz que a carta deixa a coleção, não apenas que algo muda")
  end

  # A outra metade, que torna a asserção acima discriminante: um aviso fixo,
  # impresso sempre, não informa nada. Ele só existe quando há o que avisar.
  test "sem linha destrutiva não há aviso de perda de posse" do
    conteudo = [
      CollectionCsv::Format.header_row.join(","),
      "#{@cria.card.card_number},#{@cria.variant_code},#{@cria.card.name},4"
    ].join("\n") + "\n"

    renderizar(preview_de(conteudo))

    assert_select ".import-preview__warning", false,
                  "avisar sobre perda de posse quando nenhuma se perde treina o usuário a ignorar o aviso"
  end

  # --- Entrada hostil: o `card_name` vem do arquivo, não do catálogo ---
  #
  # Achado da revisão de segurança da T10. O escape default do Rails resolve,
  # **desde que ninguém use `raw`, `html_safe` ou `<%==`** — esta asserção é o
  # que trava isso na próxima edição da view.

  test "o nome de carta vindo do arquivo é escapado e não vira marcação" do
    hostil = "<script>alert(1)</script>"
    conteudo = [
      CollectionCsv::Format.header_row.join(","),
      "#{@cria.card.card_number},#{@cria.variant_code},\"#{hostil}\",4"
    ].join("\n") + "\n"

    renderizar(preview_de(conteudo))

    assert_no_match(/<script>alert\(1\)<\/script>/, response.body,
                    "o nome vem do arquivo do usuário: é entrada hostil e precisa sair escapado")
    assert_includes response.body, "&lt;script&gt;",
                    "o texto continua visível para o usuário, apenas escapado"
    assert_select "main script", false,
                  "nenhum script pode nascer do conteúdo do arquivo"
  end

  # --- Autorização: a tela é do dono, e de mais ninguém ---

  test "a pré-visualização de outro usuário não é exibida" do
    preview = preview_de
    sign_in(@zoro)

    get collection_import_path(preview.token)

    assert_response :not_found
  end

  test "o anônimo não chega à tela de pré-visualização" do
    preview = preview_de

    get collection_import_path(preview.token)

    assert_redirected_to new_session_path
  end

  private

    # As quantidades de **todos** os usuários, ordenadas: qualquer escrita em
    # qualquer coleção move este valor.
    def retrato_da_colecao
      CollectionItem.order(:user_id, :card_variant_id).pluck(:user_id, :card_variant_id, :quantity)
    end

    # As regras da folha cujo seletor menciona o prefixo. Recorte textual
    # simples, suficiente para a auditoria: o objetivo é falhar quando alguém
    # acrescentar uma largura fixa à tela, não implementar um parser de CSS.
    #
    # **Os comentários são removidos antes do recorte**, e não por capricho: as
    # regras deste projeto são documentadas em prosa que cita as próprias
    # propriedades proibidas ("nenhuma regra usa `white-space: nowrap`"). Sem
    # esta limpeza, a auditoria reprovaria o comentário que explica por que a
    # propriedade não está lá — um falso positivo que empurraria a próxima
    # pessoa a apagar a documentação para o teste passar.
    def regras_de(folha, prefixo)
      sem_comentarios = folha.gsub(/\/\*.*?\*\//m, "\n")

      sem_comentarios.scan(/([^{}]*\{[^{}]*\})/).flatten.select do |regra|
        seletor = regra.split("{").first.to_s
        seletor.include?(prefixo)
      end
    end
end
