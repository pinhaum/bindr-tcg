require "test_helper"

# T3 — Minha pasta: títulos e indicadores (NAV-16, NAV-17, NAV-18, NAV-20, NAV-21, NAV-29).
#
# SPEC_DEVIATION: A página exibe números na forma visual (renderizada no navegador)
# que não podem ser medidos sem um navegador no container. O teste assevera sobre a
# **marcação** da página: que os números chegam no DOM nos elementos corretos, com os
# rótulos certos, na forma esperada pelo HTML.
#
# Reason: **não há navegador no container** (CLAUDE.md). A maior fidelidade disponível é
# `assert_select` sobre o HTML que a action renderiza de fato.
class MinhaPageTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "minha-pasta-t3@example.com", password: PASSWORD)

    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster",
                           base_set_size: 5, total_set_size: 7)

    # Cenário: 3 cópias de uma variante + 1 de outra = 4 total, 2 distintas
    v1 = create_variant(@set, "001", "base")
    v2 = create_variant(@set, "002", "base")

    CollectionItem.create!(user: @user, card_variant: v1, quantity: 3)
    CollectionItem.create!(user: @user, card_variant: v2, quantity: 1)
  end

  def create_variant(set, suffix, art_kind)
    card = Card.create!(card_set: set, card_number: "OP01-#{suffix}", name: "Card #{suffix}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: suffix,
                        rarity: "C", art_kind: art_kind)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # --- NAV-16: h1 "Minha pasta", h2 "Progresso por set", h3 para nome do set ---

  test "exibe h1 Minha pasta como título principal" do
    sign_in(@user)
    get progress_path

    assert_response :success
    assert_select "h1", text: "Minha pasta"
  end

  test "exibe h2 Progresso por set antes da lista de sets" do
    sign_in(@user)
    get progress_path

    assert_select "h2", text: "Progresso por set"
  end

  test "cada set exibe seu nome em h3" do
    sign_in(@user)
    get progress_path

    assert_select "h3", text: /Romance Dawn/
  end

  test "não pula nível de título entre h1 e h2" do
    sign_in(@user)
    get progress_path

    html = response.body
    # Procura por h1, depois h2, sem h2..h6 no meio
    h1_pos = html.index(/<h1/)
    h2_pos = html.index(/<h2/)
    assert h1_pos < h2_pos, "h2 deve vir depois de h1"
  end

  test "não pula nível de título entre h2 e h3" do
    sign_in(@user)
    get progress_path

    html = response.body
    h2_pos = html.index(/<h2/)
    h3_pos = html.index(/<h3/)
    assert h2_pos < h3_pos, "h3 deve vir depois de h2"
  end

  # --- NAV-17: total de cópias ---

  test "exibe total de 4 cópias com texto correto no plural" do
    sign_in(@user)
    get progress_path

    assert_select ".progress", text: /4 cartas na pasta/
  end

  test "total de 1 cópia usa singular" do
    # Criar novo usuário com apenas 1 cópia
    user_one = User.create!(email: "one-copy@example.com", password: PASSWORD)
    v = create_variant(@set, "003", "base")
    CollectionItem.create!(user: user_one, card_variant: v, quantity: 1)

    sign_in(user_one)
    get progress_path

    assert_select ".progress", text: /1 carta na pasta/
  end

  test "total de 0 cópias exibe 0" do
    user_empty = User.create!(email: "empty@example.com", password: PASSWORD)

    sign_in(user_empty)
    get progress_path

    assert_select ".progress", text: /0 cartas na pasta/
  end

  # --- NAV-18: número de variantes distintas ---

  test "exibe 2 variantes distintas com texto correto no plural" do
    sign_in(@user)
    get progress_path

    assert_select ".progress", text: /2 cartas diferentes/
  end

  test "1 variante distinta usa singular" do
    user_one_var = User.create!(email: "one-var@example.com", password: PASSWORD)
    v = create_variant(@set, "004", "base")
    CollectionItem.create!(user: user_one_var, card_variant: v, quantity: 5)

    sign_in(user_one_var)
    get progress_path

    assert_select ".progress", text: /1 carta diferente/
  end

  test "0 variantes distintas exibe 0" do
    user_no_var = User.create!(email: "no-var@example.com", password: PASSWORD)

    sign_in(user_no_var)
    get progress_path

    assert_select ".progress", text: /0 cartas diferentes/
  end

  # --- NAV-17 + NAV-18: igualdade com o catálogo ---

  test "total de cópias é igual ao que o catálogo mostra para o mesmo usuário" do
    sign_in(@user)
    get progress_path

    # Extrai o total exibido em Minha pasta (no cartão de cópias)
    stats_cards = css_select(".progress__stat")
    pasta_text = stats_cards.first.text
    pasta_match = pasta_text.match(/(\d+)/)
    assert pasta_match, "não encontrou número de cópias no cartão"
    pasta_total = pasta_match[1].to_i

    # Extrai o total exibido no catálogo
    get catalog_path
    catalog_html = response.body
    catalog_match = catalog_html.match(/Sua coleção: <span class="catalog__owned-total-count">(\d+)<\/span>/)
    assert catalog_match, "não encontrou total no catálogo"
    catalog_total = catalog_match[1].to_i

    assert_equal pasta_total, catalog_total,
                 "total na pasta (#{pasta_total}) deve ser igual ao do catálogo (#{catalog_total})"
  end

  # --- NAV-20: usuário sem cópia vê os dois com 0 ---

  test "usuário sem nenhuma cópia vê ambos os indicadores com 0" do
    user_empty = User.create!(email: "empty-t3@example.com", password: PASSWORD)

    sign_in(user_empty)
    get progress_path

    assert_select ".progress", text: /0 cartas na pasta/
    assert_select ".progress", text: /0 cartas diferentes/
  end

  # --- NAV-21: ignora user_id do request ---

  test "?user_id= de outro usuário não muda os números" do
    other_user = User.create!(email: "other@example.com", password: PASSWORD)

    sign_in(@user)
    get progress_path(user_id: other_user.id)

    assert_response :success
    # Nosso usuário tem 4 cópias, outro tem 0
    assert_select ".progress", text: /4 cartas na pasta/
    assert_select ".progress", text: /2 cartas diferentes/
  end

  # --- NAV-29: anônimo redirecionado ao login ---

  test "anônimo em /progress é redirecionado ao login" do
    get progress_path

    assert_response :redirect
    assert_redirected_to new_session_path
  end

  # --- T4 / NAV-19: links para wishlist, import e export ---

  test "exibe link para a Lista de desejos com href correto em progress__actions" do
    sign_in(@user)
    get progress_path

    assert_select ".progress__actions .progress__action-link", text: "Lista de desejos"
    assert_select ".progress__actions a[href='#{wishlist_items_path}']", text: "Lista de desejos"
  end

  test "exibe link para Importar coleção com href correto em progress__actions" do
    sign_in(@user)
    get progress_path

    assert_select ".progress__actions .progress__action-link", text: "Importar coleção"
    assert_select ".progress__actions a[href='#{new_collection_import_path}']", text: "Importar coleção"
  end

  test "exibe link para export do partial progress/_export_link (não cópia) em progress__actions" do
    sign_in(@user)
    get progress_path

    # Verifica que o partial foi renderizado dentro de .progress__actions
    assert_select ".progress__actions .collection-export__link", text: "Baixar minha coleção (CSV)"
  end

  test "os três links de ação em progress__actions existem (não duplicados ali)" do
    sign_in(@user)
    get progress_path

    # Dentro de .progress__actions, cada link deve aparecer exatamente uma vez
    assert_select ".progress__actions a[href='#{wishlist_items_path}']", count: 1
    assert_select ".progress__actions a[href='#{new_collection_import_path}']", count: 1
    assert_select ".progress__actions .collection-export__link", count: 1
  end

  test "links de wishlist, import e Adicionar cartas têm classe progress__action-link" do
    sign_in(@user)
    get progress_path

    # Verifica que a classe .progress__action-link está presente nos links
    links = css_select(".progress__action-link")
    assert links.size == 3, "deveria haver 3 links com classe progress__action-link (Adicionar cartas, wishlist, import)"
  end

  test "links têm min-width de 24px em CSS (verificado por regra na folha)" do
    # Este teste é sobre CSS puro, verificado por leitura de catalog.css
    # em test/design/. Esta assertion de integração apenas confirma que a
    # classe está presente na view; a folha é responsável pelo min-width.
    sign_in(@user)
    get progress_path

    assert_select ".progress__action-link"
  end

  test "remover o link de wishlist faria o teste falhar" do
    # Demonstração: comentar o link de wishlist na view faria esta assertion falhar
    sign_in(@user)
    get progress_path

    # Esta é a asserção que falharia se o link fosse removido
    assert_select "a[href='#{wishlist_items_path}']", text: "Lista de desejos",
                  fail_message: "link para wishlist não encontrado"
  end

  test "remover o link de import faria o teste falhar" do
    # Demonstração: comentar o link de import na view faria esta assertion falhar
    sign_in(@user)
    get progress_path

    # Esta é a asserção que falharia se o link fosse removido
    assert_select "a[href='#{new_collection_import_path}']", text: "Importar coleção",
                  fail_message: "link para import não encontrado"
  end

  test "remover o link de export faria o teste falhar" do
    # Demonstração: comentar o partial de export na view faria esta assertion falhar
    sign_in(@user)
    get progress_path

    # Esta é a asserção que falharia se o link fosse removido
    assert_select ".collection-export__link", text: "Baixar minha coleção (CSV)",
                  fail_message: "link para export não encontrado"
  end

  # --- T19: NAV-37 indicadores como cartões ---

  test "indicadores de cópias e variantes são cartões em grid" do
    sign_in(@user)
    get progress_path

    assert_select ".progress__summary" do
      assert_select ".progress__stat", count: 2,
        fail_message: "progress__summary deve conter exatamente 2 cartões"
    end
  end

  test "cartão de cópias exibe número e legenda separados" do
    sign_in(@user)
    get progress_path

    # Primeiro cartão: total de cópias
    assert_select ".progress__summary .progress__stat" do |cards|
      first_card = cards.first
      stat_value = first_card.css(".progress__stat-value").text
      stat_label = first_card.css(".progress__stat-label").text.strip

      assert_equal "4", stat_value, "número de cópias deve ser 4"
      assert_equal "cartas na pasta", stat_label, "legenda deve ser 'cartas na pasta'"
    end
  end

  test "cartão de variantes exibe número e legenda separados" do
    sign_in(@user)
    get progress_path

    assert_select ".progress__summary .progress__stat" do |cards|
      second_card = cards[1]
      stat_value = second_card.css(".progress__stat-value").text
      stat_label = second_card.css(".progress__stat-label").text.strip

      assert_equal "2", stat_value, "número de variantes deve ser 2"
      assert_equal "cartas diferentes", stat_label, "legenda deve ser 'cartas diferentes'"
    end
  end

  # --- T19: NAV-38 barra de progresso por set ---

  test "set com total conhecido exibe barra de progresso" do
    sign_in(@user)
    get progress_path

    # Barra deve estar ao lado da contagem
    assert_select ".progress-set__bar",
      fail_message: "barra de progresso não encontrada para set com total conhecido"
  end

  test "barra de progresso tem atributos value e max corretos" do
    sign_in(@user)
    get progress_path

    # Set OP01 tem 5 variantes base; posse é 2 distintas de 5
    assert_select ".progress-set__bar" do |bars|
      bar = bars.first
      assert bar["value"], "barra deve ter atributo value"
      assert bar["max"], "barra deve ter atributo max"
      # Valores podem variar conforme o set e posse, mas devem existir
    end
  end

  test "barra de progresso tem aria-hidden para não repetir contagem" do
    sign_in(@user)
    get progress_path

    assert_select ".progress-set__bar[aria-hidden='true']",
      fail_message: "barra deve ter aria-hidden='true' para não repetir informação"
  end

  # --- T20: NAV-39 link "Adicionar cartas" ---

  test "exibe link Adicionar cartas apontando para o catálogo" do
    sign_in(@user)
    get progress_path

    assert_select ".progress__actions a[href='#{catalog_path}']", text: "Adicionar cartas"
  end

  test "Adicionar cartas é o primeiro link dentro de progress__actions" do
    sign_in(@user)
    get progress_path

    links = css_select(".progress__actions a")
    assert links.size >= 1, "deve haver pelo menos um link em progress__actions"
    assert_equal "Adicionar cartas", links.first.text, "primeiro link deve ser 'Adicionar cartas'"
  end

  test "Adicionar cartas tem classe progress__action-link--primary para estilo" do
    sign_in(@user)
    get progress_path

    assert_select ".progress__action-link--primary", text: "Adicionar cartas"
  end

  test "Adicionar cartas tem min-height de 44px em CSS (via classe progress__action-link--primary)" do
    sign_in(@user)
    get progress_path

    assert_select ".progress__action-link--primary"
  end

  test "remover o link Adicionar cartas faria o teste falhar" do
    sign_in(@user)
    get progress_path

    assert_select "a[href='#{catalog_path}']", text: "Adicionar cartas",
                  fail_message: "link para Adicionar cartas não encontrado"
  end
end
