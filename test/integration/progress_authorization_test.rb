require "test_helper"
require "ripper"

# SPEC_DEVIATION: `spec.md`, história "P2: Isolamento e desempenho da agregação",
# critérios 1, 2 e 4 — falam do que cada usuário **vê** na página, e o
# `Independent Test` da história diz "conferir que cada um vê apenas o seu
# número".
#
# Reason: **não há navegador no container** (`CLAUDE.md`), logo a maior
# fidelidade disponível é `assert_select`/`css_select` sobre o HTML que a action
# renderiza de fato. É o precedente já estabelecido em
# `collection_ownership_ui_test.rb` e repetido nas T4 e T5 desta feature. Nenhum
# critério desta task depende de layout ou de interação — só de **qual número
# chega ao corpo e de quem ele é**.
#
# ---
#
# T7 — isolamento entre usuários (PRG-08 / Req. 6.5).
#
# O recorte é **autorização**, não cálculo: os números já estão provados por
# unidade em `set_progress_query_test.rb` (T1–T3) e a marcação em
# `progress_ui_test.rb` (T5–T6). Aqui prova-se que o número que chega ao corpo é
# o do usuário da sessão e de mais ninguém, e que nada vindo do request o
# desloca.
#
# ## O cenário é construído para discriminar, não para passar
#
# Os dois usuários possuem variantes **do mesmo set**, e **todo** número visível
# difere entre eles. Com qualquer campo coincidindo, uma troca de usuário
# naquele campo passaria despercebida — a asserção seria satisfeita pelo valor
# errado.
#
# `@set_x`: `base_set_size` 6, nove variantes (4 `base`, 2 `other`, 3 `parallel`).
#
# | Métrica                   | `@nami` | `@zoro` |
# |---------------------------|---------|---------|
# | `owned_variants`          | 2       | 5       |
# | `base_owned_variants`     | 1       | 3       |
# | `completion_percent`      | ~16,7%  | 50%     |
# | `parallel_owned_variants` | 1       | 2       |
# | `total_variants`          | 9       | 9       |
#
# `total_variants` é a única coincidência, e é **obrigatória**: o total sai do
# catálogo e não depende de quem olha. Há teste explícito exigindo que ele
# **não** varie entre os usuários, justamente porque a assimetria entre o que é
# do catálogo e o que é da coleção é o que a T1 e a T3 deixaram registrada.
#
# As posses são **disjuntas**: `@zoro` possui cinco variantes que `@nami` não
# possui e vice-versa. Um vazamento — `for_user` trocado por `CollectionItem.all`,
# ou o `LEFT JOIN` perdendo a correlação por usuário — infla o número de `@nami`
# em vez de deixá-lo intacto, e é isso que as asserções medem.
#
# `@usopp` existe sem posse nenhuma: é o terceiro caso, o que prova que "todos
# os sets com zero" é o resultado de não ter nada, e não de a página não saber
# de quem é o cálculo.
class ProgressAuthorizationTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @nami = User.create!(email: "nami-prg7@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-prg7@example.com", password: PASSWORD)
    @usopp = User.create!(email: "usopp-prg7@example.com", password: PASSWORD)

    # Denominador 6 contra nove impressões de propósito: `base_set_size`,
    # `total_variants` e os numeradores de cada usuário são todos números
    # distintos, então trocar um pelo outro na marcação derruba asserção.
    @set_x = CardSet.create!(code: "OPp7x", name: "Romance Dawn", kind: "booster",
                             base_set_size: 6, total_set_size: 9)

    @base = 1.upto(4).map { |i| variant(@set_x, "p7xb#{i}", "base") }
    @other = 1.upto(2).map { |i| variant(@set_x, "p7xo#{i}", "other") }
    @parallel = 1.upto(3).map { |i| variant(@set_x, "p7xp#{i}", "parallel") }

    # `@nami`: 1 base + 1 parallel = 2 possuídas, 1 no numerador (~16,7%).
    # A quantidade 4 é de propósito: o progresso conta **variantes**, nunca
    # cópias — se contasse cópias, `@nami` (5 cópias) superaria `@zoro`.
    own(@nami, @base[0], 4)
    own(@nami, @parallel[0], 1)

    # `@zoro`: 2 base + 1 other + 2 parallel = 5 possuídas, 3 no numerador (50%).
    # **Nenhuma variante em comum com `@nami`**: todo número de um que apareça
    # para o outro é vazamento, não coincidência.
    own(@zoro, @base[1], 1)
    own(@zoro, @base[2], 1)
    own(@zoro, @other[0], 1)
    own(@zoro, @parallel[1], 1)
    own(@zoro, @parallel[2], 1)

    # Zero é linha existente que significa "não tenho" (Req. 7.3): `@usopp` tem
    # registro sobre uma variante que `@zoro` possui, e mesmo assim não vê
    # número nenhum de `@zoro`.
    own(@usopp, @base[1], 0)
  end

  # A suíte roda em paralelo e o projeto não usa fixtures YAML: cada teste cria
  # os próprios registros, com chaves naturais distintas por arquivo para não
  # colidir entre workers.
  def variant(set, suffix, art_kind)
    card = Card.create!(card_set: set, card_number: "OP07-#{suffix}", name: "Carta #{suffix}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: suffix,
                        rarity: "C", art_kind: art_kind)
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

  # Os números que a página **de fato exibiu**, lidos da marcação e não da
  # variável de instância. A T4 já prova que `@rows` é do usuário da sessão; o
  # que falta provar é que é esse número que chega aos olhos de quem abriu a
  # página — um vazamento na view (uma consulta de posse feita na marcação, um
  # helper que reconsulta) não seria visível em `view_assigns`.
  def numeros_exibidos(set = @set_x)
    item = css_select("#progress_set_#{set.code}")
    assert_equal 1, item.size, "o set #{set.code} precisa aparecer exatamente uma vez"

    {
      owned: valor(".progress-set__owned"),
      total: valor(".progress-set__total"),
      percent: valor(".progress-set__percent-value"),
      parallel_owned: valor(".progress-set__parallel-owned"),
      parallel_total: valor(".progress-set__parallel-total")
    }
  end

  def valor(seletor, set = @set_x)
    nos = css_select("#progress_set_#{set.code} #{seletor}")
    assert_equal 1, nos.size, "#{seletor} precisa aparecer exatamente uma vez no set"
    nos.first.text.squish
  end

  # --- Critério 4: dois usuários, o mesmo set, números diferentes ---

  # A prova central da task. Os dois possuem variantes do **mesmo** set, e todo
  # número que depende da coleção difere entre eles. Um vazamento de qualquer
  # direção altera pelo menos um dos dez valores abaixo.
  test "dois usuários com posse no mesmo set veem cada um o seu número" do
    sign_in(@nami)
    get progress_path
    assert_response :success
    de_nami = numeros_exibidos

    sign_out

    sign_in(@zoro)
    get progress_path
    assert_response :success
    de_zoro = numeros_exibidos

    assert_equal({ owned: "2", total: "9", percent: "17%",
                   parallel_owned: "1", parallel_total: "3" }, de_nami)
    assert_equal({ owned: "5", total: "9", percent: "50%",
                   parallel_owned: "2", parallel_total: "3" }, de_zoro)

    # A asserção que torna as duas anteriores discriminantes de fato: se um dia
    # o cenário for alterado para posses do mesmo tamanho, isto falha antes de
    # as asserções acima passarem a não provar nada.
    assert_not_equal de_nami[:owned], de_zoro[:owned]
    assert_not_equal de_nami[:percent], de_zoro[:percent]
    assert_not_equal de_nami[:parallel_owned], de_zoro[:parallel_owned]
  end

  # A assimetria entre catálogo e coleção, travada: `total_variants` e
  # `parallel_variants` **não** podem variar com quem olha. Um teste que só
  # exigisse "números diferentes" seria satisfeito por uma implementação que
  # recortasse o catálogo pelo usuário — o que esconderia do colecionador
  # exatamente as cartas que ele ainda não tem.
  test "o total do set não depende de quem olha, só a posse depende" do
    sign_in(@nami)
    get progress_path
    de_nami = numeros_exibidos
    sign_out

    sign_in(@usopp)
    get progress_path
    de_usopp = numeros_exibidos

    assert_equal de_nami[:total], de_usopp[:total],
                 "o total de impressões é do catálogo e não da coleção"
    assert_equal de_nami[:parallel_total], de_usopp[:parallel_total],
                 "o total de parallels do set é do catálogo e não da coleção"
    assert_not_equal de_nami[:owned], de_usopp[:owned]
  end

  # A coleção de `@zoro` não vaza para a métrica de parallels de `@nami`. Está
  # em teste próprio porque os parallels saem de uma coluna `FILTER` separada no
  # mesmo `SELECT`: um recorte de usuário perdido **só ali** deixaria o
  # percentual correto e a contagem de parallels errada, e a asserção conjunta
  # do teste anterior pode ser lida como cobrindo o percentual apenas.
  test "a coleção de um usuário não vaza para a contagem de parallels do outro" do
    # `@zoro` possui 2 parallels e `@nami`, 1. A soma (3) coincide com o total
    # do set de propósito: se a contagem ignorasse o usuário, `@nami` veria "3
    # de 3" — indistinguível de "possuo todos" para quem lê a página.
    sign_in(@nami)

    get progress_path

    assert_select "#progress_set_OPp7x .progress-set__parallel-owned", text: "1",
                  message: "`@nami` possui 1 parallel; os 2 de `@zoro` não são dela"
    assert_select "#progress_set_OPp7x .progress-set__parallel-total", text: "3"
  end

  # O mesmo para o numerador do percentual, na direção oposta: `@zoro` não pode
  # herdar a base de `@nami`. Sem recorte de usuário o numerador viraria 4
  # (3 de `@zoro` + 1 de `@nami`) e o percentual saltaria de 50% para 67%.
  test "o percentual de um usuário não absorve a base possuída pelo outro" do
    sign_in(@zoro)

    get progress_path

    assert_select "#progress_set_OPp7x .progress-set__percent-value", text: "50%"
    assert_select "#progress_set_OPp7x .progress-set__percent-basis",
                  text: /\(3 de 6 do set base\)/,
                  message: "o numerador é o de `@zoro` (3), não a soma com o de `@nami` (4)"
  end

  # --- Critério 5: usuário sem posse alguma ---

  # `@usopp` não vê número de quem tem. A linha zerada que ele mantém sobre uma
  # variante de `@zoro` é o detalhe que torna o teste discriminante: uma
  # implementação que tratasse posse por **existência de registro** em vez de
  # por `owned` lhe daria 1, e uma que ignorasse o usuário lhe daria 7.
  test "usuário sem posse alguma não vê número de quem tem" do
    sign_in(@usopp)

    get progress_path

    assert_response :success
    assert_select ".progress-set", 1, "a página é informativa, não vazia"
    assert_equal({ owned: "0", total: "9", percent: "0%",
                   parallel_owned: "0", parallel_total: "3" }, numeros_exibidos)
    assert_select "#progress_set_OPp7x .progress-set__percent-basis",
                  text: /\(0 de 6 do set base\)/
  end

  # Trocar de sessão na mesma conexão troca o dono do cálculo. Um controller ou
  # query object que memorizasse o usuário em vida mais longa que a requisição —
  # variável de classe, cache, `Current` não resetado — devolveria o número do
  # primeiro usuário na segunda requisição, e este teste morre.
  test "trocar de sessão na mesma conexão troca o dono do cálculo" do
    sign_in(@zoro)
    get progress_path
    assert_equal "5", numeros_exibidos[:owned]

    sign_out

    sign_in(@nami)
    get progress_path

    assert_equal "2", numeros_exibidos[:owned],
                 "a segunda requisição tem que recalcular a partir da sessão nova"
  end

  # --- Critério 3: nenhum identificador vindo do request altera o resultado ---

  test "?user_id= do outro usuário não altera o número exibido" do
    sign_in(@nami)

    get progress_path(user_id: @zoro.id)

    assert_response :success
    assert_equal({ owned: "2", total: "9", percent: "17%",
                   parallel_owned: "1", parallel_total: "3" }, numeros_exibidos,
                 "o número exibido é o do usuário da sessão, não o do parâmetro")
  end

  # `?user_id=` do **próprio** usuário passaria intacto mesmo que a action
  # lesse o parâmetro. Este teste existe para fixar que a posse creditada é a da
  # sessão: é o teste anterior que morre quando a leitura do parâmetro entra, e
  # este que impede alguém de "consertá-lo" fazendo o parâmetro valer.
  test "a sessão prevalece mesmo quando o request informa o usuário correto" do
    sign_in(@nami)

    get progress_path(user_id: @nami.id)

    assert_equal "2", numeros_exibidos[:owned]
  end

  # As outras formas de enfiar um identificador na requisição, cada uma pela
  # porta que alguém tentaria sem saber que existe teste a respeito. Nenhuma
  # delas pode deslocar o cálculo.
  test "nenhuma forma de informar identificador desloca o cálculo" do
    sign_in(@nami)

    tentativas = [
      { user_id: @zoro.id },
      { user: @zoro.id },
      { id: @zoro.id },
      { user_id: @zoro.email },
      { user_id: [ @nami.id, @zoro.id ] },
      { user_id: { id: @zoro.id } }
    ]

    tentativas.each do |params|
      get progress_path, params: params

      assert_response :success, "#{params.inspect} não pode quebrar a página"
      assert_equal "2", numeros_exibidos[:owned],
                   "#{params.inspect} deslocou o cálculo para outro usuário"
      assert_equal "17%", numeros_exibidos[:percent], "#{params.inspect} alterou o percentual"
    end
  end

  # Cabeçalho é request tanto quanto query string, e é a porta que um teste de
  # `params` não cobre — o limite que os testes irmãos registram explicitamente.
  # Aqui ele é fechado pelo efeito.
  test "cabeçalho de requisição informando usuário não desloca o cálculo" do
    sign_in(@nami)

    get progress_path, headers: { "X-User-Id" => @zoro.id.to_s, "X-User" => @zoro.email }

    assert_response :success
    assert_equal "2", numeros_exibidos[:owned]
  end

  # --- Provas estruturais: o caminho errado não existe, em vez de não ser usado ---

  # A barreira de tipo de `CollectionItem.for_user` é o que torna PRG-08
  # satisfeito **por construção**: uma consulta montada a partir de um id de
  # request não compila por acidente — explode. Sem esta asserção, a suíte
  # provaria apenas que hoje ninguém escreveu o caminho errado.
  test "o query object recusa um id de usuário em vez de devolver dado alheio" do
    assert_raises(ArgumentError) { SetProgressQuery.new(@zoro.id).call }
    assert_raises(ArgumentError) { SetProgressQuery.new(@zoro.email).call }

    # `nil` não é caso de erro: é numerador vazio, e o denominador continua
    # intacto. É o que separa "anônimo" de "id inválido".
    linha = SetProgressQuery.new(nil).call.find { |row| row.set_code == @set_x.code }
    assert_equal 0, linha.owned_variants
    assert_equal 9, linha.total_variants
  end

  # Nenhum identificador de usuário cabe na URL do progresso — é o que torna
  # `?user_id=` inócuo por desenho e não por checagem. Acrescentar um segmento
  # dinâmico à rota quebra esta asserção e obriga quem o fizer a enfrentar a
  # decisão (Req. 6.5).
  #
  # O casamento é por **sufixo** e não por igualdade: uma rota futura sob
  # namespace (`api/progress`) apontaria para a mesma feature e escaparia de um
  # `== "progress"`.
  test "nenhuma rota de progresso aceita segmento dinâmico" do
    rotas = Rails.application.routes.routes.select do |rota|
      rota.defaults[:controller].to_s.split("/").last == "progress"
    end

    assert_not_empty rotas, "a T4 entregou a rota de progresso; se sumiu, a suíte precisa saber"

    rotas.each do |rota|
      assert_empty rota.path.required_names,
                   "#{rota.path.spec} aceita #{rota.path.required_names.inspect}: " \
                   "nenhum identificador pode caber na URL do progresso"
    end
  end

  # Prova estrutural complementar às de comportamento: nem o controller **nem a
  # view** derivam usuário do request. A T4 já cobre o controller; a view é a
  # metade que faltava, e é onde um `params[:user_id]` passaria despercebido por
  # não haver revisão de ERB tão atenta quanto a de controller.
  #
  # Por AST (`Ripper.sexp`) sobre o Ruby que o ERB compila, e não por regex: um
  # regex de `params[:user_id]` é contornado sem intenção por
  # `params.dig(:user_id)` ou por `params.to_unsafe_h[:user_id]`, e um regex de
  # `/params/` casaria com a palavra dentro dos comentários da própria view.
  test "a view de progresso não lê params nem User em lugar nenhum" do
    fonte = Rails.root.join("app/views/progress/index.html.erb").read
    ruby = ActionView::Template::Handlers::ERB::Erubi.new(fonte).src
    arvore = Ripper.sexp(ruby)

    assert_not_nil arvore, "a view não compila para Ruby válido"

    identificadores = identificadores(arvore)
    refute_includes identificadores, "params",
                    "o progresso exibido sai de @rows, montado a partir de Current.user"
    refute_includes constantes(arvore), "User",
                    "a view não consulta usuário: ela renderiza o que a action calculou"
  end

  private
    # Todo identificador em posição de chamada ou de referência. `Ripper.sexp`
    # já descarta comentários do Ruby compilado, então o que sobra é código.
    def identificadores(no)
      return [] unless no.is_a?(Array)

      case no
      in [ :@ident, nome, * ] then [ nome ]
      else no.flat_map { |filho| identificadores(filho) }
      end
    end

    def constantes(no)
      return [] unless no.is_a?(Array)

      case no
      in [ :@const, nome, * ] then [ nome ]
      else no.flat_map { |filho| constantes(filho) }
      end
    end
end
