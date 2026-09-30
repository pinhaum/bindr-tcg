require "test_helper"

# T2 (fonte-apitcg) — Req. 11.3 sob a presença na fonte (SRC-16). A presença
# acrescenta a toda consulta do catálogo uma subconsulta sobre
# `card_variants.last_seen_at` e `import_runs`; o teste é sobre o **plano**,
# para garantir que os filtros seletivos continuam indexados com ela.
#
# O seed reproduz a troca de fonte: 20.000 cartas, cada uma com uma variante
# ausente (run antigo) e uma presente (run novo), espalhadas por 100 sets,
# cor rara em 1 de 500 e raridade rara em 1 de 450. Com menos sets, o
# planejador estima o filtro de set como pouco seletivo e varre `cards` com
# razão; com 100, a estimativa é a do catálogo real (~85 sets com carta).
#
# Medido nesta task: `import_runs` e `sets` saem por Seq Scan, e isso é a
# escolha certa do planejador (uma dezena de runs, uma centena de sets). Por
# isso não houve migração de índice em `import_runs(status, started_at)` nem em
# `card_variants(last_seen_at)`: o acesso às tabelas grandes já é indexado, e
# um índice que o planejador não escolhe só custa escrita.
class CatalogPresencePlanTest < ActiveSupport::TestCase
  CARD_COUNT = 20_000
  SET_COUNT = 100

  setup do
    @connection = ActiveRecord::Base.connection
    seed
  end

  test "filtro por cor com presença não varre cards nem card_variants" do
    assert_indexed(plan_for(colors: [ "Yellow" ]), filtro: "cor")
  end

  test "filtro por set com presença não varre cards nem card_variants" do
    assert_indexed(plan_for(sets: [ "PS7" ]), filtro: "set")
  end

  test "filtro por raridade com presença não varre cards nem card_variants" do
    assert_indexed(plan_for(rarities: [ "SEC" ]), filtro: "raridade")
  end

  test "filtros combinados com presença não varrem cards nem card_variants" do
    assert_indexed(plan_for(sets: [ "PS7" ], colors: [ "Yellow" ]), filtro: "set e cor")
  end

  private

  def plan_for(params)
    sql = CatalogQuery.new(params).filtered_scope.to_sql
    @connection.uncached { @connection.select_values("EXPLAIN #{sql}") }.join("\n")
  end

  # `assert_match` do predicado de presença impede o teste de passar se a
  # consulta deixar de filtrar pela presença: sem ela, não haveria o que medir.
  def assert_indexed(plano, filtro:)
    assert_match(/last_seen_at >=/, plano, "#{filtro}: a presença sumiu da consulta. Plano:\n#{plano}")
    refute_match(/Seq Scan on cards/, plano, "#{filtro} varreu `cards`. Plano:\n#{plano}")
    refute_match(/Seq Scan on card_variants/, plano, "#{filtro} varreu `card_variants`. Plano:\n#{plano}")
  end

  def seed
    @connection.execute(<<~SQL)
      INSERT INTO import_runs (source, source_revision, status, started_at, created_at, updated_at)
      VALUES ('optcgjson', 'antiga', 'succeeded', '2026-09-01', now(), now()),
             ('apitcg', 'nova', 'succeeded', '2026-09-29', now(), now()),
             ('apitcg', 'falha', 'failed', '2026-09-30', now(), now())
    SQL
    @connection.execute(<<~SQL)
      INSERT INTO sets (code, name, kind, created_at, updated_at)
      SELECT 'PS' || i, 'Set ' || i, 'booster', now(), now() FROM generate_series(0, #{SET_COUNT - 1}) AS i
    SQL
    first_set = @connection.select_value("SELECT min(id) FROM sets WHERE code LIKE 'PS%'")

    @connection.execute(<<~SQL)
      INSERT INTO cards (set_id, card_number, name, card_type, colors, cost, power, created_at, updated_at)
      SELECT #{first_set}, 'PRS-' || lpad(i::text, 6, '0'), 'Carta ' || i, 'character',
             CASE WHEN i % 500 = 0 THEN ARRAY['Yellow'] ELSE ARRAY['Red'] END, 3, 1000, now(), now()
      FROM generate_series(1, #{CARD_COUNT}) AS i
    SQL
    @connection.execute(<<~SQL)
      INSERT INTO card_variants (card_id, set_id, variant_code, art_kind, rarity, last_seen_at, created_at, updated_at)
      SELECT id, #{first_set} + (id % #{SET_COUNT}), card_number, 'base', 'C', '2026-09-01', now(), now()
      FROM cards WHERE card_number LIKE 'PRS-%'
    SQL
    @connection.execute(<<~SQL)
      INSERT INTO card_variants (card_id, set_id, variant_code, art_kind, rarity, last_seen_at, created_at, updated_at)
      SELECT id, #{first_set} + (id % #{SET_COUNT}), 'tcgplayer:' || id, 'base',
             CASE WHEN id % 450 = 0 THEN 'SEC' ELSE 'C' END, '2026-09-29', now(), now()
      FROM cards WHERE card_number LIKE 'PRS-%'
    SQL

    %w[import_runs sets cards card_variants].each { @connection.execute("ANALYZE #{_1}") }
  end
end
