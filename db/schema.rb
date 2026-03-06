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

ActiveRecord::Schema[8.1].define(version: 2026_03_03_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "pokemons", force: :cascade do |t|
    t.integer "attack", null: false
    t.datetime "created_at", null: false
    t.integer "defense", null: false
    t.integer "generation", null: false
    t.integer "hp", null: false
    t.boolean "legendary", default: false, null: false
    t.string "name", null: false
    t.integer "pokedex_number", null: false
    t.integer "sp_atk", null: false
    t.integer "sp_def", null: false
    t.integer "speed", null: false
    t.integer "total", null: false
    t.string "type_1", null: false
    t.string "type_2"
    t.datetime "updated_at", null: false
    t.index ["generation"], name: "index_pokemons_on_generation"
    t.index ["legendary"], name: "index_pokemons_on_legendary"
    t.index ["name"], name: "index_pokemons_on_name"
    t.index ["pokedex_number"], name: "index_pokemons_on_pokedex_number"
  end
end
