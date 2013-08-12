class AddNotifiedFriendsToUser < ActiveRecord::Migration
  def up
    add_column :users, :notified_friends, :boolean, :default => false

    User.update_all(:notified_friends => true)
  end

  def down
    remove_column :users, :notified_friends
  end
end
