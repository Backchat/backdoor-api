class DropLastDateFromGab < ActiveRecord::Migration
  def up
    Gab.all.each do |g|
      g.updated_at = g.last_date
      g.save!
    end

    remove_column :gabs, :last_date
  end

  def down
    add_column :gabs, :last_date, :datetime
    Gab.all.each do |g|
      g.last_date = g.updated_at
      g.save!
    end
  end
end
