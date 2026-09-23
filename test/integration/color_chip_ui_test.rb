require "test_helper"

# INT-11 (Req. 12.11): enquanto a P8 estiver aberta, o chip de cor do jogo é
# neutro e o que identifica a cor é o nome escrito.
class ColorChipUiTest < ActionDispatch::IntegrationTest
  test "o chip de filtro de cor ativo exibe o nome da cor por escrito" do
    set = CardSet.create!(code: "OPch", name: "Romance Dawn", kind: "booster")
    Card.create!(card_set: set, card_number: "OP01-ch1", name: "Luffy", card_type: "leader", colors: [ "Red" ])

    get catalog_path(colors: [ "Red" ])

    assert_response :success
    assert_select ".filter-chip .filter-chip__label", text: "Cor: Red"
  end
end
