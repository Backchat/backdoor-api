class AddIndexes < ActiveRecord::Migration
  def change
    add_index :users,     :phone
    add_index :users,     :email
    add_index :users,     :uid
    add_index :gabs,      :receiver_id
    add_index :gabs,      :user_id
    add_index :messages,  :gab_id
    add_index :messages,  :user_id
    add_index :clues,     :gab_id
    add_index :clues,     :user_id
    add_index :sessions,  :user_id
    add_index :sessions,  :token,     :unique => true
    add_index :devices,   :user_id
    add_index :devices,   :token,     :unique => true
    add_index :purchases, :user_id
    add_index :purchases, :receipt,   :unique => true
  end
end
