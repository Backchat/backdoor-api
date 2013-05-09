require 'sinatra/activerecord'
require 'will_paginate'
require 'will_paginate/active_record'
require 'pony'
require 'resque'
require 'httpclient'
require 'twilio-ruby'
require 'grocer'
require 'httpclient'
require 'phony'


class User < ActiveRecord::Base
  has_many :tokens, :dependent => :destroy
  has_many :devices, :dependent => :destroy
  has_many :purchases, :dependent => :destroy
  has_many :clues, :dependent => :destroy
  has_many :gabs, :dependent => :destroy
  has_many :messages, :dependent => :destroy

  serialize :fb_data
  serialize :gpp_data

  def self.my_find_or_create(fb_id, gpp_id, email, phone, fake = false)
    user = User.find_or_create_by_fb_id(fb_id) unless fb_id.blank?
    user = User.find_or_create_by_gpp_id(gpp_id) unless gpp_id.blank?
    user = User.find_or_create_by_email(email) unless user || email.blank?
    user = User.find_or_create_by_phone(phone) unless user || phone.blank?

    return if user.nil?

    user.autocreated = true unless user.registered
    user.fb_id = fb_id if user.fb_id.blank? && !fb_id.blank?
    user.gpp_id = gpp_id if user.gpp_id.blank? && !gpp_id.blank?
    user.email = email if user.email.blank? && !email.blank?
    user.phone = phone if user.phone.blank? && !phone.blank?
    user.fb_data = { 'email' => (email || ''), 'id' => (fb_id || '') } if user.fb_data == {}
    user.gpp_data = { 'email' => (email || ''), 'id' => (gpp_id || '') } if user.gpp_data == {}
    user.fake = fake
    user.save

    user
  end

  def self.dump_featured(current_user)
    ret = []
    User.where(:featured => true).each do |user|
      next if user.id == current_user.id

      if !user.fb_id.blank?
        item = {
          :type => 'facebook',
          :value => user.fb_id,
          :name => user.fb_data['name'] || '',
        }
      elsif !user.gpp_id.blank?
        item = {
          :type => 'gpp',
          :value => user.gpp_id,
          :name => user.gpp_data['displayName'] || ''
        }
      else
        next
      end

      ret << item
    end

    ret
  end

  def available_clues
    total = purchases.sum(:clues)
    used = clues.count
    total - used
  end

  def unread_messages
    messages.where(:read => false, :deleted => false).count
  end

  def avatar_url
    if !self.fb_id.blank?
      return 'https://graph.facebook.com/%s/picture' % self.fb_id
    elsif !self.gpp_id.blank?
      return 'http://profiles.google.com/s2/photos/profile/%s?sz=50' % self.gpp_id
    else
      return ''
    end
  end

  #def fetch_facebook_data
  #  client = HTTPClient.new
  #  url = 'https://graph.facebook.com/%d' % uid
  #  resp = client.get(url)
  #  my_data = JSON.parse(resp.content)

  #  return if my_data['error']

  #  my_data = data.update(my_data)
  #  my_data['email'] = ('%s@facebook.com' % my_data['username']) if my_data['email'].blank?

  #  update_attributes(
  #    :data => my_data,
  #    :email => my_data['email']
  #  )
  #end

  def create_welcome_message
    sender = User.find_by_fb_id(FACTORY_USER_UID)
    return if sender.nil?

    gab = Gab.my_create(self, sender, 'Backdoor team', '')
    gab.update_attributes(:related_user_name => 'Backdoor team')
    gab.create_message('Welcome to Backdoor!', MESSAGE_KIND_TEXT, false)

    #gab = Gab.my_create(self, sender, 'Backdoor team', '')
    #gab.create_message('This is another message', MESSAGE_KIND_TEXT, false)
    #gab.update_attributes(
    #  :related_user_name => 'Backdoor team',
    #  :last_date => gab.last_date + 5
    #)

    self.purchases.create(:clues => CLUES_FREE)
  end

  def email_message(msg)
    ActiveRecord::Base.logger.info 'Delivering email to %s' % email
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

  def sms_message(msg, phone_number)
    if msg.kind != MESSAGE_KIND_TEXT
      related_gab = msg.gab.related_gab
      related_gab.create_message("ERROR_SMS_PHOTO_DELIVERY", MESSAGE_KIND_TEXT, false)
      return
    end

    client = Twilio::REST::Client.new TWILIO_SID, TWILIO_TOKEN
    begin
      to = Phony.formatted(phone_number, :format => :international, :spaces => '')
      ActiveRecord::Base.logger.info 'Delivering sms to %s' % to
      client.account.sms.messages.create(
        :from => '+13104398878',
        :to => to,
        :body => msg.content
      )
    rescue
      ActiveRecord::Base.logger.error $!.class.to_s + ': ' + $!.message
      ActiveRecord::Base.logger.error $!.backtrace.join("\n")
      msg.gab.related_gab.create_message("ERROR_SMS_DELIVERY", MESSAGE_KIND_TEXT, false)
    end
  end

  def push_message(msg)
    pusher = Grocer.pusher(
      certificate:  APN_CERT,
      passphrase:   '',
      gateway:      APN_GATEWAY
    )
    pusher2 = Grocer.pusher(
      certificate:  APN_CERT_PROD,
      passphrase:   '',
      gateway:      APN_GATEWAY_PROD
    )

    sender = msg.gab.related_user_name
    sender = 'Someone' if sender.blank?

    devices.each do |device|
      ActiveRecord::Base.logger.info 'Delivering apn to %s' % device.device_token
      notification = Grocer::Notification.new(
        device_token: device.device_token,
        alert:        "%s sent you a Backdoor message." % sender,
        badge:        msg.user.unread_messages,
        sound:        'default',
        custom:       { :gab_id => msg.gab.id }
      )
  
      pusher.push(notification)
      pusher2.push(notification)
    end
  end

  def deliver_message(msg)
    return if fake

    if registered
      push_message(msg)
      return unless fb_id == FACTORY_USER_UID
    end

    unless email.blank?
      email_message(msg)
      return unless fb_id == FACTORY_USER_UID
    end

    unless phone.blank?
      sms_message(msg, phone)
      return unless fb_id == FACTORY_USER_UID
    end

    unless msg.gab.related_phone.blank?
      sms_message(msg, msg.gab.related_phone)
      return unless fb_id == FACTORY_USER_UID
    end

    # NOTREACHED

    #elsif !uid.blank?
    #  fetch_facebook_data
    #  email_message(msg)
  end

  before_save do |obj|
    obj.fb_data = {} unless obj.fb_data
    obj.gpp_data = {} unless obj.gpp_data
  end
