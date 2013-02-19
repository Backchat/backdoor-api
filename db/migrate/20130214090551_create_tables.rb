class CreateTables < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.boolean   :autocreated,   :default => false
      t.boolean   :registered,    :default => false

      t.string    :phone
      t.string    :email
      t.string    :uid
      t.text      :data

      t.timestamps
    end

    create_table :gabs do |t|
      t.integer   :receiver_id
      t.integer   :user_id
      t.string    :title
      t.timestamps
    end

    create_table :messages do |t|
      t.integer   :gab_id
      t.integer   :user_id
      t.text      :content
      t.boolean   :read,          :default => false
      t.timestamps
    end

    create_table :clues do |t|
      t.integer   :user_id
      t.integer   :gab_id
      t.string    :field
      t.string    :value
      t.timestamps
    end

    create_table :sessions do |t|
      t.integer   :user_id
      t.string    :token
      t.timestamps
    end

    create_table :devices do |t|
      t.integer   :user_id
      t.string    :token
      t.timestamps
    end

    create_table :purchases do |t|
      t.integer   :user_id
      t.string    :receipt
      t.integer   :clues
      t.timestamps
    end
  end
end
