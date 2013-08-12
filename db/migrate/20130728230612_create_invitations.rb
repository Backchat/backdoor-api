class CreateInvitations < ActiveRecord::Migration
  def change
    create_table :contacts do |t|
      t.string :phone_number, :null => false
      t.string :enabled
    end

    add_index :contacts, :phone_number

    create_table :invitations do |t|
      t.integer :user_id, :null => false
      t.integer :contact_id, :null => false

      t.string :body, :null => false
      t.boolean :delivered
    end
  end

end