end

class Gab < ActiveRecord::Base
  has_one :related_gab, :class_name => 'Gab', :foreign_key => 'related_gab_id'
  has_many :messages, :dependent => :destroy
  has_many :clues
  belongs_to :user

  cattr_accessor :current_user

  def self.my_create(user, receiver, related_user_name, related_phone)
    gab = Gab.create(
      :user_id => user.id,
      :related_user_name => related_user_name || '',
      :related_avatar => receiver.avatar_url,
      :sent => true,
      :last_date => Time.now
    )

    gab_recv = Gab.create(
      :user_id => receiver.id,
      :related_gab_id => gab.id,
      :related_user_name => '',
      :related_avatar => '',
      :related_phone => related_phone || '',
      :sent => false,
      :last_date => Time.now
    )

    gab.update_attributes(:related_gab_id => gab_recv.id)

    gab
  end

  def self.dump_updated(user, time, messages)
    fields = [:id, :related_user_name, :related_avatar, :content_cache, :content_summary, :unread_count, :total_count, :sent, date_sql(:last_date)]

    gab_ids = messages.map { |x| x['gab_id'] }
    gab_ids << -1

    sql = Gab
      .select(fields)
      .where('id in (?) OR (user_id = ? AND updated_at > ?)', gab_ids, user, time)
      .order('last_date DESC')
      .to_sql

    gabs = ActiveRecord::Base.connection.select_all(sql)

    gabs
  end

  def create_message(content, kind, sent)
    if kind == MESSAGE_KIND_TEXT
      secret = ''
    elsif kind == MESSAGE_KIND_PHOTO
      secret = SecureRandom.hex(8)
      data = Base64.decode64(content)
      content = generate_thumbnail(data)
      #File.new('image.jpg', 'wb').write(content)
      content = Base64.encode64(content)
    else
      # NOTREACHED
    end

    level = ActiveRecord::Base.logger.level
    ActiveRecord::Base.logger.level = Logger::WARN

    if kind == MESSAGE_KIND_PHOTO
      image = Image.create(:data => data, :secret => secret)
    end

    msg = messages.create(
      :content => content,
      :kind => kind,
      :secret => secret,
      :read => sent,
      :sent => sent,
      :user => user,
    )

    ActiveRecord::Base.logger.level = level

    self.total_count += 1
    self.unread_count += 1 unless sent
    self.last_date = msg.updated_at

    summary = msg.summary
    unless summary.nil? or summary.empty?
      self.content_cache = (self.content_cache + ' ' + summary).strip.last(255)
      self.content_summary = summary
    end

    self.save

    Resque.enqueue(MessageDeliveryQueue, msg.id) unless sent
  end

  def mark_read
    messages.update_all(:read => true, :updated_at => Time.now)
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
    used = clues.map { |x| x.field }
    count = used.count

    return if count > CLUES_MAX
    return unless current_user.available_clues > 0

    data = DataHelper.new(related_gab.user, current_user).load
    puts data.inspect

    data.keys.each do |field|
      next if used.include?(field.to_s) || data[field].nil?

      clues.create(
        :user => current_user,
        :field => field.to_s,
        :value => data[field]
      )

      break
    end
  end
