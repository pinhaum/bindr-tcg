require "test_helper"

# T8 — custo da página de progresso (PRG-11, Req. 11.1) e viewport de 360px
# (PRG-12, Req. 2.5).
#
# O teste é sobre o **custo e a forma**, nunca sobre o número exibido: T1–T3 já
# provaram a agregação por unidade e T5–T7 já provaram a página. Uma
# implementação que devolvesse todos os números certos abrindo uma consulta por
# set passaria em todos aqueles testes — este arquivo existe para a metade que
# eles não cobrem.
#
# ## A medição é sobre a requisição, não sobre o query object
#
# A T1 já trava a forma da agregação isolada ("cinco sets a mais não podem
# custar consulta a mais"). Isso não basta para PRG-11: o requisito é sobre **a
# página que o usuário abre**, e uma view que consultasse por set — um
# `CardVariant.where(set_id: ...)` dentro do laço, um helper que reconsultasse a
# posse — deixaria o query object intacto e a página N+1 mesmo assim. Por isso a
# contagem aqui é de `get progress_path`, com sessão de verdade.
#
# ## A asserção é sobre a **diferença**, e é isso que a torna honesta
#
# Medido nesta task, a requisição emite **3** consultas: `Session Load`,
# `User Load` (as duas do `resume_session` do concern `Authentication`) e uma
# única `CardSet Load`, que é a agregação. Travar o número absoluto em 3 seria
# frágil pela razão errada: ele mudaria se o concern ganhasse um `includes`, se
# o layout passasse a exibir um contador, ou se a sessão virasse um único join —
# nenhuma dessas mudanças é a regressão que PRG-11 proíbe, e uma asserção que
# falha por elas seria apagada na primeira vez que atrapalhasse.
#
# A asserção principal é, portanto, sobre a **diferença entre dois cenários com
# quantidades de sets diferentes**: o custo da sessão e do layout é idêntico nos
# dois e se cancela na subtração, seja ele qual for. Um `count` por set produz
# diferença igual à quantidade de sets acrescentados; a agregação única produz
# **zero**. Há ainda uma asserção auxiliar que **desconta nominalmente** as
# consultas de sessão e prova que resta exatamente uma — ela é a que nomeia o
# que foi descontado, para que a subtração não esconda um segundo `SELECT` de
# catálogo que porventura também fosse constante.
#
# ## O volume semeado e o plano medido
#
# Medido nesta task com `semear_volume_realista`: **200 sets, 12.000 variantes,
# 51 usuários, 20.400 itens de coleção**, dos quais 400 do usuário alvo (2,0% do
# total) e 57 deles com `quantity = 0`. É acima do catálogo real (63 sets, 4917
# variantes) de propósito — com poucas linhas o planejador escolheria `Seq Scan`
# **com razão** e a asserção de plano pararia de distinguir "acesso indexado" de
# "tabela pequena demais para valer índice".
#
# `EXPLAIN (ANALYZE, BUFFERS)` da agregação nesse cenário, resumido:
#
#     Sort  (cost=2096.43..2096.93 rows=200)                     actual 8.271..8.279
#       GroupAggregate  (cost=1786.78..2088.78 rows=200)         Group Key: sets.id
#         Sort  (cost=1786.78..1816.78 rows=12000)               quicksort 1231kB
#           Hash Left Join  (cost=308.06..973.74 rows=12000)
#             Hash Right Join  (cost=13.50..647.67 rows=12000)
#               Seq Scan on card_variants  (rows=12000)          Buffers: hit=482
#               Hash -> Seq Scan on sets   (rows=200)            Buffers: hit=9
#             Hash -> Index Scan using index_collection_items_on_user_id
#                       on collection_items  (cost=0.29..290.27 rows=343)
#                       Index Cond: (user_id = ...)
#                       Filter: (quantity >= 1)  Rows Removed by Filter: 57
#     Planning Time: 1.614 ms   Execution Time: 8.548 ms
#
# **Uma passada pelo banco, 8,5ms com 200 sets** — contra os ~213ms que a spec
# mediu para a forma N+1 com 63 sets e coleção vazia. O acesso a
# `collection_items` é indexado; os dois `Seq Scan` do catálogo são os corretos
# e não evitáveis (ver abaixo).
#
# ## Por que **não** há migração nesta task
#
# O `ecc:database-reviewer` da Fase 1 mediu a agregação no banco de
# desenvolvimento (63 sets, 4917 variantes, coleção vazia) e concluiu que os
# dois `Seq Scan` — em `sets` e em `card_variants` — são **corretos e não
# evitáveis**: a agregação precisa de *todas* as variantes de *todos* os sets
# para produzir `total_variants` e `parallel_variants`, e não existe predicado
# seletivo que um índice pudesse explorar. O `FILTER` roda depois da leitura,
# sobre as linhas já lidas. Um índice não muda nada disso. Ele deixou anotado,
# porém, um candidato para esta task avaliar: índice parcial
# `collection_items (user_id, card_variant_id) WHERE quantity >= 1`, sob a
# hipótese de reduzir o `Filter: (quantity >= 1)` na heap.
#
# **A medição desta task reprovou o candidato**, repetindo o resultado da T10 da
# `colecao`, onde um índice quase idêntico já havia sido criado, medido e
# descartado. Criado o índice parcial sobre o seed acima, o planejador **o
# ignorou por completo**: mesmo plano, mesmo caminho
# (`Index Scan using index_collection_items_on_user_id` com `Filter:
# (quantity >= 1)`, 57 linhas descartadas) e **custo idêntico — 2096,43 com e
# sem o índice**.
#
# O caso assimétrico que a T10 nomeou como o único capaz de reabrir a decisão
# foi medido também: o mesmo usuário com **12.000 itens e 40% deles zerados** —
# muito além dos ~14% daquele seed. O índice continuou ignorado, e desta vez o
# plano **com** ele saiu marginalmente **pior**: 4172,30 contra 4172,27. Um
# índice que o planejador não escolhe é custo de escrita em toda operação de
# posse sem nenhum ganho de leitura, e por isso ele **não foi criado**. Nenhuma
# migração nesta task, e `db/structure.sql` segue intacto.
#
# **O que reabriria a decisão**, nomeado aqui para que a próxima medição não
# precise redescobrir o limite desta: o caso assimétrico que a T10 apontou já
# foi medido e também reprovou, então o que resta não é mais volume de coleção.
# O custo dominante desta página são os dois `Seq Scan` do **catálogo**, e eles
# escalam com `card_variants` — se ela crescer uma ordem de grandeza, a saída
# **não é índice** (não há predicado seletivo a explorar: a agregação lê todas
# as variantes por definição) e sim materializar a agregação do catálogo, que é
# decisão de design e não de índice. Esse é o limite desta medição.
#
# ## Limite de fidelidade declarado
#
# O seed distribui a posse **uniformemente** entre as variantes, enquanto em
# produção cartas populares concentram posse acima da média. Isso desloca a
# seletividade do acesso a `collection_items` e, portanto, o ponto em que o
# planejador escolheria inverter o join. A asserção de plano deste arquivo é
# sobre **o que não pode acontecer** (varrer `collection_items` inteira), não
# sobre qual índice é escolhido, e por isso é imune a esse deslocamento —
# precedente da T10 da `colecao`, onde travar um índice nominal reprovou o plano
# *melhor*. O viés da distribuição mudaria onde fica a fronteira, não o fato de
# o acesso ser indexado dos dois lados dela.
class SetProgressPlanTest < ActionDispatch::IntegrationTest
  PASSWORD = "grand-line-t8".freeze

  # Volume do cenário de plano. O catálogo real tem 63 sets e 4917 variantes;
  # o seed vai acima disso de propósito, pela mesma razão da T10 da `colecao`:
  # com um punhado de linhas o planejador escolhe `Seq Scan` **com razão**, e a
  # asserção de plano passaria a não distinguir "acesso indexado" de "tabela
  # pequena demais para valer índice".
  SETS_VOLUME = 200
  VARIANTES_POR_SET = 60
  USUARIOS = 50
  ITENS_POR_USUARIO = 400

  # Cenário de contagem de consultas: dois tamanhos, e a diferença entre eles é
  # a asserção. Os números são pequenos porque aqui o que se mede é **forma**,
  # não seletividade — e o contraste de 1 para 40 é largo o bastante para que
  # uma consulta por set salte aos olhos.
  SETS_PEQUENO = 1
  SETS_GRANDE = 40

  setup do
    @user = User.create!(email: "plano-t8@example.com", password: PASSWORD)
    @connection = ActiveRecord::Base.connection
  end

  # --- Done when 1 e 2: o número de consultas não varia com a quantidade de
  # sets, e a contabilidade de sessão/layout não contamina a medição ---

  # A prova central de PRG-11. Dois cenários, mesma requisição, quantidades de
  # sets muito diferentes: o que sobra na subtração é exatamente o custo que
  # **depende dos sets**, e ele precisa ser zero. Qualquer consulta constante —
  # sessão, usuário, layout, um contador global que alguém acrescente amanhã —
  # aparece nos dois lados e se cancela, então esta asserção não pode ser
  # quebrada por mudança que não seja a regressão que ela vigia.
  test "o número de consultas da requisição não cresce com a quantidade de sets" do
    semear_sets(SETS_PEQUENO, prefixo: "P")
    entrar
    pequeno = consultas_da_pagina

    semear_sets(SETS_GRANDE, prefixo: "G")
    grande = consultas_da_pagina

    assert_equal SETS_PEQUENO + SETS_GRANDE, CardSet.count,
                 "o segundo cenário precisa ter mais sets que o primeiro, senão nada é comparado"
    assert_equal pequeno.size, grande.size,
                 "#{SETS_GRANDE} sets a mais custaram #{grande.size - pequeno.size} consulta(s) a mais — " \
                 "a página está N+1 na quantidade de sets (PRG-11).\n" \
                 "Cenário pequeno:\n#{formatar(pequeno)}\nCenário grande:\n#{formatar(grande)}"
  end

  # A asserção auxiliar, e ela existe porque a subtração sozinha tem um ponto
  # cego: duas consultas de catálogo constantes também se cancelariam. Aqui o
  # que é descontado é **nomeado** — as duas consultas que o `resume_session` do
  # concern `Authentication` emite (`Session Load` e `User Load`) — e o que
  # resta tem de ser exatamente uma, a agregação. Se um dia a página passar a
  # precisar de uma segunda consulta legítima, este teste falha e obriga a
  # decisão a ser explícita, em vez de a segunda consulta entrar sem ninguém ver.
  test "descontadas as consultas de sessão, a página resolve em uma agregação só" do
    semear_sets(SETS_GRANDE, prefixo: "U")
    entrar

    consultas = consultas_da_pagina
    de_sessao, restantes = consultas.partition { |nome, _| CONSULTAS_DE_SESSAO.include?(nome) }

    assert_equal CONSULTAS_DE_SESSAO.size, de_sessao.size,
                 "as consultas de sessão descontadas mudaram de forma; a conta precisa ser refeita à mão.\n" \
                 "#{formatar(consultas)}"
    assert_equal 1, restantes.size,
                 "a página deveria resolver em **uma** consulta além da sessão, e emitiu #{restantes.size}.\n" \
                 "#{formatar(restantes)}"
    assert_match(/GROUP BY/i, restantes.first.last,
                 "a consulta restante não é a agregação por set; a página pode ter trocado de forma.\n" \
                 "#{formatar(restantes)}")
  end

  # A contagem acima mede a requisição inteira, o que é o certo — e por isso
  # mesmo ela passaria se a agregação sumisse e a página não consultasse nada.
  # Esta asserção fecha esse flanco: a requisição **tem** que tocar a agregação,
  # e a página tem que sair com os sets renderizados.
  test "a requisição de fato emite a agregação e renderiza os sets" do
    semear_sets(SETS_PEQUENO, prefixo: "R")
    entrar

    get progress_path

    assert_response :success
    assert_equal SETS_PEQUENO, css_select("li.progress-set").size,
                 "a contagem de consultas não significa nada se a página não listar os sets"
  end

  # --- Done when 3: o plano da agregação, medido com volume realista ---

  # `EXPLAIN` sobre a agregação com o seed de volume. A asserção é sobre o que
  # **não pode** acontecer, nunca sobre qual índice o planejador escolheu:
  # travar um nome de índice foi o erro que a T10 da `colecao` cometeu e teve de
  # corrigir, porque a asserção reprovava justamente o plano melhor.
  test "a agregação não varre a tabela de coleção com volume realista" do
    semear_volume_realista

    assert_agregacao_sem_varredura_indevida(plano_da_agregacao)
  end

  # Este teste guarda o próprio seed, e sem ele todas as asserções de plano
  # seriam verdes sem provar nada — é a lição literal da T10 da `colecao`: um
  # seed reduzido não faz a asserção falhar, faz ela **parar de significar** o
  # que diz, e ninguém percebe. Aqui a premissa vira asserção.
  test "o cenário de plano tem volume e seletividade que justificam a medição" do
    semear_volume_realista

    total = CollectionItem.count
    do_alvo = CollectionItem.where(user: @user).count
    fracao = do_alvo.to_f / total

    assert_operator CardVariant.count, :>=, 5_000,
                    "menos variantes que o catálogo real (4917): o plano mediria uma tabela que cabe em memória"
    assert_operator CardSet.count, :>=, 63,
                    "menos sets que o catálogo real: o `GROUP BY` não seria exercitado no volume que existe hoje"
    assert_operator total, :>=, 10_000,
                    "volume de coleção pequeno demais: o planejador escolheria Seq Scan com razão"
    assert_operator fracao, :<, 0.10,
                    "o usuário alvo detém #{(fracao * 100).round(1)}% dos itens; sem seletividade o índice " \
                    "por usuário seria inútil por custo, e não por ausência"
    assert_operator CollectionItem.where(user: @user, quantity: 0).count, :>, 0,
                    "sem item zerado, `quantity >= 1` não teria linha a descartar e a medição seria vazia"
  end

  # O volume semeado só chega ao planejador através das estatísticas, e quem as
  # atualiza é o `ANALYZE` do fim do seed. **Sem ele o planejador decide com
  # estatísticas default** e o plano medido não é o do cenário: verificado nesta
  # task, sem `ANALYZE` o Postgres estima `rows=1` para `sets`, escolhe
  # `Nested Loop` com `Bitmap Heap Scan` por set e produz um plano que nada tem
  # a ver com o que as 12.000 variantes de fato custam.
  #
  # Esta asserção existe porque o sensor de discriminação desta task mostrou que
  # **remover o `ANALYZE` não derrubava nenhum outro teste**: o plano
  # desinformado também acessa `collection_items` por índice, então as asserções
  # de plano continuavam verdes medindo outra coisa. É o mesmo defeito que o
  # teste acima previne para o volume — premissa que vira asserção —, aplicado à
  # metade que faltava.
  #
  # **A asserção é sobre `last_analyze`, e não sobre `pg_class.reltuples`.**
  # Escrevi a segunda forma primeiro e o sensor a reprovou: `reltuples` **não é
  # transacional** e sobrevive ao rollback do teste, então uma execução anterior
  # deste mesmo arquivo deixa a estimativa povoada e a asserção passa sem o
  # `ANALYZE` — verde por resíduo, e dependente da ordem em que a suíte roda.
  # `last_analyze` é um instante, e comparar com o início do teste prova que o
  # `ANALYZE` rodou **nesta** execução, o que nenhum resíduo satisfaz.
  test "o seed atualiza as estatísticas do planejador nesta execução" do
    inicio = @connection.select_value("SELECT clock_timestamp()")

    semear_volume_realista

    analises = @connection.select_rows(<<~SQL).to_h
      SELECT relname, last_analyze FROM pg_stat_user_tables
      WHERE relname IN ('sets', 'card_variants', 'collection_items')
    SQL

    %w[sets card_variants collection_items].each do |tabela|
      assert analises[tabela],
             "`#{tabela}` nunca passou por `ANALYZE`: o planejador decide com estatísticas default " \
             "e o plano medido não é o do cenário semeado"
      assert_operator analises[tabela], :>, inicio,
                      "o `ANALYZE` de `#{tabela}` é anterior a este teste (#{analises[tabela]} < " \
                      "#{inicio}): as estatísticas são resíduo de outra execução, não do seed daqui"
    end
  end

  # --- Done when 4: a decisão sobre índice, registrada como asserção ---
  #
  # Nenhum índice foi criado nesta task (a medição reprovou o candidato, ver o
  # cabeçalho). O que **existe** e sustenta o acesso à coleção é o índice do
  # `UNIQUE (user_id, card_variant_id)`, criado pela migração `20260919120200`
  # junto com a garantia de unicidade. Sem esta asserção, derrubá-lo só
  # apareceria como lentidão em produção — o plano sozinho não a cobriria,
  # porque outro índice assumiria o lugar e o acesso continuaria indexado.
  test "os índices que sustentam o acesso da agregação à coleção existem" do
    definicoes = @connection.select_rows(<<~SQL).to_h
      SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'collection_items'
    SQL

    assert definicoes["index_collection_items_on_user_id_and_card_variant_id"],
           "faltou o índice do `UNIQUE (user_id, card_variant_id)`, por onde a subconsulta de posse entra"
    assert definicoes["index_collection_items_on_user_id"],
           "faltou o índice por usuário, o caminho alternativo quando o planejador não usa o único"
  end

  # A contrapartida da decisão de não criar índice: se alguém criar o candidato
  # parcial mais adiante, esta asserção **não** o proíbe — ela apenas garante
  # que a decisão medida continue registrada onde a próxima pessoa vai olhar.
  # Índice novo sem medição nova é o que este teste torna visível na revisão.
  test "nenhum índice parcial por quantidade foi criado sem medição" do
    parciais = @connection.select_values(<<~SQL)
      SELECT indexdef FROM pg_indexes
      WHERE tablename = 'collection_items' AND indexdef ILIKE '%WHERE%quantity%'
    SQL

    assert_empty parciais,
                 "existe índice parcial por `quantity` em `collection_items`. A medição desta task (e a da " \
                 "T10 da `colecao`) reprovou esse candidato: o planejador o ignorou. Se ele voltou, a medição " \
                 "que o justifica precisa estar registrada em `tasks.md`.\n#{parciais.join("\n")}"
  end

  # --- Done when 5: viewport de 360px (PRG-12 / Req. 2.5) ---
  #
  # SPEC_DEVIATION: as asserções desta seção são sobre o **texto da folha de
  # estilo** e sobre a **marcação renderizada**, nunca sobre a largura que um
  # navegador calcularia.
  #
  # Reason: **não há navegador no container** (`CLAUDE.md`), então
  # `document.scrollWidth > clientWidth` — a única medição que provaria ausência
  # de scroll horizontal de fato — não existe aqui. O que estas asserções travam
  # são as **causas** de estouro que se pode ler estaticamente: largura fixa
  # acima de 360px e `white-space: nowrap` em bloco largo. É o precedente já
  # adotado nos testes de CSS de `progress_ui_test.rb`, `catalog_grid_test.rb` e
  # `collection_ownership_ui_test.rb`.
  #
  # Limite honesto, escrito para que ninguém leia mais do que está aqui: uma
  # tabela de muitas colunas, uma imagem sem `max-width` ou uma palavra
  # inquebrável mais larga que a caixa estouram 360px sem violar nenhuma destas
  # asserções. O que elas garantem é que as duas causas **declaráveis** não
  # foram introduzidas, e que a marcação continua sendo a lista que reflui — que
  # é a decisão de forma tomada na T5 justamente por causa deste requisito.

  # Larguras fixas em pixel acima de 360px no bloco `progress-*`. O limite é o
  # viewport inteiro do Req. 2.5: qualquer caixa da página declarada mais larga
  # que ele já estoura sozinha, sem precisar de vizinho.
  LARGURA_EM_PIXEL = /\b(?:width|min-width|flex-basis)\s*:\s*(\d+(?:\.\d+)?)px/i
  VIEWPORT_MINIMO = 360

  test "o bloco de progresso não declara largura fixa maior que o viewport de 360px" do
    infratoras = regras_do_bloco_de_progresso.flat_map do |seletor, corpo|
      corpo.scan(LARGURA_EM_PIXEL).filter_map do |(valor)|
        "#{seletor.squish} { ...#{valor}px... }" if valor.to_f > VIEWPORT_MINIMO
      end
    end

    assert_empty infratoras,
                 "regra do bloco `progress-*` declara largura fixa acima de #{VIEWPORT_MINIMO}px, " \
                 "o que estoura o viewport do Req. 2.5:\n#{infratoras.join("\n")}"
  end

  # `white-space: nowrap` num bloco que contém frase inteira impede a quebra que
  # é o único mecanismo pelo qual a página cabe em 360px. Em elemento curto
  # (um código de set, um número) ele é legítimo — por isso a asserção mira os
  # blocos **largos**, os que carregam as frases: o item do set, as linhas de
  # métrica, o nome e a lista.
  BLOCOS_LARGOS = %w[
    .progress
    .progress__list
    .progress-set
    .progress-set__name
    .progress-set__owned-line
    .progress-set__percent
    .progress-set__parallels
    .progress-set__catalog
    .progress-set__catalog-link
  ].freeze

  test "nenhum bloco largo do progresso impede a quebra de linha" do
    infratoras = regras_do_bloco_de_progresso.filter_map do |seletor, corpo|
      next unless corpo.match?(/white-space\s*:\s*nowrap/i)

      alvos = BLOCOS_LARGOS.select { |bloco| seletor.include?(bloco) }
      "#{seletor.squish} { ... } atinge #{alvos.join(", ")}" if alvos.any?
    end

    assert_empty infratoras,
                 "bloco largo do progresso com `white-space: nowrap`: a frase não quebra e a página " \
                 "passa a exigir scroll horizontal em 360px (Req. 2.5).\n#{infratoras.join("\n")}"
  end

  # As duas asserções acima olham a folha; esta olha a **marcação**, onde um
  # `style=` embutido escaparia inteiramente delas. É o mesmo defeito por outra
  # porta: largura fixa acima do viewport, escrita no atributo em vez da regra.
  test "a marcação renderizada não traz estilo embutido com largura fixa" do
    semear_sets(SETS_PEQUENO, prefixo: "V")
    entrar

    get progress_path

    embutidos = css_select("main.progress [style]").map { _1["style"].to_s }
    infratoras = embutidos.select do |estilo|
      estilo.scan(LARGURA_EM_PIXEL).any? { |(valor)| valor.to_f > VIEWPORT_MINIMO } ||
        estilo.match?(/white-space\s*:\s*nowrap/i)
    end

    assert_empty infratoras,
                 "estilo embutido na página de progresso com largura fixa acima de " \
                 "#{VIEWPORT_MINIMO}px ou `nowrap`:\n#{infratoras.join("\n")}"
  end

  # A forma que faz a página caber é a lista que reflui, escolhida na T5
  # exatamente por causa do Req. 2.5: uma tabela de cinco colunas em 360px só
  # caberia com `overflow-x`, que é o scroll horizontal que o requisito proíbe.
  # A asserção trava a escolha — trocar a `<ul>` por `<table>` é a regressão que
  # reintroduziria o problema, e ela não aparece em nenhuma regra de CSS.
  test "os sets são apresentados em lista que reflui, e não em tabela" do
    semear_sets(SETS_PEQUENO, prefixo: "T")
    entrar

    get progress_path

    assert_equal 1, css_select("ul.progress__list").size,
                 "a lista de sets sumiu; a forma que reflui em 360px é a lista da T5"
    assert_empty css_select("main.progress table"),
                 "tabela na página de progresso: em 360px ela só cabe com `overflow-x`, " \
                 "que é exatamente o scroll horizontal que o Req. 2.5 proíbe"
  end

  # E o contêiner não pode recuperar o scroll por outro caminho: `overflow-x`
  # declarado no bloco do progresso é o remédio usual para conteúdo que não
  # cabe, e aqui ele **é** a violação, não a cura.
  test "o bloco de progresso não declara scroll horizontal" do
    infratoras = regras_do_bloco_de_progresso.filter_map do |seletor, corpo|
      seletor.squish if corpo.match?(/overflow(?:-x)?\s*:\s*(?:auto|scroll)/i)
    end

    assert_empty infratoras,
                 "regra do bloco `progress-*` declara scroll horizontal, que é a violação " \
                 "literal do Req. 2.5:\n#{infratoras.join("\n")}"
  end

  # A asserção que guarda as três anteriores: elas varrem "as regras do bloco
  # `progress-*`", e se esse conjunto ficar vazio — folha renomeada, bloco
  # movido de arquivo — todas passariam sem ler uma linha sequer. A premissa
  # vira asserção, como no teste que guarda o seed.
  test "o bloco de progresso da folha de estilo foi de fato encontrado" do
    regras = regras_do_bloco_de_progresso

    assert_operator regras.size, :>=, 5,
                    "só #{regras.size} regra(s) `progress-*` encontrada(s) na folha; as asserções de " \
                    "360px estariam varrendo o vazio e passando sem ler nada"
    assert regras.any? { |seletor, _| seletor.include?(".progress-set") },
           "a regra do item do set não foi encontrada; o seletor mudou e as asserções perderam o alvo"
  end

  private

  # As duas consultas que o `resume_session` do concern `Authentication` emite
  # antes de a action rodar. Nomeadas aqui para que o desconto seja explícito e
  # falhe alto quando mudar, em vez de virar um número mágico na asserção.
  CONSULTAS_DE_SESSAO = [ "Session Load", "User Load" ].freeze

  def entrar
    post session_path, params: { email: @user.email, password: PASSWORD }
    assert_response :redirect, "a sessão não foi estabelecida; a medição seria a do redirect de login"
  end

  def consultas_da_pagina
    consultas = capturar_consultas { get progress_path }
    assert_response :success, "a página não respondeu 200; a contagem mediria a resposta errada"
    consultas
  end

  def capturar_consultas
    consultas = []
    assinante = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].to_s.in?([ "SCHEMA", "TRANSACTION" ])
      next if payload[:sql].to_s.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      consultas << [ payload[:name].to_s, payload[:sql].to_s ]
    end
    yield
    consultas
  ensure
    ActiveSupport::Notifications.unsubscribe(assinante)
  end

  def formatar(consultas)
    consultas.map.with_index { |(nome, sql), i| "  #{i + 1}. [#{nome}] #{sql.squish[0, 160]}" }.join("\n")
  end

  # --- Plano ---

  def plano_da_agregacao
    sql = SetProgressQuery.new(@user).send(:rows).to_sql

    @connection.uncached { @connection.select_values("EXPLAIN #{sql}") }.join("\n")
  end

  # A asserção é dupla, pela mesma razão da T10 da `colecao`: um `refute_match`
  # sozinho passaria se a consulta parasse de tocar `collection_items` — uma
  # agregação que não consulta a posse também não a varre, e devolveria zero
  # para todo mundo. O `assert_match` exige que o acesso **exista** e seja
  # indexado, sem travar por qual índice.
  #
  # Os dois `Seq Scan` do catálogo (`sets` e `card_variants`) **não** são
  # assertados como ausentes, e isso é deliberado: eles são corretos e não
  # evitáveis. `total_variants` e `parallel_variants` exigem todas as variantes
  # de todos os sets, então não há predicado seletivo a explorar e um índice não
  # teria o que fazer. Exigir sua ausência reprovaria o plano certo e empurraria
  # para um índice que só serviria para satisfazer a asserção.
  ACESSO_INDEXADO_A_COLECAO = /
    (?:Index|Index\ Only|Bitmap\ Index)\ Scan[^\n]*
    index_collection_items_on_(?:user_id|card_variant_id|user_id_and_card_variant_id)
  /x

  def assert_agregacao_sem_varredura_indevida(plano)
    refute_match(/Seq Scan on collection_items/, plano,
                 "a agregação varreu `collection_items` inteira. Plano:\n#{plano}")
    assert_match(ACESSO_INDEXADO_A_COLECAO, plano,
                 "a agregação não acessou `collection_items` por índice nenhum. Plano:\n#{plano}")
  end

  # --- CSS ---

  def folha_de_estilo
    Rails.root.join("app/assets/stylesheets/catalog.css").read
  end

  # Todas as regras cujo seletor menciona o bloco `progress-*`. A varredura é
  # por seletor e não por faixa de linhas: o bloco pode ser reordenado dentro da
  # folha sem que as asserções percam o alvo, e uma regra de progresso escrita
  # longe do bloco (como a de `:focus-visible`, que vive no grupo dos controles
  # de posse) continua sendo inspecionada.
  def regras_do_bloco_de_progresso
    folha_de_estilo.scan(/([^{}]+)\{([^}]*)\}/m)
                   .select { |seletor, _| seletor.match?(/\.progress(?:-set)?(?:__|\b)/) }
  end

  # --- Seed ---

  # Cenário de contagem: sets com variantes de verdade e posse de verdade, para
  # que a página tenha o que renderizar e a agregação tenha o que agregar. O
  # prefixo separa as chaves naturais entre as chamadas dentro de um mesmo teste
  # e entre os testes, que rodam em paralelo.
  def semear_sets(quantidade, prefixo:)
    quantidade.times do |i|
      set = CardSet.create!(code: "T8#{prefixo}#{i}", name: "Set #{prefixo}#{i}", kind: "booster",
                            base_set_size: 2, total_set_size: 3)
      base = criar_variante(set, "#{prefixo}#{i}a", "base")
      criar_variante(set, "#{prefixo}#{i}b", "parallel")
      CollectionItem.create!(user: @user, card_variant: base, quantity: 1 + (i % 3))
    end
  end

  def criar_variante(set, sufixo, art_kind)
    card = Card.create!(card_set: set, card_number: "T8-#{sufixo}", name: "Carta #{sufixo}",
                        card_type: "character", colors: [ "Red" ])
    CardVariant.create!(card: card, card_set: set, variant_code: "t8#{sufixo}",
                        rarity: "C", art_kind: art_kind)
  end

  # Volume realista para a medição de plano: SQL direto, porque 12.000 variantes
  # e 20.400 itens de coleção por `create!` levariam minutos e o teste deixaria
  # de ser rodado. O `ANALYZE` ao fim não é detalhe: sem
  # ele o planejador decide com estatísticas default e o plano medido não
  # reflete o que foi semeado — foi a armadilha nomeada na T10 da `colecao`.
  def semear_volume_realista
    semear_catalogo_em_volume
    semear_usuarios_e_posse

    %w[sets cards card_variants collection_items users].each { @connection.execute("ANALYZE #{_1}") }
  end

  def semear_catalogo_em_volume
    @connection.execute(<<~SQL)
      INSERT INTO sets (code, name, kind, base_set_size, total_set_size, created_at, updated_at)
      SELECT 'T8V' || lpad(i::text, 4, '0'), 'Volume ' || i, 'booster',
             #{VARIANTES_POR_SET / 2}, #{VARIANTES_POR_SET}, now(), now()
      FROM generate_series(1, #{SETS_VOLUME}) AS i
    SQL

    @connection.execute(<<~SQL)
      INSERT INTO cards (set_id, card_number, name, card_type, colors, created_at, updated_at)
      SELECT s.id, 'T8V-' || s.code || '-' || lpad(i::text, 3, '0'), 'Carta ' || i,
             'character', ARRAY['Red'], now(), now()
      FROM sets s, generate_series(1, #{VARIANTES_POR_SET}) AS i
      WHERE s.code LIKE 'T8V%'
    SQL

    # Um terço `parallel`, para que a coluna `FILTER` da métrica separada tenha
    # linhas de fato e não seja otimizada sobre um conjunto vazio.
    @connection.execute(<<~SQL)
      INSERT INTO card_variants (card_id, set_id, variant_code, art_kind, rarity, created_at, updated_at)
      SELECT c.id, c.set_id, c.card_number || '_v',
             CASE WHEN c.id % 3 = 0 THEN 'parallel' ELSE 'base' END,
             'C', now(), now()
      FROM cards c JOIN sets s ON s.id = c.set_id
      WHERE s.code LIKE 'T8V%'
    SQL
  end

  # Cinquenta usuários, e não um só: com um único usuário o predicado
  # `user_id = $1` casaria 100% da tabela e o índice por usuário seria inútil
  # por **seletividade**, não por ausência — a asserção de plano mediria outra
  # coisa. `quantity = 0` em 1 de 7 mantém real o descarte de `quantity >= 1`.
  def semear_usuarios_e_posse
    @connection.execute(<<~SQL)
      INSERT INTO users (email, password_digest, created_at, updated_at)
      SELECT 'plano-t8-' || i || '@example.com', 'x', now(), now()
      FROM generate_series(1, #{USUARIOS}) AS i
    SQL

    # O deslocamento por `u.id` evita que todos possuam exatamente as mesmas
    # variantes, o que tornaria `card_variant_id` degenerado e falsearia o custo
    # do join. O usuário alvo (`@user`) entra no mesmo sorteio pelo `UNION`.
    @connection.execute(<<~SQL)
      INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
      SELECT u.id, v.id,
             CASE WHEN v.id % 7 = 0 THEN 0 ELSE 1 + (v.id % 3) END,
             now(), now()
      FROM (
        SELECT id FROM users WHERE email LIKE 'plano-t8-%@example.com'
        UNION ALL SELECT #{@user.id}
      ) u
      JOIN LATERAL (
        SELECT cv.id FROM card_variants cv JOIN sets s ON s.id = cv.set_id
        WHERE s.code LIKE 'T8V%'
        ORDER BY (cv.id * (u.id % 97 + 1)) % 20011
        LIMIT #{ITENS_POR_USUARIO}
      ) v ON true
    SQL
  end
end
