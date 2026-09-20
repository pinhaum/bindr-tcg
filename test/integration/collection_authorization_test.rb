require "test_helper"
require "ripper"

# SPEC_DEVIATION: `spec.md`, história "P1: Isolamento entre usuários" (COL-05),
# critério 4 — "WHEN um usuário autenticado solicitar um item de coleção que
# pertence a outro usuário THEN the system SHALL responder com 404 sem revelar a
# existência do item" — pressupõe uma URL que aceite id de `collection_item`.
#
# Reason: o desenho entregue pela T6 **não expõe nenhuma**. As duas rotas são
# `POST /collection_items/:card_variant_id/increment` e `.../decrement`: a chave
# é a **variante**, porque o botão "+1" nasce na grade do catálogo, onde o
# registro de coleção normalmente ainda não existe. O requisito de origem,
# `.context/requirements.md` Req. 6.5 ("Um usuário NUNCA DEVE conseguir ler ou
# alterar a coleção de outro"), não menciona 404 nem id — o "404 por id" é uma
# operacionalização que a spec da feature escolheu assumindo um desenho REST por
# id de item. Aqui o requisito é satisfeito **por construção**: não há id de item
# em nenhuma URL, logo não há id de outro usuário a recusar. Criar rota por id só
# para ter o que testar produziria superfície de ataque que o produto não usa, e
# código morto.
#
# Decisão do orquestrador, registrada em `.specs/STATE.md`: não acrescentar rota
# por id de item nesta task. O critério migra para a **T13 (wishlist)**, que tem
# remoção por item e portanto id na URL de verdade — lá o teste de 404 é real, e
# não encenado.
#
# O que este arquivo faz no lugar: prova a **ausência** por teste em vez de por
# afirmação (`nenhuma rota de collection_items aceita id de item`), de modo que
# acrescentar a rota no futuro não passe sem enfrentar a decisão.
#
# ---
#
# T7 — isolamento entre usuários (Req. 6.5 / COL-05).
#
# O recorte é autorização, não operação: a T6 já cobriu incremento, decremento,
# piso em zero e anônimo em `collection_items_test.rb`. Aqui o que se prova é que
# o usuário da escrita e da leitura é **sempre** o da sessão, e que nada vindo do
# request o desloca.
class CollectionAuthorizationTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @nami = User.create!(email: "nami-t7@example.com", password: PASSWORD)
    @zoro = User.create!(email: "zoro-t7@example.com", password: PASSWORD)
    @variant = create_variant(suffix: "t7a")
  end

  # A suíte roda em paralelo e o projeto não usa fixtures YAML: cada teste cria
  # os próprios registros, com chaves naturais distintas por arquivo para não
  # colidir entre workers.
  def create_variant(suffix:)
    set = CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: "OP01-#{suffix}",
      rarity: "L", art_kind: "base")
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  def sign_out
    delete session_path
  end

  def quantity_for(user, variant = @variant)
    CollectionItem.for_user(user).find_by(card_variant: variant)&.quantity
  end

  # Percorre a AST e devolve todo símbolo que aparece dentro de uma expressão
  # que toca `params`. Cobre `params[:x]`, `params.dig(:x)`,
  # `params.to_unsafe_h[:x]` e `params.permit(:x)` com a mesma regra, porque a
  # busca é pela **subárvore** que contém o identificador `params`, e não por
  # uma lista de métodos de acesso que teria de ser mantida à mão.
  #
  # Um acesso sem símbolo literal (`chave = :user_id; params[chave]`) não expõe
  # símbolo nenhum e cai no conjunto vazio — que **também** falha a asserção,
  # porque o esperado é exatamente `[:card_variant_id]`. Escapar do teste exige,
  # portanto, remover o acesso legítimo junto, o que nenhuma regressão faz por
  # acidente.
  def simbolos_lidos_de_params(no)
    return [] unless no.is_a?(Array)

    # Só o nó de **acesso** conta, e só quando a cadeia de receptores nasce em
    # `params`: `params[:x]`, `params.dig(:x)`, `params.to_unsafe_h[:x]`,
    # `params.permit(:x)`. Subir mais do que isso varreria o método inteiro e
    # devolveria todo literal do corpo — inclusive o SQL — em vez das chaves.
    argumentos =
      case no
      in [ :aref, receptor, indice ] if enraizado_em_params?(receptor) then indice
      in [ :method_add_arg, [ :call, receptor, * ], argumentos ] if enraizado_em_params?(receptor) then argumentos
      in [ :command_call, receptor, *, argumentos ] if enraizado_em_params?(receptor) then argumentos
      else nil
      end

    return simbolos_em(argumentos) if argumentos

    no.flat_map { |filho| simbolos_lidos_de_params(filho) }
  end

  # `params` na raiz da cadeia: `params` sozinho, ou qualquer `.metodo` sobre
  # algo que já nasce em `params`.
  def enraizado_em_params?(no)
    case no
    in [ :vcall | :var_ref, [ :@ident, "params", * ] ] then true
    in [ :call, receptor, * ] then enraizado_em_params?(receptor)
    in [ :aref, receptor, * ] then enraizado_em_params?(receptor)
    in [ :method_add_arg, interno, * ] then enraizado_em_params?(interno)
    else false
    end
  end

  # Só **símbolo literal** e string literal contam: o nome do método de acesso
  # (`dig`, `to_unsafe_h`) e o próprio `params` são identificadores, não chaves,
  # e entrariam como ruído se a busca fosse por `@ident` solto.
  def simbolos_em(no)
    case no
    in [ :symbol_literal | :dyna_symbol, *resto ] then nomes_literais(resto)
    in [ :string_literal, *resto ] then nomes_literais(resto)
    in Array then no.flat_map { |filho| simbolos_em(filho) }
    else []
    end
  end

  def nomes_literais(no)
    case no
    in [ :@ident | :@const | :@kw | :@tstring_content, String => nome, * ] then [ nome.to_sym ]
    in Array then no.flat_map { |filho| nomes_literais(filho) }
    else []
    end
  end

  # --- Critério 3: dois usuários, a mesma variante, quantidades separadas ---

  # A posse de um não é a posse do outro nem depois de as duas existirem sobre a
  # **mesma** variante. O `UNIQUE (user_id, card_variant_id)` permite as duas
  # linhas; o que se prova aqui é que a escrita de cada sessão cai na linha certa.
  test "dois usuários acumulam quantidades independentes sobre a mesma variante" do
    sign_in @nami
    3.times { post increment_collection_item_path(card_variant_id: @variant.id) }
    sign_out

    sign_in @zoro
    post increment_collection_item_path(card_variant_id: @variant.id)

    assert_equal 3, quantity_for(@nami)
    assert_equal 1, quantity_for(@zoro)
  end

  # O decremento de um usuário não pode tocar a linha do outro. O `WHERE user_id`
  # é o que segura isso; sem ele o `UPDATE` atingiria as duas linhas.
  test "o decremento de um usuário não altera a quantidade do outro" do
    CollectionItem.create!(user: @nami, card_variant: @variant, quantity: 4)
    CollectionItem.create!(user: @zoro, card_variant: @variant, quantity: 9)

    sign_in @nami
    post decrement_collection_item_path(card_variant_id: @variant.id)

    assert_equal 3, quantity_for(@nami)
    assert_equal 9, quantity_for(@zoro)
  end

  # Cada sessão enxerga **a sua** quantidade. Hoje a única leitura devolvida pelo
  # HTTP é a mensagem de confirmação da operação (a exibição na grade é a T8/T11),
  # e ela precisa relatar a posse de quem pediu, não a de quem tem mais cópias.
  test "cada usuário recebe de volta a própria quantidade, não a do outro" do
    CollectionItem.create!(user: @zoro, card_variant: @variant, quantity: 40)

    sign_in @nami
    post increment_collection_item_path(card_variant_id: @variant.id)

    assert_equal "Você tem 1 cópia(s) desta variante.", flash[:notice]
    assert_equal 40, quantity_for(@zoro)
  end

  # O mesmo para o decremento, e aqui sobre a **resposta**, não só sobre o
  # banco: a mensagem devolvida relata a posse de quem operou. Um defeito que
  # escrevesse na linha certa mas relatasse a quantidade da linha do outro
  # usuário seria vazamento de dado alheio sem alterar nada — nenhuma asserção
  # de `quantity_for` o pegaria (achado MEDIUM do `ecc:pr-test-analyzer`).
  test "o decremento relata a própria quantidade, não a do outro usuário" do
    CollectionItem.create!(user: @nami, card_variant: @variant, quantity: 2)
    CollectionItem.create!(user: @zoro, card_variant: @variant, quantity: 40)

    sign_in @nami
    post decrement_collection_item_path(card_variant_id: @variant.id)

    assert_equal "Você tem 1 cópia(s) desta variante.", flash[:notice]
    assert_equal 40, quantity_for(@zoro)
  end

  # O escopo de leitura recusa o caminho errado em vez de devolver dado alheio:
  # `for_user` exige o objeto `User`, então uma consulta construída a partir de um
  # id de request não compila por acidente — explode.
  test "a leitura da coleção por id de usuário é impossível pelo escopo" do
    CollectionItem.create!(user: @zoro, card_variant: @variant, quantity: 7)

    assert_raises(ArgumentError) { CollectionItem.for_user(@zoro.id).to_a }
    assert_empty CollectionItem.for_user(@nami)
    assert_equal [ 7 ], CollectionItem.for_user(@zoro).pluck(:quantity)
  end

  # --- Critério 2: `user_id` no request é ignorado nas DUAS actions ---
  #
  # A T6 já provava isso para o incremento. O decremento é a metade que faltava, e
  # é a mais perigosa: um `user_id` aceito ali **subtrai** da coleção alheia.

  test "user_id no request não desvia o incremento para outro usuário" do
    sign_in @nami

    post increment_collection_item_path(card_variant_id: @variant.id),
      params: { user_id: @zoro.id }

    assert_equal 1, quantity_for(@nami)
    assert_nil quantity_for(@zoro)
  end

  test "user_id no request não deixa um usuário decrementar a coleção do outro" do
    CollectionItem.create!(user: @zoro, card_variant: @variant, quantity: 5)
    sign_in @nami

    post decrement_collection_item_path(card_variant_id: @variant.id),
      params: { user_id: @zoro.id }

    assert_equal 5, quantity_for(@zoro)
    assert_nil quantity_for(@nami)
  end

  # `user_id` na query string, e não no corpo, é o mesmo `params` para o Rails —
  # mas é a forma que um link compartilhado tomaria, e a que passa despercebida.
  test "user_id na query string também é ignorado" do
    sign_in @nami

    post "#{increment_collection_item_path(card_variant_id: @variant.id)}?user_id=#{@zoro.id}"

    assert_equal 1, quantity_for(@nami)
    assert_nil quantity_for(@zoro)
  end

  # O id do dono não vem do request **nem quando o request insiste**: mesmo com
  # `user_id` apontando para o próprio dono da linha existente, a escrita continua
  # saindo da sessão. Se a action lesse `params[:user_id]`, este teste passaria —
  # ele existe para fixar que a posse creditada é a da sessão, e o teste anterior
  # é o que morre quando a leitura do parâmetro entra.
  test "a sessão prevalece mesmo quando o request informa o usuário correto" do
    sign_in @nami

    post increment_collection_item_path(card_variant_id: @variant.id),
      params: { user_id: @nami.id }

    assert_equal 1, quantity_for(@nami)
  end

  # Trocar de sessão troca o dono da escrita. Um controller que memorizasse o
  # usuário em qualquer lugar de vida mais longa que a requisição — variável de
  # classe, cache, `Current` não resetado — credita a segunda operação ao primeiro
  # usuário e este teste morre.
  test "trocar de sessão na mesma conexão troca o dono da escrita" do
    sign_in @nami
    post increment_collection_item_path(card_variant_id: @variant.id)
    sign_out

    sign_in @zoro
    post increment_collection_item_path(card_variant_id: @variant.id)

    assert_equal 1, quantity_for(@nami)
    assert_equal 1, quantity_for(@zoro)
  end

  # --- Critério 4: nenhuma action lê `params[:user_id]` ---

  # Prova estrutural, complementar às de comportamento acima: o controller não
  # deriva o usuário de `params` em lugar nenhum. Um teste de comportamento só
  # pega a leitura que ele exercita; este pega a que alguém acrescentar amanhã
  # numa action nova.
  #
  # A análise é por **AST** (`Ripper.sexp`), não por regex sobre o texto. Um
  # regex de `params[:user_id]` é contornado sem intenção nenhuma por
  # `params.dig(:user_id)`, por `params.to_unsafe_h[:user_id]` ou por
  # `chave = :user_id; params[chave]` — as três formas idiomáticas que alguém
  # escreveria sem saber que existe um teste a respeito. Pela árvore, o que se
  # procura é o **identificador** `params` em qualquer posição, o que reduz a
  # pergunta a "o controller toca `params`?" e torna a lista de acessos
  # irrelevante.
  #
  # Limite conhecido e aceito: isto prova que nenhum dado de request vira
  # usuário **por esta porta**. Um parâmetro com outro nome lido por outro
  # caminho (`request.headers`, `cookies` não assinado) não é coberto aqui — é o
  # que os testes de comportamento acima cobrem, cada um pelo efeito.
  test "o controller de coleção só lê card_variant_id de params, nada mais" do
    fonte = Rails.root.join("app/controllers/collection_items_controller.rb").read
    arvore = Ripper.sexp(fonte)

    assert_not_nil arvore, "o controller não é Ruby válido"

    assert_equal [ :card_variant_id ], simbolos_lidos_de_params(arvore).uniq.sort,
      "o controller derivou de `params` algo além da variante: o usuário vem de " \
      "`Current.user` e nada mais (Req. 6.5)"
  end

  # --- Critério 2 (SPEC_DEVIATION): não existe id de item em URL nenhuma ---

  # O critério "id de item de outro usuário devolve 404" é satisfeito por
  # construção: não há onde esse id caiba. Este teste é o que transforma a
  # construção em garantia verificada — acrescentar uma rota por id de
  # `collection_item` quebra a suíte e obriga quem o fizer a enfrentar a decisão
  # registrada no cabeçalho (e a escrever o teste de 404 que ela adia para a T13).
  test "nenhuma rota de collection_items aceita id de item" do
    # O casamento é por **sufixo** e não por igualdade: uma rota futura sob
    # namespace (`api/collection_items`) apontaria para a mesma feature e
    # escaparia silenciosamente de um `== "collection_items"` — o teste
    # continuaria verde sem checar a rota nova (achado MEDIUM do
    # `ecc:pr-test-analyzer`).
    rotas = Rails.application.routes.routes.select do |rota|
      rota.defaults[:controller].to_s.split("/").last == "collection_items"
    end

    assert_not_empty rotas, "a T6 entregou rotas de coleção; se sumiram, a suíte precisa saber"

    rotas.each do |rota|
      padrao = rota.path.spec.to_s
      segmentos = rota.path.required_names

      assert_equal [ "card_variant_id" ], segmentos,
        "#{padrao} aceita #{segmentos.inspect}: a chave da URL deve ser a variante, " \
        "nunca o id do registro de coleção (ver SPEC_DEVIATION no topo deste arquivo)"
    end
  end
end
