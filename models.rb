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
  has_many :gabs, :dependent => :destroy, :order => "updated_at DESC"
  has_many :messages, :dependent => :destroy, :order => "created_at DESC"
  #TODO: when fb_id is changed, destroy all facebook friendships; fetch friends when fb_id is set
  has_many :friendships, :dependent => :destroy
  has_many :incoming_friendships, :class_name => 'Friendship', :dependent => :destroy, :foreign_key => 'friend_id'

  serialize :fb_data
  serialize :gpp_data
  serialize :settings

  after_create :add_default_purchases
  after_create :send_welcome_message

  def self.find_by_params(param_obj) 
    return User.find_by_id(param_obj[:id])
  end

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
          :friend_id => user.id
        }
      elsif !user.gpp_id.blank?
        item = {
          :type => 'gpp',
          :value => user.gpp_id,
          :name => user.gpp_data['displayName'] || '',
          :friend_id => user.id
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
    used = clues.where(:revealed => true).count
    [0, total-used].max
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

  def add_default_purchases
    self.purchases.create(:clues => CLUES_DEFAULT)
  end

  def send_welcome_message
    sender = User.find_by_fb_id(FACTORY_USER_UID)
    return if sender.nil? || sender == self

    gab = Gab.my_create(self, sender, 'Backdoor', '')
    gab.create_message('Welcome to Backdoor!', MESSAGE_KIND_TEXT, false, random_key)
  end

  #unused right now
  def email_message(msg)
    ActiveRecord::Base.logger.info 'Delivering email to %s' % email
    Pony.mail(
      :to => email,
      :via => :smtp,
      :via_options => SMTP_SETTINGS,
      :subject => 'Backdoor Message',
      :from => 'Backdoor <noreply@backdoorapp.com>',
      :reply_to => 'noreply@backdoorapp.com',
      :body => msg.content + "\n\nYou've been Backdoored"
    )
  end

  #unused right now
  def sms_message(msg, phone_number)
    if msg.kind != MESSAGE_KIND_TEXT
      related_gab = msg.gab.related_gab
      related_gab.create_message("ERROR_SMS_PHOTO_DELIVERY", MESSAGE_KIND_TEXT, false, random_key)
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
      msg.gab.related_gab.create_message("ERROR_SMS_DELIVERY", MESSAGE_KIND_TEXT, false, random_key)
    end
  end

  def fetch_fb_friends
    client = HTTPClient.new

    url = 'https://graph.facebook.com/oauth/access_token'
    resp = client.get(url, :client_id => FACEBOOK_APP_ID, :client_secret => FACEBOOK_APP_SECRET, :grant_type => 'client_credentials')
    token = resp.content.sub('access_token=', '')

    url = "https://graph.facebook.com/#{self.fb_id}/friends?fields=id,first_name,last_name"
    resp = client.get(url, :access_token => token)
    data = JSON.parse(resp.content)

    friends = data['data']

    social_ids = []

    data['data'].each do |item|
      friend = User.find_by_fb_id(item['id'])
      social_ids << item['id']
      next if friend.nil?
      friendship = self.friendships.find_or_initialize_by_friend_id_and_provider_and_social_id(friend.id, Friendship::FACEBOOK_PROVIDER, item['id'])
      friendship.first_name = item['first_name']
      friendship.last_name = item['last_name']
      friendship.save
    end

    #TODO this is expensive, change 
    if social_ids.empty?
      #no friends anymore, lover
      self.friendships.facebook.destroy_all
    else
      self.friendships.facebook.where('social_id NOT IN (?)', social_ids).destroy_all
    end
  end

  def fetch_friends
    self.fetch_fb_friends unless self.fb_id.blank?
  end

  def get_friends
    if self.friendships.count == 0
      self.fetch_friends
    end

    sql = Friendship
      .select([:provider, :social_id, :first_name, :last_name, :name])
      .where('user_id = ?', self.id)
      .to_sql

    data = ActiveRecord::Base.connection.select_all(sql)

    data
  end

  before_save do |obj|
    obj.fb_data = {} if obj.fb_data.blank?
    obj.gpp_data = {} if obj.gpp_data.blank?
    obj.settings = USER_DEFAULT_SETTINGS if obj.settings.blank?
  end
end

class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => "User"

  FACEBOOK_PROVIDER = "facebook"

  scope :facebook, -> {where(provider: FACEBOOK_PROVIDER)}

  def as_json(opt={})
    super(:only => [:id, :user_id, :friend_id, :social_id, :provider, :first_name, :last_name])
  end

  def name
    "#{first_name} #{last_name}"
  end
end

class Time
  def written_time
    self.strftime("%F %T")
  end
end

class Gab < ActiveRecord::Base
  has_one :related_gab, :class_name => 'Gab', :foreign_key => 'related_gab_id'
  has_many :messages, :dependent => :destroy, :order => "created_at DESC"
  has_many :clues
  belongs_to :user

  def as_json opts={}
    hsh = super(except: [:user_id, :created_at, :related_gab_id, :updated_at])
    hsh["gab"]["updated_at"] = updated_at.written_time #TODO more beauitufl via method: but later
    hsh
  end
   
  #sender, receiver!!!
  def self.my_create(user, receiver, related_user_name, related_phone)
    gab = Gab.create(
      :user_id => user.id,
      :related_user_name => related_user_name || '',
      :related_avatar => receiver.avatar_url,
      :sent => true,
    )

    gab_recv = Gab.create(
      :user_id => receiver.id,
      :related_gab_id => gab.id,
      :related_user_name => '',
      :related_avatar => '',
      :related_phone => related_phone || '',
      :sent => false,
    )

    gab.update_attributes(:related_gab_id => gab_recv.id)
    gab_recv.create_clues

    gab
  end

  def create_message(content, kind, sent, key)
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
      :key => key,
      :read => sent,
      :sent => sent,
      :user => user,
    )

    ActiveRecord::Base.logger.level = level

    self.total_count += 1
    self.unread_count += 1 unless sent

    summary = msg.summary
    unless summary.nil? or summary.empty?
      self.content_cache = (self.content_cache + ' ' + summary).strip.last(255)
      self.content_summary = summary
    end

    self.save

    if !self.user.fake && self.user.registered && self.user.fb_id != FACTORY_USER_UID
      msg_obj = msg.build_apn_hash
      Resque.enqueue(MessageDeliveryQueue, msg_obj) unless sent
    end

    msg
  end

  def create_message_from_params(params) 
    content = params[:content]
    kind = params[:kind].try(:to_i)
    key = params[:key] || ''
  
    return nil if content.blank? || kind.blank?

    message = self.create_message(content, kind, true, key) 
    self.related_gab.create_message(content, kind, false, key)

    self.mark_read #TODO stop doing this

    message
  end

  def mark_read
    messages.update_all(:read => true, :updated_at => Time.now)
    #use update_all to maintain timestamp
    self.update_column(:unread_count, 0)
  end

  def mark_deleted
    #TODO mark the actual gab as deleted as well
    messages.update_all(:deleted => true, :updated_at => Time.now)    
    #update the timestamp
    self.total_count = 0
    self.unread_count = 0
    self.content_cache = ''
    self.content_summary = ''
    self.save
  end

  def create_clues
    data = DataHelper.new(related_gab.user).avail_clues

    data.each_index do |i|
      item = data[i]

      clues.create(
        :user => self.user,
        :number => i,
        :field => item[0].to_s,
        :value => item[1]
      )
    end
  end
