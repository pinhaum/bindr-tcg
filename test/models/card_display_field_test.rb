require "test_helper"

# Req. 5.5 — campo inaplicável ao tipo é **omitido**, não exibido vazio.
#
# `display_field?` tem duas condições: o campo se aplica ao tipo E tem valor.
# Os testes de view da T14 não separam as duas, porque toda fixture de lá dá
# `nil` ao campo inaplicável (um Leader sem `cost`): "não se aplica" e "não
# tem valor" colapsam na mesma resposta e a primeira guarda fica sem prova.
# O Verifier do B2 mostrou isso removendo a guarda sem quebrar nenhum teste.
#
# Aqui os dados são escolhidos para separar: um Leader **com** `cost` e
# `counter` preenchidos. São campos que Leader não tem no jogo, e o valor
# existir no registro não pode fazê-los aparecer.
class CardDisplayFieldTest < ActiveSupport::TestCase
  setup do
    @set = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")
  end

  def card(**attrs) = Card.create!(set_id: @set.id, **attrs)

  test "campo inaplicável ao tipo não aparece nem quando tem valor" do
    lider = card(card_number: "OP01-001", name: "Roronoa Zoro", card_type: "leader",
                 colors: [ "Red" ], power: 5000, life: 5, cost: 4, counter: 1000)

    refute lider.display_field?(:cost), "Leader não tem cost, mesmo com valor gravado"
    refute lider.display_field?(:counter), "Leader não tem counter, mesmo com valor gravado"
  end

  test "campo aplicável ao tipo aparece quando tem valor" do
    lider = card(card_number: "OP01-004", name: "Leader", card_type: "leader",
                 colors: [ "Red" ], power: 5000, life: 5)

    assert lider.display_field?(:power)
    assert lider.display_field?(:life)
  end

  test "campo aplicável sem valor não aparece" do
    evento = card(card_number: "OP01-002", name: "Event", card_type: "event",
                  colors: [ "Blue" ], cost: nil)

    refute evento.display_field?(:cost), "cost nulo não deve ser exibido vazio"
  end

  # `counter` NULL ≠ 0 vale também aqui: counter 0 é um valor, e aparece.
  test "counter zero é valor e aparece; counter nulo não" do
    com_zero = card(card_number: "OP01-005", name: "Zero", card_type: "character",
                    colors: [ "Red" ], cost: 1, counter: 0)
    sem = card(card_number: "OP01-006", name: "Sem", card_type: "character",
               colors: [ "Red" ], cost: 1, counter: nil)

    assert com_zero.display_field?(:counter), "counter 0 é valor, não ausência"
    refute sem.display_field?(:counter)
  end

  test "array vazio não aparece, array com itens aparece" do
    sem_trait = card(card_number: "OP01-003", name: "Sem trait", card_type: "character",
                     colors: [ "Red" ], cost: 1, traits: [])

    refute sem_trait.display_field?(:traits)
    assert sem_trait.display_field?(:colors)
  end
end
