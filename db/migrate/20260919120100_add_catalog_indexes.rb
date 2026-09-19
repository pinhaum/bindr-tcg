# Índices de design.md §3.4 e as extensões que os Req. 3 e 4 exigem.
#
# Sintaxe conferida na documentação do PostgreSQL 17 (a versão em uso), não
# escrita de memória — era um `⚠️ VERIFICAR` de design.md §4.1:
#
# - `CREATE INDEX ... USING GIN (t gin_trgm_ops)` — docs/17/pgtrgm.html.
#   GIN com gin_trgm_ops serve LIKE, ILIKE, ~, ~* e =; ordenação por distância
#   (`<->`) é caso de GiST, não de GIN, e não é usada aqui.
# - `to_tsvector('english', ...)` — docs/17/textsearch-tables.html. Só a forma
#   de dois argumentos é IMMUTABLE e, por isso, a única admitida em coluna
#   gerada ou índice de expressão. Confirmado no catálogo do servidor:
#   to_tsvector(regconfig, text) tem provolatile = 'i'.
# - `unaccent` NÃO é indexável direto. Medido neste servidor (17.11), as duas
#   assinaturas — unaccent(text) e unaccent(regdictionary, text) — são STABLE,
#   não IMMUTABLE, porque dependem do dicionário carregado. Um índice sobre
#   elas falha com "functions in index expression must be marked IMMUTABLE".
#   Daí o wrapper `immutable_unaccent` abaixo: ele fixa o dicionário e só
#   então pode ser declarado IMMUTABLE. Se o dicionário `unaccent` for
#   redefinido, este índice precisa ser reconstruído — é o preço da escolha.
class AddCatalogIndexes < ActiveRecord::Migration[8.0]
  def up
    enable_extension "pg_trgm"
    enable_extension "unaccent"

    # Req. 4.1 e 4.5 — sobreposição de arrays (`&&`) resolve o filtro por cor
    # incluindo multicoloridas.
    add_index :cards, :colors, using: :gin
    add_index :cards, :traits, using: :gin
    add_index :cards, :attributes_list, using: :gin

    # Req. 4.1 e 4.2 — igualdade e faixas.
    add_index :cards, :card_type
    add_index :cards, :cost
    add_index :cards, :power
    add_index :cards, :counter

    # Req. 4.1 e Req. 9 — filtro por set/raridade e progresso por set.
    add_index :card_variants, [ :set_id, :rarity ]

    # Req. 3.2 e 3.3 — nome tolerante a typo e insensível a acento.
    execute <<~SQL
      CREATE FUNCTION immutable_unaccent(text) RETURNS text
      LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT AS
      $$ SELECT public.unaccent('public.unaccent'::regdictionary, $1) $$
    SQL

    execute <<~SQL
      CREATE INDEX index_cards_on_unaccent_name_trgm
      ON cards
      USING GIN (immutable_unaccent(name) gin_trgm_ops)
    SQL

    # Req. 3.1 — texto de efeito por full-text.
    execute <<~SQL
      CREATE INDEX index_cards_on_effect_text_tsvector
      ON cards
      USING GIN (to_tsvector('english', coalesce(effect_text, '')))
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS index_cards_on_effect_text_tsvector"
    execute "DROP INDEX IF EXISTS index_cards_on_unaccent_name_trgm"
    execute "DROP FUNCTION IF EXISTS immutable_unaccent(text)"
    remove_index :card_variants, [ :set_id, :rarity ]
    remove_index :cards, :counter
    remove_index :cards, :power
    remove_index :cards, :cost
    remove_index :cards, :card_type
    remove_index :cards, :attributes_list
    remove_index :cards, :traits
    remove_index :cards, :colors
    disable_extension "unaccent"
    disable_extension "pg_trgm"
  end
end
