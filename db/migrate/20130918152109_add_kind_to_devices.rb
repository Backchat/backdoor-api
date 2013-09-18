class AddKindToDevices < ActiveRecord::Migration
  def up
    add_column :devices, :kind, :string

    execute "UPDATE devices set kind='APPLE'"
  end

  def down
    remove_column :devices, :kind, :string
  end
end
