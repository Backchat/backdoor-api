require 'sinatra/activerecord'
require 'will_paginate'
require 'will_paginate/active_record'
require 'pony'
require 'resque'
require 'httpclient'
require 'twilio-ruby'
require 'grocer'

class User < ActiveRecord::Base
  has_many :sessions, :dependent => :destroy
  has_many :purchases
  has_many :clues
  has_many :gabs

  serialize :data

  def self.my_find_or_create(uid, email, phone)
    user = User.find_or_create_by_uid(uid) unless uid.blank?
    user = User.find_or_create_by_email(email) unless user || email.blank?
    user = User.find_or_create_by_phone(phone) unless user || phone.blank?

    return if user.nil?

    user.autocreated = true unless user.registered
    user.uid = uid if user.uid.blank?
    user.email = email if user.email.blank?
    user.phone = phone if user.phone.blank?
    user.data = { 'email' => email, 'id' => uid } if user.data == {}
    user.save

    user
  end

  def available_clues
    total = purchases.sum(:clues)
    used = clues.count
    total - used
  end

  def fetch_facebook_data
    client = HTTPClient.new
    url = 'https://graph.facebook.com/%d' % uid
    resp = client.get(url)
    my_data = JSON.parse(resp.content)

    return if my_data['error']

    my_data = data.update(my_data)
    my_data['email'] = ('%s@facebook.com' % my_data['username']) if my_data['email'].blank?

    update_attributes(
      :data => my_data,
      :email => my_data['email']
    )
  end

  def email_message(msg)
    return if email.blank?

    Pony.mail(
      :to => email,
      :via => :smtp,
      :via_options => SMTP_SETTINGS,
      :subject => msg.gab.title,
      :from => 'YouTell Mobile <noreply@youtell.com>',
      :reply_to => 'noreply@youtell.com',
      :body => msg.content + "\n\nMessage sent by YouTell Mobile"
    )
  end

  def sms_message(msg)
    return if phone.blank?

    client = Twilio::REST::Client.new TWILIO_SID, TWILIO_TOKEN
    client.account.sms.messages.create(
      :from => '+14248357900',
      :to => phone,
      :body => msg.content
    )
  end

  def push_message(msg)
    pusher = Grocer.pusher(
      certificate:  APN_CERT,
      passphrase:   APN_PASS,
      gateway:      "gateway.push.apple.com",
      port:         2195,
      retries:      3
    )

    devices.each do |device|
      notification = Grocer::Notification.new(
        device_token: device.token,
        alert:        "New message from YouTell"
      )
      pusher.push(notification)
    end
  end

  def deliver_message(msg)
    if false and devices.count > 0
      push_message(msg)
    elsif !email.blank?
      email_message(msg)
    elsif !uid.blank?
      fetch_facebook_data
      email_message(msg)
    elsif false and !phone.blank?
      sms_message(msg)
    else
      # NOTREACHED
      raise 'Cannot deliver message: %s' % msg.id
    end
  end

  before_save do |obj|
    obj.data = {} unless obj.data
  end
end

class Gab < ActiveRecord::Base
  JSON_OPTS = {
    :root => false,
    :only => [:id, :title, :created_at, :updated_at],
    :methods => [:total_count, :unread_count, :is_sent]
  }

  has_many :messages
  has_many :clues

  belongs_to :user
  belongs_to :receiver, :class_name => 'User', :foreign_key => 'receiver_id'

  cattr_accessor :current_user

  def is_sent
    user_id == current_user.id
  end

  def total_count
    messages.count
  end

  def unread_count
    messages.where('user_id != ?', current_user).where(:read => false).count
  end

  def mark_read
    messages
      .where('user_id != ?', current_user)
      .update_all(:read => true)
  end

  def create_clue
    count = clues.count

    return if count > 2
    return unless current_user.available_clues > 0

    field = ['gender', 'birthday', 'first_name'][count]
    value = user.data[field]
    clues.create(
      :user => current_user,
      :field => field,
      :value => value
    )
  end

  def as_json(options = {})
    options ||= {}
    options = Gab::JSON_OPTS.merge(options)
    super options
  end

  def as_json_full
    inc = { :messages => Message::JSON_OPTS, }
    inc[:clues] = Clue::JSON_OPTS if receiver_id == current_user.id
    as_json(:include => inc)
  end

end

class Message < ActiveRecord::Base
  JSON_OPTS = {
    :only => [:id, :content, :created_at, :updated_at],
    :methods => [:is_read, :is_sent]
  }

  belongs_to :user
  belongs_to :gab

  after_create do |msg|
    Resque.enqueue(MessageDeliveryQueue, msg.id)
  end

  def is_sent
    user_id == Gab.current_user.id
  end

  def is_read
    is_sent || read
  end

  def as_json
    options ||= {}
    options = Message::JSON_OPTS.merge(options)
    super options
  end

  def deliver
    my_user = (user.id == gab.user.id) ? gab.receiver : gab.user
    my_user.deliver_message self
  end
end

class Clue < ActiveRecord::Base
  JSON_OPTS = {
    :only => [:field, :value]
  }

  belongs_to :gab
  belongs_to :user

  def as_json(options={})
    options ||= {}
    options = Clue::JSON_OPTS.merge(options)
    super options
  end
end

class Session < ActiveRecord::Base
  belongs_to :user
  before_save do |obj|
    obj.token = SecureRandom.hex(16) unless obj.token
  end
end

class Device < ActiveRecord::Base
  belongs_to :user
end

class Purchase < ActiveRecord::Base
  belongs_to :user
end

class MessageDeliveryQueue
  @queue = :message_delivery

  def self.perform(id)
    msg = Message.find_by_id(id)
    msg.deliver unless msg.nil?
  end
end

class DeviceCleanupQueue
  @queue = :device_cleanup

  def self.perform
    feedback = Grocer.feedback(
      certificate:  APN_CERT,
      passphrase:   APN_PASS,
      gateway:      "feedback.push.apple.com",
      port:         2196,
      retries:      3
    )

    feedback.each do |attempt|
      device = Device.find_by_device_token(attempt.device_token)
      next if device.nil?
      device.destroy if attempt.timestamp > device.updated_at
    end
  end

end