end

class Message < ActiveRecord::Base
  belongs_to :user
  belongs_to :gab

  def self.dump_updated(user, time)
    fields = [:id, :gab_id, :content, :kind, :sent, :deleted, :secret, date_sql(:created_at)]

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

  def summary
    return '' unless kind == MESSAGE_KIND_TEXT
    return '' if content == 'ERROR_SMS_DELIVERY'
    return '' if content == 'ERROR_SMS_PHOTO_DELIVERY'
    return content
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

  def self.auth_fb(access_token, fb_data)

    client = HTTPClient.new
    url = 'https://graph.facebook.com/me'
    resp = client.get(url, :access_token => access_token)
    data = JSON.parse(resp.content)
    puts data.inspect

    err 403, 'forbidden' unless data['id']

    user = User.find_by_fb_id(data['id'])
    user = User.find_by_email(data['email']) unless user
    user = User.create unless user

    fb_data = user.fb_data.blank? ? data : user.fb_data.update(data)

    new_user = !user.registered

    user.update_attributes(
      :email => data['email'],
      :fb_id => data['id'],
      :fb_data => fb_data,
      :registered => true
    )

    { :user => user, :new_user => new_user }
  end

  def self.auth_gpp(access_token, gpp_data)

    client = HTTPClient.new
    url = 'https://www.googleapis.com/oauth2/v1/tokeninfo'
    resp = client.get(url, :access_token => access_token, :prettyPrint => true)
    data = JSON.parse(resp.content)

    err 403, 'forbidden' unless data['user_id']

    user = User.find_by_gpp_id(data['user_id'])
    user = User.find_by_email(data['email']) unless user
    user = User.create unless user

    gpp_data = user.gpp_data.blank? ? data : user.gpp_data.update(data)

    new_user = !user.registered

    user.update_attributes(
      :email => data['email'],
      :gpp_id => data['user_id'],
      :gpp_data => gpp_data,
      :registered => true
    )

    { :user => user, :new_user => new_user }
  end

  def self.token_authenticate(access_token)
    token = Token.find_by_access_token(access_token)
    return token.nil? ? nil : token
  end

  def self.authenticate(access_token, provider, fb_data, gpp_data)
    if provider == 'facebook'
      resp = self.auth_fb(access_token, fb_data)
    elsif provider == 'gpp'
      resp = self.auth_gpp(access_token, gpp_data)
    else
      err 403, 'forbidden'
    end

    user = resp[:user]
    new_user = resp[:new_user]

    user.create_welcome_message unless user.registered == true
    token = user.tokens.create(:access_token => access_token)

    [user, new_user]
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

class Image < ActiveRecord::Base
  def content_type
    'image/jpeg'
  end

  def file_name
    "#{secret}.jpg"
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
    user_name = user.fb_data['name'] || 'Anonymous user'
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
