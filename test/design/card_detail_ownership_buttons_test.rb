require "test_helper"
require_relative "support/stylesheet"

# T31: Controles de posse de 44px no detalhe (NAV-50)
#
# No detalhe da carta, os botões +1 e −1 passam a ter alvo de 44×44px;
# na grade, continuam com 24px.
class CardDetailOwnershipButtonsTest < ActiveSupport::TestCase
  setup do
    @rules = Stylesheet.rules
  end

  test "a regra base .ownership__button continua com min-height e min-width de 24px" do
    base_rule = @rules.find { |selector, _| selector == ".ownership__button" }&.last
    assert base_rule, "regra base .ownership__button sumiu"

    decls = Stylesheet.declarations(base_rule).to_h
    assert_equal "24px", decls["min-height"], ".ownership__button deve ter min-height: 24px na regra base"
    assert_equal "24px", decls["min-width"], ".ownership__button deve ter min-width: 24px na regra base"
  end

  test "regra escopada .card-detail .ownership__button tem min-height e min-width de 44px" do
    scoped_rule = @rules.find { |selector, _| selector == ".card-detail .ownership__button" }&.last
    assert scoped_rule, "regra escopada .card-detail .ownership__button sumiu da folha"

    decls = Stylesheet.declarations(scoped_rule).to_h
    assert_equal "44px", decls["min-height"], ".card-detail .ownership__button deve ter min-height: 44px"
    assert_equal "44px", decls["min-width"], ".card-detail .ownership__button deve ter min-width: 44px"
  end

  test "a regra escopada não redeclara outras propriedades" do
    scoped_rule = @rules.find { |selector, _| selector == ".card-detail .ownership__button" }&.last
    assert scoped_rule, "regra escopada não encontrada"

    decls = Stylesheet.declarations(scoped_rule).to_h
    assert_equal 2, decls.size, "regra escopada deve ter exatamente min-height e min-width"
  end
end
