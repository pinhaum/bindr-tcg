require "test_helper"

# T17 — custo do export e da pré-visualização do CSV de coleção (POR-13,
# Req. 11.1), medido com volume realista.
#
# O teste é sobre o **custo**, nunca sobre o conteúdo: as T5, T6, T9 e T16 já
# provaram que o arquivo sai certo e que a classificação está correta. Uma
# implementação que produzisse exatamente o mesmo arquivo abrindo uma consulta
# por linha passaria em todos aqueles testes — este arquivo existe para a
# metade que eles não cobrem.
#
# ## O que POR-13 afirma, e o que ele **não** afirma
#
# Os dois critérios da história P2 falam em **número de consultas**: "resolver o
# export em um número de consultas que não cresce com a quantidade de linhas"
# (critério 4) e "resolver a pré-visualização sem emitir uma consulta por linha
# do arquivo" (critério 5). Round-trip ao banco, não operador de acesso.
#
# Isso decide a forma das asserções deste arquivo e o separa de
# `catalog_owned_plan_test.rb` e `set_progress_plan_test.rb`, que assertam
# `refute_match(/Seq Scan on X/)` **mais** `assert_match(Index Scan)`. Aqui a
# dupla estaria errada, e a revisão de banco desta task mediu por quê: nas duas
# consultas medidas abaixo o `Seq Scan` é o plano **correto**, e exigir índice
# reprovaria o plano melhor — o erro que a T10 da `colecao` cometeu e teve de
# corrigir, aqui antecipado pela medição em vez de descoberto pela falha.
#
# ## Os dois regimes de seletividade, e por que os dois são necessários
#
# Medido nesta task, com o seed abaixo (20.000 cartas e variantes, 50 usuários,
# ~24.900 itens de coleção):
#
# - **Colecionador comum (~1,6% dos itens, 342 linhas exportadas)**: o
#   planejador entra por `index_collection_items_on_user_id`, casa
#   `card_variants` por `Seq Scan` em hash join e sonda `cards` por
#   `cards_pkey` em **nested loop**. Custo 1130, 2,3ms.
# - **Colecionador grande (~21% dos itens, 4.541 linhas exportadas)**: o
#   planejador troca o nested loop por **hash join** e varre `cards` também.
#   Custo 2102, 7,0ms.
#
# Medir só o primeiro cairia na armadilha oposta à que
# `catalog_owned_plan_test.rb` documenta: exigiria `Index Scan` onde, em fração
# alta de posse, `Seq Scan` é o certo. E medir com catálogo pequeno faria os
# dois regimes colapsarem em `Seq Scan` por acidente de volume — a tabela
# inteira cabe em poucas centenas de páginas e o planejador escolhe varrer com
# razão. Daí as 20.000 variantes.
#
# ## O `loops=` alto do cenário de 2% **não** é violação de POR-13
#
# No plano do colecionador comum aparece
# `Index Scan using cards_pkey ... rows=1 loops=343`: 343 sondas em `cards`,
# uma por linha exportada. É a assinatura visual de N+1 — e aqui ela não é um.
# O export é **uma única consulta** (`joins` + `pluck`, veja
# `app/services/collection_csv/export.rb:52-60`), e `loops` conta iteração de
# nested loop **dentro** dela: nenhum round-trip a mais, nenhuma ida ao banco a
# mais. É por isso que este arquivo não assevera `refute_match(/loops=\d{3,}/)`
# sobre os dois cenários — ela reprovaria o cenário de 2%, que é legítimo.
#
# O que se assevera é o outro lado, e ele é a prova de fato: a **contagem de
# consultas** medida pelo instrumento do Active Record. Um N+1 de verdade —
# instanciar a carta e ler `card.name` por linha — muda essa contagem de 1 para
# N+1, e os testes abaixo morrem. O `loops` não muda nada nessa contagem, e é
# exatamente por isso que ele é observação de plano e não critério.
#
# **E a tentativa de promovê-lo a critério foi medida e descartada aqui.** A
# hipótese inicial era que no regime de fração alta o planejador se protege
# sozinho, trocando o nested loop por hash join, e que isso poderia virar
# `refute_match(/Nested Loop/)`. A hipótese é **falsa como invariante**: o
# mesmo cenário, mesmo seed e mesmo volume produziu `Hash Join` numa execução
# (custo 2102, 7,0ms) e `Gather Merge` → `Nested Loop ... loops=4525` em três
# outras (custo 14078, 9,5ms, dois workers paralelos) — a escolha depende de
# cache e de paralelismo, não de nada que POR-13 vigie. A asserção
# correspondente é intermitente e foi **removida**; o que ficou no lugar está
# em "os dois regimes de seletividade custam uma consulta cada".
#
# ## Por que **não** há migração nesta task
#
# A revisão de banco não encontrou índice ausente cujo uso reduzisse custo, e o
# único contrafactual testado mostrou índice **pior** que a varredura.
# Reproduzido nesta task sobre a consulta de variantes do resolvedor com 5.000
# números: com `SET LOCAL enable_seqscan = off`, o custo sobe de **2505,53 para
# 6832,82** (+173%), porque o `Index Scan using index_card_variants_on_card_id`
# sozinho custa 5268 contra 941 do `Seq Scan`. O planejador está certo. Criar
# índice aqui seria custo de escrita em toda a ingestão sem ganho de leitura.
#
# Precedente da casa, e ele é literal: a T10 da `colecao` mediu um candidato e
# **não** o criou; a T8 da `progresso` fez o mesmo. Esta task segue os dois.
#
# ## Observação LOW registrada, que não é violação de POR-13
#
# O `Planning Time` da consulta de variantes cresce com o tamanho da lista
# literal do `IN`: ~4,8ms com 5.000 números neste seed, e a revisão mediu
# ~10,6ms com 5.000 e ~17–19,5ms com 10.000 no banco dela. É custo de **parsear
# a lista**, não de executar — o `Execution Time` fica em ~4,4ms nos dois. Não
# viola POR-13, que fala de número de consultas, e fica registrado junto da
# dívida da T14: se o teto de 10.000 linhas da AD-008 algum dia apertar o tempo
# de resposta, a saída medida é passar a lista por `VALUES`/`unnest` em vez de
# literal, **com medição** — nunca trocar de stack nem partir para assíncrono
# no escuro, que é o que o próprio "Done when" desta task exige.
class CollectionCsvPlanTest < ActionDispatch::IntegrationTest
  PASSWORD = "grand-line-t17".freeze

  # Volume do catálogo. O real tem 63 sets e 4917 variantes; o seed vai bem
  # acima de propósito, pela razão medida no cabeçalho: com catálogo pequeno os
  # dois regimes de seletividade colapsam em `Seq Scan` e a medição ficaria
  # verde por acidente de volume, não por ausência de N+1.
  CARTAS = 20_000

  # Cinquenta usuários, e não um só: com um único usuário o predicado
  # `user_id = $1` casaria 100% de `collection_items` e a seletividade que
  # distingue os dois regimes não existiria.
  USUARIOS = 50

  # Os dois regimes. ~1,6% é o colecionador comum; ~21% é o grande. A diferença
  # entre eles é o que faz o planejador trocar de forma de plano, e é ela que
  # este arquivo cobre dos dois lados.
  ITENS_COMUM = 400
  ITENS_GRANDE = 5_000

  # Volumes da pré-visualização. O teto da AD-008 é 10.000 linhas de dado; o
  # cenário grande fica em 2.000 porque o que se mede é **forma** (a contagem
  # tem de ser idêntica), e o contraste de 40 para 2.000 já faria uma consulta
  # por linha saltar de ~3 para ~2.000. Rodar no teto puro só somaria minutos
  # de parser ao teste sem acrescentar prova.
  LINHAS_PREVIA_PEQUENA = 40
  LINHAS_PREVIA_GRANDE = 2_000

  setup do
    @connection = ActiveRecord::Base.connection
    semear_volume_realista
  end

  # --- Done when 1: o export não cresce em consultas com o número de linhas ---

  # A prova central do critério 4 da história P2. Dois volumes, e a
  # **igualdade** afirmada — nunca um número absoluto.
  #
  # Por que a igualdade e não `assert_equal 1`: um export N+1 satisfaria
  # "é igual a 1" se o cenário medido tivesse uma linha só, e satisfaria
  # qualquer número fixo escolhido a partir de uma medição única. A igualdade
  # entre dois volumes muito diferentes é a única forma que um N+1 **não** tem
  # como satisfazer: ele produziria 343 contra 4.542.
  #
  # A T5 já afirma isso, e com 1 linha contra 10. A diferença desta asserção é
  # o volume: 342 contra 4.541 linhas, sobre um catálogo de 20.000 variantes em
  # que o planejador de fato **troca de forma de plano** entre os dois. É o que
  # POR-13 quer dizer por "não cresce com a quantidade de linhas".
  test "o número de consultas do export não cresce com o número de linhas" do
    consultas_comum = capturar_consultas { CollectionCsv::Export.new(@comum).to_csv }
    consultas_grande = capturar_consultas { CollectionCsv::Export.new(@grande).to_csv }

    assert_equal consultas_comum.size, consultas_grande.size,
                 "exportar #{linhas_exportadas(@grande)} linhas custou " \
                 "#{consultas_grande.size - consultas_comum.size} consulta(s) a mais que exportar " \
                 "#{linhas_exportadas(@comum)} — o export está N+1 no número de linhas (POR-13).\n" \
                 "Cenário comum:\n#{formatar(consultas_comum)}\n" \
                 "Cenário grande:\n#{formatar(consultas_grande)}"
  end

  # A igualdade acima tem um ponto cego: ela passaria se o export parasse de
  # consultar o banco — zero é igual a zero, e um arquivo vazio custa o mesmo
  # nos dois cenários. Esta asserção fecha o flanco pelo lado positivo: a
  # consulta **existe**, é **uma só**, e traz de fato as linhas do usuário.
  test "o export resolve em uma única consulta que de fato traz as linhas" do
    consultas = capturar_consultas { @csv = CollectionCsv::Export.new(@grande).to_csv }

    assert_equal 1, consultas.size,
                 "o export deveria resolver em **uma** consulta e emitiu #{consultas.size}.\n" \
                 "#{formatar(consultas)}"
    assert_equal linhas_exportadas(@grande), @csv.lines.size - 1,
                 "a contagem de consultas não significa nada se o arquivo não trouxer as linhas"
  end

  # --- Done when 2: a pré-visualização, medida de ponta a ponta ---

  # O critério 5 da história P2, e ele é sobre **a requisição que o usuário
  # dispara**, não sobre o resolvedor isolado. A T9 já trava a forma do
  # `Resolver`; isso não basta, porque o upload atravessa parser, resolvedor,
  # gravação do staging e o `resume_session` do concern — e uma escrita de
  # staging por linha, ou um `find` de variante na serialização, deixaria o
  # resolvedor intacto e a requisição N+1 mesmo assim.
  #
  # A asserção é sobre a **diferença entre dois volumes de arquivo**: o custo
  # de sessão, CSRF e layout é idêntico nos dois e se cancela na subtração,
  # seja ele qual for. Uma consulta por linha produziria diferença de 1.960;
  # a forma correta produz **zero**.
  test "o número de consultas da pré-visualização não cresce com o número de linhas do arquivo" do
    entrar

    pequena = capturar_consultas { enviar(csv_de(LINHAS_PREVIA_PEQUENA)) }
    grande = capturar_consultas { enviar(csv_de(LINHAS_PREVIA_GRANDE)) }

    assert_equal pequena.size, grande.size,
                 "um arquivo de #{LINHAS_PREVIA_GRANDE} linhas custou " \
                 "#{grande.size - pequena.size} consulta(s) a mais que um de " \
                 "#{LINHAS_PREVIA_PEQUENA} — a pré-visualização emite consulta por linha (POR-13).\n" \
                 "Arquivo pequeno:\n#{formatar(pequena)}\nArquivo grande:\n#{formatar(grande)}"
  end

  # O mesmo ponto cego da subtração, fechado do mesmo jeito: a requisição
  # precisa **ter** classificado as linhas, e não apenas ter custado pouco.
  # Sem isto, um upload que recusasse o arquivo em silêncio passaria — recusa
  # também custa o mesmo nos dois volumes.
  test "a pré-visualização de fato classifica todas as linhas do arquivo" do
    entrar
    enviar(csv_de(LINHAS_PREVIA_GRANDE))

    previa = CollectionImport.order(:id).last

    assert_equal @grande, previa.user,
                 "a pré-visualização não ficou com o usuário da sessão; a medição seria de outro fluxo"
    assert_equal LINHAS_PREVIA_GRANDE, previa.linhas.size,
                 "a contagem de consultas não significa nada se o arquivo não foi classificado inteiro"
    assert_empty previa.linhas_resolvidas.select(&:rejeitada?),
                 "o cenário deveria ser todo de linhas aceitas; com rejeição em massa o caminho " \
                 "medido não é o que resolve variante e posse"
  end

  # Descontadas as consultas que não dependem do arquivo, o que resta é o custo
  # real do fluxo — e ele precisa ser um número pequeno e **nomeado**. A
  # subtração do teste acima cancela qualquer consulta constante, inclusive uma
  # segunda consulta de catálogo que alguém acrescente amanhã; esta asserção é
  # a que torna esse acréscimo visível em vez de silencioso.
  #
  # Medido nesta task: 2 do `resume_session` (`Session Load`, `User Load`) e 3
  # do fluxo — as duas do `Resolver` (variantes por par, posses atuais) e o
  # `INSERT` do staging. Se um dia o fluxo precisar de uma quarta, este teste
  # falha e obriga a decisão a ser explícita.
  test "descontada a sessão, a pré-visualização resolve em um punhado de consultas constante" do
    entrar

    consultas = capturar_consultas { enviar(csv_de(LINHAS_PREVIA_GRANDE)) }
    de_sessao, restantes = consultas.partition { |nome, _| CONSULTAS_DE_SESSAO.include?(nome) }

    assert_equal CONSULTAS_DE_SESSAO.size, de_sessao.size,
                 "as consultas de sessão descontadas mudaram de forma; a conta precisa ser refeita à mão.\n" \
                 "#{formatar(consultas)}"
    assert_equal CONSULTAS_DA_PREVIA, restantes.size,
                 "a pré-visualização deveria custar #{CONSULTAS_DA_PREVIA} consultas além da sessão, " \
                 "e custou #{restantes.size}. Se a consulta a mais é legítima, a decisão precisa ser " \
                 "explícita aqui — foi para isso que esta asserção foi escrita.\n#{formatar(restantes)}"
  end

  # --- Done when 3: o seed que dá sentido às medições acima ---

  # Este teste guarda o próprio seed, e é a lição literal da T10 da `colecao`:
  # um seed reduzido não faz as asserções acima falharem, faz elas **pararem de
  # significar** o que dizem, e ninguém percebe. Aqui a premissa vira asserção.
  test "o cenário semeado tem volume e os dois regimes de seletividade" do
    total = CollectionItem.count
    fracao_comum = CollectionItem.where(user: @comum).count.to_f / total
    fracao_grande = CollectionItem.where(user: @grande).count.to_f / total

    assert_operator CardVariant.count, :>=, 5_000,
                    "menos variantes que o catálogo real (4917): com catálogo que cabe em poucas " \
                    "páginas os dois regimes colapsam em Seq Scan e a medição fica verde por acidente"
    assert_operator total, :>=, 10_000,
                    "volume de coleção pequeno demais: o planejador escolheria Seq Scan com razão " \
                    "nos dois cenários e eles deixariam de ser dois regimes"
    assert_operator fracao_comum, :<, 0.05,
                    "o colecionador comum detém #{(fracao_comum * 100).round(1)}% dos itens; acima " \
                    "disso ele deixa de ser o regime seletivo e os dois cenários viram um só"
    assert_operator fracao_grande, :>, 0.15,
                    "o colecionador grande detém #{(fracao_grande * 100).round(1)}% dos itens; abaixo " \
                    "disso o planejador não troca de forma de plano e o regime de fração alta não é medido"
    assert_operator CollectionItem.where(user: @comum, quantity: 0).count, :>, 0,
                    "sem item zerado, o `owned` do export não teria linha a descartar"
  end

  # O volume semeado só chega ao planejador pelas estatísticas, e quem as
  # atualiza é o `ANALYZE` do fim do seed. Sem ele o Postgres decide com
  # estatísticas default e os planos medidos não são os do cenário.
  #
  # A asserção é sobre `pg_stats`, e **não** sobre `pg_class.reltuples` nem
  # sobre `pg_stat_user_tables.last_analyze` — as duas foram medidas e
  # reprovadas na T8 da `progresso`, a primeira por ficar verde com resíduo de
  # execução anterior (não é transacional), a segunda por intermitência (passa
  # pelo coletor assíncrono de estatísticas). `pg_stats` é síncrono e
  # transacional: o rollback do teste o desfaz, então resíduo não o satisfaz.
  #
  # A drenagem de pending list da AD-009 **não se aplica aqui** e não é imitada:
  # nenhuma das colunas que o export e o resolvedor tocam
  # (`collection_items.user_id`, `cards.card_number`, `card_variants.card_id`)
  # usa índice GIN. Aquela decisão é de `catalog_search_test.rb`, onde os três
  # índices da busca são GIN com `fastupdate`.
  test "o seed atualiza as estatísticas do planejador nesta execução" do
    colunas = @connection.select_rows(<<~SQL).to_h
      SELECT tablename, count(*) FROM pg_stats
      WHERE tablename IN ('cards', 'card_variants', 'collection_items')
      GROUP BY tablename
    SQL

    %w[cards card_variants collection_items].each do |tabela|
      assert_operator colunas.fetch(tabela, 0), :>, 0,
                      "`#{tabela}` não tem estatística de coluna em `pg_stats` nesta transação: ou o " \
                      "`ANALYZE` do seed não rodou, ou rodou sobre tabela vazia. Nos dois casos o " \
                      "planejador decide com estatísticas default e os planos medidos não são os do " \
                      "cenário semeado."
    end
  end

  # --- Done when 4: os planos, com o que eles podem e não podem afirmar ---

  # A asserção de plano deste arquivo é **só** o `refute_match`, e a ausência do
  # `assert_match(Index Scan)` que as T10/T8 têm é deliberada e medida (ver o
  # cabeçalho). O que se proíbe é a varredura da tabela de coleção — a única
  # que cresce com o número de linhas **do usuário** e a única que um predicado
  # seletivo poderia evitar. As varreduras de `cards` e `card_variants` ficam
  # livres de propósito: o planejador as escolhe por custo, e no regime de
  # fração alta elas são o plano certo.
  test "o export não varre a tabela de coleção em nenhum dos dois regimes" do
    { "colecionador comum" => @comum, "colecionador grande" => @grande }.each do |rotulo, user|
      plano = plano_do_export(user)

      refute_match(/Seq Scan on collection_items/, plano,
                   "o export do #{rotulo} varreu `collection_items` inteira — o recorte por usuário " \
                   "deixou de ser indexável. Plano:\n#{plano}")
    end
  end

  # A observação do cabeçalho sobre `loops=` **não** virou asserção, e a
  # tentativa de transformá-la em uma foi medida e descartada nesta task.
  #
  # A versão escrita primeiro era `refute_match(/Nested Loop/)` sobre o cenário
  # de fração alta, sob a hipótese de que ali o planejador sempre troca o
  # nested loop por hash join. **Ela é intermitente**: passou na execução do
  # arquivo inteiro e falhou nas três execuções seguintes rodada sozinha, com o
  # mesmo seed e o mesmo volume. A causa é que a forma do plano depende do
  # estado de cache e de quantos workers paralelos o Postgres resolve lançar —
  # medido, o mesmo cenário produziu tanto `Hash Join` (custo 2102, sem
  # paralelismo) quanto `Gather Merge` → `Nested Loop ... loops=4525` (custo
  # 14078, com dois workers). Nenhuma das duas é regressão, e as duas custam
  # **uma consulta**.
  #
  # Isso é a mesma lição que a T10 da `colecao` aprendeu por outro caminho:
  # travar operador de acesso reprova plano legítimo. Aqui ela aparece na
  # versão pior, porque a asserção não erra sempre — ela erra às vezes, e um
  # teste que falha de forma intermitente por motivo que não é defeito é o que
  # acaba apagado na primeira vez que atrapalha.
  #
  # O que resta no lugar é o que POR-13 de fato afirma, e é estável por
  # construção: **uma consulta**, qualquer que seja a forma do plano. Esta
  # asserção mede os dois regimes lado a lado com o instrumento certo.
  test "os dois regimes de seletividade custam uma consulta cada, qualquer que seja o plano" do
    por_regime = {
      "colecionador comum" => @comum,
      "colecionador grande" => @grande
    }.transform_values { |user| capturar_consultas { CollectionCsv::Export.new(user).to_csv } }

    por_regime.each do |rotulo, consultas|
      assert_equal 1, consultas.size,
                   "o export do #{rotulo} custou #{consultas.size} consultas em vez de uma. " \
                   "O número de round-trips é o que POR-13 afirma, e ele não depende de qual " \
                   "forma de plano o planejador escolheu.\n#{formatar(consultas)}"
    end
  end

  # A decisão de **não** criar índice, registrada como asserção — mesmo
  # desenho da T8 da `progresso`. Ela não proíbe que alguém crie um índice
  # adiante; ela garante que a medição que o reprovou esteja onde a próxima
  # pessoa vai olhar, e torna visível na revisão um índice novo sem medição
  # nova.
  test "nenhum índice foi criado para o export ou para a pré-visualização sem medição" do
    indices_de_import = @connection.select_values(<<~SQL)
      SELECT indexdef FROM pg_indexes
      WHERE tablename IN ('cards', 'card_variants', 'collection_items')
        AND (indexdef ILIKE '%csv%' OR indexdef ILIKE '%import%' OR indexdef ILIKE '%export%')
    SQL

    assert_empty indices_de_import,
                 "existe índice batizado para o fluxo de CSV. A medição desta task o reprovou: o " \
                 "contrafactual `enable_seqscan = off` fez o custo da consulta de variantes subir de " \
                 "2505 para 6833 (+173%), ou seja, o índice é **pior** que a varredura. Se um índice " \
                 "voltou, a medição que o justifica precisa estar em `tasks.md`.\n#{indices_de_import.join("\n")}"
  end

  # Os índices que os dois fluxos de fato usam, e que nenhum plano sozinho
  # cobriria: derrubá-los faria outro índice assumir o lugar em alguns
  # caminhos, e a regressão só apareceria como lentidão em produção.
  test "os índices que sustentam o export e a resolução de variantes existem" do
    def_colecao = @connection.select_values(
      "SELECT indexname FROM pg_indexes WHERE tablename = 'collection_items'"
    )
    def_cartas = @connection.select_values(
      "SELECT indexname FROM pg_indexes WHERE tablename = 'cards'"
    )

    assert_includes def_colecao, "index_collection_items_on_user_id",
                    "faltou o índice por usuário, por onde o export recorta a coleção do dono"
    assert_includes def_cartas, "index_cards_on_card_number",
                    "faltou o índice por `card_number`, por onde o resolvedor casa o lote inteiro " \
                    "de linhas do arquivo em uma consulta só"
  end

  private

  # As duas consultas que o `resume_session` do concern `Authentication` emite
  # antes de a action rodar. Nomeadas para que o desconto seja explícito e
  # falhe alto quando mudar, em vez de virar número mágico na asserção.
  CONSULTAS_DE_SESSAO = [ "Session Load", "User Load" ].freeze

  # Medido nesta task: quatro consultas além da sessão, nenhuma delas
  # dependente do número de linhas do arquivo:
  #
  #   1. `CardVariant Pluck`        — as variantes do lote inteiro, por par
  #   2. `CollectionItem Pluck`     — as posses atuais do lote inteiro
  #   3. `CollectionImport Exists?` — a validação de unicidade do token
  #   4. `CollectionImport Create`  — o `INSERT` do staging
  #
  # A terceira foi **descoberta por este teste**, não prevista: o
  # `validates :token, uniqueness: true` do model emite um `SELECT 1` por
  # gravação. Ela é constante — um token por upload, não um por linha —, logo
  # não toca POR-13. Fica nomeada aqui em vez de embutida no número, que é o
  # que torna visível uma quinta consulta que alguém acrescente amanhã.
  CONSULTAS_DA_PREVIA = 4

  def entrar
    post session_path, params: { email: @grande.email, password: PASSWORD }
    assert_response :redirect, "a sessão não foi estabelecida; a medição seria a do redirect de login"
  end

  def enviar(csv)
    post collection_imports_path, params: {
      arquivo: Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "c.csv")
    }
    assert_response :redirect, "o upload não produziu pré-visualização; a medição seria a de uma recusa"
  end

  # Um CSV de `n` linhas, todas resolvíveis: variantes que existem no catálogo
  # semeado, sem duplicata e sem quantidade inválida. O caminho medido tem de
  # ser o que resolve variante e consulta posse — um arquivo de linhas
  # rejeitadas sairia mais barato e mediria outra coisa.
  def csv_de(n)
    CSV.generate(col_sep: CollectionCsv::Format::DELIMITER) do |csv|
      csv << CollectionCsv::Format.header_row
      @pares.first(n).each_with_index do |(numero, codigo, nome), i|
        csv << [ numero, codigo, nome, (i % 4) + 1 ]
      end
    end
  end

  def linhas_exportadas(user)
    CollectionItem.for_user(user).owned.count
  end

  def capturar_consultas
    consultas = []
    assinante = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:cached]
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

  # O `EXPLAIN` roda sobre o SQL que o export de fato emite. `select` e não
  # `pluck` porque `pluck` executa: o que se quer aqui é a string da consulta,
  # com as mesmas colunas, o mesmo `joins` e a mesma ordenação.
  def plano_do_export(user)
    sql = CollectionItem
            .for_user(user)
            .owned
            .joins(card_variant: :card)
            .order("cards.card_number ASC", "card_variants.variant_code ASC")
            .select("cards.card_number", "card_variants.variant_code",
              "cards.name", "collection_items.quantity")
            .to_sql

    @connection.uncached { @connection.select_values("EXPLAIN #{sql}") }.join("\n")
  end

  # --- Seed ---
  #
  # SQL direto, e não `create!`: 20.000 cartas, 20.000 variantes e ~24.900
  # itens de coleção por Active Record levariam minutos, e um teste lento
  # demais deixa de ser rodado. Tudo dentro da transação do
  # `use_transactional_tests` — nenhuma linha sobrevive ao teste, que é o que
  # impede um `sets` órfão de quebrar os testes de outras features que
  # assertam `CardSet.count` global.
  def semear_volume_realista
    set_id = semear_catalogo
    semear_usuarios_e_posse(set_id)

    # Sem `ANALYZE` o planejador opera com estatísticas default e os planos
    # medidos não refletem o que foi semeado — a armadilha nomeada na T10 da
    # `colecao` e travada por asserção logo acima.
    %w[sets cards card_variants collection_items users].each { @connection.execute("ANALYZE #{_1}") }

    @pares = @connection.select_rows(<<~SQL)
      SELECT c.card_number, v.variant_code, c.name
      FROM card_variants v JOIN cards c ON c.id = v.card_id
      WHERE v.set_id = #{set_id} ORDER BY v.id LIMIT #{LINHAS_PREVIA_GRANDE}
    SQL
  end

  def semear_catalogo
    set_id = @connection.select_value(<<~SQL)
      INSERT INTO sets (code, name, kind, base_set_size, total_set_size, created_at, updated_at)
      VALUES ('T17V', 'Custo do CSV', 'booster', #{CARTAS / 2}, #{CARTAS}, now(), now())
      RETURNING id
    SQL

    @connection.execute(<<~SQL)
      INSERT INTO cards (set_id, card_number, name, card_type, colors, created_at, updated_at)
      SELECT #{set_id}, 'T17-' || lpad(i::text, 6, '0'), 'Carta ' || i, 'character',
             ARRAY['Red'], now(), now()
      FROM generate_series(1, #{CARTAS}) AS i
    SQL

    @connection.execute(<<~SQL)
      INSERT INTO card_variants (card_id, set_id, variant_code, art_kind, rarity, created_at, updated_at)
      SELECT id, #{set_id}, card_number || '_base', 'base', 'C', now(), now()
      FROM cards WHERE set_id = #{set_id}
    SQL

    set_id
  end

  # Os 50 usuários recebem a fatia do colecionador comum; o alvo do regime de
  # fração alta recebe a dele por cima. O deslocamento por `u.id` evita que
  # todos possuam exatamente as mesmas variantes, o que tornaria
  # `card_variant_id` degenerado e falsearia o custo do join.
  # `quantity = 0` em 1 de 7 mantém real o descarte do `owned`.
  def semear_usuarios_e_posse(set_id)
    @connection.execute(<<~SQL)
      INSERT INTO users (email, password_digest, created_at, updated_at)
      SELECT 'plano-t17-' || i || '@example.com', '#{digest_da_senha}', now(), now()
      FROM generate_series(1, #{USUARIOS}) AS i
    SQL

    @connection.execute(<<~SQL)
      INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
      SELECT u.id, v.id,
             CASE WHEN v.id % 7 = 0 THEN 0 ELSE 1 + (v.id % 3) END,
             now(), now()
      FROM (SELECT id FROM users WHERE email LIKE 'plano-t17-%@example.com') u
      JOIN LATERAL (
        SELECT id FROM card_variants WHERE set_id = #{set_id}
        ORDER BY (id * (u.id % 97 + 1)) % 20011
        LIMIT #{ITENS_COMUM}
      ) v ON true
    SQL

    usuarios = User.where("email LIKE 'plano-t17-%@example.com'").order(:id)
    @comum = usuarios.first
    @grande = usuarios.last

    # O `ON CONFLICT DO NOTHING` é necessário porque o sorteio acima já deu ao
    # alvo `ITENS_COMUM` variantes, e parte delas reaparece aqui.
    @connection.execute(<<~SQL)
      INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
      SELECT #{@grande.id}, v.id,
             CASE WHEN v.id % 7 = 0 THEN 0 ELSE 1 + (v.id % 3) END,
             now(), now()
      FROM (SELECT id FROM card_variants WHERE set_id = #{set_id} ORDER BY id LIMIT #{ITENS_GRANDE}) v
      ON CONFLICT (user_id, card_variant_id) DO NOTHING
    SQL
  end

  # O seed insere usuários por SQL, então o `has_secure_password` não roda e o
  # digest precisa ser produzido à mão — o login do fluxo de pré-visualização é
  # real e passa pelo `authenticate_by`. Gerado uma vez e reusado: 50 hashes de
  # BCrypt custariam mais que o resto do seed inteiro.
  def digest_da_senha
    @digest_da_senha ||= BCrypt::Password.create(PASSWORD, cost: BCrypt::Engine::MIN_COST)
  end
end
