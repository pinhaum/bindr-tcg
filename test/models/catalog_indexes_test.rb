require "test_helper"

# Req. 11.3 — os filtros do Req. 4 devem ter índice que os sustente, "verificável
# por plano de execução". O teste é sobre o plano, não sobre o resultado: uma
# consulta correta que varre a tabela inteira passa em qualquer teste funcional
# e ainda assim viola o requisito.
#
# Por que semear milhares de linhas: com tabela pequena o planejador escolhe
# Seq Scan mesmo com índice disponível, e isso é a decisão certa dele. Um teste
# sobre tabela vazia não distinguiria "índice ausente" de "índice ignorado por
# custo" — passaria a provar nada. O volume aqui é o mínimo para o índice virar
# a escolha mais barata.
class CatalogIndexesTest < ActiveSupport::TestCase
  SEED_SIZE = 20_000

  setup do
    @connection = ActiveRecord::Base.connection
    seed_catalog
  end

  # O volume e a distribuição não são arbitrários. Um índice só é escolhido
  # quando é mais barato que varrer a tabela, e isso depende da seletividade
  # do filtro: um predicado que casa 17% das linhas é legitimamente mais
  # rápido por Seq Scan, e forçar o índice ali provaria o contrário do que o
  # Req. 11.3 pede. A distribuição abaixo é a do catálogo real — cor rara,
  # custo alto raro, trait raro — que é exatamente o caso em que o usuário
  # filtra e em que a varredura completa seria inaceitável.
  def seed_catalog
    set_id = @connection.select_value(<<~SQL)
      INSERT INTO sets (code, name, kind, created_at, updated_at)
      VALUES ('OP99', 'Índices', 'booster', now(), now())
      RETURNING id
    SQL

    @connection.execute(<<~SQL)
      INSERT INTO cards (set_id, card_number, name, card_type, colors, traits, cost, power, counter, effect_text, created_at, updated_at)
      SELECT
        #{set_id},
        'IDX-' || lpad(i::text, 6, '0'),
        'Carta ' || i,
        CASE WHEN i % 500 = 0 THEN 'leader' ELSE 'character' END,
        CASE WHEN i % 500 = 0 THEN ARRAY['Yellow'] ELSE ARRAY['Red'] END,
        CASE WHEN i % 500 = 0 THEN ARRAY['Supernovas'] ELSE ARRAY['Straw Hat Crew'] END,
        CASE WHEN i % 400 = 0 THEN 10 ELSE 3 END,
        1000 * (1 + (i % 3)),
        -- `counter` alto é raro, como no catálogo real: é a faixa seletiva que
        -- o usuário filtra. A faixa baixa casa a maioria das linhas e por isso
        -- é legitimamente Seq Scan — medido no catálogo real.
        CASE WHEN i % 3 = 0 THEN NULL WHEN i % 700 = 0 THEN 2000 ELSE 1000 END,
        CASE WHEN i % 600 = 0 THEN 'Draw one card and rest this Character.'
             ELSE 'Gain plus one thousand power during this turn.' END,
        now(), now()
      FROM generate_series(1, #{SEED_SIZE}) AS i
    SQL

    # Sem ANALYZE o planejador opera com estatísticas default e o plano não
    # reflete os dados recém-inseridos.
    @connection.execute("ANALYZE cards")
  end

  def plan_for(sql)
    @connection.uncached { @connection.select_values("EXPLAIN #{sql}") }.join("\n")
  end

  def assert_no_sequential_scan(sql, filtro:)
    plan = plan_for(sql)
    refute_match(/Seq Scan on cards/, plan,
                 "#{filtro} fez varredura completa de `cards`. Plano:\n#{plan}")
    assert_match(/Index|Bitmap/, plan,
                 "#{filtro} deveria usar índice. Plano:\n#{plan}")
  end

  # Done when: teste prova, via plano de execução, que filtro por cor não faz
  # full table scan. Req. 4.1 e 4.5.
  test "filtro por cor usa índice, sem varredura completa" do
    assert_no_sequential_scan(
      "SELECT id FROM cards WHERE colors && ARRAY['Yellow']::text[]",
      filtro: "filtro por cor"
    )
  end

  # Req. 4.5 — multicolorida entra no filtro de cada cor, e a sobreposição de
  # arrays com várias cores é o caso de OU dentro da categoria (Req. 4.4).
  test "filtro por múltiplas cores usa índice, sem varredura completa" do
    assert_no_sequential_scan(
      "SELECT id FROM cards WHERE colors && ARRAY['Yellow','Blue']::text[]",
      filtro: "filtro por duas cores"
    )
  end

  # Done when: teste prova que filtro por faixa de custo não faz full table
  # scan. Req. 4.2.
  test "filtro por faixa de custo usa índice, sem varredura completa" do
    assert_no_sequential_scan(
      "SELECT id FROM cards WHERE cost >= 9 AND cost <= 10",
      filtro: "filtro por faixa de custo"
    )
  end

  # Done when: `pg_trgm` e `unaccent` habilitadas.
  # Req. 4.2 — `counter` é a terceira coluna de faixa, e a de semântica mais
  # delicada (NULL ≠ 0). O filtro seletivo precisa do índice; a faixa larga,
  # não — no catálogo real `counter BETWEEN 1000 AND 2000` casa 1721 de 2815
  # cartas e o Seq Scan é a escolha certa do planejador. Asserir índice ali
  # provaria o contrário do que o Req. 11.3 pede.
  test "filtro seletivo por counter usa índice, sem varredura completa" do
    assert_no_sequential_scan(
      "SELECT * FROM cards WHERE counter >= 2000",
      filtro: "faixa alta de counter"
    )
  end

  # `counter` NULL é "não tem counter", não counter 0: filtrar por faixa não
  # pode arrastar as cartas sem counter junto.
  test "filtro por faixa de counter não inclui cartas sem counter" do
    sem_counter = @connection.select_value(
      "SELECT count(*) FROM cards WHERE counter >= 0 AND counter IS NULL"
    )

    assert_equal 0, sem_counter
  end

  # Req. 3.1 — busca no texto de efeito. O índice existe desde a T4; sem
  # verificação de plano ninguém saberia se ele é usado de fato.
  test "busca full-text no texto de efeito usa índice" do
    assert_no_sequential_scan(
      "SELECT * FROM cards WHERE to_tsvector('english', coalesce(effect_text, '')) " \
      "@@ plainto_tsquery('english', 'rest character')",
      filtro: "full-text de effect_text"
    )
  end

  test "as extensões pg_trgm e unaccent estão habilitadas" do
    instaladas = @connection.select_values("SELECT extname FROM pg_extension")

    assert_includes instaladas, "pg_trgm"
    assert_includes instaladas, "unaccent"
  end

  # Done when: GIN nas colunas de array; trigram no nome.
  test "existe índice GIN em cada coluna de array de cards" do
    gin_indexes = @connection.select_values(<<~SQL)
      SELECT indexdef FROM pg_indexes
      WHERE tablename = 'cards' AND indexdef ILIKE '%USING gin%'
    SQL

    %w[colors traits attributes_list].each do |coluna|
      assert gin_indexes.any? { |definicao| definicao.include?("(#{coluna})") },
             "faltou índice GIN em cards.#{coluna}. Índices GIN: #{gin_indexes.inspect}"
    end
  end

  test "o índice trigram do nome existe e ignora acento" do
    definicao = @connection.select_value(<<~SQL)
      SELECT indexdef FROM pg_indexes
      WHERE tablename = 'cards' AND indexname = 'index_cards_on_unaccent_name_trgm'
    SQL

    assert definicao, "índice trigram do nome não existe"
    assert_match(/gin_trgm_ops/, definicao)
    assert_equal "Portgas D. Ace",
                 @connection.select_value("SELECT immutable_unaccent('Pórtgas D. Ácé')")
  end

  # Req. 3.2 e 3.3 — o índice de nome só serve se a busca tolerante a typo
  # de fato o usar em vez de varrer a tabela.
  test "busca por nome com similaridade trigram usa índice" do
    assert_no_sequential_scan(
      "SELECT id FROM cards WHERE immutable_unaccent(name) ILIKE '%Carta 4242%'",
      filtro: "busca por nome"
    )
  end
end
