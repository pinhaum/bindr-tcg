require "test_helper"

# T8 (conformidade) — "Variantes na pasta" com stepper (CNF-19, CNF-20, CNF-21).
#
# `collection_ownership_ui_test.rb` já cobre o contrato do Turbo Stream e os
# rótulos acessíveis dos botões (T8 herdou os dois de T7/T31 sem mudança).
# Este arquivo prova especificamente o que a T8 mudou: o título e o divisor da
# seção, o texto combinado "{raridade} · {tipo de arte}", a ordem no DOM do
# stepper e o "não tenho" em zero.
class CardDetailVariantsTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @user = User.create!(email: "stepper-t8@example.com", password: PASSWORD)
    @set = CardSet.create!(code: "OPt8v", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(card_set: @set, card_number: "OP01-t8v", name: "Nami",
                         card_type: "character", colors: [ "Blue" ], cost: 1, power: 2000)

    @base = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: @card, card_set: @set, variant_code: "OP01-t8v",
                                rarity: "SR", art_kind: "base")
    @parallel = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: @card, card_set: @set, variant_code: "OP01-t8v_p1",
                                    rarity: "SEC", art_kind: "parallel")
    @promo = CardVariant.create!(last_seen_at: CATALOG_SEEN_AT, card: @card, card_set: @set, variant_code: "OP01-t8v_p2",
                                 rarity: "SP CARD", art_kind: "promo")
    mark_catalog_present!
  end

  def sign_in = post(session_path, params: { email: @user.email, password: PASSWORD })

  def ownership_id(variant) = "ownership_card_variant_#{variant.id}"

  # --- CNF-19: título e divisor ---

  test "a seção tem o título Variantes na pasta" do
    get card_path(@card.card_number)

    assert_response :success
    assert_select "h2", text: "Variantes na pasta"
  end

  # --- CNF-20: texto combinado "{raridade} · {tipo de arte}" ---

  test "cada linha combina raridade e tipo de arte traduzido" do
    get card_path(@card.card_number)

    assert_select ".variant__rarity", text: "SR · arte base"
    assert_select ".variant__rarity", text: "SEC · parallel"
    # `promo` não está no mapa fechado (só `base` e `parallel` têm tradução
    # própria): cai no fallback "alternativa", o mesmo destino de
    # `alternate_art`, `manga` e `other`.
    assert_select ".variant__rarity", text: "SP CARD · alternativa"
  end

  test "os rótulos Código, Raridade e Set estão no HTML, fora da vista" do
    get card_path(@card.card_number)

    assert_select ".variant__meta dt", text: "Código"
    assert_select ".variant__meta dt", text: "Raridade"
    assert_select ".variant__meta dt", text: "Set"
  end

  # --- CNF-21: ordem no DOM do stepper, `[n]` não é input, "não tenho" em zero ---

  test "com sessão a ordem no DOM do stepper é −, [n], +" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 3)

    get card_path(@card.card_number)

    assert_response :success
    actions = css_select("##{ownership_id(@base)} .ownership__actions").first
    # Filho direto de `.ownership__actions`: `button_to` embrulha cada botão
    # num `<form class="ownership__form">`, então o filho não é o `<button>`
    # em si — é o form. A classe do botão de dentro é o que identifica qual é
    # qual.
    ordem = actions.children.select(&:element?).map do |node|
      node.name == "form" ? node.at_css("button")["class"] : node["class"]
    end

    assert_equal [
      "ownership__button ownership__button--decrement",
      "ownership__step",
      "ownership__button ownership__button--increment"
    ], ordem
  end

  test "o [n] do stepper não é um input" do
    sign_in

    get card_path(@card.card_number)

    assert_select ".ownership__step", 3
    assert_select ".ownership__step input", 0
    assert_select "input.ownership__step", 0
  end

  test "o [n] do stepper mostra a quantidade, incluindo zero" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 3)

    get card_path(@card.card_number)

    assert_select "##{ownership_id(@base)} .ownership__step", text: "3"
    assert_select "##{ownership_id(@parallel)} .ownership__step", text: "0"
  end

  test "em zero o texto visível é não tenho e o − é aria-disabled" do
    sign_in

    get card_path(@card.card_number)

    assert_select "##{ownership_id(@base)} .ownership__empty", text: "não tenho"
    assert_select "##{ownership_id(@base)} .ownership__button--decrement[aria-disabled=?]", "true"
  end

  test "em zero o rótulo cópias não fica visível ao lado do não tenho" do
    sign_in

    get card_path(@card.card_number)

    assert_select "##{ownership_id(@base)} .ownership__unit.ownership__unit--empty", text: "cópias"
  end

  test "com posse o rótulo da unidade continua visível" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 2)

    get card_path(@card.card_number)

    assert_select "##{ownership_id(@base)} .ownership__unit", text: "cópias"
    assert_select "##{ownership_id(@base)} .ownership__unit--empty", 0
  end

  test "com posse o não tenho desaparece" do
    sign_in
    CollectionItem.create!(user: @user, card_variant: @base, quantity: 1)

    get card_path(@card.card_number)

    assert_select "##{ownership_id(@base)} .ownership__empty", 0
  end

  # --- Nomes acessíveis dos botões continuam mantidos (CNF-21) ---

  test "os nomes acessíveis dos botões continuam Adicionar/Remover uma cópia" do
    sign_in

    get card_path(@card.card_number)

    assert_select "##{ownership_id(@base)} button[aria-label=?]",
      "Adicionar uma cópia de #{@card.name} #{@base.variant_code}"
    assert_select "##{ownership_id(@base)} button[aria-label=?]",
      "Remover uma cópia de #{@card.name} #{@base.variant_code}"
  end

  # --- CNF-22: o POST com Accept de Turbo Stream continua atualizando só a linha ---

  test "o incremento com Accept de Turbo Stream responde stream que atualiza a linha" do
    sign_in

    post increment_collection_item_path(card_variant_id: @base.id),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_select "turbo-stream[action=?][target=?]", "update", ownership_id(@base), 1
    assert_select "turbo-stream template .ownership__step", text: "1"
  end

  # --- Req. 8.1: marca de wishlist por variante continua na linha ---

  test "a marca de wishlist continua presente em cada variante" do
    sign_in

    get card_path(@card.card_number)

    assert_select ".wishlist-mark", 3
  end

  # --- Anônimo continua sem controle, mas com o resto da linha ---

  test "anônimo vê a linha da variante sem o stepper" do
    get card_path(@card.card_number)

    assert_response :success
    assert_select ".variant", 3
    assert_select ".ownership__step", 0
    assert_select ".ownership__sign-in", 3
  end
end
