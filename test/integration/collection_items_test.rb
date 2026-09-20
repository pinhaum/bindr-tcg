require "test_helper"

# T6 — incremento e decremento por variante (Req. 7.2, 7.3, 7.4 / COL-07,
# COL-08, COL-18).
#
# O teste é de integração porque o que a task entrega é comportamento HTTP: uma
# requisição por operação, o usuário vindo da sessão e não do request, e o
# anônimo barrado **antes** de a alteração ser aplicada. Nenhuma dessas três
# coisas é observável no model.
#
# A T7 volta a este controller pelo isolamento entre usuários; aqui o recorte é
# a operação em si.
class CollectionItemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "nami@example.com", password: "log-pose-77")
    @variant = create_variant(suffix: "t6a")
  end

  def create_variant(suffix:)
    set = CardSet.create!(code: "OP#{suffix}", name: "Romance Dawn", kind: "booster")
    card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: "Roronoa Zoro",
      card_type: "leader", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: "OP01-#{suffix}",
      rarity: "L", art_kind: "base")
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: "log-pose-77" }
  end

  def quantity_of(variant = @variant, user: @user)
    CollectionItem.for_user(user).find_by(card_variant: variant)&.quantity
  end

  # --- Incremento (Req. 7.2) ---

  # "Uma requisição por operação, sem formulário intermediário": um único `POST`
  # sai de zero-registro para posse 1. Não há `new`, não há `edit`, não há GET
  # preparatório — se houvesse, este teste falharia por não encontrar o
  # registro.
  test "um POST cria o registro e registra a primeira cópia" do
    sign_in

    assert_difference -> { CollectionItem.count }, 1 do
      post increment_collection_item_path(card_variant_id: @variant.id)
    end

    assert_equal 1, quantity_of
  end

  test "incrementos sucessivos somam sobre o mesmo registro" do
    sign_in

    3.times { post increment_collection_item_path(card_variant_id: @variant.id) }

    # Um registro só: o `UNIQUE (user_id, card_variant_id)` e o `ON CONFLICT`
    # do controller precisam concordar. Se o incremento inserisse cegamente, o
    # segundo POST estouraria `RecordNotUnique` em vez de somar.
    assert_equal 1, CollectionItem.for_user(@user).where(card_variant: @variant).count
    assert_equal 3, quantity_of
  end

  # A soma é feita **no banco**, sobre o valor corrente da linha, e não sobre
  # um valor lido antes pela aplicação. Escrever a linha por fora entre a
  # leitura e a escrita é a forma barata de simular a segunda aba: se o
  # controller tivesse memorizado a quantidade, o resultado seria 2 em vez de 6.
  test "o incremento soma sobre o valor corrente da linha, não sobre um valor lido antes" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 5)

    post increment_collection_item_path(card_variant_id: @variant.id)

    assert_equal 6, quantity_of
  end

  # --- Decremento e piso em zero (Req. 7.4) ---

  test "o decremento tira uma cópia" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 2)

    post decrement_collection_item_path(card_variant_id: @variant.id)

    assert_equal 1, quantity_of
  end

  # "Decremento abaixo de zero é rejeitado e mantém a quantidade anterior": a
  # quantidade continua zero, a resposta não é erro de servidor e a linha
  # continua existindo — zero é registro, não ausência (Req. 7.3).
  test "decremento em quantidade zero é rejeitado e mantém o zero" do
    sign_in
    item = CollectionItem.create!(user: @user, card_variant: @variant, quantity: 0)

    post decrement_collection_item_path(card_variant_id: @variant.id)

    assert_response :redirect
    assert_equal 0, item.reload.quantity
  end

  test "decrementar de uma cópia chega a zero e para lá" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variant, quantity: 1)

    post decrement_collection_item_path(card_variant_id: @variant.id)
    assert_equal 0, quantity_of

    post decrement_collection_item_path(card_variant_id: @variant.id)
    assert_equal 0, quantity_of
  end

  # "Decremento de variante sem registro não cria registro negativo": o caso
  # que importa é o **nenhum** registro criado. Um controller que fizesse
  # find_or_create antes de decrementar passaria no teste do piso e falharia
  # aqui, deixando lixo com quantidade zero para cada botão apertado por
  # engano.
  test "decremento de variante sem registro não cria registro nenhum" do
    sign_in

    assert_no_difference -> { CollectionItem.count } do
      post decrement_collection_item_path(card_variant_id: @variant.id)
    end

    assert_nil quantity_of
  end

  test "decremento rejeitado avisa o usuário em português" do
    sign_in

    post decrement_collection_item_path(card_variant_id: @variant.id)

    assert_equal "Você não tem cópias desta variante para remover.", flash[:alert]
  end

  # --- Anônimo (Req. 6.4) ---

  test "anônimo é redirecionado e o incremento não é aplicado" do
    assert_no_difference -> { CollectionItem.count } do
      post increment_collection_item_path(card_variant_id: @variant.id)
    end

    assert_redirected_to new_session_path
  end

  test "anônimo é redirecionado e o decremento não é aplicado" do
    item = CollectionItem.create!(user: @user, card_variant: @variant, quantity: 2)

    post decrement_collection_item_path(card_variant_id: @variant.id)

    assert_redirected_to new_session_path
    assert_equal 2, item.reload.quantity
  end

  # --- O usuário vem da sessão, nunca do request (Req. 6.5) ---
  #
  # A T7 aprofunda o isolamento; esta asserção fica aqui porque é a operação
  # desta task que poderia aceitar um `user_id` por descuido.

  test "user_id no request é ignorado e a posse vai para o usuário da sessão" do
    outro = User.create!(email: "zoro@example.com", password: "log-pose-77")
    sign_in

    post increment_collection_item_path(card_variant_id: @variant.id), params: { user_id: outro.id }

    assert_equal 1, quantity_of(user: @user)
    assert_nil quantity_of(user: outro)
  end

  # --- Variante inexistente ---

  test "variante inexistente é 404 e não cria registro" do
    sign_in

    assert_no_difference -> { CollectionItem.count } do
      post increment_collection_item_path(card_variant_id: 0)
    end

    assert_response :not_found
  end

  # --- Volta à página de origem ---
  #
  # O botão vive na grade e no detalhe (Req. 5.3 / COL-18): terminar a operação
  # na raiz tiraria o usuário do lugar onde ele estava registrando a caixa de
  # boosters. A T8 substitui isso por Turbo Stream, e este redirect continua
  # sendo o caminho sem JavaScript.
  test "o redirect devolve o usuário à página de onde veio" do
    sign_in
    origem = card_path(@variant.card.card_number)

    post increment_collection_item_path(card_variant_id: @variant.id),
      headers: { "HTTP_REFERER" => origem }

    assert_redirected_to origem
  end

  # O destino do redirect vem do `Referer`, que é header do cliente. Um
  # `Referer` de outro host cai no `fallback_location` em vez de levar o
  # usuário para fora do app — achado MEDIUM da revisão de segurança. Hoje o
  # default de `raise_on_open_redirects` já cobriria isso; o teste existe para
  # que a cobertura não dependa de uma config global que ninguém relaciona com
  # a linha do redirect.
  test "referer de outro host não leva o usuário para fora do app" do
    sign_in

    post increment_collection_item_path(card_variant_id: @variant.id),
      headers: { "HTTP_REFERER" => "https://evil.example.com/phishing" }

    assert_redirected_to catalog_path
    assert_equal 1, quantity_of
  end
end
