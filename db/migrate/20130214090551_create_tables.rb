class CreateTables < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.boolean   :autocreated,   :default => false
      t.boolean   :registered,    :default => false
      t.boolean   :fake,          :default => false

      t.string    :phone
      t.string    :email
      t.string    :uid
      t.text      :data

      t.timestamps
    end

    add_index :users, :phone
    add_index :users, :email
    add_index :users, :uid

    create_table :gabs do |t|
      t.integer   :user_id

      t.integer   :related_gab_id
      t.string    :related_user_name

      t.string    :content_cache,   :default => ''
      t.string    :content_summary, :default => ''
      t.integer   :unread_count,    :default => 0
      t.integer   :total_count,     :default => 0
      t.boolean   :sent,            :default => false
      t.datetime  :last_date

      t.timestamps
    end

    add_index :gabs, :user_id

    create_table :messages do |t|
      t.integer   :gab_id
      t.integer   :user_id
      t.text      :content
      t.boolean   :read,          :default => false
      t.boolean   :deleted,       :default => false
      t.boolean   :sent,          :default => false
      t.timestamps
    end

    add_index :messages, :gab_id
    add_index :messages, :user_id

    create_table :clues do |t|
      t.integer   :user_id
      t.integer   :gab_id
      t.string    :field
      t.string    :value
      t.timestamps
    end

    add_index :clues, :gab_id
    add_index :clues, :user_id

    create_table :tokens do |t|
      t.integer   :user_id
      t.string    :access_token
      t.timestamps
    end

    add_index :tokens, :user_id
    add_index :tokens, :access_token, :unique => true

    create_table :devices do |t|
      t.integer   :user_id
      t.string    :device_token
      t.timestamps
    end

    add_index :devices, :user_id
    add_index :devices, :device_token, :unique => true

    create_table :purchases do |t|
      t.integer   :user_id
      t.string    :receipt
      t.integer   :clues
      t.timestamps
    end

    add_index :purchases, :user_id
    add_index :purchases, :receipt, :unique => true

    create_table :feedbacks do |t|
      t.integer :user_id
      t.text    :content
      t.integer :rating
      t.timestamps
    end
  end
end
