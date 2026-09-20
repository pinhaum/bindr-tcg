require "test_helper"

# T10 — o filtro de posse do Req. 7.6 / COL-11 sob plano de execução
# (Req. 11.3). O teste é sobre o **plano**, não sobre o resultado: a T9 já
# provou que o conjunto devolvido está certo, e uma consulta correta que varre
# `collection_items` inteira passaria em todos aqueles testes.
#
# ## O volume e a distribuição não são decoração
#
# Esta é a armadilha herdada da T4 do `catalogo`, e ela inverte o teste em
# silêncio: com dez itens de coleção o planejador escolhe Seq Scan **com
# razão** — varrer dez linhas é mais barato que abrir um índice —, e a asserção
# passaria a não distinguir "índice ausente" de "índice ignorado por custo".
# O seed abaixo existe para que o índice seja a escolha **racional** do
# planejador, e é o que dá sentido ao `refute_match`:
#
# - 20.000 cartas com 20.000 variantes, o tamanho do catálogo real (2815) com
#   folga, para que `cards` e `card_variants` não caibam num punhado de páginas;
# - **50 usuários** com coleção, e não um só: com um único usuário o predicado
#   `user_id = $1` casa 100% da tabela e o índice por usuário seria inútil por
#   seletividade, não por ausência. O alvo possui ~2% dos itens — a seletividade
#   que faz o índice valer a pena;
# - ~14% dos itens do alvo com `quantity = 0`, para que `quantity >= 1` tenha
#   de fato linhas a descartar e a medição do custo dessa checagem seja real;
# - `ANALYZE` nas três tabelas ao fim: sem ele o planejador decide com
#   estatísticas default e o plano não reflete o que foi semeado.
#
# ## Por que não há migração nesta task
#
# A T9 deixou registrado um índice candidato — parcial,
# `collection_items (user_id, card_variant_id) WHERE quantity >= 1` — sugerido
# pelo `ecc:database-reviewer` sob a hipótese de que o
# `UNIQUE (user_id, card_variant_id)` localiza o usuário mas não filtra
# `quantity`, empurrando a checagem para a heap. O mesmo revisor pediu medição
# antes de criar. A medição foi feita nesta task, com o seed abaixo, e
# **reprovou o candidato**: criado o índice parcial, o planejador continuou
# escolhendo `index_collection_items_on_user_id` com `Filter: (quantity >= 1)`,
# ao custo idêntico de 19.29. Com um usuário pesado (15.000 itens, 12.857
# possuídos) o índice parcial também foi ignorado — custo total 2397.84 com ele
# contra 2404.20 sem ele, 0,27% de diferença, dentro do ruído e sem troca de
# plano. Um índice que o planejador não escolhe é custo de escrita em toda
# operação de posse sem nenhum ganho de leitura, então ele **não foi criado**.
#
# **O que reabriria essa decisão**, nomeado aqui para que a próxima medição não
# precise redescobrir o limite desta: o custo do `Filter: (quantity >= 1)`
# escala com **linhas por usuário**, não com o tamanho da tabela — então
# `collection_items` crescer para milhões de linhas distribuídas entre muitos
# usuários **não** muda nada do que foi medido. O que mudaria é o caso
# assimétrico: um único usuário com dezenas de milhares de itens **e** uma
# fração de `quantity = 0` muito acima dos ~14% deste seed (um fluxo de "zerar
# tudo e recomeçar", ou import em massa), quando o filtro passaria a descartar
# a maioria das linhas sondadas. Nada no Req. 7 sugere esse padrão hoje.

