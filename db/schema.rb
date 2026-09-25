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

ActiveRecord::Schema[8.1].define(version: 2026_09_25_133506) do
  create_table "allowed_email_domains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_allowed_email_domains_on_domain", unique: true
  end

  create_table "locker_number_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "pattern"
    t.datetime "updated_at", null: false
  end

  create_table "locker_swap_proposals", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.text "decline_comment"
    t.string "recipient_floor_at_resolution"
    t.integer "recipient_id", null: false
    t.string "recipient_locker_number_at_resolution"
    t.datetime "requester_acknowledged_at"
    t.string "requester_floor_at_resolution"
    t.integer "requester_id", null: false
    t.string "requester_locker_number_at_resolution"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["recipient_id"], name: "index_locker_swap_proposals_on_recipient_id"
    t.index ["recipient_id"], name: "index_swap_proposals_accepted_recipient", unique: true, where: "status = 1"
    t.index ["requester_id", "recipient_id"], name: "index_swap_proposals_pending_pair", unique: true, where: "status = 0"
    t.index ["requester_id"], name: "index_locker_swap_proposals_on_requester_id"
    t.index ["requester_id"], name: "index_swap_proposals_accepted_requester", unique: true, where: "status = 1"
  end

  create_table "locker_wishes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "floor", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_locker_wishes_on_user_id", unique: true
  end

  create_table "site_floor_lists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "floors"
    t.datetime "updated_at", null: false
  end

  create_table "site_language_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "language", default: "en", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "admin_granted_at"
    t.integer "admin_granted_by_id"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false, collation: "NOCASE"
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "floor"
    t.datetime "locked_at"
    t.datetime "locker_edited_at"
    t.integer "locker_edited_by_id"
    t.string "locker_number"
    t.datetime "remember_created_at"
    t.datetime "search_cancelled_at"
    t.integer "search_cancelled_by_id"
    t.datetime "updated_at", null: false
    t.index ["admin"], name: "index_users_on_bootstrap_admin", unique: true, where: "admin = 1 AND admin_granted_at IS NULL"
    t.index ["admin_granted_by_id"], name: "index_users_on_admin_granted_by_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["floor", "locker_number"], name: "index_users_on_floor_and_locker_number", unique: true
    t.index ["locker_edited_by_id"], name: "index_users_on_locker_edited_by_id"
    t.index ["search_cancelled_by_id"], name: "index_users_on_search_cancelled_by_id"
  end

  add_foreign_key "locker_swap_proposals", "users", column: "recipient_id"
  add_foreign_key "locker_swap_proposals", "users", column: "requester_id"
  add_foreign_key "locker_wishes", "users"
  add_foreign_key "users", "users", column: "admin_granted_by_id"
  add_foreign_key "users", "users", column: "locker_edited_by_id"
  add_foreign_key "users", "users", column: "search_cancelled_by_id"
end
