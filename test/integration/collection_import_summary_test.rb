require "test_helper"

# SPEC_DEVIATION: a história "P2: Resumo final da importação" (POR-09, POR-10 /
# Req. 10.4) descreve o que o usuário **lê depois de confirmar**, e o plano
# marca a T15 como `Tests: integration` por isso. Dois pontos não são
# verificáveis como escritos neste ambiente, e o que segue é o que foi feito no
# lugar de cada um:
#
# 1. **"Sem scroll horizontal em 360px" (Req. 2.5).** Medir overflow exige
#    layout, e **não há navegador no container** (verificado nas T12/T14 do
#    `catalogo`, na T8 da `colecao` e nas T7/T13 desta feature). O que este
#    arquivo prova é o verificável sobre a **folha de estilo**: que nenhuma
#    regra nova do resumo declara largura fixa, `white-space: nowrap` ou
#    `overflow-x` — as três formas pelas quais um bloco em fluxo empurra a
#    página para o lado. Mesmo precedente de `collection_import_preview_ui_test`.
#    **Não se afirma** aqui que a página foi renderizada em 360px.
#
# 2. **Fluxo por requisição HTTP, não por interação real.** O resumo é
#    verificado sobre o HTML renderizado da resposta da confirmação, e o efeito
#    é conferido **no banco**.
#
# ---
#
# T15 — o resumo final da importação (POR-09, POR-10 / Req. 10.4).
#
# ## O que este arquivo existe para provar
#
# A T14 grava. Este arquivo prova que o usuário **descobre o que foi gravado**,
# e que os números que ele lê são os números que estão no banco — não a
# intenção que a pré-visualização tinha. A diferença é o eixo deste arquivo:
# entre a tela da T13 e a gravação da T14 cabe um intervalo em que o usuário
# pode ter mexido na coleção por outro caminho, e cabe a falha isolada de linha
# do Req. 10.3. Um resumo que repetisse a pré-visualização mentiria nos dois
# casos.
#
# Por isso as contagens não são conferidas contra o `Result` do serviço: o
# teste **conta no banco** — quantos registros passaram a existir, quantos
# mudaram de valor — e compara com o que a tela imprime. Uma implementação que
# imprimisse o `Result` errado, ou o `Result` certo de um cálculo errado,
# morre nos dois casos.
#
# ## As CINCO classificações e as TRÊS categorias do Req. 10.4
#
# O `CollectionCsv::Resolver` (T9) produz cinco classificações; o Req. 10.4
# nomeia três. O mapeamento, decidido nesta task:
#
# | Categoria do Req. 10.4 | Classificações |
# |---|---|
# | importadas | `:cria` |
# | atualizadas | `:atualiza` + `:zera` |
# | rejeitadas | `:rejeita` |
# | (fora das três) | `:inalterada` — linha própria "sem alteração" |
#
# **`:zera` não pode desaparecer dentro de "atualizadas".** Somar as duas e
# calar é a falha que o Req. 10.5 existe para impedir: o usuário confirmou um
# efeito destrutivo e o resumo não confirmaria que ele aconteceu. O resumo diz,
# em texto, quantas dessas atualizações **removeram posse**, e há teste que
# falha se esse número não aparecer distinto do total de atualizadas.
#
# ## O cenário é construído para discriminar
#
# As contagens por categoria são **todas diferentes entre si** — 3 criadas,
# 2 atualizadas (1 delas destrutiva), 2 rejeitadas, 1 inalterada. Com contagens
# iguais, trocar a contagem de importadas pela de atualizadas passaria
# despercebido. As duas rejeições têm **motivos diferentes** (variante
# inexistente e quantidade inválida): com um motivo só, uma tela que imprimisse
# a mesma frase para toda rejeição passaria.
class CollectionImportSummaryTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-15".freeze

  setup do
    @nami = User.create!(email: "nami-por15@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-por15@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OPp15", name: "Romance Dawn", kind: "booster",
                           base_set_size: 9, total_set_size: 9)

    # Três que passam a constar (`:cria`).
    @cria_a = variant("p15a", "Tony Tony Chopper")
    @cria_b = variant("p15b", "Nico Robin")
    @cria_c = variant("p15c", "Franky")

    # Duas atualizações, e **uma delas é destrutiva** (`:zera`).
    @atualiza = variant("p15d", "Bell-mère")
    @zera = variant("p15e", "Nefertari Vivi")

    # Uma sem efeito (`:inalterada`).
    @inalterada = variant("p15f", "Roronoa Zoro")

    # Uma rejeitada por quantidade inválida; a outra rejeição é uma variante
    # que não existe no catálogo, escrita direto no CSV.
    @invalida = variant("p15g", "Usopp")

    own(@nami, @atualiza, 2)
    own(@nami, @zera, 5)
    own(@nami, @inalterada, 3)
    own(@nami, @invalida, 4)

    # @zoro possui **as mesmas** variantes com outras quantidades: uma contagem
    # que lesse a coleção de qualquer usuário em vez da de `Current.user`
    # apareceria aqui.
    own(@zoro, @atualiza, 9)
    own(@zoro, @zera, 9)
    own(@zoro, @cria_a, 9)
  end

  def variant(suffix, card_name)
    card = Card.create!(card_set: @set, card_number: "OP15-#{suffix}", name: card_name,
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

  # O arquivo com os cinco desfechos, em contagens distintas entre si.
  def csv_completo
    linhas = [
      CollectionCsv::Format.header_row.join(","),
      linha_csv(@cria_a, 4),
      linha_csv(@cria_b, 1),
      linha_csv(@cria_c, 6),
      linha_csv(@atualiza, 7),
      linha_csv(@zera, 0),
      linha_csv(@inalterada, 3),
      "#{@invalida.card.card_number},#{@invalida.variant_code}," \
        "#{@invalida.card.name},nao-e-numero",
      "OP15-fantasma,zzz,Carta Que Não Existe,6"
    ]
    linhas.join("\n") + "\n"
  end

  def linha_csv(card_variant, quantidade)
    "#{card_variant.card.card_number},#{card_variant.variant_code}," \
      "#{card_variant.card.name},#{quantidade}"
  end

  def upload(conteudo, filename: "colecao.csv")
    Rack::Test::UploadedFile.new(
      StringIO.new(conteudo), "text/csv", original_filename: filename
    )
  end

  def previsualizar(conteudo = csv_completo)
    post collection_imports_path, params: { arquivo: upload(conteudo) }
    CollectionImport.order(:id).last
  end

  # Sobe a pré-visualização, tira o retrato do "antes" e confirma. Devolve o
  # retrato, que é o que permite contar no banco o que de fato mudou.
  def confirmar_com_retrato(conteudo = csv_completo)
    preview = previsualizar(conteudo)
    antes = retrato_de(@nami)
    post confirm_collection_import_path(preview.token)
    [ preview, antes ]
  end

  def retrato_de(user)
    CollectionItem.for_user(user).pluck(:card_variant_id, :quantity).to_h
  end

  # O texto do resumo inteiro, normalizado. É sobre ele que as asserções de
  # tom e de vocabulário correm.
  def texto_do_resumo
    css_select("main").text.squish
  end

  # A contagem que a tela publica para uma categoria, lida do elemento que a
  # nomeia — nunca do texto corrido. Num texto corrido, "3 importadas, 2
  # atualizadas" e "2 importadas, 3 atualizadas" exigiriam casar ordem, e a
  # troca de uma pela outra passaria por um `assert_match` frouxo.
  def contagem_de(categoria)
    elemento = css_select(%(.import-summary__count[data-categoria="#{categoria}"])).first

    assert_not_nil elemento, "o resumo precisa publicar a contagem de #{categoria}"

    elemento.css(".import-summary__number").text.squish
  end

  # --- POR-09 / Req. 10.4: as três contagens ---

  test "o resumo apresenta as três contagens do Req. 10.4" do
    sign_in
    confirmar_com_retrato

    assert_response :success

    assert_equal "3", contagem_de("importadas"),
                 "três linhas do arquivo criam registro que não existia"
    assert_equal "2", contagem_de("atualizadas"),
                 "duas linhas trocam a quantidade de um registro existente"
    assert_equal "2", contagem_de("rejeitadas"),
                 "duas linhas foram recusadas: variante inexistente e quantidade inválida"
  end

  # O critério mais duro do plano: os números da tela batem com o **estado real
  # da coleção**, não com a intenção da pré-visualização. O teste conta no
  # banco — quantos pares (variante, quantidade) passaram a existir e quantos
  # mudaram de valor — e compara com o que a tela imprimiu.
  test "as contagens do resumo batem com o que de fato mudou no banco" do
    sign_in
    _preview, antes = confirmar_com_retrato
    depois = retrato_de(@nami)

    criadas_no_banco = (depois.keys - antes.keys).size
    atualizadas_no_banco = antes.count do |variante, quantidade|
      depois.key?(variante) && depois[variante] != quantidade
    end

    assert_equal 3, criadas_no_banco, "o cenário precisa criar três registros"
    assert_equal 2, atualizadas_no_banco, "o cenário precisa alterar dois registros"

    assert_equal criadas_no_banco.to_s, contagem_de("importadas"),
                 "o resumo tem de contar o que entrou no banco, não o que a tela previu"
    assert_equal atualizadas_no_banco.to_s, contagem_de("atualizadas"),
                 "o resumo tem de contar o que mudou no banco, não o que a tela previu"
  end

  # A contagem de rejeitadas também é conferida contra o banco, pelo avesso:
  # nenhuma das duas linhas recusadas deixou marca na coleção.
  test "as rejeitadas do resumo são exatamente as que não tocaram a coleção" do
    sign_in
    _preview, antes = confirmar_com_retrato
    depois = retrato_de(@nami)

    assert_equal antes[@invalida.id], depois[@invalida.id],
                 "a linha de quantidade inválida não pode ter alterado a posse"
    assert_equal 2, contagem_de("rejeitadas").to_i
  end

  # --- A decisão de mapeamento: `:zera` não desaparece em "atualizadas" ---

  # O resumo diz que houve duas atualizações **e** diz, em texto, que uma delas
  # removeu a carta da coleção. Somar as duas e calar é a falha que o Req. 10.5
  # existe para impedir: o usuário confirmou um efeito destrutivo e o resumo não
  # confirmaria que ele aconteceu.
  test "o resumo nomeia quantas atualizações removeram a carta da coleção" do
    sign_in
    confirmar_com_retrato

    removidas = css_select(".import-summary__removidas").first

    assert_not_nil removidas,
                   "o resumo precisa dizer quantas atualizações removeram posse"

    texto = removidas.text.squish

    assert_match(/\b1\b/, texto,
                 "uma das duas atualizações levou a posse a zero")
    assert_match(/remov/i, texto,
                 "o número sozinho não diz o que aconteceu; o texto precisa nomear a remoção")

    # O número da remoção é **distinto** do total de atualizadas: se os dois
    # fossem o mesmo, o resumo estaria dizendo que as duas atualizações
    # removeram posse.
    assert_not_equal contagem_de("atualizadas"), texto[/\d+/],
                     "a remoção é um recorte das atualizadas, não o total delas"
  end

  # A prova pelo avesso: a variante zerada está com quantidade zero no banco, e
  # é dela que o número acima fala.
  test "a remoção que o resumo anuncia aconteceu de fato no banco" do
    sign_in
    confirmar_com_retrato

    assert_equal 0, CollectionItem.for_user(@nami).find_by(card_variant: @zera).quantity,
                 "a linha destrutiva do arquivo levou a posse a zero"
  end

  # --- POR-10 / Req. 10.4: motivo e identificação por linha rejeitada ---

  test "cada linha rejeitada aparece com o motivo e com a identificação da linha" do
    sign_in
    confirmar_com_retrato

    rejeitadas = css_select(".import-summary__rejeitada")

    assert_equal 2, rejeitadas.size, "as duas rejeições aparecem no resumo"

    fantasma = rejeitadas.find { |linha| linha.text.include?("OP15-fantasma") }
    invalida = rejeitadas.find { |linha| linha.text.include?(@invalida.card.card_number) }

    assert_not_nil fantasma, "a rejeição por variante inexistente precisa ser identificável"
    assert_not_nil invalida, "a rejeição por quantidade inválida precisa ser identificável"

    assert_not_empty fantasma.css(".import-summary__motivo").text.squish,
                     "rejeição sem motivo não diz ao usuário o que corrigir"
    assert_not_empty invalida.css(".import-summary__motivo").text.squish,
                     "rejeição sem motivo não diz ao usuário o que corrigir"
  end

  # Motivos **diferentes** para rejeições diferentes. Com uma frase genérica
  # para toda rejeição, o usuário não sabe se corrige o código ou a quantidade.
  test "rejeições de causas diferentes trazem motivos diferentes" do
    sign_in
    confirmar_com_retrato

    rejeitadas = css_select(".import-summary__rejeitada")
    motivos = rejeitadas.map { |linha| linha.css(".import-summary__motivo").text.squish }

    assert_equal 2, motivos.uniq.size,
                 "duas causas distintas não podem produzir a mesma frase: #{motivos.inspect}"
  end

  # A identificação é o **número da linha do arquivo**, contado como o usuário
  # o vê num editor: o cabeçalho é a linha 1, então o índice zero-based do
  # resolvedor vira `indice + 2`. Sem isso o resumo manda corrigir duas linhas
  # acima do erro — pior do que não dizer nada.
  test "a identificação da linha rejeitada é o número da linha no arquivo" do
    sign_in
    preview, _antes = confirmar_com_retrato

    esperados = preview.linhas_resolvidas.select(&:rejeitada?).map { |l| l.indice.to_i + 2 }

    assert_equal 2, esperados.size

    origens = css_select(".import-summary__rejeitada .import-summary__origin")
      .map { |o| o.text.squish[/\d+/].to_i }

    assert_equal esperados.sort, origens.sort,
                 "a linha citada é a do arquivo (cabeçalho = 1), não o índice interno"
  end

  # --- Critério 4 da história P2: sem rejeição, o resumo não sugere erro ---

  # O cenário limpo: um arquivo cujas linhas todas são aceitas.
  #
  # **"Não sugerir erro" não é "não dizer a palavra recusada".** O rótulo da
  # terceira contagem é exigido pelo critério 1 do mesmo requisito — as três
  # contagens aparecem sempre —, e "0 Recusadas" é um fato neutro, não um
  # alarme. Uma lista negra de vocabulário tornaria os critérios 1 e 4
  # mutuamente insatisfazíveis, e o que ela pegaria seria o rótulo, não o
  # alarme.
  #
  # O que o critério 4 proíbe é o **aparato de erro**: o bloco de atenção, a
  # lista de linhas a conferir, e a linguagem de falha ou problema. Nada disso
  # pode existir no DOM — e "não existir" e não "estar escondido por CSS": uma
  # frase de alarme com `display: none` continua sendo lida por leitor de tela,
  # e teria passado por uma asserção sobre texto visível.
  test "sem nenhuma rejeição o resumo não sugere erro" do
    sign_in

    limpo = [
      CollectionCsv::Format.header_row.join(","),
      linha_csv(@cria_a, 4),
      linha_csv(@atualiza, 7)
    ].join("\n") + "\n"

    confirmar_com_retrato(limpo)

    assert_equal "0", contagem_de("rejeitadas"),
                 "as três contagens aparecem sempre (critério 1); o que muda é o tom"

    assert_empty css_select(".import-summary__rejeitada"),
                 "sem rejeição não há lista de linhas a conferir"
    assert_empty css_select(".import-summary__alert"),
                 "sem rejeição não há bloco de atenção"
    assert_empty css_select(".import-summary__falhada"),
                 "sem falha de gravação não há lista de linhas que falharam"

    texto = texto_do_resumo

    # O vocabulário de **alarme**, distinto do rótulo neutro da contagem.
    %w[erro erros falha falhas falhou problema problemas atenção confira
       tentar cuidado].each do |palavra|
      assert_no_match(/\b#{palavra}\b/i, texto,
                      "sem nenhuma rejeição, '#{palavra}' sugere erro onde não houve: #{texto}")
    end

    # E a prova pela positiva: o resumo limpo afirma que a importação deu
    # certo. Sem isto, apagar a tela inteira passaria no teste acima.
    assert_match(/conclu/i, texto,
                 "o resumo limpo precisa afirmar que a importação foi concluída")
  end

  # O contrapositivo do teste acima, e é ele que impede a solução preguiçosa de
  # apagar todo vocabulário de recusa da tela: **com** rejeição, o resumo
  # precisa sinalizar que há o que olhar.
  test "com rejeição o resumo sinaliza que há linhas a conferir" do
    sign_in
    confirmar_com_retrato

    assert_not_empty css_select(".import-summary__alert"),
                     "havendo recusa, o resumo precisa chamar atenção para ela"
  end

  # --- A invariante da feature: o resumo é leitura, não escrita ---

  # A T15 é tela. Renderizar o resumo não pode alterar a coleção — nem a do
  # usuário, nem a de ninguém. O retrato é tirado **depois** da gravação da T14
  # e conferido depois de uma releitura da página.
  test "renderizar o resumo não altera a coleção" do
    sign_in
    preview, _antes = confirmar_com_retrato

    depois_da_gravacao = CollectionItem.order(:id)
      .pluck(:id, :user_id, :card_variant_id, :quantity)

    assert_no_changes -> { CollectionItem.order(:id).pluck(:id, :user_id, :card_variant_id, :quantity) } do
      get collection_import_path(preview.token)
    end

    assert_equal depois_da_gravacao,
                 CollectionItem.order(:id).pluck(:id, :user_id, :card_variant_id, :quantity),
                 "a tela do resumo é leitura; a única escrita da feature é a da T14"
  end

  # --- Autorização: o resumo é do dono da sessão ---

  test "o resumo exige sessão" do
    sign_in
    preview = previsualizar

    delete session_path

    post confirm_collection_import_path(preview.token)

    assert_redirected_to new_session_path
  end

  # --- Português e plural correto ---

  # O inflector do Rails é inglês: `pluralize(1, "linha")` produz "1 linha" e
  # `pluralize(2, "linha")` produz "2 linhas" só por acidente de que "linha" +
  # "s" funciona. Com "carta que sai" ou qualquer substantivo composto ele
  # erra, e a lição da T8 da `colecao` é nunca deixar o Rails derivar.
  test "o resumo está em português e não vaza vocabulário de sistema" do
    sign_in
    confirmar_com_retrato

    texto = texto_do_resumo

    %w[create update delete import export row error skip preview commit].each do |palavra|
      assert_no_match(/\b#{palavra}\b/i, texto,
                      "'#{palavra}' é vocabulário de sistema; a interface é em português")
    end
  end

  # O singular é o caso que o inflector inglês erra em silêncio, então ele tem
  # teste próprio: um arquivo de uma linha só não pode produzir "1 linhas".
  test "o resumo usa o singular quando há uma linha só de cada tipo" do
    sign_in

    uma_so = [
      CollectionCsv::Format.header_row.join(","),
      linha_csv(@cria_a, 4)
    ].join("\n") + "\n"

    confirmar_com_retrato(uma_so)

    texto = texto_do_resumo

    assert_no_match(/\b1 linhas\b/, texto, "'1 linhas' é plural errado no singular")
    assert_no_match(/\b1 cartas\b/, texto, "'1 cartas' é plural errado no singular")
    assert_no_match(/\(s\)/, texto,
                    "'linha(s)' é gambiarra de plural; o resumo escolhe a forma certa")
  end

  # --- Req. 2.5: 360px, verificado sobre a folha (ver SPEC_DEVIATION) ---

  test "nenhuma regra nova do resumo declara largura fixa, nowrap ou overflow horizontal" do
    folha = File.read(Rails.root.join("app/assets/stylesheets/catalog.css"))
    regras = regras_de(folha, "import-summary")

    assert_not_empty regras, "o resumo precisa de regras próprias na folha"

    regras.each do |regra|
      assert_no_match(/(?:\A|[;{]|\n)\s*width:\s*\d+(px|rem|em|ch)/, regra,
                      "largura fixa empurra a página para o lado em 360px: #{regra}")
      assert_no_match(/white-space:\s*nowrap/, regra,
                      "`nowrap` num bloco de texto força scroll horizontal: #{regra}")
      assert_no_match(/overflow-x:\s*(auto|scroll)/, regra,
                      "o Req. 2.5 proíbe o scroll horizontal, não o gerencia: #{regra}")
    end
  end

  # --- Escape: o nome da carta vem do arquivo do usuário ---

  # Mesmo achado da revisão de segurança da T10 que a tela da T13 carrega: o
  # `card_name` é entrada hostil. O resumo imprime nome de carta nas linhas
  # rejeitadas, então a trava vale aqui também.
  test "o nome da carta vindo do arquivo é escapado no resumo" do
    sign_in

    hostil = [
      CollectionCsv::Format.header_row.join(","),
      %(OP15-fantasma,zzz,"<script>alert(1)</script>",2)
    ].join("\n") + "\n"

    confirmar_com_retrato(hostil)

    assert_no_match(/<script>/, response.body,
                    "o nome vem do arquivo do usuário e não pode ser HTML")
  end

  private

    # As regras da folha cujo seletor menciona o prefixo, sem os comentários —
    # a prosa deste projeto cita as próprias propriedades proibidas, e sem a
    # limpeza a auditoria reprovaria o comentário que explica por que a
    # propriedade não está lá. Mesmo recorte de
    # `collection_import_preview_ui_test`.
    def regras_de(folha, prefixo)
      sem_comentarios = folha.gsub(/\/\*.*?\*\//m, "\n")

      sem_comentarios.scan(/([^{}]*\{[^{}]*\})/).flatten.select do |regra|
        seletor = regra.split("{").first.to_s
        seletor.include?(prefixo)
      end
    end
end