end

class Message < ActiveRecord::Base
  belongs_to :user
  belongs_to :gab, :touch => true
  scope :visible, -> {where(deleted: false)}

  def as_json(opt={})
    hsh = super(:except => [:updated_at, :created_at])
    hsh["message"]["created_at"] = created_at.written_time
    hsh
  end

  def summary
    return '' unless kind == MESSAGE_KIND_TEXT
    return '' if content == 'ERROR_SMS_DELIVERY'
    return '' if content == 'ERROR_SMS_PHOTO_DELIVERY'
    return content
  end

  def build_apn_hash
    sender = gab.related_user_name
    sender = 'Someone' if sender.blank?

    message_preview = !!user.settings["message_preview"]

    if message_preview and self.summary.length > 0
      alert = "%s: %s" % [sender, summary]
    else
      alert = "%s sent you a Backdoor message." % sender
    end

    if alert.length > 100
      alert = alert[0..96] + "..."
    end

    {
      :device_tokens => user.devices.map {|d| d.device_token},
      :alert => alert,
      :badge =>  user.unread_messages,
      :custom => { 
        :gab_id => gab.id
      }
    }
  end

  def self.deliver_apn_hash pushers, hash
    hash = hash.symbolize_keys
    hash[:device_tokens].each do |device_token|
      ActiveRecord::Base.logger.info 'Delivering apn to %s' % device_token
      notification = 
        Grocer::Notification.new(
                                 device_token: device_token,
                                 alert:        hash[:alert],
                                 badge:        hash[:badge],
                                 sound:        'default',
                                 custom:       hash[:custom]
                                 )
      
      pushers.each do |push|
        push.push(notification)
      end
    end
  end
end

class Clue < ActiveRecord::Base
  belongs_to :gab, :counter_cache => :clue_count
  belongs_to :user
  scope :revealed, -> { where(revealed: true) }

  def as_json(opt={})
    super(only: [:id, :gab_id, :field, :value, :number])
  end

  def reveal
    return nil unless self.user.available_clues > 0

    self.revealed = true
    self.save

    return self
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
      :email => data['email'] || '',
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

class AbuseReport < ActiveRecord::Base
  belongs_to :user

  after_create do |ar|
    Resque.enqueue(AbuseReportDeliveryQueue, ar.id)
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

  def self.build_pushers
    pushers = []
    pushers << Grocer.pusher(
      certificate:  APN_CERT,
      passphrase:   '',
      gateway:      APN_GATEWAY
    )
    pushers
  end

  def self.perform(hash)
    Message.deliver_apn_hash(MessageDeliveryQueue.build_pushers, hash)
  end
end

class DeviceCleanupQueue
  @queue = :device_cleanup

  def self.perform
    feedback = Grocer.feedback(
      certificate:  APN_CERT,
      gateway:      APN_GATEWAY,
      passphrase:   '',
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

class AbuseReportDeliveryQueue
  @queue = :abuse_report_delivery

  def self.perform(id)
    ar = AbuseReport.find_by_id(id)
    return if ar.nil?

    user = ar.user
    data = DataHelper.new(user, user).load
    user_name = data['name'] || 'Anonymous user'
    from = "%s <%s>" % [user_name, user.email]

    body = ar.content

    Pony.mail(
      :to => ABUSE_REPORT_EMAIL,
      :via => :smtp,
      :via_options => SMTP_SETTINGS,
      :subject => 'Abuse report from %s (#%s)' % [user_name, user.id],
      :from => from,
      :reply_to => user.email,
      :body => body,
    )
  end
end
