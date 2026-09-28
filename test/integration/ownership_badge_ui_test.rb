require "test_helper"

# INT-07 (Req. 12.6): variante possuída exibe badge com a quantidade; faltante
# não recebe badge nenhum — nem com registro zerado, nem sem registro.
class OwnershipBadgeUiTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze
  TURBO_STREAM = "text/vnd.turbo-stream.html".freeze

  setup do
    @user = User.create!(email: "badge@example.com", password: PASSWORD)
    set = CardSet.create!(code: "OPbg", name: "Romance Dawn", kind: "booster")
    @card = Card.create!(card_set: set, card_number: "OP01-bg1", name: "Nami",
                         card_type: "character", colors: [ "Blue" ], cost: 1, power: 2000)
    @duas, @zerada, @sem_registro = %w[OP01-bg1 OP01-bg1_p1 OP01-bg1_p2].map do |code|
      CardVariant.create!(card: @card, card_set: set, variant_code: code, rarity: "C", art_kind: "base")
    end

    post session_path, params: { email: @user.email, password: PASSWORD }
  end

  def control(variant) = "#ownership_card_variant_#{variant.id}"

  test "só a variante possuída renderiza o badge, com a quantidade" do
    CollectionItem.create!(user: @user, card_variant: @duas, quantity: 2)
    CollectionItem.create!(user: @user, card_variant: @zerada, quantity: 0)

    get card_path(@card.card_number)

    assert_response :success
    assert_select "#{control(@duas)} .ownership__count.ownership__count--owned", text: "2"

    [ @zerada, @sem_registro ].each do |variant|
      assert_select "#{control(variant)} .ownership__count", text: "0"
      assert_select "#{control(variant)} .ownership__count--owned", 0,
                    "#{variant.variant_code} sem cópia recebeu badge"
    end
  end

  test "o Stream do incremento de 0 para 1 traz o badge" do
    post increment_collection_item_path(card_variant_id: @sem_registro.id),
         headers: { "Accept" => TURBO_STREAM }

    assert_select "turbo-stream[target=?] template", control(@sem_registro).delete("#") do
      assert_select ".ownership__count.ownership__count--owned", text: "1"
    end
    assert_select "turbo-stream template .ownership__count--owned", 1,
                  "o payload do Stream traz mais de um badge"
  end

  test "o Stream do decremento de 1 para 0 não traz o badge" do
    CollectionItem.create!(user: @user, card_variant: @duas, quantity: 1)

    post decrement_collection_item_path(card_variant_id: @duas.id),
         headers: { "Accept" => TURBO_STREAM }

    assert_select "turbo-stream[target=?] template", control(@duas).delete("#") do
      assert_select ".ownership__count", text: "0"
      assert_select ".ownership__count--owned", 0
    end
  end

  # T10: incremento e decremento se distinguem pelo rótulo visível, não por cor.
  #
  # SPEC_DEVIATION (T8, CNF-21): o texto visível do botão deixou de trazer o
  # "1" ("+1"/"-1") -- o stepper do canvas mostra a quantidade uma vez so, no
  # `[n]` entre os dois botoes, e repeti-la no rotulo do botao duplicaria a
  # informacao. A intencao original do teste continua provada: os dois botoes
  # tem rotulos visiveis diferentes um do outro, nao distinguidos por cor.
  test "incremento e decremento se distinguem pelo rótulo" do
    get card_path(@card.card_number)

    assert_select "#{control(@duas)} .ownership__button--increment", text: "+"
    assert_select "#{control(@duas)} .ownership__button--decrement", text: "\u2212"
  end
end
