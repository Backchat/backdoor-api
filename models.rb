require 'sinatra/activerecord'
require 'will_paginate'
require 'will_paginate/active_record'

class User < ActiveRecord::Base
  has_many :sessions

  has_many :created_messages, :class_name => 'Message', :foreign_key => 'sender_id'
  has_many :received_messages, :class_name => 'Message', :foreign_key => 'receiver_id'

  has_many :created_topics, :class_name => 'Topic', :foreign_key => 'sender_id'
  has_many :received_topics, :class_name => 'Topic', :foreign_key => 'receiver_id'
end

class Topic < ActiveRecord::Base
  has_many :messages
  belongs_to :sender, :class_name => 'User', :foreign_key => 'sender_id'
  belongs_to :receiver, :class_name => 'User', :foreign_key => 'receiver_id'

  def as_json(options = {})
    defaults = {
      :only => [:id, :title, :created_at, :updated_at],
    }
    options ||= {}
    options = defaults.merge(options)
    super options
  end

  def as_json_basic(current_user)
    owned = current_user.id == receiver_id
    data = as_json
    data['topic']['readable'] = owned
    data['topic']['message_count'] = messages.count if owned
    data
  end

  def as_json_full
    data = as_json
    data['topic']['messages'] = messages.map &:as_json_basic
    data
  end
end

class Message < ActiveRecord::Base
  belongs_to :sender, :class_name => 'User', :foreign_key => 'sender_id'
  belongs_to :receiver, :class_name => 'User', :foreign_key => 'receiver'
  belongs_to :topic
  has_many :messages

  def as_json_basic
    as_json :only => [:id, :content, :created_at, :updated_at]
  end

end

class Clue < ActiveRecord::Base
  belongs_to :message
end

class Session < ActiveRecord::Base
  belongs_to :user
  before_save do |obj|
    obj.token = SecureRandom.hex(16) unless obj.token
  end
end

