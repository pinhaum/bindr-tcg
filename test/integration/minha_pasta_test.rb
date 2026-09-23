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

    # Extrai o total exibido em Minha pasta
    progress_text = css_select(".progress").first.text
    pasta_match = progress_text.match(/(\d+) cartas? na pasta/)
    assert pasta_match, "não encontrou 'X cartas na pasta'"
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
end
