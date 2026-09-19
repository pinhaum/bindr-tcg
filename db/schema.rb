# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_09_19_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "card_variants", force: :cascade do |t|
    t.bigint "card_id", null: false
    t.bigint "set_id", null: false
    t.text "variant_code", null: false
    t.text "rarity"
    t.text "art_kind", default: "base", null: false
    t.text "image_url"
    t.text "image_url_large"
    t.text "illustrator"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "variant_code"], name: "index_card_variants_on_card_id_and_variant_code", unique: true
    t.index ["card_id"], name: "index_card_variants_on_card_id"
    t.index ["set_id"], name: "index_card_variants_on_set_id"
    t.check_constraint "art_kind = ANY (ARRAY['base'::text, 'alternate_art'::text, 'parallel'::text, 'manga'::text, 'promo'::text, 'other'::text])", name: "card_variants_art_kind_check"
  end

  create_table "cards", force: :cascade do |t|
    t.bigint "set_id", null: false
    t.text "card_number", null: false
    t.text "name", null: false
    t.text "card_type", null: false
    t.text "colors", default: [], null: false, array: true
    t.integer "cost"
    t.integer "life"
    t.integer "power"
    t.integer "counter"
    t.text "attributes_list", default: [], null: false, array: true
    t.text "traits", default: [], null: false, array: true
    t.integer "block_icon"
    t.text "effect_text"
    t.text "trigger_text"
    t.datetime "last_seen_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_number"], name: "index_cards_on_card_number", unique: true
    t.index ["set_id"], name: "index_cards_on_set_id"
    t.check_constraint "card_type = ANY (ARRAY['leader'::text, 'character'::text, 'event'::text, 'stage'::text])", name: "cards_card_type_check"
  end

  create_table "import_runs", force: :cascade do |t|
    t.text "source", null: false
    t.text "source_revision", null: false
    t.text "status", default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "created_count", default: 0, null: false
    t.integer "updated_count", default: 0, null: false
    t.integer "failed_count", default: 0, null: false
    t.jsonb "error_log"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "status = ANY (ARRAY['running'::text, 'succeeded'::text, 'failed'::text])", name: "import_runs_status_check"
  end

  create_table "sets", force: :cascade do |t|
    t.text "code", null: false
    t.text "name", null: false
    t.text "kind", default: "other", null: false
    t.date "released_on"
    t.integer "base_set_size"
    t.integer "total_set_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_sets_on_code", unique: true
    t.check_constraint "kind = ANY (ARRAY['booster'::text, 'starter'::text, 'extra_booster'::text, 'premium_booster'::text, 'promo'::text, 'other'::text])", name: "sets_kind_check"
  end

  add_foreign_key "card_variants", "cards", on_delete: :restrict
  add_foreign_key "card_variants", "sets", on_delete: :restrict
  add_foreign_key "cards", "sets", on_delete: :restrict
end
