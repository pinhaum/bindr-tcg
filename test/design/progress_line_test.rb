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

  # Mobile:47 — o nome numa linha só, truncado em reticências. `overflow: hidden`
  # com `text-overflow: ellipsis` corta o excesso dentro do próprio link (que tem
  # `min-width: 0`), então não há como estourar 360px (Req. 2.5).
  test "o nome do set (link) resolve caption muted, numa linha com reticências e sem sublinhado" do
    nome = Stylesheet.resolved("progress-set__catalog-link")
    assert_equal "var(--caption-size)", nome["font-size"]
    assert_equal "var(--caption-line-height)", nome["line-height"]
    assert_equal "var(--ink-muted)", nome["color"]
    assert_equal "nowrap", nome["white-space"]
    assert_equal "hidden", nome["overflow"]
    assert_equal "ellipsis", nome["text-overflow"]
    assert_equal "none", nome["text-decoration"]
    assert_equal "0", nome["min-width"]
    assert_equal "var(--caption-weight)", nome["font-weight"]
  end

  # Req. 2.5: sem trilha que admita encolher, a coluna do set cresce até o nome
  # inteiro em `nowrap` e empurra a contagem para fora de 360px.
  test "a linha do set encolhe até a coluna, e o nome é que corta" do
    assert_equal "minmax(0, 1fr)", Stylesheet.resolved("progress-set")["grid-template-columns"]
    assert_equal "0", Stylesheet.resolved("progress-set__header")["min-width"]
  end

  test "a legenda de base e parallels é uma só, 13px muted" do
    legenda = Stylesheet.resolved("progress-set__legend")
    assert_equal "var(--caption-size)", legenda["font-size"]
    assert_equal "var(--caption-line-height)", legenda["line-height"]
    assert_equal "var(--ink-muted)", legenda["color"]
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

  # CNF-29: o desenho do chip vem de `.catalog__chip` (44px, borda border-strong)
  # e o da ordem aplicada leva o fundo do chip ativo do catálogo.
  test "os chips de ordem têm 44px e a borda do chip do catálogo; o atual leva fundo accent" do
    chip = Stylesheet.resolved("catalog__chip")
    assert_equal 44.0, Stylesheet.to_pixels(chip["min-height"])
    assert_equal "1px solid var(--border-strong)", chip["border"]

    ativo = declarations('.progress__order-link[aria-current="page"]')
    assert_equal "var(--accent)", ativo["background-color"]
    assert_equal "var(--on-accent)", ativo["color"]
  end
end
