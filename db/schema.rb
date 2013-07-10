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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130709104836) do

  create_table "abuse_reports", :force => true do |t|
    t.integer  "user_id",    :default => 0,  :null => false
    t.text     "content",    :default => "", :null => false
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
  end

  create_table "clues", :force => true do |t|
    t.integer  "user_id",    :default => 0,     :null => false
    t.integer  "gab_id",     :default => 0,     :null => false
    t.integer  "number",     :default => 0,     :null => false
    t.string   "field",      :default => "",    :null => false
    t.string   "value",      :default => "",    :null => false
    t.boolean  "revealed",   :default => false, :null => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
  end

  add_index "clues", ["gab_id"], :name => "index_clues_on_gab_id"
  add_index "clues", ["user_id"], :name => "index_clues_on_user_id"

  create_table "devices", :force => true do |t|
    t.integer  "user_id",      :default => 0,  :null => false
    t.string   "device_token", :default => "", :null => false
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
  end

  add_index "devices", ["device_token"], :name => "index_devices_on_device_token", :unique => true
  add_index "devices", ["user_id"], :name => "index_devices_on_user_id"

  create_table "feedbacks", :force => true do |t|
    t.integer  "user_id",    :default => 0,  :null => false
    t.text     "content",    :default => "", :null => false
    t.integer  "rating",     :default => 0,  :null => false
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
  end

  create_table "friendships", :force => true do |t|
    t.integer  "user_id",    :default => 0,  :null => false
    t.integer  "friend_id"
    t.string   "social_id",  :default => "", :null => false
    t.string   "provider",   :default => "", :null => false
    t.string   "name",       :default => "", :null => false
    t.string   "first_name", :default => "", :null => false
    t.string   "last_name",  :default => "", :null => false
    t.datetime "created_at",                 :null => false
    t.datetime "updated_at",                 :null => false
  end

  add_index "friendships", ["user_id"], :name => "index_friendships_on_user_id"

  create_table "gabs", :force => true do |t|
    t.integer  "user_id",           :default => 0,                     :null => false
    t.integer  "related_gab_id",    :default => 0,                     :null => false
    t.string   "related_user_name", :default => "",                    :null => false
    t.string   "related_phone",     :default => "",                    :null => false
    t.string   "related_avatar",    :default => "",                    :null => false
    t.string   "content_cache",     :default => "",                    :null => false
    t.string   "content_summary",   :default => "",                    :null => false
    t.integer  "unread_count",      :default => 0,                     :null => false
    t.integer  "total_count",       :default => 0,                     :null => false
    t.integer  "clue_count",        :default => 0,                     :null => false
    t.boolean  "sent",              :default => false,                 :null => false
    t.datetime "last_date",         :default => '1970-01-01 00:00:00', :null => false
    t.datetime "created_at",                                           :null => false
    t.datetime "updated_at",                                           :null => false
  end

  add_index "gabs", ["user_id"], :name => "index_gabs_on_user_id"

  create_table "images", :force => true do |t|
    t.string "secret", :default => "",    :null => false
    t.binary "data",   :default => "\\x", :null => false
  end

  add_index "images", ["secret"], :name => "index_images_on_secret"

  create_table "messages", :force => true do |t|
    t.integer  "gab_id",     :default => 0,     :null => false
    t.integer  "user_id",    :default => 0,     :null => false
    t.text     "content",    :default => "",    :null => false
    t.integer  "kind",       :default => 0,     :null => false
    t.string   "secret",     :default => "",    :null => false
    t.boolean  "read",       :default => false, :null => false
    t.boolean  "deleted",    :default => false, :null => false
    t.boolean  "sent",       :default => false, :null => false
    t.datetime "created_at",                    :null => false
    t.datetime "updated_at",                    :null => false
    t.string   "key",        :default => "",    :null => false
  end

  add_index "messages", ["gab_id"], :name => "index_messages_on_gab_id"
  add_index "messages", ["user_id"], :name => "index_messages_on_user_id"

  create_table "purchases", :force => true do |t|
    t.integer  "user_id",        :default => 0,  :null => false
    t.string   "transaction_id", :default => "", :null => false
    t.integer  "clues",          :default => 0,  :null => false
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
  end

  add_index "purchases", ["user_id"], :name => "index_purchases_on_user_id"

  create_table "tokens", :force => true do |t|
    t.integer  "user_id",      :default => 0,  :null => false
    t.string   "access_token", :default => "", :null => false
    t.datetime "created_at",                   :null => false
    t.datetime "updated_at",                   :null => false
  end

  add_index "tokens", ["access_token"], :name => "index_tokens_on_access_token", :unique => true
  add_index "tokens", ["user_id"], :name => "index_tokens_on_user_id"

  create_table "users", :force => true do |t|
    t.boolean  "autocreated", :default => false, :null => false
    t.boolean  "registered",  :default => false, :null => false
    t.boolean  "fake",        :default => false, :null => false
    t.boolean  "featured",    :default => false, :null => false
    t.string   "phone",       :default => "",    :null => false
    t.string   "email",       :default => "",    :null => false
    t.string   "gpp_id",      :default => "",    :null => false
    t.string   "fb_id",       :default => "",    :null => false
    t.text     "gpp_data",    :default => "",    :null => false
    t.text     "fb_data",     :default => "",    :null => false
    t.datetime "created_at",                     :null => false
    t.datetime "updated_at",                     :null => false
    t.text     "settings",    :default => "",    :null => false
  end

  add_index "users", ["email"], :name => "index_users_on_email"
  add_index "users", ["fb_id"], :name => "index_users_on_fb_id"
  add_index "users", ["gpp_id"], :name => "index_users_on_gpp_id"
  add_index "users", ["phone"], :name => "index_users_on_phone"

end
