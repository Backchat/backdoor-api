class CreateTables < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.boolean   :autocreated,       :null => false, :default => false
      t.boolean   :registered,        :null => false, :default => false
      t.boolean   :fake,              :null => false, :default => false
      t.boolean   :featured,          :null => false, :default => false

      t.string    :phone,             :null => false, :default => ''
      t.string    :email,             :null => false, :default => ''
      t.string    :gpp_id,            :null => false, :default => ''
      t.string    :fb_id,             :null => false, :default => ''
      t.text      :gpp_data,          :null => false, :default => ''
      t.text      :fb_data,           :null => false, :default => ''
      t.text      :settings,          :null => false, :default => ''

      t.timestamps
    end

    add_index :users, :phone
    add_index :users, :email
    add_index :users, :gpp_id
    add_index :users, :fb_id

    create_table :gabs do |t|
      t.integer   :user_id,           :null => false, :default => 0

      t.integer   :related_gab_id,    :null => false, :default => 0
      t.string    :related_user_name, :null => false, :default => ''
      t.string    :related_phone,     :null => false, :default => ''
      t.string    :related_avatar,    :null => false, :default => ''

      t.string    :content_cache,     :null => false, :default => ''
      t.string    :content_summary,   :null => false, :default => ''
      t.integer   :unread_count,      :null => false, :default => 0
      t.integer   :total_count,       :null => false, :default => 0
      t.integer   :clue_count,        :null => false, :default => 0
      t.boolean   :sent,              :null => false, :default => false
      t.datetime  :last_date,         :null => false, :default => Time.new(1970,1,1)

      t.timestamps
    end

    add_index :gabs, :user_id

    create_table :messages do |t|
      t.integer   :gab_id,            :null => false, :default => 0
      t.integer   :user_id,           :null => false, :default => 0
      t.text      :content,           :null => false, :default => ''
      t.integer   :kind,              :null => false, :default => 0
      t.string    :secret,            :null => false, :default => ''
      t.boolean   :read,              :null => false, :default => false
      t.boolean   :deleted,           :null => false, :default => false
      t.boolean   :sent,              :null => false, :default => false
      t.timestamps
    end

    add_index :messages, :gab_id
    add_index :messages, :user_id

    create_table :clues do |t|
      t.integer   :user_id,           :null => false, :default => 0
      t.integer   :gab_id,            :null => false, :default => 0
      t.integer   :number,            :null => false, :default => 0
      t.string    :field,             :null => false, :default => ''
      t.string    :value,             :null => false, :default => ''
      t.boolean   :revealed,          :null => false, :default => false
      t.timestamps
    end

    add_index :clues, :gab_id
    add_index :clues, :user_id

    create_table :tokens do |t|
      t.integer   :user_id,           :null => false, :default => 0
      t.string    :access_token,      :null => false, :default => ''
      t.timestamps
    end

    add_index :tokens, :user_id
    add_index :tokens, :access_token, :unique => true

    create_table :devices do |t|
      t.integer   :user_id,           :null => false, :default => 0
      t.string    :device_token,      :null => false, :default => ''
      t.timestamps
    end

    add_index :devices, :user_id
    add_index :devices, :device_token, :unique => true

    create_table :purchases do |t|
      t.integer   :user_id,           :null => false, :default => 0
      t.string    :transaction_id,    :null => false, :default => ''
      t.integer   :clues,             :null => false, :default => 0
      t.timestamps
    end

    add_index :purchases, :user_id

    create_table :feedbacks do |t|
      t.integer :user_id,             :null => false, :default => 0
      t.text    :content,             :null => false, :default => ''
      t.integer :rating,              :null => false, :default => 0
      t.timestamps
    end

    create_table :abuse_reports do |t|
      t.integer :user_id,             :null => false, :default => 0
      t.text    :content,             :null => false, :default => ''
      t.timestamps
    end

    create_table :images do |t|
      t.string  :secret,              :null => false, :default => ''
      t.binary  :data,                :null => false, :default => ''
    end

    add_index :images, :secret
  end
end
