require "test_helper"

# SPEC_DEVIATION: `spec.md`, história "P1: Registrar posse por variante"
# (COL-10), critério 3 — "WHEN o usuário registrar posse a partir da grade do
# catálogo THEN the system SHALL atualizar a quantidade exibida sem recarregar a
# página inteira" — descreve comportamento de navegador, e o plano marca a T8
# como `Tests: integration` justamente por isso.
#
# Reason: **não há navegador no container.** A imagem de desenvolvimento não tem
# chromedriver nem binário `chrom*` (verificado na T12/T14 do `catalogo`, que
# registraram a mesma divergência), e acrescentá-los é mudança de
# `Dockerfile.dev` — fora do escopo desta task e já registrada como pendência em
# `STATE.md`.
#
# O que este arquivo prova no lugar, e que é observável no HTML e no
# `text/vnd.turbo-stream.html` renderizados:
#
# - a resposta ao `POST` com `Accept: text/vnd.turbo-stream.html` é um
#   `<turbo-stream action="update">` que mira **só** o contêiner daquela
#   variante — logo não é a página inteira;
# - o alvo do Stream é o mesmo `id` que a grade e o detalhe renderizam, de modo
#   que o Stream de fato encontra o que trocar (um `id` divergente seria uma
#   atualização que não acontece, e nenhum teste de status a pegaria);
# - a mesma rota, sem `Accept` de Stream, responde `redirect_back` — o caminho
#   sem JavaScript que os Edge Cases exigem manter.
#
# O que **não** fica coberto: a execução do Turbo no navegador, isto é, que o
# `<turbo-stream>` recebido seja de fato aplicado ao DOM. A marcação que o
# dispara é asserida; o disparo em si não. Fechar essa lacuna é a mesma mudança
# de `Dockerfile.dev` das T12/T14.
#
# ---
#
# T8 — posse na grade e no detalhe, sem recarregar (Req. 5.3, 7.5 / COL-10,
# COL-18).
class CollectionOwnershipUiTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  TURBO_STREAM = "text/vnd.turbo-stream.html".freeze

  setup do
    @user = User.create!(email: "usopp-t8@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OPt8", name: "Romance Dawn", kind: "booster")

    # Uma carta com **uma** variante e outra com **três**: é a distinção que
    # decide o que a grade mostra, e sem as duas o teste não discrimina nada.
    @unica = create_card(number: "OP01-t8a", name: "Usopp")
    @variante_unica = create_variant(@unica, "OP01-t8a")

    @multipla = create_card(number: "OP01-t8b", name: "Roronoa Zoro")
    @variantes_multiplas = [ "OP01-t8b", "OP01-t8b_p1", "OP01-t8b_p2" ].map do |code|
      create_variant(@multipla, code)
    end
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

  def ownership_id(variant) = "ownership_card_variant_#{variant.id}"

  # --- "Controles presentes na grade e no detalhe, sempre por variante" ---

  # No detalhe **toda** variante tem o seu controle: é onde a impressão aparece
  # inteira e a escolha é inequívoca. Três variantes, três controles, cada um
  # com o seu `id`.
  test "o detalhe traz um controle de posse para cada variante" do
    sign_in

    get card_path(@multipla.card_number)

    assert_response :success
    assert_select ".ownership", 3
    @variantes_multiplas.each do |variant|
      assert_select "##{ownership_id(variant)}", 1,
        "faltou o controle de posse da variante #{variant.variant_code}"
      assert_select "form[action=?]",
        increment_collection_item_path(card_variant_id: variant.id)
    end
  end

  # Na grade o controle direto só existe quando a carta tem **uma** variante:
  # aí há exatamente uma variante a incrementar e nenhuma ambiguidade.
  test "a grade traz o controle direto na carta de variante única" do
    sign_in

    get catalog_path

    assert_response :success
    assert_select "##{ownership_id(@variante_unica)}", 1
    assert_select "form[action=?]",
      increment_collection_item_path(card_variant_id: @variante_unica.id)
  end

  # O critério que impede a saída errada. Um controle único no tile de uma carta
  # com três variantes **agregaria a posse na carta** — o Req. 5.3 de
  # `.context/requirements.md` diz que o registro é por variante, nunca agregado.
  # Em 40,1% do catálogo real (1129 de 2815 cartas) é esse o caso.
  test "a grade não oferece controle direto para carta com mais de uma variante" do
    sign_in

    get catalog_path

    @variantes_multiplas.each do |variant|
      assert_select "##{ownership_id(variant)}", 0,
        "a grade ofereceu controle para #{variant.variant_code} sem o usuário escolher a impressão"
      assert_select "form[action=?]",
        increment_collection_item_path(card_variant_id: variant.id), 0
    end
  end

  # A alternativa ao controle: o tile diz quantas impressões existem e leva ao
  # detalhe, onde a escolha é explícita. Sem isto o tile pareceria só incompleto.
  test "a carta de várias variantes leva ao detalhe informando quantas impressões tem" do
    sign_in

    get catalog_path

    assert_select ".card-tile__variants-link", text: /3 impressões/
    assert_select ".card-tile__variants-link[href=?]", card_path(@multipla.card_number)
  end

  # --- "Atualização por Turbo Stream, sem recarregar a página inteira" ---

  # O que prova "sem recarregar a página inteira" sem navegador: a resposta é um
  # `<turbo-stream>`, e não um documento. Um `action="update"` mirando um `id`
  # de variante troca aquele pedaço e nada mais.
  test "o incremento responde Turbo Stream mirando só o controle daquela variante" do
    sign_in

    post increment_collection_item_path(card_variant_id: @variante_unica.id),
      headers: { "Accept" => TURBO_STREAM }

    assert_response :success
    assert_equal TURBO_STREAM, response.media_type

    assert_select "turbo-stream[action=?][target=?]", "update",
      ownership_id(@variante_unica), 1
    # A resposta **não** é a página. A grade tem `.card-tile` e `.catalog__grid`;
    # nenhum dos dois aparece aqui, porque o que voltou foi só o pedaço que
    # mudou. (`assert_select "html", 0` não serviria: o parser embrulha
    # qualquer fragmento num documento sintético e o `<html>` existiria sempre.)
    assert_select ".card-tile", 0
    assert_select ".catalog__grid", 0
    assert_no_match(/<!DOCTYPE/i, response.body)
  end

  # O Stream precisa trazer a quantidade **nova**, senão a atualização sem
  # recarga mostraria o valor velho — o defeito exato que o Req. 7.5 existe para
  # evitar, e que um teste só de status não pegaria.
  test "o Turbo Stream traz a quantidade já atualizada" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variante_unica, quantity: 4)

    post increment_collection_item_path(card_variant_id: @variante_unica.id),
      headers: { "Accept" => TURBO_STREAM }

    assert_select "turbo-stream template" do
      assert_select ".ownership__count", text: "5"
    end
  end

  test "o decremento responde Turbo Stream com a quantidade já atualizada" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variante_unica, quantity: 2)

    post decrement_collection_item_path(card_variant_id: @variante_unica.id),
      headers: { "Accept" => TURBO_STREAM }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "update",
      ownership_id(@variante_unica)
    assert_select "turbo-stream template" do
      assert_select ".ownership__count", text: "1"
    end
  end

  # O alvo do Stream tem de ser o `id` que a página **de fato** renderizou. Se
  # os dois divergirem, o Turbo recebe a resposta, não encontra o elemento e não
  # atualiza nada — e o status continuaria 200. Este teste amarra os dois lados.
  test "o alvo do Stream é o mesmo id que a página renderiza" do
    sign_in

    get card_path(@multipla.card_number)
    variant = @variantes_multiplas.last
    assert_select "##{ownership_id(variant)}", 1

    post increment_collection_item_path(card_variant_id: variant.id),
      headers: { "Accept" => TURBO_STREAM }

    assert_select "turbo-stream[target=?]", ownership_id(variant), 1
  end

  # A recusa também precisa chegar sem recarga. Sem isto, decrementar o que não
  # se tem seria silencioso no caminho com JavaScript e visível no caminho sem —
  # o mesmo requisito atendido de dois jeitos diferentes.
  test "o decremento recusado avisa o usuário pelo Stream, em português" do
    sign_in

    post decrement_collection_item_path(card_variant_id: @variante_unica.id),
      headers: { "Accept" => TURBO_STREAM }

    assert_select "turbo-stream[action=?][target=?]", "update", "flash_alert", 1
    assert_select "turbo-stream template" do
      assert_select ".flash--alert", text: "Você não tem cópias desta variante para remover."
    end
  end

  # A recusa é assertiva (`role="alert"`, que interrompe a leitura corrente) e o
  # retorno de rotina do "+1" é educado (`role="status"`). Uma região assertiva
  # única cortaria a fala do leitor de tela a cada incremento de quem está
  # registrando uma caixa inteira — achado MEDIUM da revisão de a11y.
  test "sucesso e recusa vão para regiões de anúncio com assertividade diferente" do
    sign_in

    get catalog_path

    assert_select "[role=?] #flash_notice", "status", 1
    assert_select "[role=?] #flash_alert", "alert", 1
  end

  # O botão em zero é marcado com `aria-disabled`, **não** com `disabled`: um
  # `disabled` de verdade sai da árvore de foco, e como o Turbo re-renderiza
  # este botão logo depois do clique que zerou a quantidade, o foco do usuário
  # cairia no `<body>` (SC 2.4.3). Achado HIGH da revisão de a11y.
  test "o decremento em zero é aria-disabled e continua focável" do
    sign_in

    get card_path(@unica.card_number)

    assert_select ".ownership__button--decrement[aria-disabled=?]", "true", 1
    assert_select ".ownership__button--decrement[disabled]", 0,
      "`disabled` de verdade tira o botão da árvore de foco e o usuário perde o lugar"
  end

  # Com posse o botão deixa de ser marcado — o estado acompanha a quantidade.
  test "o decremento deixa de ser aria-disabled quando há o que remover" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @variante_unica, quantity: 1)

    get card_path(@unica.card_number)

    assert_select ".ownership__button--decrement[aria-disabled=?]", "true", 0
  end

  # O anúncio precisa dizer de qual carta é a quantidade. Numa grade, "3 cópias"
  # sozinho não identifica nada — achado MEDIUM da revisão de a11y.
  test "a região anunciada identifica a carta, não só o código da variante" do
    sign_in

    get card_path(@multipla.card_number)

    variant = @variantes_multiplas.first
    assert_select "##{ownership_id(variant)} .ownership__variant",
      text: "#{@multipla.name} #{variant.variant_code}"
  end

  # --- "Sem JavaScript, incremento e decremento continuam funcionando" ---

  # Os Edge Cases da spec: "IF o JavaScript não estiver disponível, THEN
  # incremento e decremento continuam funcionando por submissão normal, com
  # recarga". O navegador sem Turbo manda `Accept: text/html` e espera um
  # documento — o `redirect_back` da T6 é o que responde.
  test "sem Turbo o incremento continua funcionando por submissão normal" do
    sign_in
    origem = card_path(@unica.card_number)

    post increment_collection_item_path(card_variant_id: @variante_unica.id),
      headers: { "Accept" => "text/html", "HTTP_REFERER" => origem }

    assert_redirected_to origem
    assert_equal 1, CollectionItem.for_user(@user)
                                  .find_by(card_variant: @variante_unica).quantity
  end

  test "sem Turbo o decremento continua funcionando por submissão normal" do
    sign_in
    item = CollectionItem.create!(user: @user, card_variant: @variante_unica, quantity: 3)

    post decrement_collection_item_path(card_variant_id: @variante_unica.id),
      headers: { "Accept" => "text/html" }

    assert_response :redirect
    assert_equal 2, item.reload.quantity
  end

  # O `button_to` gera formulário de verdade, com método POST e token CSRF: é
  # isso que faz a submissão sem JavaScript funcionar. Um `<button>` solto
  # dependendo de um listener não funcionaria, e o markup pareceria igual de
  # longe.
  test "o controle é um formulário POST de verdade, não um botão que depende de JS" do
    sign_in

    get card_path(@unica.card_number)

    assert_select "form.ownership__form[method=?]", "post" do
      assert_select "button[type=?]", "submit"
    end
  end

  # --- "Alvos de toque com no mínimo 24px" (SC 2.5.8) ---

  # A dívida de a11y do `STATE.md` diz que código novo não deve herdá-la. A
  # folha é servida como arquivo, então a asserção é sobre a regra em si.
  test "os botões de posse declaram alvo de toque de 24px" do
    css = Rails.root.join("app/assets/stylesheets/catalog.css").read
    regra = css[/\.ownership__button\s*\{[^}]*\}/m]

    assert regra, "a regra .ownership__button sumiu da folha do catálogo"
    assert_match(/min-height:\s*24px/, regra, "alvo de toque sem altura mínima (SC 2.5.8)")
    assert_match(/min-width:\s*24px/, regra, "alvo de toque sem largura mínima (SC 2.5.8)")
  end

  # --- Rótulos distinguíveis (SC 2.4.6 / 4.1.2) ---

  # Numa página com três impressões, três botões "+1" idênticos são
  # indistinguíveis para quem navega por lista de botões. O rótulo acessível
  # cita a carta e o código da variante.
  test "cada botão tem rótulo acessível que identifica a variante" do
    sign_in

    get card_path(@multipla.card_number)

    @variantes_multiplas.each do |variant|
      assert_select "button[aria-label=?]",
        "Adicionar uma cópia de #{@multipla.name} #{variant.variant_code}", 1
      assert_select "button[aria-label=?]",
        "Remover uma cópia de #{@multipla.name} #{variant.variant_code}", 1
    end
  end

  # A quantidade muda sem recarga: quem usa leitor de tela só percebe se a
  # região for `aria-live`. E ela precisa estar no nó que **permanece** — é por
  # isso que o Stream usa `update` (troca os filhos) e não `replace` (trocaria o
  # nó, e uma região viva recém-inserida não anuncia).
  test "a quantidade vive numa região anunciada por leitor de tela" do
    sign_in

    get card_path(@unica.card_number)

    assert_select "##{ownership_id(@variante_unica)}[aria-live=?]", "polite", 1
    assert_select "##{ownership_id(@variante_unica)} .ownership__count", 1
  end

  # O texto sai dentro da região `aria-live`, então é ele que o leitor de tela
  # lê a cada mudança. O inflector do Rails é inglês e não sabe acentuação
  # portuguesa: `"cópia".pluralize(2)` devolve "cópia", e o anúncio sairia
  # "2 cópia". O plural é explícito por isso.
  test "a unidade concorda em número com a quantidade" do
    sign_in

    get card_path(@unica.card_number)
    assert_select "##{ownership_id(@variante_unica)} .ownership__unit", text: "cópias"

    post increment_collection_item_path(card_variant_id: @variante_unica.id),
      headers: { "Accept" => TURBO_STREAM }
    assert_select ".ownership__unit", text: "cópia"

    post increment_collection_item_path(card_variant_id: @variante_unica.id),
      headers: { "Accept" => TURBO_STREAM }
    assert_select ".ownership__unit", text: "cópias"
  end

  # --- Catálogo público continua funcionando sem sessão (Req. 6.3) ---

  test "anônimo vê a grade e o detalhe sem erro e sem controle de posse" do
    get catalog_path
    assert_response :success
    assert_select ".ownership__button", 0
    assert_select ".ownership__sign-in", 1

    get card_path(@multipla.card_number)
    assert_response :success
    assert_select ".ownership__button", 0
    assert_select ".ownership__sign-in", 3
  end

  # --- Isolamento: a quantidade exibida é a do usuário da sessão (Req. 6.5) ---

  test "a quantidade exibida é a do usuário da sessão, não a de outro" do
    outro = User.create!(email: "kaya-t8@example.com", password: PASSWORD)
    CollectionItem.create!(user: outro, card_variant: @variante_unica, quantity: 9)
    CollectionItem.create!(user: @user, card_variant: @variante_unica, quantity: 2)
    sign_in

    get card_path(@unica.card_number)

    assert_select ".ownership__count", text: "2"
    assert_select ".ownership__count", text: "9", count: 0
  end

  # --- Sem N+1 ---

  # O controle precisa saber, por tile, quantas variantes a carta tem e quanto o
  # usuário possui. Feito ingenuamente, isso é uma consulta por tile: com 24
  # cartas na página, 48 idas ao banco que crescem com a página. O controller
  # carrega variantes e quantidades em consultas de conjunto, então o número de
  # consultas **não** acompanha a quantidade de cartas.
  test "a grade não dispara consulta por carta para montar os controles" do
    sign_in
    20.times do |i|
      card = create_card(number: "OP01-t8n#{i}", name: "Carta #{i}")
      variant = create_variant(card, "OP01-t8n#{i}")
      CollectionItem.create!(user: @user, card_variant: variant, quantity: 1)
    end

    consultas = count_queries { get catalog_path }
    assert_response :success

    # O limite é folgado de propósito: o que o teste protege é a **ausência de
    # crescimento linear**, não um número exato de consultas — fixar o número
    # exato faria o teste quebrar em toda mudança inócua do controller. Com
    # N+1, 22 cartas na página dariam mais de 40 consultas só para as variantes.
    assert_operator consultas, :<, 20,
      "a grade disparou #{consultas} consultas — provável N+1 no controle de posse"
  end

  def count_queries
    contador = 0
    assinatura = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      contador += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) ||
                           payload[:sql].start_with?("SAVEPOINT", "RELEASE SAVEPOINT", "ROLLBACK")
    end
    yield
    contador
  ensure
    ActiveSupport::Notifications.unsubscribe(assinatura)
  end
end
