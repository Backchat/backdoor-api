require 'sinatra/activerecord'
require 'will_paginate'
require 'will_paginate/active_record'
require 'pony'
require 'resque'
require 'httpclient'
require 'twilio-ruby'
require 'grocer'
require 'httpclient'


class User < ActiveRecord::Base
  has_many :tokens, :dependent => :destroy
  has_many :devices, :dependent => :destroy
  has_many :purchases, :dependent => :destroy
  has_many :clues, :dependent => :destroy
  has_many :gabs, :dependent => :destroy

  serialize :data

  def self.my_find_or_create(uid, email, phone, fake = false)
    user = User.find_or_create_by_uid(uid) unless uid.blank?
    user = User.find_or_create_by_email(email) unless user || email.blank?
    user = User.find_or_create_by_phone(phone) unless user || phone.blank?

    return if user.nil?

    user.autocreated = true unless user.registered
    user.uid = uid if user.uid.blank?
    user.email = email if user.email.blank?
    user.phone = phone if user.phone.blank?
    user.data = { 'email' => email, 'id' => uid } if user.data == {}
    user.fake = fake
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

  def create_welcome_message
    sender = User.find_by_uid("100002519356657")
    return if sender.nil?

    gab = Gab.my_create(self, sender, 'Backdoor team')
    gab.update_attributes(:related_user_name => 'Backdoor team')
    gab.create_message('Welcome to Backdoor', MESSAGE_KIND_TEXT, false)

    gab = Gab.my_create(self, sender, 'Backdoor team')
    gab.create_message('This is another message', MESSAGE_KIND_TEXT, false)
    gab.update_attributes(
      :related_user_name => 'Backdoor team',
      :last_date => gab.last_date + 5
    )

    self.purchases.create(:clues => 3)
  end

  def email_message(msg)
    Pony.mail(
      :to => email,
      :via => :smtp,
      :via_options => SMTP_SETTINGS,
      :subject => 'New message on YouTell',
      :from => 'YouTell Mobile <noreply@youtell.com>',
      :reply_to => 'noreply@youtell.com',
      :body => msg.content + "\n\nMessage sent by YouTell Mobile"
    )
  end

  def sms_message(msg)
    client = Twilio::REST::Client.new TWILIO_SID, TWILIO_TOKEN
    client.account.sms.messages.create(
      :from => '+13104398878',
      :to => phone,
      :body => msg.content
    )
  end

  def push_message(msg)
    pusher = Grocer.pusher(
      certificate:  APN_CERT,
      passphrase:   APN_PASS
    )

    devices.each do |device|
      puts "pushing to: ", device.device_token
      notification = Grocer::Notification.new(
        device_token: device.device_token,
        alert:        "New message from YouTell",
        sound:        'default',
        custom:       { :gab_id => msg.gab.id }
      )
      pusher.push(notification)
    end
  end

  def deliver_message(msg)
    return if fake

    if devices.count > 0
      push_message(msg)
    elsif !email.blank?
      email_message(msg)
    elsif !uid.blank?
      fetch_facebook_data
      email_message(msg)
    elsif !phone.blank?
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
  has_one :related_gab, :class_name => 'Gab', :foreign_key => 'related_gab_id'
  has_many :messages, :dependent => :destroy
  has_many :clues
  belongs_to :user

  cattr_accessor :current_user

  def self.my_create(user, receiver, receiver_name)
    gab = Gab.create(
      :user_id => user.id,
      :related_user_name => receiver_name,
      :sent => true
    )

    gab_recv = Gab.create(
      :user_id => receiver.id,
      :related_gab_id => gab.id,
      :related_user_name => '',
      :sent => false
    )

    gab.update_attributes(:related_gab_id => gab_recv.id)

    gab
  end

  def self.dump_updated(user, time, messages)
    fields = [:id, :related_user_name, :content_cache, :content_summary, :unread_count, :total_count, :sent, date_sql(:last_date)]

    return [] if messages.count == 0

    gab_ids = messages.map { |x| x['gab_id'] }

    sql = Gab
      .select(fields)
      .where('id in (?)', gab_ids)
      .order('last_date DESC')
      .to_sql

    gabs = ActiveRecord::Base.connection.select_all(sql)

    gabs
  end

  def create_message(content, kind, sent)
    if kind == MESSAGE_KIND_PHOTO
      content = Base64.decode64(content)
      content = generate_thumbnail(content)
      File.new('image.jpg', 'wb').write(content)
      content = Base64.encode64(content)
    end

    level = ActiveRecord::Base.logger.level
    ActiveRecord::Base.logger.level = Logger::WARN

    msg = messages.create(
      :content => content,
      :kind => kind,
      :read => sent,
      :sent => sent,
      :user => user,
    )

    ActiveRecord::Base.logger.level = level

    self.total_count += 1
    self.unread_count += 1 unless sent
    self.last_date = msg.updated_at
    if kind == MESSAGE_KIND_TEXT
      self.content_cache = (self.content_cache + ' ' + content).strip.last(255)
      self.content_summary = content
    end
    self.save

    Resque.enqueue(MessageDeliveryQueue, msg.id) unless sent
  end

  def mark_read
    messages.update_all(:read => true)
    self.unread_count = 0
    self.save
  end

  def mark_deleted
    messages.update_all(:deleted => true, :updated_at => Time.now)
    self.total_count = 0
    self.unread_count = 0
    self.content_cache = ''
    self.content_summary = ''
    self.save
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
end

