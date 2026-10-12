require "test_helper"

# T8 — plano da agregação de progresso (PRG-11, Req. 11.1).
#
# Este arquivo mede só o **plano** (`EXPLAIN`) e os índices do acesso à coleção.
# A contagem de consultas por requisição ("cinco sets a mais não podem custar
# consulta a mais") vive em `test/integration/api/progress_plan_test.rb`, sobre
# `GET /api/progress`; a T1 já trava a forma da agregação isolada.
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

  setup do
    @user = User.create!(email: "plano-t8@example.com", password: PASSWORD)
    @connection = ActiveRecord::Base.connection
    mark_catalog_present!
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
  # **A asserção é sobre `pg_stats`, e não sobre `pg_class.reltuples` nem sobre
  # `pg_stat_user_tables.last_analyze`.** As três formas foram escritas e medidas
  # nesta ordem, e as duas primeiras foram reprovadas por razões diferentes:
  #
  # 1. **`reltuples` é verde por resíduo.** Não é transacional e sobrevive ao
  #    rollback do teste, então uma execução anterior deste mesmo arquivo deixa a
  #    estimativa povoada e a asserção passa **sem o `ANALYZE`**. Medido: sem
  #    `ANALYZE`, `reltuples` continua em 300 de uma rodada anterior enquanto o
  #    `ANALYZE` de fato não rodou. Foi o defeito que a T8 corrigiu, e **não se
  #    volta para cá**.
  # 2. **`last_analyze` é intermitente.** Corrige o resíduo (é um instante, e
  #    comparar com o início do teste prova a execução desta rodada), mas trocou
  #    aquele modo de falha por um de concorrência: a verificação independente
  #    mediu 2 falhas em 12 execuções completas (~17%). `pg_stat_user_tables` é
  #    servido de um snapshot que o Postgres congela **por objeto, na primeira
  #    leitura de cada transação** (`stats_fetch_consistency = cache`, o default
  #    desde a 15; aqui roda 17.11), e o teste inteiro vive dentro da transação do
  #    `use_transactional_tests`. `pg_stat_clear_snapshot()` derruba esse cache e
  #    reduz muito a intermitência, mas **não a elimina**: medido, o teste ainda
  #    falhou 1 vez em 2 execuções completas com o descarte aplicado. O caminho
  #    inteiro passa pelo coletor de estatísticas, que é assíncrono por projeto, e
  #    asserção sobre observável assíncrono é instável por construção.
  #
  # ## `pg_stats` é síncrono, transacional, e prova exatamente a mesma coisa
  #
  # `ANALYZE` grava as estatísticas de coluna em `pg_statistic` (exposto por
  # `pg_stats`) **dentro da transação**, sem passar pelo coletor. Isso dá as duas
  # propriedades que as outras duas formas não tinham ao mesmo tempo:
  #
  # - **Síncrono**: o valor está visível na consulta seguinte, sem coletor no
  #   meio. Não há janela de corrida a tolerar — é o que remove a intermitência
  #   pela raiz, em vez de reduzir sua probabilidade.
  # - **Transacional**: o rollback do teste o desfaz. Medido: 9 linhas em
  #   `pg_stats` depois do `ANALYZE`, **0 após o rollback**, enquanto `reltuples`
  #   sobrevive em 300. Ou seja, resíduo de execução anterior **não** satisfaz
  #   esta asserção, que era a única virtude que `last_analyze` tinha sobre
  #   `reltuples`.
  #
  # A garantia vigiada é a mesma e foi conferida nos dois sentidos: com o
  # `ANALYZE`, `pg_stats` tem linhas; **sem** ele, tem zero e o teste falha — que
  # é exatamente a regressão que esta asserção existe para pegar (sem `ANALYZE` o
  # planejador estima `rows=1` para `sets`, escolhe `Nested Loop` e as asserções
  # de plano seguem verdes medindo outra coisa).
  test "o seed atualiza as estatísticas do planejador nesta execução" do
    semear_volume_realista

    colunas_analisadas = @connection.select_rows(<<~SQL).to_h
      SELECT tablename, count(*) FROM pg_stats
      WHERE tablename IN ('sets', 'card_variants', 'collection_items')
      GROUP BY tablename
    SQL

    %w[sets card_variants collection_items].each do |tabela|
      assert_operator colunas_analisadas.fetch(tabela, 0), :>, 0,
                      "`#{tabela}` não tem estatística de coluna em `pg_stats` nesta transação: ou o " \
                      "`ANALYZE` do seed não rodou, ou ele rodou sobre tabela vazia. Nos dois casos o " \
                      "planejador decide com estatísticas default e o plano medido não é o do cenário " \
                      "semeado. (O volume em si é travado pelo teste do seed, acima.)"
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

  private

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
  # evitáveis. Os números distintos e `parallel_variants` exigem todas as
  # variantes presentes de todos os sets, então não há predicado seletivo a
  # explorar e um índice não teria o que fazer. Exigir sua ausência reprovaria o plano certo e empurraria
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

  # --- Seed ---

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
      INSERT INTO card_variants (card_id, set_id, variant_code, art_kind, rarity, last_seen_at,
                                 created_at, updated_at)
      SELECT c.id, c.set_id, c.card_number || '_v',
             CASE WHEN c.id % 3 = 0 THEN 'parallel' ELSE 'base' END,
             'C', '#{CATALOG_SEEN_AT.to_fs(:db)}', now(), now()
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
