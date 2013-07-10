class CreateFriendships < ActiveRecord::Migration
  def change
    create_table :friendships do |t|
      t.integer   :user_id,           :null => false, :default => 0
      t.integer   :friend_id,         :null => true
      t.string    :social_id,         :null => false, :default => ''
      t.string    :provider,          :null => false, :default => ''
      t.string    :name,              :null => false, :default => ''
      t.timestamps
    end
  end
end
