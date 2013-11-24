class DropUserIdIndexOnTokens < ActiveRecord::Migration
  def change
    remove_index :tokens, column: :user_id
  end
end
