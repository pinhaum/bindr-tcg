require "test_helper"

# SPEC_DEVIATION: não há navegador no container, logo não há system test — o
# padrão já usado nas T8 e T11 desta feature e nas T12/T14 do `catalogo`.
#
# Reason: o Req. 8.1 fala de "marcar uma variante como desejada", que é
# comportamento de interface. O que se pode provar sem navegador é o **HTML
# renderizado**: que existe um controle por impressão, que ele aponta para a
# rota certa com a variante certa, que tem rótulo acessível distinguível, e que
# o anônimo não o vê. O que **não** se prova aqui é o clique real nem o
# comportamento visual em 360px — este último é decisão de layout justificada
# no partial (`wishlist_items/_mark`) e na folha, sem cobertura automatizada,
# como a grade em 360px do `catalogo`.
#
# T13 — o controle de marcar como desejada vive **só na página de detalhe**, e
# esta escolha é testada: o Req. 2.5 exige a grade usável em 360px sem scroll
# horizontal, e o tile já carrega o controle de posse. Um teste que exigisse o
# controle na grade travaria a decisão contrária; os daqui travam a decisão
# tomada.
class WishlistMarkUiTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "chopper-t13ui@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "WU13", name: "Romance Dawn", kind: "booster")

    @card = Card.create!(card_set: @set, card_number: "WU13-a", name: "Roronoa Zoro",
      card_type: "character", colors: [ "Green" ], cost: 3, power: 5000)
    @base = CardVariant.create!(card: @card, card_set: @set, variant_code: "WU13-a",
      rarity: "C", art_kind: "base")
    @parallel = CardVariant.create!(card: @card, card_set: @set, variant_code: "WU13-a_p1",
      rarity: "SR", art_kind: "parallel")

    # Carta de variante única, para a asserção sobre a grade.
    @solo_card = Card.create!(card_set: @set, card_number: "WU13-b", name: "Nami",
      card_type: "character", colors: [ "Blue" ], cost: 1, power: 1000)
    @solo = CardVariant.create!(card: @solo_card, card_set: @set, variant_code: "WU13-b",
      rarity: "C", art_kind: "base")
  end

  def sign_in(user = @user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # Req. 8.1 / COL-14 — um controle **por impressão**, como a posse. Agregar na
  # carta destruiria a distinção entre `Card` e `CardVariant`, que é a decisão
  # central do modelo (design.md §3.1).
  test "o detalhe oferece um controle de desejo por impressão" do
    sign_in
    get card_path(@card.card_number)

    assert_response :success
    assert_select ".wishlist-mark", 2
    assert_select ".wishlist-mark__form input[name=?][value=?]", "card_variant_id", @base.id.to_s
    assert_select ".wishlist-mark__form input[name=?][value=?]", "card_variant_id", @parallel.id.to_s
  end

  # Numa página com várias impressões, "Quero esta" se repete idêntico: o que
  # distingue um controle do outro para quem navega por formulário é o nome do
  # **grupo** (SC 2.4.6 / 4.1.2), não um `aria-label` no campo.
  test "cada formulário de desejo se identifica pela carta e pela impressão" do
    sign_in
    get card_path(@card.card_number)

    assert_select ".wishlist-mark__form[role=group][aria-label=?]",
      "Marcar Roronoa Zoro WU13-a como desejada"
    assert_select ".wishlist-mark__form[role=group][aria-label=?]",
      "Marcar Roronoa Zoro WU13-a_p1 como desejada"
  end

  # SC 2.5.3 (*Label in Name*), achado HIGH da revisão de a11y desta task.
  #
  # `aria-label` tem precedência **total** sobre `<label for>` na computação do
  # nome acessível: um `aria-label` no campo descartaria o rótulo visível
  # "Quero", e quem usa comando de voz ("clique em Quero") deixaria de
  # conseguir mirar o campo. O contexto de carta e impressão mora no `role`
  # `group` do formulário justamente para não competir com o rótulo visível.
  test "o campo de alvo não tem aria-label que sobrescreva o rótulo visível" do
    sign_in
    get card_path(@card.card_number)

    # SC 2.5.3: um `aria-label` aqui descartaria o rótulo visível "Quero" do
    # nome acessível do campo.
    assert_select ".wishlist-mark__input[aria-label]", 0
    # E o rótulo visível continua associado ao campo.
    assert_select "label.wishlist-mark__label", text: "Quero", minimum: 1
  end

  # Ids repetidos quebrariam a associação `label`/`input` de todas as
  # impressões menos a primeira.
  test "cada campo de alvo tem id próprio, associado ao seu rótulo" do
    sign_in
    get card_path(@card.card_number)

    ids = css_select(".wishlist-mark__input").map { |node| node["id"] }
    assert_equal ids.uniq, ids, "ids repetidos quebram a associação label/input"

    ids.each do |id|
      assert_select "label[for=?]", id
    end
  end

  # O formulário já vem preenchido com o alvo registrado, e o botão muda de
  # rótulo: sem isso, o usuário não teria como saber que a impressão já está na
  # lista e digitaria um alvo novo às cegas.
  test "impressão já desejada mostra o alvo registrado e rótulo de atualização" do
    WishlistItem.create!(user: @user, card_variant: @base, target_quantity: 4)

    sign_in
    get card_path(@card.card_number)

    assert_select ".wishlist-mark__input[id=?][value=?]", "wishlist_target_#{@base.id}", "4"
    assert_select ".wishlist-mark__submit[value=?]", "Atualizar desejo"
    # A outra impressão não foi marcada e continua oferecendo o rótulo inicial.
    assert_select ".wishlist-mark__submit[value=?]", "Quero esta"
  end

  # O catálogo é público (Req. 6.3) e não pode quebrar sem sessão; um
  # formulário que só levasse ao login seria promessa quebrada.
  test "o anônimo não vê controle de desejo no detalhe" do
    get card_path(@card.card_number)

    assert_response :success
    assert_select ".wishlist-mark", 0
  end

  # Req. 2.5 — a decisão de layout, travada por teste. O tile da grade já
  # carrega o controle de posse em colunas abaixo de 180px; acrescentar ali um
  # campo numérico e um botão espremeria o caminho principal do produto.
  test "a grade não recebe controle de desejo, nem em carta de variante única" do
    sign_in
    get catalog_path

    assert_response :success
    assert_select ".card-tile .ownership", minimum: 1,
      message: "o controle de posse continua na grade"
    assert_select ".card-tile .wishlist-mark", 0,
      "marcar desejo fica no detalhe: o tile não comporta um segundo controle em 360px"
  end

  # Fecha a matriz autenticado/anônimo × grade/detalhe.
  test "a grade também não traz controle de desejo para o anônimo" do
    get catalog_path

    assert_response :success
    assert_select ".wishlist-mark", 0
  end

  # O caminho sem JavaScript é requisito dos Edge Cases, não cortesia: o
  # formulário é um `<form method="post">` de verdade, com token CSRF.
  #
  # O `Referer` vai **explícito** no `post`. `ActionDispatch::IntegrationTest`
  # não popula esse header a partir da navegação anterior como um navegador
  # faria, então sem ele o teste exercitaria só o `fallback_location` e a
  # asserção de destino seria vazia — achado HIGH da revisão de testes, onde o
  # comentário afirmava um redirect que nenhuma asserção verificava.
  test "marcar desejo pelo formulário do detalhe devolve o usuário ao detalhe" do
    sign_in
    get card_path(@card.card_number)

    assert_difference -> { WishlistItem.count }, 1 do
      post wishlist_items_path,
        params: { card_variant_id: @parallel.id, target_quantity: 2 },
        headers: { "HTTP_REFERER" => card_path(@card.card_number) }
    end

    assert_equal @parallel, WishlistItem.sole.card_variant
    assert_redirected_to card_path(@card.card_number)
  end

  # Sem `Referer` — o caso de quem chega por URL direta — o destino é o
  # `fallback_location`, e não uma exceção.
  test "sem Referer, marcar desejo cai na lista de desejos" do
    sign_in

    post wishlist_items_path, params: { card_variant_id: @base.id, target_quantity: 1 }

    assert_redirected_to wishlist_items_path
  end
end