# Limite de fidelidade declarado: o seed distribui a posse **uniformemente**
# entre as variantes, enquanto em produção cartas populares concentram posse
# muito acima da média. Isso afeta a seletividade de
# `index_collection_items_on_card_variant_id` e, portanto, o ponto exato em que
# o planejador inverte o join. O teste cobre os **dois lados** da inversão
# (`Red` e `Yellow`), que é o que importa para a asserção; a distribuição
# enviesada mudaria onde fica a fronteira, não o fato de os dois caminhos serem
# indexados. Escopo não coberto, de propósito, e não descuido.
#
# O que a medição mostrou é que o acesso a `collection_items` **já** é
# indexado, e por três caminhos: `index_collection_items_on_user_id` quando o
# recorte de cartas é largo, `index_collection_items_on_card_variant_id` quando
# ele é estreito e o planejador inverte o join, e o
# `UNIQUE (user_id, card_variant_id)` quando nenhum dos dois existe. O
# `quantity >= 1` fica como filtro de heap nos três, e é barato porque o
# recorte por usuário já reduziu o conjunto a centenas de linhas.
#
# ## Contra o que este teste protege de fato — e contra o que não protege
#
# Medido pelo sensor de discriminação desta task: **derrubar os dois índices
# não-únicos de `collection_items` não derruba as asserções de plano**, porque
# o índice do `UNIQUE (user_id, card_variant_id)` assume o lugar deles e o
# acesso continua indexado. Isso não é fragilidade do teste, é uma propriedade
# do schema: aquele índice é inseparável da garantia de unicidade que a
# migração `20260919120200` criou, então `collection_items` tem um piso de
# acesso indexado por `user_id` que nenhuma migração remove sem antes remover a
# própria unicidade. **A asserção de existência de índice é feita em teste
# separado, explicitamente, porque o plano sozinho não a cobriria.**
#
# O que as asserções de plano pegam é a outra metade, e é a que de fato
# acontece em revisão: **reescrever a consulta numa forma não indexável**.
# Verificado por mutação — envolver `user_id` numa expressão (`user_id + 0`,
# o análogo do `upper(card_number)` que a T11 do `catalogo` já tinha achado)
# produz `Seq Scan on collection_items` a custo 6846 contra 19.29, e **dois
# destes testes falham**. O resultado da consulta continua idêntico; só a
# latência muda — exatamente a classe de defeito que nenhum teste funcional
# pega e que este existe para pegar.
class CatalogOwnedPlanTest < ActiveSupport::TestCase
  CARD_COUNT = 20_000
  USER_COUNT = 50
  ITEMS_PER_USER = 400

  setup do
    @connection = ActiveRecord::Base.connection
    seed_catalog_and_collections
  end

  # --- Done when 1: sem Seq Scan na tabela de coleção ---

  test "filtro owned não varre a tabela de coleção" do
    assert_collection_access_indexed(plan_for_mode("owned"), filtro: "filtro owned")
  end

  test "filtro missing não varre a tabela de coleção" do
    assert_collection_access_indexed(plan_for_mode("missing"), filtro: "filtro missing")
  end

  # O "Done when" fala do filtro **combinado com busca**, que é a consulta que
  # o usuário de fato dispara: `?q=...&owned=owned`. Ela é outro caminho de
  # código (`searchable_scope` aplica `apply_search` por cima de
  # `filtered_scope`), então medir só o filtro isolado deixaria esse caminho
  # sem cobertura de plano.
  test "filtro de posse combinado com busca não varre a tabela de coleção" do
    plano = plan_for(
      CatalogQuery.new({ owned: "owned", q: "Carta 4242", colors: [ "Red" ] }, @user)
                  .searchable_scope.to_sql
    )

    assert_collection_access_indexed(plano, filtro: "posse combinada com busca")
  end

  test "filtro de posse combinado com filtro de cor não varre a tabela de coleção" do
    plano = plan_for(
      CatalogQuery.new({ owned: "owned", colors: [ "Yellow" ] }, @user).filtered_scope.to_sql
    )

    assert_collection_access_indexed(plano, filtro: "posse combinada com cor")
  end

  # --- Done when 2: a seletividade semeada é realista ---
  #
  # Este teste guarda o próprio seed. Se um dia alguém reduzir o volume ou
  # deixar um usuário só, as asserções de plano acima continuariam verdes sem
  # provar nada — e ninguém notaria, porque elas não falham por falta de
  # seletividade, elas apenas param de significar o que dizem. Aqui a premissa
  # vira asserção.
  test "o cenário semeado tem seletividade que justifica índice" do
    total = CollectionItem.count
    do_alvo = CollectionItem.where(user: @user).count
    fracao = do_alvo.to_f / total

    assert_operator total, :>=, 10_000,
                    "volume pequeno demais: o planejador escolheria Seq Scan com razão"
    assert_operator fracao, :<, 0.10,
                    "o usuário alvo detém #{(fracao * 100).round(1)}% dos itens; " \
                    "sem seletividade o índice por usuário seria inútil por custo, não por ausência"
    assert_operator CollectionItem.where(user: @user, quantity: 0).count, :>, 0,
                    "sem item zerado, `quantity >= 1` não teria linha a descartar e a medição seria vazia"
  end

  # --- Done when 3: registro da decisão de não criar índice ---
  #
  # A ausência de migração nesta task é uma **decisão medida**, não um
  # esquecimento, e por isso tem asserção: o índice que sustenta o filtro é o
  # `index_collection_items_on_user_id`, e ele precisa continuar existindo.
  # Sem este teste, derrubá-lo só apareceria como lentidão em produção.
  test "os índices que sustentam o filtro de posse existem" do
    definicoes = @connection.select_rows(<<~SQL).to_h
      SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'collection_items'
    SQL

    assert definicoes["index_collection_items_on_user_id"],
           "faltou o índice por usuário, que sustenta o filtro com recorte pouco seletivo de cartas"
    assert definicoes["index_collection_items_on_card_variant_id"],
           "faltou o índice por variante, que sustenta o filtro quando o planejador inverte o join"
  end

  private

  def plan_for_mode(mode)
    plan_for(CatalogQuery.new({ owned: mode, colors: [ "Red" ] }, @user).filtered_scope.to_sql)
  end

  def plan_for(sql)
    @connection.uncached { @connection.select_values("EXPLAIN #{sql}") }.join("\n")
  end

  # A asserção é dupla de propósito. `refute_match` sozinho passaria se a
  # consulta parasse de tocar `collection_items` — um filtro quebrado que não
  # consulta nada também não varre nada. O `assert_match` exige que o acesso
  # exista **e** seja indexado.
  #
  # **Qual índice é escolha do planejador, e travar um nome específico seria
  # errado.** Medido nesta task: quando o filtro de cartas é pouco seletivo
  # (`Red`, 19.960 de 20.000), o planejador entra por
  # `index_collection_items_on_user_id` e resolve o resto em hash join; quando
  # é muito seletivo (`Yellow`, 40 cartas), ele **inverte** o join, dirige por
  # `cards` e sonda `collection_items` por
  # `index_collection_items_on_card_variant_id`, com `user_id` e `quantity`
  # como filtro de heap sobre uma única linha. As duas formas são acesso
  # indexado e as duas estão certas — a segunda inclusive é mais barata
  # (custo 1339 contra 2398). Exigir um nome fixo reprovaria o plano **melhor**
  # e empurraria para um índice que só serviria para satisfazer a asserção.
  # O requisito é "sem full table scan", e é isso que se asserta.
  COLLECTION_INDEXES = /
    (?:Index|Bitmap\ Index)\ Scan[^\n]*
    index_collection_items_on_(?:user_id|card_variant_id|user_id_and_card_variant_id)
  /x

  def assert_collection_access_indexed(plano, filtro:)
    refute_match(/Seq Scan on collection_items/, plano,
                 "#{filtro} varreu `collection_items` inteira. Plano:\n#{plano}")
    assert_match(COLLECTION_INDEXES, plano,
                 "#{filtro} não acessou `collection_items` por índice nenhum. Plano:\n#{plano}")
  end

  def seed_catalog_and_collections
    set_id = @connection.select_value(<<~SQL)
      INSERT INTO sets (code, name, kind, created_at, updated_at)
      VALUES ('OPt10', 'Plano de posse', 'booster', now(), now())
      RETURNING id
    SQL

    # Cor rara em 1 de 500, como no catálogo real: é o filtro seletivo que o
    # usuário de fato combina com a posse.
    @connection.execute(<<~SQL)
      INSERT INTO cards (set_id, card_number, name, card_type, colors, cost, power, created_at, updated_at)
      SELECT #{set_id}, 'PLN-' || lpad(i::text, 6, '0'), 'Carta ' || i, 'character',
             CASE WHEN i % 500 = 0 THEN ARRAY['Yellow'] ELSE ARRAY['Red'] END,
             CASE WHEN i % 400 = 0 THEN 10 ELSE 3 END,
             1000 * (1 + (i % 3)), now(), now()
      FROM generate_series(1, #{CARD_COUNT}) AS i
    SQL

    @connection.execute(<<~SQL)
      INSERT INTO card_variants (card_id, set_id, variant_code, art_kind, rarity, created_at, updated_at)
      SELECT id, #{set_id}, card_number || '_base', 'base', 'C', now(), now()
      FROM cards WHERE set_id = #{set_id}
    SQL

    seed_users_and_items(set_id)
  end

  def seed_users_and_items(set_id)
    @connection.execute(<<~SQL)
      INSERT INTO users (email, password_digest, created_at, updated_at)
      SELECT 'plano-t10-' || i || '@example.com', 'x', now(), now()
      FROM generate_series(1, #{USER_COUNT}) AS i
    SQL

    # Cada usuário possui uma fatia distinta do catálogo. O deslocamento por
    # `u.id` evita que os 50 possuam exatamente as mesmas variantes, o que
    # tornaria `card_variant_id` degenerado e falsearia o custo do join.
    # `quantity = 0` em 1 de 7 mantém o descarte de `quantity >= 1` real.
    @connection.execute(<<~SQL)
      INSERT INTO collection_items (user_id, card_variant_id, quantity, created_at, updated_at)
      SELECT u.id, v.id,
             CASE WHEN v.id % 7 = 0 THEN 0 ELSE 1 + (v.id % 3) END,
             now(), now()
      FROM (SELECT id FROM users WHERE email LIKE 'plano-t10-%@example.com') u
      JOIN LATERAL (
        SELECT id FROM card_variants WHERE set_id = #{set_id}
        ORDER BY (id * (u.id % 97 + 1)) % 20011
        LIMIT #{ITEMS_PER_USER}
      ) v ON true
    SQL

    @user = User.where("email LIKE 'plano-t10-%@example.com'").order(:id).first

    # Sem `ANALYZE` o planejador opera com estatísticas default e o plano não
    # reflete os dados recém-inseridos — o teste mediria outra coisa.
    %w[cards card_variants collection_items users].each { @connection.execute("ANALYZE #{_1}") }
  end
end
