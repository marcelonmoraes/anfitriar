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

ActiveRecord::Schema[8.1].define(version: 2026_08_10_120200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "asaas_webhook_events", force: :cascade do |t|
    t.string "asaas_event_id", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "event_type", null: false
    t.jsonb "payload", null: false
    t.datetime "processed_at"
    t.bigint "subscription_id"
    t.datetime "updated_at", null: false
    t.index ["asaas_event_id"], name: "index_asaas_webhook_events_on_asaas_event_id", unique: true
    t.index ["event_type"], name: "index_asaas_webhook_events_on_event_type"
    t.index ["processed_at"], name: "index_asaas_webhook_events_on_processed_at"
    t.index ["subscription_id"], name: "index_asaas_webhook_events_on_subscription_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.string "access_token", null: false
    t.date "check_in", null: false
    t.date "check_out", null: false
    t.datetime "created_at", null: false
    t.bigint "guest_id", null: false
    t.bigint "property_id", null: false
    t.datetime "revoked_at"
    t.datetime "updated_at", null: false
    t.index ["access_token"], name: "index_bookings_on_access_token", unique: true
    t.index ["guest_id"], name: "index_bookings_on_guest_id"
    t.index ["property_id"], name: "index_bookings_on_property_id"
  end

  create_table "cards", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.boolean "hidden", default: false, null: false
    t.integer "position"
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_cards_on_category_id"
    t.index ["property_id", "category_id"], name: "index_cards_on_property_id_and_category_id", unique: true
    t.index ["property_id"], name: "index_cards_on_property_id"
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "host_id"
    t.string "name", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index ["host_id", "name"], name: "index_categories_on_host_id_and_name_unique", unique: true, where: "(host_id IS NOT NULL)"
    t.index ["host_id"], name: "index_categories_on_host_id"
    t.index ["name"], name: "index_categories_on_name_standard_unique", unique: true, where: "(host_id IS NULL)"
  end

  create_table "credit_cards", force: :cascade do |t|
    t.string "asaas_token", null: false
    t.string "brand", null: false
    t.datetime "created_at", null: false
    t.datetime "default_since"
    t.integer "expiry_month", null: false
    t.integer "expiry_year", null: false
    t.string "holder_name", null: false
    t.bigint "host_id", null: false
    t.string "last_four", null: false
    t.datetime "updated_at", null: false
    t.index ["host_id", "asaas_token"], name: "index_credit_cards_on_host_id_and_asaas_token", unique: true
    t.index ["host_id", "default_since"], name: "index_credit_cards_on_host_id_and_default_since"
    t.index ["host_id"], name: "index_credit_cards_on_host_id"
  end

  create_table "guests", force: :cascade do |t|
    t.string "cpf", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.bigint "host_id", null: false
    t.string "name", null: false
    t.string "phone", null: false
    t.datetime "updated_at", null: false
    t.index ["host_id", "cpf"], name: "index_guests_on_host_id_and_cpf", unique: true
    t.index ["host_id"], name: "index_guests_on_host_id"
  end

  create_table "hosts", force: :cascade do |t|
    t.string "address_number"
    t.string "asaas_customer_id"
    t.string "cpf_cnpj"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "phone", null: false
    t.string "postal_code"
    t.datetime "updated_at", null: false
    t.index ["asaas_customer_id"], name: "index_hosts_on_asaas_customer_id", unique: true
    t.index ["email_address"], name: "index_hosts_on_email_address", unique: true
  end

  create_table "owners", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_owners_on_email_address", unique: true
  end

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

  create_table "properties", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.bigint "host_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["host_id"], name: "index_properties_on_host_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "host_id", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["host_id"], name: "index_sessions_on_host_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "asaas_subscription_id"
    t.string "billing_cycle"
    t.datetime "canceled_at"
    t.string "canceled_by"
    t.datetime "created_at", null: false
    t.bigint "credit_card_id"
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.bigint "host_id", null: false
    t.bigint "plan_id", null: false
    t.string "status", default: "trial", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.index ["asaas_subscription_id"], name: "index_subscriptions_on_asaas_subscription_id_unique", unique: true
    t.index ["credit_card_id"], name: "index_subscriptions_on_credit_card_id"
    t.index ["host_id"], name: "index_subscriptions_on_host_id", unique: true
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "asaas_webhook_events", "subscriptions"
  add_foreign_key "bookings", "guests"
  add_foreign_key "bookings", "properties"
  add_foreign_key "cards", "categories"
  add_foreign_key "cards", "properties"
  add_foreign_key "categories", "hosts"
  add_foreign_key "credit_cards", "hosts"
  add_foreign_key "guests", "hosts"
  add_foreign_key "properties", "hosts"
  add_foreign_key "sessions", "hosts"
  add_foreign_key "subscriptions", "credit_cards"
  add_foreign_key "subscriptions", "hosts"
  add_foreign_key "subscriptions", "plans"
end
