require 'data_mapper'
require 'resque'

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_JADE_URL'] || "postgres://localhost/youtell-api")

class Topic
  include DataMapper::Resource

  has n, :messages

  property :id,             Serial
  property :title,          String,   :required => true
  property :sender_id,      Integer
  property :recipient_id,   Integer
end

class Message
  include DataMapper::Resource

  belongs_to :topic

  property :id,             Serial
  property :content,        Text,     :required => true
  property :sender_id,      Integer
  property :topic_id,       Integer,  :required => true
  property :is_anonymous,   Boolean,  :default => true

  after :create, :send

  def send
    #Resque.enqueue(MessageDelivery, id)
  end
end

class MessageDelivery
  @queue = :api_messages
  def self.perform(mid)
    message = Message.get(mid)
    puts '-- delivering message: ', message.content
  end
end

DataMapper.finalize
DataMapper.auto_upgrade!
