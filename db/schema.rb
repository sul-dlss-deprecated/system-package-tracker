# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160323062302) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "advisories", force: :cascade do |t|
    t.string   "name"
    t.string   "description"
    t.string   "issue_date"
    t.string   "references"
    t.string   "kind"
    t.string   "synopsis"
    t.string   "severity"
    t.string   "os_family"
    t.text     "fix_versions"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "advisories", ["name", "os_family"], name: "index_advisories_on_name_and_os_family", unique: true, using: :btree

  create_table "advisory_to_packages", force: :cascade do |t|
    t.integer  "package_id"
    t.integer  "advisory_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "packages", force: :cascade do |t|
    t.string   "name"
    t.string   "version"
    t.string   "arch"
    t.string   "provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "os_family"
  end

  add_index "packages", ["name", "version", "arch", "provider", "os_family"], name: "unique_pkg", unique: true, using: :btree
  add_index "packages", ["name"], name: "index_packages_on_name", using: :btree

  create_table "server_to_packages", force: :cascade do |t|
    t.integer  "server_id"
    t.integer  "package_id"
    t.string   "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "servers", force: :cascade do |t|
    t.string   "hostname"
    t.string   "os_family"
    t.string   "os_release"
    t.datetime "last_checkin"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "servers", ["hostname"], name: "index_servers_on_hostname", unique: true, using: :btree

end
