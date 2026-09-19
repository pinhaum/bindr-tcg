# Schema do catálogo conforme design.md §3.2.
#
# Duas escolhas deste arquivo são invariantes de projeto, não preferência:
#
# 1. `cards` e `card_variants` são tabelas distintas. Card é a carta do jogo
#    (`card_number`); CardVariant é a impressão física. A coleção referencia
#    variantes. Colapsar as duas destrói a distinção base/alternate art.
# 2. `rarity` é texto livre, não enum. A fonte é um scraper comunitário
#    (AD-001): um valor novo tem de entrar sem derrubar a ingestão.
class CreateCatalogTables < ActiveRecord::Migration[8.0]
  SET_KINDS = %w[booster starter extra_booster premium_booster promo other].freeze
  CARD_TYPES = %w[leader character event stage].freeze
  ART_KINDS = %w[base alternate_art parallel manga promo other].freeze
  IMPORT_STATUSES = %w[running succeeded failed].freeze

  def change
    create_table :sets do |t|
      t.text :code, null: false
      t.text :name, null: false
      t.text :kind, null: false, default: "other"
      t.date :released_on
      t.integer :base_set_size
      t.integer :total_set_size
      t.timestamps
    end
    add_index :sets, :code, unique: true
    add_check_constraint :sets, "kind IN (#{quoted_list(SET_KINDS)})", name: "sets_kind_check"

    create_table :cards do |t|
      t.references :set, null: false, foreign_key: { on_delete: :restrict }
      t.text :card_number, null: false
      t.text :name, null: false
      t.text :card_type, null: false
      t.text :colors, null: false, array: true, default: []
      t.integer :cost
      t.integer :life
      t.integer :power
      # NULL = a carta não tem counter. Distinto de counter 0 — nunca usar 0
      # como sentinela (design.md §3.3).
      t.integer :counter
      # SPEC_DEVIATION: design.md §3.2 chama esta coluna de `attributes`.
      # Reason: `attributes` é método público do Active Record — uma coluna com
      # esse nome faz o model levantar ActiveRecord::DangerousAttributeError na
      # primeira instanciação (verificado nesta task). O nome interno muda; a
      # semântica (array Postgres de attributes do jogo) não.
      t.text :attributes_list, null: false, array: true, default: []
      t.text :traits, null: false, array: true, default: []
      t.integer :block_icon
      t.text :effect_text
      t.text :trigger_text
      # Req. 1.7: carta ausente da fonte é marcada, nunca deletada.
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :cards, :card_number, unique: true
    add_check_constraint :cards, "card_type IN (#{quoted_list(CARD_TYPES)})", name: "cards_card_type_check"

    create_table :card_variants do |t|
      t.references :card, null: false, foreign_key: { on_delete: :restrict }
      t.references :set, null: false, foreign_key: { on_delete: :restrict }
      t.text :variant_code, null: false
      t.text :rarity
      t.text :art_kind, null: false, default: "base"
      t.text :image_url
      t.text :image_url_large
      t.text :illustrator
      t.datetime :last_seen_at
      t.timestamps
    end
    add_index :card_variants, [ :card_id, :variant_code ], unique: true
    add_check_constraint :card_variants, "art_kind IN (#{quoted_list(ART_KINDS)})",
                         name: "card_variants_art_kind_check"

    create_table :import_runs do |t|
      t.text :source, null: false
      t.text :source_revision, null: false
      t.text :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.jsonb :error_log
      t.timestamps
    end
    add_check_constraint :import_runs, "status IN (#{quoted_list(IMPORT_STATUSES)})",
                         name: "import_runs_status_check"
  end

  private

  def quoted_list(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
