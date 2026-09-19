require "test_helper"

# T12 — grade do catálogo (Req. 2.1 a 2.5, 3.5, 4.6, 4.7, 11.2).
#
# **Por que integração e não system test:** a imagem de desenvolvimento não tem
# navegador nem chromedriver (verificado: nenhum binário `chrom*` no
# container), e acrescentá-los é mudança de Dockerfile — fora do escopo desta
# task, registrada como pendência. Todos os critérios do "Done when" da T12 são
# observáveis no HTML renderizado: o placeholder é markup, não comportamento de
# JS; o estado na URL é query string; os chips são links; o lazy loading é
# atributo. O que **não** fica coberto é a execução do `onerror` da imagem num
# navegador real — a marcação que o dispara é asserida, o disparo em si não.
class CatalogGridTest < ActionDispatch::IntegrationTest
  setup do
    @op01 = CardSet.create!(code: "OP01", name: "Romance Dawn", kind: "booster")

    @zoro = create_card(card_number: "OP01-001", name: "Roronoa Zoro",
                        card_type: "leader", colors: [ "Red" ], cost: 3, power: 5000)
    @nami = create_card(card_number: "OP01-002", name: "Nami",
                        card_type: "character", colors: [ "Green" ], cost: 1, power: 1000)
    @law = create_card(card_number: "OP01-003", name: "Trafalgar Law",
                       card_type: "leader", colors: [ "Red", "Blue" ], cost: 4)

    @com_imagem = CardVariant.create!(
      card: @zoro, set_id: @op01.id, variant_code: "OP01-001", rarity: "L",
      art_kind: "base", image_url: "https://example.test/OP01-001.png"
    )
    # Variante sem `image_url`: é o caso em que o placeholder do Req. 2.3 é a
    # única coisa que o usuário vê. AD-004 depende disso — a arte é hotlink de
    # terceiro e pode sumir sem aviso.
    @sem_imagem = CardVariant.create!(
      card: @nami, set_id: @op01.id, variant_code: "OP01-002", rarity: "C",
      art_kind: "base", image_url: nil
    )
    CardVariant.create!(card: @law, set_id: @op01.id, variant_code: "OP01-003",
                        rarity: "L", art_kind: "base",
                        image_url: "https://example.test/OP01-003.png")
  end

  def create_card(**attrs) = Card.create!(set_id: @op01.id, **attrs)

  # --- Req. 2.1: imagem, nome e card_number ---

  test "a grade exibe imagem, nome e card_number de cada carta" do
    get catalog_path

    assert_response :success
    assert_select ".card-tile", 3
    assert_select ".card-tile__name", text: "Roronoa Zoro"
    assert_select ".card-tile__number", text: "OP01-001"
    assert_select "img[src=?]", "https://example.test/OP01-001.png"
  end

  # --- Req. 11.2: lazy loading ---

  test "as imagens da grade carregam de forma preguiçosa" do
    get catalog_path

    assert_select "img.card-tile__image" do |imagens|
      assert imagens.any?, "a grade não renderizou nenhuma imagem"
      imagens.each do |img|
        assert_equal "lazy", img["loading"],
                     "toda imagem da grade precisa de loading=lazy (Req. 11.2)"
      end
    end
  end

  # --- Req. 2.3: placeholder com nome e código ---

  test "carta sem imagem exibe placeholder com nome e código" do
    get catalog_path

    assert_select ".card-tile__placeholder" do
      assert_select ".card-tile__placeholder-name", text: "Nami"
      assert_select ".card-tile__placeholder-number", text: "OP01-002"
    end
  end

  # O placeholder existe para quando o hotlink falhar (AD-004), não só para
  # quando a URL for nula — e tem que funcionar sem JavaScript, que este
  # projeto ainda não serve. A mitigação é de camada: o placeholder é sempre
  # renderizado, embaixo, e a imagem por cima; imagem quebrada não pinta nada
  # e o placeholder continua visível.
  test "o placeholder é renderizado mesmo quando existe imagem" do
    get catalog_path

    # A carta OP01-001 tem `image_url`. O placeholder dela precisa existir
    # assim mesmo, senão o hotlink quebrado deixa o espaço vazio.
    assert_select ".card-tile", 3
    assert_select ".card-tile__placeholder", 3,
                  "toda carta precisa de placeholder por baixo da imagem (AD-004)"
    assert_select ".card-tile__placeholder-number", text: "OP01-001"
  end

  test "o placeholder fica atrás da imagem, sem depender de JavaScript" do
    css = Rails.root.join("app/assets/stylesheets/catalog.css").read

    assert_match(/\.card-tile__art\s*\{[^}]*position:\s*relative/m, css)
    assert_match(/position:\s*absolute/, css,
                 "imagem e placeholder precisam ocupar a mesma área")
  end

  test "a imagem tem texto alternativo com nome e código" do
    get catalog_path

    assert_select "img.card-tile__image[alt=?]", "Roronoa Zoro (OP01-001)"
  end

  # --- Req. 4.8: contagem total ---

  test "a grade exibe a contagem total de cartas que satisfazem os filtros" do
    get catalog_path(colors: [ "Red" ])

    assert_select ".catalog__count", text: /2/
  end

  # --- Req. 4.7: estado na URL ---

  test "a URL reproduz o mesmo resultado ao ser recarregada" do
    parametros = { q: "Zoro", colors: [ "Red" ], sort: "name", dir: "desc", page: 1 }

    get catalog_path(parametros)
    primeira = css_select(".card-tile__number").map(&:text)

    get catalog_path(parametros)
    segunda = css_select(".card-tile__number").map(&:text)

    assert_equal primeira, segunda
    assert_includes primeira, "OP01-001"
  end

  test "filtro aplicado sem termo de busca também vive na URL" do
    get catalog_path(colors: [ "Green" ])

    assert_select ".card-tile__number", text: "OP01-002"
    assert_select ".card-tile", 1
  end

  # --- Req. 4.6: chips removíveis individualmente ---

  test "cada filtro ativo vira um chip com link que remove só ele" do
    get catalog_path(colors: [ "Red" ], card_types: [ "leader" ])

    assert_select ".filter-chip", 2

    # Remover a cor tem que preservar o tipo, e vice-versa. Um chip que limpa
    # tudo satisfaria "removível" no texto e falharia o "individualmente".
    chips = css_select(".filter-chip a").map { |a| a["href"] }
    sem_cor = chips.find { |href| !href.include?("colors") }
    sem_tipo = chips.find { |href| !href.include?("card_types") }

    assert sem_cor, "faltou chip que remove só a cor"
    assert_includes sem_cor, "card_types"
    assert sem_tipo, "faltou chip que remove só o tipo"
    assert_includes sem_tipo, "colors"
  end

  test "o chip de busca remove só o termo e preserva os filtros" do
    get catalog_path(q: "Zoro", colors: [ "Red" ])

    href = css_select(".filter-chip a").map { |a| a["href"] }.find { |h| !h.include?("q=") }

    assert href, "faltou chip que remove só o termo de busca"
    assert_includes href, "colors"
  end

  test "um valor de cada categoria é removível separadamente" do
    get catalog_path(colors: [ "Red", "Green" ])

    hrefs = css_select(".filter-chip a").map { |a| a["href"] }

    assert_equal 2, hrefs.size, "cada valor selecionado é um chip"
    assert hrefs.any? { |h| h.include?("Green") && !h.include?("Red") },
           "remover Red tem que preservar Green"
    assert hrefs.any? { |h| h.include?("Red") && !h.include?("Green") },
           "remover Green tem que preservar Red"
  end

  test "sem filtro ativo não há chip" do
    get catalog_path

    assert_select ".filter-chip", 0
  end

  # --- Req. 3.5: estado vazio ---

  test "estado vazio mostra o termo buscado e ação de limpar filtros" do
    get catalog_path(q: "xyzqwkjhgf")

    assert_select ".catalog__empty"
    assert_select ".catalog__empty", text: /xyzqwkjhgf/
    assert_select ".catalog__empty a[href=?]", catalog_path
  end

  test "estado vazio por filtro também oferece limpar" do
    get catalog_path(colors: [ "Chartreuse" ])

    assert_select ".catalog__empty a[href=?]", catalog_path
  end

  # --- Req. 2.2: paginação ---

  test "a grade pagina e a página seguinte traz cartas diferentes" do
    get catalog_path(per_page: 2, page: 1)
    primeira = css_select(".card-tile__number").map(&:text)

    get catalog_path(per_page: 2, page: 2)
    segunda = css_select(".card-tile__number").map(&:text)

    assert_equal 2, primeira.size
    assert_equal 1, segunda.size
    assert_empty primeira & segunda, "a mesma carta não pode aparecer em duas páginas"
  end

  test "a paginação preserva busca e filtros no link" do
    get catalog_path(colors: [ "Red" ], per_page: 1, page: 1)

    proxima = css_select(".pagination a").map { |a| a["href"] }.compact

    assert proxima.any? { |href| href.include?("colors") },
           "o link de paginação perdeu o filtro ativo (Req. 4.7)"
  end

  # --- Req. 2.4: ordenação ---

  test "a ordenação escolhida é aplicada e refletida na URL" do
    get catalog_path(sort: "name", dir: "asc")
    nomes = css_select(".card-tile__name").map(&:text)

    assert_equal nomes.sort, nomes
  end

  # --- Req. 2.5: 360px sem scroll horizontal ---

  # A largura mínima é uma propriedade do CSS, não do HTML: o que quebra o
  # layout em 360px é largura fixa maior que a viewport. A asserção é sobre a
  # folha de estilo porque é lá que a regressão aconteceria.
  # Varre **toda** declaração em px, não só `width:`. A primeira versão deste
  # teste olhava apenas `width`/`min-width` e passava com zero asserções: a
  # largura mínima da coluna mora numa custom property (`--tile-min`), que o
  # padrão não pegava. Um teste que não assere nada é pior que nenhum.
  test "a folha de estilo não impõe largura fixa maior que a viewport de 360px" do
    css = Rails.root.join("app/assets/stylesheets/catalog.css").read
    declaracoes = css.gsub(%r{/\*.*?\*/}m, "").scan(/([\w-]+):\s*([^;]*?\d+px[^;]*);/)

    refute_empty declaracoes, "nenhuma declaração em px encontrada — o padrão quebrou"

    declaracoes.each do |propriedade, valor|
      valor.scan(/(\d+)px/).flatten.map(&:to_i).each do |pixels|
        assert_operator pixels, :<=, 360,
                        "#{propriedade}: #{valor} estoura a viewport de 360px (Req. 2.5)"
      end
    end
  end

  # A coluna mínima da grade tem que caber duas vezes em 360px com o respiro
  # lateral, senão a grade vira coluna única mesmo num celular comum.
  test "a coluna mínima da grade cabe duas vezes em 360px" do
    css = Rails.root.join("app/assets/stylesheets/catalog.css").read
    minimo = css[/--tile-min:\s*(\d+)px/, 1]&.to_i

    assert minimo, "a grade precisa declarar a largura mínima da coluna"
    assert_operator minimo * 2, :<=, 360, "duas colunas de #{minimo}px não cabem em 360px"
  end

  test "a grade usa colunas fluidas em vez de contagem fixa de colunas" do
    css = Rails.root.join("app/assets/stylesheets/catalog.css").read

    assert_match(/auto-fill|auto-fit/, css,
                 "a grade precisa se adaptar à largura disponível (Req. 2.5)")
    assert_match(/max-width:\s*100%/, css)
  end

  test "o layout declara a viewport para dispositivos móveis" do
    get catalog_path

    assert_select "meta[name=viewport][content*=?]", "width=device-width"
  end

  # --- robustez: Req. 4.7 não pode virar 500 ---

  test "parâmetro desconhecido na URL não quebra a página" do
    get catalog_path(filtro_extinto: "valor", colors: [ "Red" ])

    assert_response :success
    assert_select ".card-tile", 2
  end

  test "valor inválido de filtro não quebra a página" do
    get catalog_path(cost_min: "abacaxi", page: "-1", sort: "'; DROP TABLE cards; --")

    assert_response :success
    assert_equal 3, Card.count
  end
end
