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

ActiveRecord::Schema.define(version: 20160426224158) do

  create_table "almacens", force: :cascade do |t|
    t.integer  "espacioUtilizado", limit: 4
    t.integer  "espacioTotal",     limit: 4
    t.boolean  "recepcion"
    t.boolean  "despacho"
    t.boolean  "pulmon"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  create_table "productos", force: :cascade do |t|
    t.integer  "sku",        limit: 4
    t.float    "costos",     limit: 24
    t.integer  "almacen_id", limit: 4
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.string   "name",       limit: 255
  end

  add_index "productos", ["almacen_id"], name: "index_productos_on_almacen_id", using: :btree

  add_foreign_key "productos", "almacens"
end
