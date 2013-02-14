class CreateTables < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string    :uid
      t.string    :access_token
      t.text      :data
      t.timestamps
    end

    create_table :topics do |t|
      t.integer   :receiver_id
      t.integer   :sender_id
      t.string    :title
      t.timestamps
    end

    create_table :messages do |t|
      t.text      :content
      t.integer   :topic_id
      t.integer   :sender_id
      t.string    :receiver_email
      t.string    :receiver_uid
      t.integer   :receiver_id
      t.boolean   :is_anonymous
      t.timestamps
    end

    create_table :clues do |t|
      t.integer   :message_id
      t.string    :field
      t.string    :value
      t.timestamps
    end

    create_table :sessions do |t|
      t.integer   :user_id
      t.string    :token
      t.timestamps
    end
  end
end
