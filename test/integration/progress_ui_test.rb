require "test_helper"

# SPEC_DEVIATION: `spec.md`, história "P1: Progresso de conclusão por set"
# (PRG-01, PRG-02, PRG-06, PRG-10) descreve o que o colecionador **vê** na
# página, e o plano marca a T5 como `Tests: integration` justamente por isso.
#
# Reason: **não há navegador no container.** A imagem de desenvolvimento não tem
# chromedriver nem binário `chrom*` (verificado nas T12/T14 do `catalogo` e
# repetido na T8 da `colecao`), e acrescentá-los é mudança de `Dockerfile.dev`,
# fora do escopo desta task. A maior fidelidade disponível é `assert_select`
# sobre o HTML que a action renderiza de fato, que é o que este arquivo faz.
#
# O que fica coberto: quais números chegam ao corpo, sob quais rótulos, em que
# elemento, e que "indisponível" e "zero por cento" produzem marcação
# **diferente**. O que **não** fica coberto: renderização visual e ausência de
# scroll horizontal em 360px — esta última é PRG-12 e da T8, que a mede sobre a
# folha de estilo pela mesma limitação.
#
# ---
#
# T5 — view de progresso (PRG-01, PRG-02, PRG-06, PRG-10).
#
# O cenário é montado para **discriminar**, não só para passar:
#
# 1. **Números todos diferentes entre si.** `@set_a` tem 3 possuídas, 7 no
#    total, 5 de denominador, 60% e 2 parallels — nenhum par coincide, então
#    trocar um campo por outro na marcação derruba asserção. Com números iguais
#    (o erro clássico de "1 de 1, 100%, 1 parallel") uma troca de `owned` por
#    `total` passaria despercebida.
# 2. **Zero por cento conhecido e percentual indisponível na MESMA página.**
#    `@set_b` tem denominador conhecido e nenhuma posse — `0.0`, um número.
#    `@set_c` não tem `base_set_size` — `nil`, ausência. O Edge Case proíbe
#    apresentá-los igual, e só tê-los lado a lado permite exigir que difiram.
#    Há asserção explícita de que a marcação dos dois **não** é a mesma.
class ProgressUiTest < ActionDispatch::IntegrationTest
  PASSWORD = "log-pose-77".freeze

  setup do
    @luffy = User.create!(email: "luffy-prg5@example.com", password: PASSWORD)

    # Denominador 5, total de 7 variantes: 3 possuídas de base/other (60%) e 2
    # parallels, dos quais 1 possuído. Cinco números distintos na mesma linha.
    @set_a = CardSet.create!(code: "OPp5a", name: "Romance Dawn", kind: "booster",
                             base_set_size: 5, total_set_size: 7)
    a_base = 1.upto(3).map { |i| variant(@set_a, "p5a#{i}", "base") }
    variant(@set_a, "p5a4", "base")
    variant(@set_a, "p5a5", "other")
    a_par = 1.upto(2).map { |i| variant(@set_a, "p5ap#{i}", "parallel") }

    a_base.each { |v| CollectionItem.create!(user: @luffy, card_variant: v, quantity: 1) }
    # Duas cópias de propósito: o progresso conta **variantes**, não cópias.
    CollectionItem.create!(user: @luffy, card_variant: a_par.first, quantity: 2)

    # Denominador conhecido, posse nenhuma: percentual `0.0`, um número de fato.
    # `base_set_size` (4) difere do total de impressões (2) de propósito: são
    # dois números distintos na mesma linha, e trocá-los na marcação é
    # detectável.
    @set_b = CardSet.create!(code: "OPp5b", name: "Paramount War", kind: "booster",
                             base_set_size: 4, total_set_size: 4)
    variant(@set_b, "p5b1", "base")
    variant(@set_b, "p5b2", "base")

    # Sem `base_set_size`: o caso `PRB9cd8` medido pela spec. Posse real de 1
    # variante, para provar que a posse continua exibida sem o percentual.
    @set_c = CardSet.create!(code: "OPp5c", name: "X", kind: "promo",
                             base_set_size: nil, total_set_size: nil)
    c1 = variant(@set_c, "p5c1", "base")
    variant(@set_c, "p5c2", "base")
    CollectionItem.create!(user: @luffy, card_variant: c1, quantity: 1)
  end

  def variant(set, suffix, art_kind)
    card = Card.create!(card_set: set, card_number: "OP05-#{suffix}", name: "Carta #{suffix}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: suffix,
                        rarity: "C", art_kind: art_kind)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: PASSWORD }
  end

  # O item da lista correspondente a um set, isolado pelo `id` que a view
  # deriva do código. Asserir dentro dele é o que impede que um número do set
  # vizinho satisfaça a asserção por acidente.
  def item_do_set(set)
    css_select("#progress_set_#{set.code}").tap do |nodes|
      assert_equal 1, nodes.size, "o set #{set.code} precisa aparecer exatamente uma vez"
    end.first
  end

  def texto_do_set(set)
    item_do_set(set).text.squish
  end

  # --- PRG-01: nome, possuídas e total por set ---

  test "cada set exibe nome, possuídas e total de variantes" do
    sign_in(@luffy)

    get progress_path

    assert_response :success
    texto = texto_do_set(@set_a)
    assert_match(/Romance Dawn/, texto)
    # 4 possuídas: as 3 de base/other mais o parallel. `owned_variants` é a
    # posse **do set inteiro** (Req. 9.1); o numerador do percentual é outro
    # número (`base_owned_variants`, 3) e aparece separado — é justamente por
    # serem diferentes que uma troca entre eles é detectável.
    assert_select "#progress_set_OPp5a .progress-set__owned", text: "4"
    assert_select "#progress_set_OPp5a .progress-set__total", text: "7"
  end

  # Os rótulos não são ornamento: em leitura linear de leitor de tela, "3 7 60 1"
  # não diz o que é cada número. Esta asserção trava que cada número chega
  # acompanhado da palavra que o identifica.
  test "os números são identificáveis em leitura linear, sem depender de layout" do
    sign_in(@luffy)

    get progress_path

    texto = texto_do_set(@set_a)
    assert_match(/4 de 7 variantes/, texto,
                 "possuídas e total precisam vir numa frase, não como números soltos")
    assert_match(/60% concluído/, texto,
                 "o percentual sozinho não diz do que é o percentual")
    assert_match(/1 de 2 parallels/, texto,
                 "a contagem de parallels precisa se identificar como tal")
  end

  # PRG-04 exercido pela apresentação: `a_par.first` tem 2 cópias e conta 1.
  test "conta variantes distintas e não cópias" do
    sign_in(@luffy)

    get progress_path

    assert_select "#progress_set_OPp5a .progress-set__parallel-owned", text: "1"
  end

  # --- PRG-02: percentual de conclusão ---

  test "exibe o percentual com o denominador base_set_size" do
    sign_in(@luffy)

    get progress_path

    # 3 possuídas de base/other sobre `base_set_size` 5 = 60%. Se a view usasse
    # `total_variants` (7) daria 43%; se usasse `owned_variants` no denominador
    # daria 100%.
    assert_select "#progress_set_OPp5a .progress-set__percent", text: /60/
    assert_no_match(/43%/, texto_do_set(@set_a))
    assert_no_match(/100%/, texto_do_set(@set_a))
  end

  test "set com denominador conhecido e nenhuma posse exibe zero por cento" do
    sign_in(@luffy)

    get progress_path

    assert_select "#progress_set_OPp5b .progress-set__percent", text: /0%/
    # 0 possuídas de 2 impressões, e o denominador do percentual é 4 — os dois
    # números convivem na mesma linha sem se confundirem.
    assert_match(/0 de 2 variantes/, texto_do_set(@set_b))
    assert_match(/0 de 4 do set base/, texto_do_set(@set_b))
  end

  # --- PRG-10: denominador ausente ---

  test "set sem denominador exibe a posse e o percentual como indisponível" do
    sign_in(@luffy)

    get progress_path

    texto = texto_do_set(@set_c)

    assert_match(/X/, texto)
    assert_select "#progress_set_OPp5c .progress-set__owned", text: "1",
                  message: "a posse real do set continua exibida sem o percentual"

    assert_select "#progress_set_OPp5c .progress-set__percent--unknown"
    assert_match(/indisponível/i, texto)
    assert_no_match(/0%/, texto)
    assert_no_match(/100%/, texto)
  end

  # Separado do teste acima de propósito: uma asserção que falha aborta o
  # método, e estas duas provam uma coisa **diferente** — que não sobrou
  # percentual nenhum a renderizar, nem vazio. `number_to_percentage(nil)`
  # devolve string vazia: sem o predicado, o elemento existiria sem dizer nada e
  # o set ficaria com a palavra "concluído" solta ao lado de um denominador
  # ausente. Juntas no mesmo método, esse defeito contaria como uma falha só.
  test "set sem denominador não renderiza percentual nenhum, nem vazio" do
    sign_in(@luffy)

    get progress_path

    assert_select "#progress_set_OPp5c .progress-set__percent-value", false,
                  "sem denominador não há percentual a renderizar, nem mesmo vazio"
    assert_no_match(/concluído/, texto_do_set(@set_c),
                    "sem denominador conhecido nada foi concluído")
  end

  # A asserção que torna as duas anteriores discriminantes: um `0%` vazando
  # para o set sem denominador satisfaria "exibe a posse" e "não é 100%", e só
  # a comparação lado a lado o pega. Se as duas marcações forem iguais, falha.
  test "indisponível e zero por cento são apresentados de formas diferentes" do
    sign_in(@luffy)

    get progress_path

    zero = item_do_set(@set_b).to_s
    ausente = item_do_set(@set_c).to_s

    assert_select "#progress_set_OPp5b .progress-set__percent--unknown", false,
                  "zero por cento é um número conhecido, não um percentual indisponível"
    assert_select "#progress_set_OPp5b .progress-set__percent-value", text: /\A0%\z/,
                  message: "o set com denominador conhecido exibe um percentual de fato"

    percentual_zero = css_select("#progress_set_OPp5b .progress-set__percent").first.text.squish
    percentual_ausente = css_select("#progress_set_OPp5c .progress-set__percent").first.text.squish

    assert_not_equal percentual_zero, percentual_ausente,
                     "denominador ausente e zero por cento não podem renderizar igual"
    assert_not_equal zero.sub("OPp5b", ""), ausente.sub("OPp5c", "")
  end

  # O set sem denominador **nunca** é omitido — omiti-lo esconderia posse real.
  test "nenhum set é omitido da lista" do
    sign_in(@luffy)

    get progress_path

    assert_select "#progress_set_OPp5a"
    assert_select "#progress_set_OPp5b"
    assert_select "#progress_set_OPp5c"
    assert_select ".progress-set", 3
  end

  # --- PRG-06: parallels como métrica separada ---

  test "parallels aparecem como métrica separada do percentual" do
    sign_in(@luffy)

    get progress_path

    assert_select "#progress_set_OPp5a .progress-set__parallel-owned", text: "1"
    assert_select "#progress_set_OPp5a .progress-set__parallel-total", text: "2"

    # A separação é estrutural, não só textual: a contagem de parallels não
    # pode estar dentro do elemento do percentual. Se estiver, um leitor de
    # tela lê os dois como a mesma afirmação e a mutação "somar parallels ao
    # percentual" fica indistinguível na marcação.
    assert_select "#progress_set_OPp5a .progress-set__percent .progress-set__parallel-owned",
                  false, "a contagem de parallels não pertence ao elemento do percentual"

    percentual = css_select("#progress_set_OPp5a .progress-set__percent").first.text.squish
    assert_no_match(/\b1\b/, percentual,
                    "o percentual não pode carregar a contagem de parallels")
  end

  test "set sem nenhuma variante parallel apresenta a métrica como zero" do
    sign_in(@luffy)

    get progress_path

    assert_select "#progress_set_OPp5b .progress-set__parallel-owned", text: "0"
    assert_select "#progress_set_OPp5b .progress-set__parallel-total", text: "0"
  end

  # --- Edge Case: usuário sem posse alguma ---

  test "usuário autenticado sem nenhuma posse vê todos os sets com zero" do
    sem_posse = User.create!(email: "usopp-prg5@example.com", password: PASSWORD)
    sign_in(sem_posse)

    get progress_path

    assert_response :success
    assert_select ".progress-set", 3, "a página é informativa, não vazia"
    assert_select "#progress_set_OPp5a .progress-set__owned", text: "0"
    assert_select "#progress_set_OPp5a .progress-set__total", text: "7",
                  message: "o denominador é do catálogo e não depende de quem olha"
    assert_select "#progress_set_OPp5c .progress-set__percent--unknown"
  end

  # --- Entrada no cabeçalho ---

  test "o cabeçalho oferece entrada para o progresso a quem tem sessão" do
    sign_in(@luffy)

    get progress_path

    assert_select "header.site-header a[href=?]", progress_path
  end

  # O par simétrico: um link que só leva ao login é promessa quebrada, e é a
  # mesma razão pela qual "Lista de desejos" não aparece para anônimo.
  test "o cabeçalho não oferece a entrada para anônimo" do
    get catalog_path

    assert_response :success
    assert_select "header.site-header a[href=?]", wishlist_items_path, false,
                  "o cenário precisa de um anônimo de fato, senão nada discrimina"
    assert_select "header.site-header a[href=?]", progress_path, false
  end

  # --- PRG-03: link para o catálogo filtrado por set ---
  #
  # T6. O critério da spec é que o teste **siga** o link, não que monte a URL.
  # Montar `get catalog_path(sets: ["OPp5a"])` à mão provaria que o catálogo
  # filtra — o que `catalog_query_test` já prova —, e passaria intacto se a view
  # emitisse `sets` com o **id** do set, um parâmetro de nome errado, ou nenhum
  # parâmetro. O `href` é extraído do HTML renderizado e é ele que vai à
  # requisição seguinte: o contrato sob teste é o que a view emite.

  # O href real da página, sem reconstrução: é este valor que os testes seguem.
  def href_do_catalogo(set)
    links = css_select("#progress_set_#{set.code} a.progress-set__catalog-link")
    assert_equal 1, links.size,
                 "o set #{set.code} precisa oferecer exatamente um link para o catálogo"
    links.first["href"]
  end

  test "cada set oferece link para o catálogo filtrado por ele" do
    sign_in(@luffy)

    get progress_path

    # Todos os sets, não só o primeiro: um link emitido fora do laço satisfaria
    # uma asserção sobre um set só.
    assert_select "a.progress-set__catalog-link", 3
    [ @set_a, @set_b, @set_c ].each { |set| assert href_do_catalogo(set).present? }
  end

  # Presente no DOM não é o mesmo que oferecido ao usuário: `hidden` deixa o
  # elemento passar por `css_select` e some da página para todo mundo, inclusive
  # para leitor de tela. Achado do sensor de discriminação — sem esta asserção,
  # esconder o link de 62 dos 63 sets não derrubava nenhum teste.
  test "os links dos sets são oferecidos de fato, não apenas presentes no DOM" do
    sign_in(@luffy)

    get progress_path

    assert_select "a.progress-set__catalog-link[hidden]", false,
                  "um link escondido não é oferecido a ninguém"
    assert_select ".progress-set__catalog[hidden]", false,
                  "esconder o contêiner esconde o link junto"
    assert_select "a.progress-set__catalog-link[aria-hidden=?]", "true", false,
                  "o link é a saída do set para o catálogo e não pode sumir da árvore de acessibilidade"
  end

  # O parâmetro é o do contrato de `design.md` §4.2, e o valor é o **código**
  # do set. Trocar `sets` por outro nome, ou o código pelo id, muda este href.
  test "o link usa o parâmetro sets com o código do set" do
    sign_in(@luffy)

    get progress_path

    assert_equal catalog_path(sets: [ @set_a.code ]), href_do_catalogo(@set_a)
    assert_no_match(/#{@set_a.id}/, href_do_catalogo(@set_a),
                    "o filtro do catálogo resolve por `sets.code`, nunca pelo id")
  end

  test "seguir o link leva ao catálogo com o filtro ativo" do
    sign_in(@luffy)
    get progress_path
    href = href_do_catalogo(@set_a)

    get href

    assert_response :success
    # O chip de filtro ativo é como o catálogo declara que o filtro valeu: um
    # parâmetro descartado pelo saneador não vira chip (`CatalogQuery`).
    assert_select ".catalog__chips .filter-chip__label", text: "Set: #{@set_a.code}"
  end

  # A prova de que o filtro recortou o conjunto certo, e não apenas de que a
  # página respondeu 200: uma carta do set presente e uma de outro set ausente.
  test "o conjunto devolvido pelo link corresponde ao set" do
    sign_in(@luffy)
    get progress_path
    href = href_do_catalogo(@set_a)

    get href

    assert_select "a[href=?]", card_path("OP05-p5a1"),
                  { count: 1 }, "uma carta do set filtrado precisa aparecer"
    assert_select "a[href=?]", card_path("OP05-p5b1"),
                  { count: 0 }, "nenhuma carta de outro set pode aparecer"
  end

  # Seguir o link de outro set devolve outro conjunto: sem esta asserção, um
  # link sem filtro nenhum passaria no teste acima por acaso, já que o catálogo
  # completo também contém a carta do set A.
  test "o link de cada set leva ao seu próprio recorte" do
    sign_in(@luffy)
    get progress_path
    href = href_do_catalogo(@set_b)

    get href

    assert_select "a[href=?]", card_path("OP05-p5b1"),
                  { count: 1 }, "uma carta do set B precisa aparecer no recorte do set B"
    assert_select "a[href=?]", card_path("OP05-p5a1"),
                  { count: 0 }, "o recorte do set B não contém cartas do set A"
  end

  # O texto do link identifica **qual** set. Numa lista de 63 links todos
  # escritos "Ver no catálogo", quem navega por lista de links não consegue
  # escolher — o nome acessível precisa se sustentar fora do contexto visual.
  test "o nome acessível do link identifica o set sem depender do contexto visual" do
    sign_in(@luffy)

    get progress_path

    assert_select "#progress_set_OPp5a a.progress-set__catalog-link" do |links|
      nome = links.first["aria-label"].to_s
      assert_match(/Romance Dawn/, nome,
                   "o nome acessível precisa nomear o set")
      assert_match(/catálogo/i, nome,
                   "o nome acessível precisa dizer para onde o link leva")
    end
  end

  # Os nomes acessíveis são distintos entre si: é a asserção que um texto fixo
  # como "Ver no catálogo", repetido 63 vezes, não sobrevive.
  test "os links dos sets têm nomes acessíveis distintos entre si" do
    sign_in(@luffy)

    get progress_path

    nomes = css_select("a.progress-set__catalog-link").map { |link| link["aria-label"].to_s.squish }

    assert_equal 3, nomes.size
    assert_equal nomes.size, nomes.uniq.size,
                 "links com o mesmo nome acessível são indistinguíveis em lista de links"
  end
end
