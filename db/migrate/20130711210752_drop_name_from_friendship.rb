class DropNameFromFriendship < ActiveRecord::Migration
  def up
    remove_column :friendships, :name
  end

  def down
    add_column :friendships, :name, :string
  end
end
