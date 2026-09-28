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

  # --- T10: checklist do artboard (Mobile-Pasta.dc.html, Desktop-Pasta.dc.html) ---

  test "h2 Progresso por set resolve title (20/26/600), não display" do
    heading = declarations(".progress__heading")
    assert_equal "var(--title-size)", heading["font-size"]
    assert_equal "var(--title-line-height)", heading["line-height"]
    assert_equal "var(--title-weight)", heading["font-weight"]
  end

  test "código do set resolve code (mono/13/500)" do
    assert Stylesheet.code_styled?("progress-set__code"),
           "o código do set precisa do estilo code inteiro de §11.4"
  end

  # O artboard mostra o nome truncado em reticências; `set_progress_plan_test.rb`
  # (AD-017, protegido) proíbe `white-space: nowrap` em `.progress-set__catalog-link`
  # por ser bloco largo do progresso (Req. 2.5, 360px sem scroll horizontal) — a
  # decisão desta task foi priorizar o teste protegido e deixar o nome quebrar.
  test "o nome do set (link) resolve caption muted, sem nowrap" do
    nome = declarations(".progress-set__catalog-link")
    assert_equal "var(--caption-size)", nome["font-size"]
    assert_equal "var(--caption-line-height)", nome["line-height"]
    assert_equal "var(--ink-muted)", nome["color"]
    assert_nil nome["white-space"],
               "nowrap num bloco largo do progresso impede a quebra exigida por Req. 2.5 (AD-017)"
  end

  test "possuídas / total resolve caption muted, à direita e sem quebrar" do
    linha = declarations(".progress-set__owned-line")
    assert_equal "var(--caption-size)", linha["font-size"]
    assert_equal "var(--caption-line-height)", linha["line-height"]
    assert_equal "var(--ink-muted)", linha["color"]
    assert_equal "0", linha["flex-shrink"]
  end

  test "a barra abaixo da linha resolve altura 8, trilho sunken, raio 4, preenchimento border-strong" do
    barra = declarations(".progress-set__bar")
    assert_equal "8px", barra["height"]
    assert_equal "var(--surface-sunken)", barra["background-color"]
    assert_equal "var(--radius-sm)", barra["border-radius"]

    preenchimento = declarations(".progress-set__bar::-webkit-progress-value")
    assert_equal "var(--border-strong)", preenchimento["background-color"]
  end

  # CNF-29: os chips de ordem existem e o ativo se distingue do inativo por
  # `[aria-current="page"]`, o mesmo atributo que `nav_link_to` já usa no
  # cabeçalho — não uma classe `--active` nova e paralela.
  test "os chips de ordem existem junto do h2 e o ativo usa aria-current" do
    grupo = declarations(".progress__order")
    assert_equal "flex", grupo["display"]

    ativo = declarations('.progress__order-link[aria-current="page"]')
    assert_not_nil ativo["font-weight"], "o chip ativo precisa se distinguir do inativo"
  end
end
