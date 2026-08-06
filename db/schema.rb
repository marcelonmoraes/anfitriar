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

ActiveRecord::Schema[8.1].define(version: 2026_08_06_145313) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "plans", force: :cascade do |t|
    t.integer "annual_price_cents", null: false
    t.datetime "created_at", null: false
    t.integer "max_properties"
    t.integer "monthly_price_cents", null: false
    t.string "name", null: false
    t.integer "quarterly_price_cents", null: false
    t.integer "semiannual_price_cents", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_plans_on_name", unique: true
    t.index ["slug"], name: "index_plans_on_slug", unique: true
  end

  create_table "platform_configurations", force: :cascade do |t|
    t.integer "booking_access_margin_days", default: 2, null: false
    t.datetime "created_at", null: false
    t.integer "trial_days", default: 7, null: false
    t.datetime "updated_at", null: false
  end
end