class Message < ActiveRecord::Base
  belongs_to :user
  belongs_to :gab

  def self.dump_updated(user, time)
    fields = [:id, :gab_id, :content, :kind, :sent, :deleted, date_sql(:created_at)]

    sql = Message
      .select(fields)
      .where('user_id = ?', user)
      .where('updated_at > ?', time)
      .order('created_at DESC')
      .limit(200)
      .to_sql

    values = ActiveRecord::Base.connection.select_all(sql)

    values.each do |val|
      val['content'] = '' if val['deleted'] == 't'
    end

    values
  end

  def deliver
    gab.user.deliver_message self
  end
end

class Clue < ActiveRecord::Base
  belongs_to :gab
  belongs_to :user

  def self.dump_updated(user, time)
    fields = [:id, :gab_id, :field, :value]

    sql = Clue
      .select(fields)
      .where('user_id = ?', user)
      .where('updated_at > ?', time)
      .order('created_at DESC')
      .to_sql

    clues = ActiveRecord::Base.connection.select_all(sql)

    clues
  end
end

class Token < ActiveRecord::Base
  belongs_to :user

  def self.authenticate(access_token, user_data)

    token = Token.find_by_access_token(access_token)
    return token unless token.nil?

    client = HTTPClient.new
    url = 'https://graph.facebook.com/me'
    resp = client.get(url, :access_token => access_token)
    data = JSON.parse(resp.content)
    puts data.inspect

    err 403, 'forbidden' unless data['id']

    user = User.find_by_uid(data['id'])
    user = User.find_by_email(data['email']) unless user
    user = User.create unless user

    user.create_welcome_message unless user.registered == true

    user_data = {} if user_data.nil?
    user_data = user_data.update(data)
    user_data = user.data.update(user_data)

    user.update_attributes(
      :email => data['email'],
      :uid => data['id'],
      :data => user_data,
      :registered => true
    )

    token = user.tokens.create(:access_token => access_token)

    token
  end
end

class Device < ActiveRecord::Base
  belongs_to :user

  def self.my_find_or_create(device_token, user)
    return if device_token.nil?

    device = Device.find_or_create_by_device_token(device_token)
    device.user = user
    device.save

    device
  end
end

class Purchase < ActiveRecord::Base
  belongs_to :user
end

class Feedback < ActiveRecord::Base
  belongs_to :user

  after_create do |fb|
    Resque.enqueue(FeedbackDeliveryQueue, fb.id)
  end
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

class FeedbackDeliveryQueue
  @queue = :feedback_delivery

  def self.perform(id)
    fb = Feedback.find_by_id(id)
    return if fb.nil?

    user = fb.user
    user_name = user.data['name'] || 'Anonymous user'
    from = "%s <%s>" % [user_name, user.email]

    body = fb.content
    body = body + "\n\nRating: %s" % fb.rating if fb.rating != 0

    Pony.mail(
      :to => FEEDBACK_EMAIL,
      :via => :smtp,
      :via_options => SMTP_SETTINGS,
      :subject => 'New feedback' % user_name,
      :from => from,
      :reply_to => fb.user.email,
      :body => body,
    )
  end
end
