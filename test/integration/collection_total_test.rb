require "test_helper"

# T11 — total de cartas possuídas (Req. 7.7 / COL-12), história "P2: Filtro de
# posse e total", critérios 4 e 5.
#
# O total é sobre a **coleção inteira** do usuário da sessão, não sobre a
# página exibida: é por isso que os testes daqui paginam e filtram a grade e
# continuam exigindo o mesmo número. Somar `@owned_quantities` — o hash que a
# T8 montou para exibir a quantidade por tile — daria o total da página, que
# mudaria a cada clique de paginação.
#
# Todas as quantidades semeadas são **diferentes de 1** de propósito. Com uma
# cópia por variante, `sum(:quantity)` e `count` devolvem o mesmo número e
# nenhum teste distinguiria "contando cópias" de "contando variantes
# distintas", que é exatamente o que o critério 4 separa.
class CollectionTotalTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "nico-t11@example.com", password: PASSWORD)
    @outro = User.create!(email: "franky-t11@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OPt11", name: "Romance Dawn", kind: "booster")

    @robin = create_card(number: "OP01-t11a", name: "Nico Robin")
    @chopper = create_card(number: "OP01-t11b", name: "Tony Tony Chopper")
    @brook = create_card(number: "OP01-t11c", name: "Brook")

    @variante_robin = create_variant(@robin, "OP01-t11a")
    @variante_chopper = create_variant(@chopper, "OP01-t11b")
    @variante_brook = create_variant(@brook, "OP01-t11c")
  end

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

  # O texto do parágrafo com o espaçamento normalizado. O ERB quebra linha
  # entre o número e a unidade, e o navegador colapsa esse espaço em branco na
  # renderização — asserir sobre o texto cru faria a asserção depender da
  # indentação do template em vez da frase que o usuário lê e o leitor de tela
  # anuncia.
  def total_exibido
    nodes = css_select(".catalog__owned-total")
    return nil if nodes.empty?

    nodes.first.text.squish
  end

  # --- Critério 4: "contando cópias" ---

  # O teste que separa `sum(:quantity)` de `count`: três cópias de uma variante
  # e duas de outra são **cinco** cópias em **duas** variantes. Se a agregação
  # virar `count`, o número cai para 2 e este teste morre.
  test "o total soma as cópias, não as variantes distintas" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 3)
    CollectionItem.create!(user: @user, card_variant: @variante_chopper, quantity: 2)

    sign_in
    get catalog_path

    assert_response :success
    assert_select ".catalog__owned-total", text: /\b5\b/
    refute_match(/\b2 cópias\b/, total_exibido,
      "2 seria a contagem de variantes distintas, não de cópias")
  end

  # --- Critério 5: quantidade zero não entra no total ---

  # Zero é linha existente, não ausência de linha (Req. 7.3): o usuário que
  # zerou uma quantidade mantém o registro. Ele não pode inflar o total nem
  # pela soma nem por uma contagem futura de linhas.
  test "variante com quantidade zero não entra no total" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 4)
    CollectionItem.create!(user: @user, card_variant: @variante_chopper, quantity: 0)

    sign_in
    get catalog_path

    assert_select ".catalog__owned-total", text: /\b4\b/
  end

  # A mesma asserção pelo lado que discrimina a agregação: com **só** linhas
  # zeradas, uma soma dá zero e uma contagem de linhas daria 2.
  test "coleção inteiramente zerada exibe total zero" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 0)
    CollectionItem.create!(user: @user, card_variant: @variante_chopper, quantity: 0)

    sign_in
    get catalog_path

    assert_select ".catalog__owned-total", text: /\b0\b/
    refute_match(/\b2\b/, total_exibido, "linhas zeradas não são cópias possuídas")
  end

  # --- Critério 3: nada é exibido para anônimo ---

  # O catálogo é público (Req. 6.3). Para quem não tem sessão o total não é
  # zero — ele simplesmente não existe, e "0 cópias" seria uma afirmação sobre
  # uma coleção que não há.
  test "o anônimo não vê total de coleção nenhum" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 7)

    get catalog_path

    assert_response :success
    assert_select ".catalog__owned-total", 0,
      "o anônimo não tem coleção, logo não tem total a exibir"
  end

  # --- Isolamento (Req. 6.5): o total é do usuário da sessão ---

  test "o total conta apenas a coleção do usuário da sessão" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 3)
    CollectionItem.create!(user: @outro, card_variant: @variante_chopper, quantity: 9)

    sign_in
    get catalog_path

    assert_select ".catalog__owned-total", text: /\b3\b/
    refute_match(/\b12\b/, total_exibido, "o total somou a coleção de outro usuário")
    refute_match(/\b9\b/, total_exibido)
  end

  # `user_id` na URL não escolhe a coleção de ninguém — o usuário sai de
  # `Current.user` e não há caminho do request até ele.
  test "user_id na URL não troca a coleção contada" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 3)
    CollectionItem.create!(user: @outro, card_variant: @variante_chopper, quantity: 9)

    sign_in
    get catalog_path(user_id: @outro.id)

    assert_select ".catalog__owned-total", text: /\b3\b/
  end

  # --- O total é da coleção, não da página ---

  # É o teste que mata a saída errada de somar `@owned_quantities`: aquele hash
  # cobre só as variantes da página corrente. Com uma carta por página, a soma
  # da página seria 3, 2 ou 8 conforme a página aberta; o total da coleção é 13
  # em todas.
  test "o total não muda ao paginar" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 3)
    CollectionItem.create!(user: @user, card_variant: @variante_chopper, quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @variante_brook, quantity: 8)

    sign_in

    totais = (1..3).map do |pagina|
      get catalog_path(per_page: 1, page: pagina)

      assert_select ".card-tile", 1
      total_exibido
    end

    totais.each do |texto|
      assert_match(/\b13\b/, texto, "o total mudou ao paginar — somou a página, não a coleção")
    end
  end

  # Mesmo raciocínio pelo filtro: um recorte que esconde as cartas possuídas
  # não reduz a coleção do usuário.
  test "o total não muda quando um filtro esconde as cartas possuídas" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 6)

    sign_in
    get catalog_path(colors: [ "Chartreuse" ])

    assert_select ".catalog__empty"
    assert_select ".catalog__owned-total", text: /\b6\b/
  end

  # --- Distinguível do total do catálogo ---

  # Os dois números ficam lado a lado e são coisas diferentes. O do catálogo é
  # "N cartas"; o da coleção precisa se identificar por texto próprio, porque
  # em leitura linear por leitor de tela um número solto não diz de quem é.
  test "o total da coleção é distinguível do total do catálogo" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 5)

    sign_in
    get catalog_path

    assert_select ".catalog__count", text: /3 cartas/
    assert_match(/coleção/i, total_exibido,
      "o total da coleção precisa se identificar, não ser um número solto")
    assert_match(/cópias/, total_exibido, "a unidade do total da coleção é cópia, não carta")
  end

  # --- O total acompanha a posse sem recarregar a página ---

  # Achado HIGH da revisão de a11y desta task (SC 4.1.3). Os controles de posse
  # da T8 atualizam por Turbo Stream só o contêiner da variante; sem um alvo
  # para o total, o número no topo da grade ficaria o do carregamento enquanto
  # a contagem da variante logo abaixo já mostraria o valor novo — duas
  # afirmações contraditórias na mesma tela.
  #
  # SPEC_DEVIATION herdado da T8: não há navegador no container, então o que se
  # prova é o `text/vnd.turbo-stream.html` renderizado — que a resposta traz um
  # `<turbo-stream action="update">` mirando o mesmo `id` que a grade
  # renderiza, com o total já recalculado. A aplicação do Stream ao DOM por um
  # navegador real não fica coberta.
  test "o incremento devolve o total recalculado por Turbo Stream" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 4)

    sign_in
    post increment_collection_item_path(card_variant_id: @variante_robin.id),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action=update][target=?]", "catalog_owned_total" do
      assert_select ".catalog__owned-total", text: /\b5\b/
    end
  end

  test "o decremento devolve o total recalculado por Turbo Stream" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 4)

    sign_in
    post decrement_collection_item_path(card_variant_id: @variante_robin.id),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_select "turbo-stream[action=update][target=?]", "catalog_owned_total" do
      assert_select ".catalog__owned-total", text: /\b3\b/
    end
  end

  # O alvo do Stream tem que ser o mesmo `id` que a página renderiza. Um `id`
  # divergente é uma atualização que nunca acontece, e nenhum teste de status a
  # pegaria — o Turbo descarta em silêncio o update cujo alvo não está no DOM.
  test "o alvo do Stream é o id que a grade renderiza" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 2)

    sign_in
    get catalog_path

    assert_select "#catalog_owned_total", 1

    post increment_collection_item_path(card_variant_id: @variante_robin.id),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    alvo = css_select("turbo-stream").map { |node| node["target"] }

    assert_includes alvo, "catalog_owned_total",
      "o Stream não mira o mesmo id que a grade renderiza"
  end

  # A região do total **não** é `aria-live`, e isso é decisão, não esquecimento:
  # quem dispara o "+1" já recebe o anúncio específico da região viva do
  # controle da variante ("Nico Robin OP01-t11a, 3 cópias"). Uma segunda região
  # viva faria cada incremento produzir duas falas, e quem registra uma caixa de
  # boosters aperta o botão dezenas de vezes.
  test "o total não é uma região viva, para não duplicar o anúncio da variante" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 2)

    sign_in
    get catalog_path

    assert_select "#catalog_owned_total[aria-live]", 0
    assert_select "#catalog_owned_total[role=status]", 0
    assert_select ".ownership[aria-live=polite]",
      { minimum: 1 }, "o anúncio continua sendo o da variante"
  end

  # Concordância de número em português. O inflector do Rails é inglês e
  # `"cópia".pluralize(2)` devolve "cópia" — a T8 já tinha encontrado isso nos
  # controles de posse. Uma cópia é "1 cópia", não "1 cópias".
  test "uma cópia é anunciada no singular" do
    CollectionItem.create!(user: @user, card_variant: @variante_robin, quantity: 1)

    sign_in
    get catalog_path

    assert_match(/\b1 cópia\b/, total_exibido)
    refute_match(/cópias/, total_exibido)
  end
end
