require "test_helper"
require "csv"

# SPEC_DEVIATION: a história "P2: Isolamento e custo das duas metades" descreve
# o usuário baixando o arquivo, abrindo em planilha e reenviando. Dois pontos
# não são verificáveis como escritos neste ambiente:
#
# 1. **Não há navegador no container** (verificado nas T12/T14 do `catalogo`,
#    na T8 da `colecao` e nas T7/T13/T15 desta feature), logo não há download
#    real nem upload por formulário. A ida e volta é exercitada por requisição
#    HTTP: o corpo da resposta de `GET collection_export_path` é reenviado,
#    **byte a byte e sem edição**, como `Rack::Test::UploadedFile` para
#    `POST collection_imports_path`. É a mesma travessia que o navegador faria
#    — o arquivo é o mesmo —, sem a camada de interface.
#
# 2. **Nenhuma planilha real abre o arquivo no meio do caminho.** Excel e
#    LibreOffice reescrevem o que salvam (BOM, delimitador regional, aspas), e
#    isso é coberto pelos Edge Cases nos testes do parser (T8). Aqui a volta é
#    do arquivo **como o app o gerou**, que é o que o POR-11 afirma.
#
# ---
#
# T16 — ida e volta fechada (POR-11) e isolamento entre usuários (POR-12).
#
# ## O que este arquivo existe para provar
#
# As fases anteriores provaram cada metade por dentro. Este arquivo prova as
# duas afirmações que só existem **entre** elas, e das quais depende a
# correção de tudo que veio antes:
#
# - **A ida e volta é fechada.** Exportar, reimportar sem editar e confirmar
#   deixa a coleção **idêntica**. É a consequência direta da AD-006
#   (substituir, não somar): sob "somar", o fluxo mais óbvio do produto — o
#   usuário que baixa, olha e reenvia — dobraria a coleção inteira. É a decisão
#   que o teste desta task existe para guardar.
#
# - **As duas coleções são independentes.** O export traz só o de quem pediu, e
#   o import escreve só na coleção de quem confirmou, ainda que o arquivo
#   descreva variantes que outra pessoa também possui.
#
# ## O retrato, e por que contar linhas não prova nada
#
# A idempotência é verificada por **retrato**: o hash inteiro
# `(card_variant_id => quantity)`, comparado com `assert_equal` antes do export
# e depois da confirmação. Contar linhas passaria sob quase toda corrupção
# imaginável — somar dobra as quantidades sem mudar a contagem; trocar o dono
# de duas escritas simétricas mantém os dois totais. O hash inteiro não passa
# por nenhuma delas.
#
# ## O cenário é construído para discriminar
#
# - **Quantidades todas diferentes entre si** (2, 3, 5, 7): com quantidades
#   iguais, uma implementação que trocasse a quantidade de uma variante pela de
#   outra sobreviveria ao retrato.
# - **Acento (`Bell-mère`), vírgula (`Nami, a Navegadora`) e aspas
#   (`Sanji "Perna Preta"`)** nos nomes: o escape do CSV é exercido de ida e de
#   volta. Um export que não citasse a vírgula produziria cinco colunas na
#   volta e o arquivo seria recusado — o teste cairia em vez de passar por
#   acaso.
# - **Dois sets**: a resolução na volta é pelo par `card_number` +
#   `variant_code`, e com um set só um bug que ignorasse o `card_number`
#   poderia não aparecer.
# - **Uma variante possuída por `@nami` com quantidade `0`**, que o export
#   **não** escreve (POR-02): a volta não pode ressuscitá-la nem apagá-la.
# - **Duas variantes em comum entre os dois usuários, com quantidades
#   diferentes**: é o que torna o vazamento visível. Se o import escrevesse na
#   coleção errada, a quantidade de um apareceria na do outro.
class CollectionCsvRoundtripTest < ActionDispatch::IntegrationTest
  PASSWORD = "thousand-sunny-16".freeze

  setup do
    @nami = User.create!(email: "nami-por16@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-por16@example.com", password: PASSWORD)

    # Dois sets: a chave da volta é o par, e o `card_number` precisa importar.
    @romance = CardSet.create!(code: "OPa16", name: "Romance Dawn", kind: "booster",
                               base_set_size: 6, total_set_size: 6)
    @paramount = CardSet.create!(code: "OPb16", name: "Paramount War", kind: "booster",
                                 base_set_size: 6, total_set_size: 6)

    # Os três nomes que exercem o escape do CSV: acento, vírgula e aspas.
    @acento = variant(@romance, "A16", "r1", "Bell-mère")
    @virgula = variant(@romance, "A16", "r2", "Nami, a Navegadora")
    @aspas = variant(@paramount, "B16", "p1", "Sanji \"Perna Preta\"")
    @simples = variant(@paramount, "B16", "p2", "Roronoa Zoro")

    # Possuída com zero: o export não a escreve (POR-02), e a volta não pode
    # nem ressuscitá-la nem apagar o registro.
    @zerada = variant(@romance, "A16", "r3", "Nefertari Vivi")

    # Quantidades todas distintas entre si.
    own(@nami, @acento, 2)
    own(@nami, @virgula, 3)
    own(@nami, @aspas, 5)
    own(@nami, @simples, 7)
    own(@nami, @zerada, 0)

    # `@zoro` possui **duas das mesmas** variantes, com quantidades diferentes,
    # e uma que só ele tem. Qualquer escrita no dono errado aparece aqui.
    @so_do_zoro = variant(@paramount, "B16", "p3", "Tony Tony Chopper")
    own(@zoro, @acento, 11)
    own(@zoro, @simples, 13)
    own(@zoro, @so_do_zoro, 17)
  end

  # A suíte roda em paralelo e o projeto não usa fixtures YAML: cada arquivo
  # cria os próprios registros, com chaves naturais distintas para não colidir
  # entre workers.
  def variant(card_set, prefixo, suffix, card_name)
    card = Card.create!(card_set: card_set, card_number: "#{prefixo}-#{suffix}",
                        name: card_name, card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: card_set, variant_code: suffix,
                        rarity: "C", art_kind: "base")
  end

  def own(user, card_variant, quantity)
    CollectionItem.create!(user: user, card_variant: card_variant, quantity: quantity)
  end

  def sign_in(user = @nami)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def sign_out
    delete session_path
  end

  # O retrato: `(card_variant_id => quantity)` para **toda** linha do usuário,
  # inclusive as de quantidade zero. Incluir as zeradas é deliberado — é o que
  # faz o teste perceber um registro apagado, que um retrato só de `owned`
  # confundiria com "nunca existiu".
  def retrato_de(user)
    CollectionItem.for_user(user).pluck(:card_variant_id, :quantity).to_h
  end

  # **`dup` não é adorno.** `Rack::Test::UploadedFile.new(StringIO.new(s), …)`
  # lê `s` e deixa a codificação dela em `ASCII-8BIT` — e o objeto que
  # `response.body` devolve é o **mesmo** que o teste guardou. Sem a cópia, o
  # arquivo capturado antes do upload muda de codificação por causa do próprio
  # upload, e a comparação de dois exports falha com os bytes idênticos dos
  # dois lados. Diagnosticado nesta task; é artefato do harness de teste, não
  # do produto: a resposta declara `charset=utf-8` nas duas vezes.
  def exportar
    get collection_export_path
    response.body.dup
  end

  def upload(conteudo, filename: "colecao.csv")
    Rack::Test::UploadedFile.new(
      StringIO.new(conteudo), "text/csv", original_filename: filename
    )
  end

  def previsualizar(conteudo)
    post collection_imports_path, params: { arquivo: upload(conteudo) }
    CollectionImport.order(:id).last
  end

  def confirmar(preview)
    post confirm_collection_import_path(preview.token)
  end

  def linhas_do_csv(conteudo)
    CSV.parse(conteudo, headers: true, col_sep: CollectionCsv::Format::DELIMITER)
  end

  # O par que identifica a variante no arquivo, como conjunto — é o que
  # permite afirmar "só o seu" sem depender da ordem das linhas.
  def pares_do_csv(conteudo)
    linhas_do_csv(conteudo).map { |l| [ l["card_number"], l["variant_code"] ] }.to_set
  end

  # --- POR-11: a ida e volta é fechada ---

  # A prova central da task, e da AD-006. O retrato **inteiro** antes do export
  # e depois da confirmação, comparado item a item. Substituir por soma faz
  # cada quantidade dobrar e este teste morre em todas as linhas de uma vez.
  test "reimportar o próprio export sem edição não altera a coleção" do
    sign_in(@nami)

    antes = retrato_de(@nami)
    arquivo = exportar

    preview = previsualizar(arquivo)
    confirmar(preview)

    assert_response :success
    assert_equal antes, retrato_de(@nami),
                 "a ida e volta precisa ser fechada: reimportar o export sem " \
                 "editar não pode mudar uma única quantidade (POR-11 / AD-006)"
  end

  # O critério irmão do anterior: não basta o retrato bater ao final do
  # primeiro ciclo. Três ciclos seguidos é o que separa "idempotente" de
  # "estável por um acaso da primeira volta" — sob soma, o segundo ciclo
  # quadruplicaria.
  test "três ciclos seguidos de exportar e reimportar deixam a coleção idêntica" do
    sign_in(@nami)

    antes = retrato_de(@nami)

    3.times do |ciclo|
      confirmar(previsualizar(exportar))

      assert_equal antes, retrato_de(@nami),
                   "a coleção mudou no ciclo #{ciclo + 1} de exportar e reimportar"
    end
  end

  # A volta produz o **mesmo arquivo**. É a face do POR-11 que o retrato não
  # cobre sozinho: uma implementação que alterasse o nome ou a ordem das linhas
  # manteria o retrato e mudaria o que o usuário vê na planilha.
  test "o export depois da volta é byte a byte igual ao export de antes" do
    sign_in(@nami)

    primeiro = exportar
    confirmar(previsualizar(primeiro))
    segundo = exportar

    assert_equal primeiro.b, segundo.b,
                 "reimportar o export não pode mudar o arquivo que o próximo " \
                 "export produz"
  end

  # A ida e volta precisa ser exercida sobre o escape de verdade, e não só
  # sobre nomes simples. Esta é a prova de que os três nomes difíceis
  # atravessaram: um export que não citasse a vírgula produziria uma coluna a
  # mais, e o arquivo seria recusado na volta em vez de resolver.
  test "acento, vírgula e aspas sobrevivem à ida e à volta" do
    sign_in(@nami)

    arquivo = exportar
    linhas = linhas_do_csv(arquivo)
    nomes = linhas.map { |l| l["card_name"] }

    assert_includes nomes, "Bell-mère", "o acento precisa sair no arquivo"
    assert_includes nomes, "Nami, a Navegadora", "a vírgula precisa sair escapada"
    assert_includes nomes, "Sanji \"Perna Preta\"", "as aspas precisam sair escapadas"

    antes = retrato_de(@nami)
    confirmar(previsualizar(arquivo))

    assert_equal antes, retrato_de(@nami)
    assert_equal nomes.sort, linhas_do_csv(exportar).map { |l| l["card_name"] }.sort,
                 "os nomes difíceis precisam continuar iguais depois da volta"
  end

  # Mais de um set no arquivo, e os dois resolvem. Sem isto, um bug que
  # resolvesse só pelo `variant_code` — ignorando o `card_number` — poderia
  # atravessar o retrato por não haver colisão para revelá-lo.
  test "a volta resolve variantes de mais de um set" do
    sign_in(@nami)

    arquivo = exportar
    numeros = linhas_do_csv(arquivo).map { |l| l["card_number"] }

    assert numeros.any? { |n| n.start_with?("A16-") }, "o arquivo precisa ter cartas do primeiro set"
    assert numeros.any? { |n| n.start_with?("B16-") }, "o arquivo precisa ter cartas do segundo set"

    antes = retrato_de(@nami)
    confirmar(previsualizar(arquivo))

    assert_equal antes, retrato_de(@nami)
  end

  # A variante possuída com zero não está no arquivo (POR-02), e a volta não
  # pode nem criá-la com outra quantidade nem apagar o registro dela. É o caso
  # em que "idêntica" e "as linhas do arquivo bateram" divergem.
  test "a variante com quantidade zero não é escrita no arquivo nem alterada na volta" do
    sign_in(@nami)

    arquivo = exportar

    assert_not_includes pares_do_csv(arquivo), [ @zerada.card.card_number, @zerada.variant_code ],
                        "o export escreve só variantes possuídas (POR-02)"

    confirmar(previsualizar(arquivo))

    registro = CollectionItem.for_user(@nami).find_by(card_variant: @zerada)
    assert_not_nil registro, "a volta não pode apagar o registro de quantidade zero"
    assert_equal 0, registro.quantity
  end

  # A invariante da feature (Req. 10.5), exercida dentro do fluxo da ida e
  # volta: **o upload não grava**. Se este teste falhar, a coleção mudou antes
  # de o usuário confirmar, e é defeito grave — não do teste.
  test "o upload da ida e volta não grava nada antes da confirmação" do
    sign_in(@nami)

    arquivo = exportar
    antes = retrato_de(@nami)

    assert_no_changes -> { retrato_de(@nami) },
                      "nenhuma escrita pode acontecer sem confirmação (Req. 10.5)" do
      previsualizar(arquivo)
    end

    assert_equal antes, retrato_de(@nami)
  end

  # --- POR-12: o export devolve a cada um só o seu ---

  # O critério "exportar por dois usuários com posses distintas devolve a cada
  # um só o seu". O `@so_do_zoro` é a variante que só um possui: ela precisa
  # estar num arquivo e faltar no outro.
  test "cada usuário exporta só a própria coleção" do
    sign_in(@nami)
    da_nami = exportar
    sign_out

    sign_in(@zoro)
    do_zoro = exportar
    sign_out

    par_exclusivo = [ @so_do_zoro.card.card_number, @so_do_zoro.variant_code ]

    assert_includes pares_do_csv(do_zoro), par_exclusivo
    assert_not_includes pares_do_csv(da_nami), par_exclusivo,
                        "o export não pode trazer variante de outro usuário"

    assert_not_includes pares_do_csv(do_zoro), [ @virgula.card.card_number, @virgula.variant_code ],
                        "o export do @zoro não pode trazer o que só a @nami possui"
  end

  # Não basta o conjunto de variantes ser o certo: as **quantidades** também
  # são de quem pediu. As duas variantes em comum têm quantidades diferentes
  # nos dois usuários, e é isso que este teste lê.
  test "o export traz a quantidade do usuário da sessão, não a do outro" do
    sign_in(@nami)
    da_nami = quantidades_por_par(exportar)
    sign_out

    sign_in(@zoro)
    do_zoro = quantidades_por_par(exportar)
    sign_out

    par_acento = [ @acento.card.card_number, @acento.variant_code ]
    par_simples = [ @simples.card.card_number, @simples.variant_code ]

    assert_equal "2", da_nami[par_acento]
    assert_equal "11", do_zoro[par_acento]
    assert_equal "7", da_nami[par_simples]
    assert_equal "13", do_zoro[par_simples]
  end

  def quantidades_por_par(conteudo)
    linhas_do_csv(conteudo).each_with_object({}) do |linha, acc|
      acc[[ linha["card_number"], linha["variant_code"] ]] = linha["quantity"]
    end
  end

  # --- POR-12: o import escreve só na coleção de quem confirmou ---

  # O critério 3 da história P2, na forma em que ela o escreve: **o mesmo
  # arquivo**, importado pelos dois, deixa as duas coleções independentes. O
  # arquivo é o export da `@nami`, e o `@zoro` o importa inteiro — cada um
  # termina com o que o arquivo descreve **na sua própria coleção**, sem que a
  # do outro mude.
  test "dois usuários que importam o mesmo arquivo mantêm coleções independentes" do
    sign_in(@nami)
    arquivo = exportar
    da_nami_antes = retrato_de(@nami)
    confirmar(previsualizar(arquivo))
    sign_out

    assert_equal da_nami_antes, retrato_de(@nami)

    sign_in(@zoro)
    confirmar(previsualizar(arquivo))
    sign_out

    assert_equal da_nami_antes, retrato_de(@nami),
                 "a importação do @zoro não pode tocar na coleção da @nami"

    # O `@zoro` recebeu o que o arquivo descreve, na coleção dele: as duas
    # variantes em comum passaram às quantidades do arquivo (AD-006:
    # substituir), e o que só ele possuía continua intacto.
    do_zoro = retrato_de(@zoro)
    assert_equal 2, do_zoro[@acento.id], "a quantidade do arquivo substitui a do @zoro"
    assert_equal 7, do_zoro[@simples.id]
    assert_equal 17, do_zoro[@so_do_zoro.id],
                 "o que não está no arquivo não é tocado"
    assert_equal 3, do_zoro[@virgula.id], "o que o arquivo cria nasce na coleção do @zoro"
  end

  # O "Independent Test" da história P2, literal: importar o arquivo de um
  # estando autenticado como o outro e conferir que a coleção do primeiro não
  # muda. É o mesmo arquivo do teste anterior, mas a asserção é a inversa — o
  # retrato da `@nami`, item a item, tirado antes de o `@zoro` sequer fazer o
  # upload.
  test "importar o arquivo de um estando autenticado como o outro não altera a coleção do primeiro" do
    sign_in(@nami)
    arquivo = exportar
    sign_out

    da_nami_antes = retrato_de(@nami)

    sign_in(@zoro)
    confirmar(previsualizar(arquivo))

    # A asserção de resposta corre **antes** do `sign_out`: depois dele a
    # última resposta é a do logout, e um `assert_response :success` ali leria
    # o redirect da sessão em vez do resumo da confirmação.
    assert_response :success
    sign_out

    assert_equal da_nami_antes, retrato_de(@nami),
                 "a coleção do primeiro usuário precisa ficar intacta (POR-12)"
  end

  # A face do isolamento que o retrato não cobre: o **arquivo** que a `@nami`
  # exporta depois de o `@zoro` importar o dela é o mesmo de antes. Uma escrita
  # no dono errado que por acaso mantivesse o retrato de `collection_items`
  # apareceria aqui.
  test "o export do primeiro usuário não muda depois de o segundo importar o arquivo dele" do
    sign_in(@nami)
    antes = exportar
    sign_out

    sign_in(@zoro)
    confirmar(previsualizar(antes))
    sign_out

    sign_in(@nami)
    depois = exportar

    assert_equal antes.b, depois.b
  end

  # A pré-visualização do `@zoro` descreve a coleção **dele**, não a da `@nami`
  # de quem o arquivo veio. Sem isto, a tela poderia anunciar "nada muda" —
  # verdade para a `@nami`, mentira para ele — e a T13 não teria como saber.
  test "a pré-visualização do arquivo alheio é calculada sobre a coleção de quem enviou" do
    sign_in(@nami)
    arquivo = exportar
    sign_out

    sign_in(@zoro)
    preview = previsualizar(arquivo)

    assert_equal @zoro.id, preview.user_id

    classificacoes = preview.linhas.map { |linha| linha["classificacao"] }

    assert_includes classificacoes, "cria",
                    "as variantes que o @zoro não possui precisam ser criação para ele"
    assert_includes classificacoes, "atualiza",
                    "as variantes em comum têm quantidade diferente: para o @zoro é atualização"
  end

  # **"Nada mudou" não é prova de que a escrita aconteceu no lugar certo.**
  # Este teste existe por causa de um sobrevivente do sensor de discriminação:
  # trocar o alvo da escrita do `Commit` para outro usuário **passava** por
  # todos os testes anteriores. A razão é que a ida e volta afirma só que a
  # coleção da origem ficou igual — e uma escrita que vai para o dono errado
  # deixa a origem igual também, por não tocá-la. Pior: com os dois usuários
  # importando, as duas trocas se cancelam e o estado final parece correto.
  #
  # O que discrimina é afirmar o **lado positivo**: a confirmação precisa
  # gravar, na coleção de quem confirmou, uma quantidade que só o arquivo
  # traz. O `@zoro` importa o arquivo da `@nami`, e as linhas que ele não
  # possuía passam a existir **com dono ele**. Um `Commit` que escrevesse em
  # qualquer outro usuário deixaria essas linhas sem nascer.
  test "a confirmação grava na coleção de quem confirmou, e não na de outro usuário" do
    sign_in(@nami)
    arquivo = exportar
    sign_out

    # O par que só a `@nami` possui: para o `@zoro` ele é criação, e é por ele
    # que se vê em qual coleção a escrita caiu.
    assert_nil CollectionItem.for_user(@zoro).find_by(card_variant: @virgula),
               "pré-condição: o @zoro não pode possuir esta variante antes"

    sign_in(@zoro)
    confirmar(previsualizar(arquivo))

    criado = CollectionItem.for_user(@zoro).find_by(card_variant: @virgula)

    assert_not_nil criado,
                   "a linha precisa nascer na coleção de quem confirmou; se ela " \
                   "não existe, a escrita foi para o dono errado (POR-12)"
    assert_equal 3, criado.quantity

    # E o dono errado mais provável — a origem do arquivo — não ganhou linha
    # nenhuma: a `@nami` continua com exatamente as variantes que já tinha.
    assert_equal 5, CollectionItem.for_user(@nami).count,
                   "a coleção da origem do arquivo não pode ganhar nem perder linha"
  end

  # A ida e volta do **próprio** arquivo, para o `@zoro`, fecha igual. Prova
  # que a idempotência não é propriedade de um usuário específico nem do
  # cenário da `@nami`.
  test "a ida e volta fecha também para o segundo usuário" do
    sign_in(@zoro)

    antes = retrato_de(@zoro)
    confirmar(previsualizar(exportar))

    assert_equal antes, retrato_de(@zoro)
  end
end
