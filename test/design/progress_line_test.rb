require "test_helper"
require_relative "support/stylesheet"

# T32 — cada set de "Minha pasta" é uma linha sem moldura, com nome à esquerda e
# contagem à direita, e as ações secundárias formam uma linha própria (NAV-51).
class ProgressLineTest < ActiveSupport::TestCase
  def declarations(selector)
    rule = Stylesheet.rules.find { |candidate, _| candidate.strip == selector }
    assert_not_nil rule, "regra #{selector} não encontrada na folha"
    Stylesheet.declarations(rule[1]).to_h
  end

  test "o set não desenha moldura nem fundo próprios" do
    set = declarations(".progress-set")
    assert_nil set["border"], "a caixa do set some (NAV-51)"
    assert_nil set["background-color"]
    assert_nil set["background"]
  end

  test "nome e contagem dividem a mesma linha, a contagem à direita" do
    header = declarations(".progress-set__header")
    assert_equal "flex", header["display"]
    assert_equal "space-between", header["justify-content"]
    assert_nil header["flex-wrap"], "com wrap a contagem desce para baixo do nome em 360px"

    name = declarations(".progress-set__header > .progress-set__name")
    assert_equal "0", name["min-width"], "sem isso o nome longo empurra a contagem para fora (NAV-28)"

    count = declarations(".progress-set__header > .progress-set__owned-line")
    assert_equal "none", count["flex"]
  end

  test "as ações secundárias formam uma linha que quebra, não uma pilha" do
    secondary = declarations(".progress__secondary")
    assert_equal "flex", secondary["display"]
    assert_equal "wrap", secondary["flex-wrap"]
  end
end
