require 'sinatra/activerecord'
require 'will_paginate'
require 'will_paginate/active_record'
require 'pony'
require 'resque'
require 'httpclient'
require 'twilio-ruby'
require 'grocer'
require 'phony'

class User < ActiveRecord::Base
  has_many :tokens, :dependent => :destroy
  has_many :devices, :dependent => :destroy
  has_many :purchases, :dependent => :destroy
  has_many :clues, :dependent => :destroy
  #TODO get rid of using actual access tokens as login tokens
  #TODO at some point get rid of fb_data and gpp_data  
  has_many :gabs, :dependent => :destroy, :order => "updated_at DESC"
  has_many :messages, :dependent => :destroy, :order => "created_at DESC"
  #TODO: when fb_id is changed, destroy all facebook friendships; fetch friends when fb_id is set
  #TODO : same for gpp_id ...
  has_many :friendships, :dependent => :destroy
  has_many :incoming_friendships, :class_name => 'Friendship', :dependent => :destroy, :foreign_key => 'friend_id'

  has_many :invitations, :dependent => :destroy

  serialize :fb_data
  serialize :gpp_data
  serialize :settings

  after_create :add_default_purchases

  def as_json(opt={})
    {:user => {
        :new_user => !self.registered,
        :settings => self.settings,
        :available_clues => self.available_clues,
        :id => self.id,
        :full_name => self.name
      }
    }
  end

  def update_from_db_name
    self.update_fb_data(self.fb_data) unless self.fb_data.nil?
    self.update_gpp_data(self.gpp_data) unless self.gpp_data.nil?
  end

  def update_first_name(trial_first)
    self.first_name = trial_first unless trial_first.nil? || trial_first.empty?
  end

  def update_last_name(trial_last)
    self.last_name = trial_last unless trial_last.nil? || trial_last.empty?
  end

  def update_fb_data(data)
    self.fb_data = data unless data.nil? || data.blank?
    update_first_name(self.fb_data['first_name'])
    update_last_name(self.fb_data['last_name'])
  end

  def update_gpp_data(data)
    self.gpp_data = data unless data.nil? || data.blank?    
    trial_first_name = self.gpp_data['firstName']
    trial_first_name = display_name_parts[0] unless trial_first_name
    update_first_name(trial_first_name)
    trial_last_name = self.gpp_data['lastName']
    trial_last_name = display_name_parts[1] unless trial_last_name
    update_last_name(trial_last_name)
  end

  def self.find_by_params(param_obj) 
    return User.find_by_id(param_obj[:id])
  end

  def self.dump_featured
    #TODO fix this guy
    User.where(:featured => true).each_with_index.map do |user, count|
      if !user.fb_id.blank?
        item = {
          #old
          :type => 'facebook',
          :value => user.fb_id,
          :name => user.name,

          #new
          :first_name => user.first_name,
          :last_name => user.last_name,
          :featured_id => user.id,
          :social_id => user.fb_id,
          :provider => 'facebook',
          :id => -(count + 1)
        }
      elsif !user.gpp_id.blank?
        item = {
          :type => 'gpp',
          :value => user.gpp_id,
          :name => user.name,

          #new
          :first_name => user.first_name,
          :last_name => user.last_name,
          :featured_id => user.id,
          :social_id => user.gpp_id,
          :provider => 'gpp',
          :id => -(count + 1)
        }
      else
        next
      end
    end
  end

  def available_clues
    total = purchases.sum(:clues)
    used = clues.where(:revealed => true).count
    [0, total-used].max
  end

  def unread_messages
    gabs.sum(:unread_count)
  end

  def has_name?
    !first_name.blank? || !last_name.blank?
  end

  #TODO send to database
  def avatar_url
    if !self.fb_id.blank?
      return 'https://graph.facebook.com/%s/picture?width=90&height=90' % self.fb_id
    elsif !self.gpp_id.blank?
      return 'http://profiles.google.com/s2/photos/profile/%s?sz=90' % self.gpp_id
    else
      return ''
    end
  end

  def add_default_purchases
    self.purchases.create(:clues => CLUES_DEFAULT)
  end

  def send_welcome_message
    sender = User.find_by_fb_id(FACTORY_USER_UID)
    return if sender.nil? || sender == self

    gab = Gab.my_create(self, sender, 'Backdoor', '')
    gab.create_message('Welcome to Backdoor!', MESSAGE_KIND_TEXT, false, random_key)
  end

  def fetch_fb_friends(is_new)
    client = HTTPClient.new

    url = 'https://graph.facebook.com/oauth/access_token'
    resp = client.get(url, :client_id => FACEBOOK_APP_ID, :client_secret => FACEBOOK_APP_SECRET, :grant_type => 'client_credentials')
    token = resp.content.sub('access_token=', '')

    url = "https://graph.facebook.com/#{self.fb_id}/friends?fields=id,first_name,last_name"
    resp = client.get(url, :access_token => token)
    data = JSON.parse(resp.content)

    return unless data['data'].present?

    social_ids = []

    data['data'].each do |item|
      next unless item['id']
      social_ids << item['id']
    end

    valid_users = User.find_all_by_fb_id(social_ids)
    valid_users.each do |friend|
      Friendship.generate_friendship self, friend, self.fb_id, friend.fb_id, Friendship::FACEBOOK_PROVIDER, is_new
    end

    #TODO this is expensive, change 
    if social_ids.empty?
      #no friends anymore, lover
      self.friendships.facebook.destroy_all
    else
      self.friendships.facebook.where('social_id NOT IN (?)', social_ids).destroy_all
    end
  end

  def fetch_gpp_friends(valid_access_token, is_new)
    client = HTTPClient.new

    url = 'https://www.googleapis.com/plus/v1/people/me/people/visible'
    resp = client.get(url, :access_token => valid_access_token)
    data = JSON.parse(resp.content)
    return unless data['items'].present?
    items = data['items']

    social_ids = []
    items.each do |item|
      gpp_id = item['id']
      next unless gpp_id
      social_ids << gpp_id
    end

    valid_users = User.find_all_by_gpp_id(social_ids)
    valid_users.each do |friend|
      Friendship.generate_friendship self, friend, self.gpp_id, friend.gpp_id, Friendship::GPP_PROVIDER, is_new
    end

    if social_ids.empty?
      self.friendships.gpp.destroy_all
    else
      #TODO eexepsnvie
      self.friendships.gpp.where('social_id NOT IN (?)', social_ids).destroy_all
    end    
  end

  def unique_friendships
    self.friendships
  end

  def name
    has_name? ? "#{first_name} #{last_name}" : ""
  end

  def display_name_parts
    if gpp_data && gpp_data['displayName'] 
      parts = gpp_data['displayName'].split
      if parts.length >= 2
        return parts
      end
    end
    
    [nil, nil]
  end

  before_save do |obj|
    obj.settings = USER_DEFAULT_SETTINGS if obj.settings.blank?
  end
end

class Friendship < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => "User"

  FACEBOOK_PROVIDER = "facebook"
  GPP_PROVIDER = "gpp"

  scope :facebook, -> {where(provider: FACEBOOK_PROVIDER)}
  scope :gpp, -> {where(provider: GPP_PROVIDER)}

  def as_json(opt={})
    super(:only => [:id, :user_id, :friend_id, :social_id, :provider, :first_name, :last_name])
  end

  def name
    "#{first_name} #{last_name}"
  end

  class << self
    def generate_friendship user_1, user_2, user_1_id, user_2_id, kind, new
      unless user_1.has_name?
        user_1.update_from_db_name
        user_1.save if user_1.has_name?
      end

      unless user_2.has_name?
        user_2.update_from_db_name
        user_2.save if user_2.has_name?
      end

      f_1_2 = user_1.friendships.find_or_initialize_by_friend_id_and_provider_and_social_id(user_2.id,
                                                                                            kind,
                                                                                            user_2_id)      

      f_1_2_new = f_1_2.new_record? && !new
      f_1_2.first_name = user_2.first_name
      f_1_2.last_name = user_2.last_name
      f_1_2.save

      f_2_1 = user_2.friendships.find_or_initialize_by_friend_id_and_provider_and_social_id(user_1.id,
                                                                                            kind,
                                                                                            user_1_id)

      f_2_1_new = f_2_1.new_record?
      f_2_1.first_name = user_1.first_name
      f_2_1.last_name = user_1.last_name
      f_2_1.save

      f_1_2.enqueue_new_friend_notification if f_1_2_new
      f_2_1.enqueue_new_friend_notification if f_2_1_new
    end
  end
                                                                        
  def enqueue_new_friend_notification
    message = "#{name} just joined Backchat!"

    hash = {
      apn_device_tokens: self.user.devices.where(kind: Device::APPLE).map {|d| d.device_token},
      gcm_device_tokens: self.user.devices.where(kind: Device::GOOGLE).map {|d| d.device_token},

      apn_hash: {
        custom: {friendship_id: self.id, kind: KIND_FRIEND_NOTIF},
        alert: message,
        badge: self.user.unread_messages,
      },

      google_hash: {
        message: message,
        unread_count: self.user.unread_messages,
        friendship_id: self.id,
        kind: KIND_FRIEND_NOTIF,
      }
    }

    Resque.enqueue(FriendNotificationQueue, hash)
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

    if BACKDOOR_ENV=='release'
      level = ActiveRecord::Base.logger.level
      ActiveRecord::Base.logger.level = Logger::WARN
    end

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

    if BACKDOOR_ENV=='release'
      ActiveRecord::Base.logger.level = level
    end

    self.total_count += 1
    self.unread_count += 1 unless sent

    summary = msg.summary
    unless summary.nil? or summary.empty?
      self.content_cache = (self.content_cache + ' ' + summary).strip.last(250)
      self.content_summary = summary.last(50)
    end

    self.save

    if !self.user.fake && self.user.registered && self.user.fb_id != FACTORY_USER_UID
      msg_obj = msg.build_notification_hash
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
   
    return if data.empty?

    #we want one insert query please.
    sql = 'INSERT INTO CLUES ("created_at", "field", "gab_id", "number", "revealed", "updated_at", "user_id", "value") VALUES '

    connection = ActiveRecord::Base.connection

    sql += data.each_with_index.map {|item, i|
      "( now(), #{connection.quote item.kind.to_s}, #{self.id}, #{i}, false, now(), #{self.user.id}, #{connection.quote item.value}) "}.join ","

    connection.execute sql

    Gab.update_counters self.id, clue_count: data.count
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

  def build_notification_hash
    sender = gab.related_user_name
    sender = 'Someone' if sender.blank?

    message_preview = !!user.settings["message_preview"]

    if message_preview and self.summary.length > 0
      alert = "%s: %s" % [sender, summary]
    else
      alert = "%s sent you a Backdoor message." % sender
    end

    short_message = alert
    if short_message.length > 80
      short_message = short_message[0..76] + "..."
    end
    
    {
      apn_device_tokens: user.devices.where(kind: Device::APPLE).map {|d| d.device_token},
      gcm_device_tokens: user.devices.where(kind: Device::GOOGLE).map {|d| d.device_token},      
      apn_hash: {
        custom: {gab_id: gab.id, kind: KIND_MSG_NOTIF},
        alert: short_message,
        badge: user.unread_messages,
      },
      google_hash: {
        message: alert,
        unread_count: user.unread_messages,
        gab_id: gab.id,
        kind: KIND_MSG_NOTIF
      }
    }
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

  def self.auth_fb(access_token)

    client = HTTPClient.new
    url = 'https://graph.facebook.com/me'
    resp = client.get(url, :access_token => access_token)
    data = JSON.parse(resp.content)

    return nil unless data['id']

    user = User.find_by_fb_id(data['id'])
    user = User.find_by_email(data['email']) unless user
    user = User.create unless user

    new_user = !user.registered

    user.update_attributes(
      :email => data['email'] || '',
      :fb_id => data['id'],
      :registered => true
    )

    { :user => user, :new_user => new_user }
  end

  def self.auth_gpp(access_token)

    client = HTTPClient.new
    url = 'https://www.googleapis.com/oauth2/v1/tokeninfo'
    resp = client.get(url, :access_token => access_token, :prettyPrint => true)
    data = JSON.parse(resp.content)

    return nil unless data['user_id']

    user = User.find_by_gpp_id(data['user_id'])
    user = User.find_by_email(data['email']) unless user
    user = User.create unless user

    new_user = !user.registered

    user.update_attributes(
      :email => data['email'],
      :gpp_id => data['user_id'],
      :registered => true
    )

    { :user => user, :new_user => new_user }
  end

  def self.token_authenticate(access_token)
    token = Token.find_by_access_token(access_token)
    return token.nil? ? nil : token
  end

  def self.authenticate(access_token, provider)
    if provider == 'facebook'
      resp = self.auth_fb(access_token)
    elsif provider == 'gpp'
      resp = self.auth_gpp(access_token)
    else
      return err 403, 'forbidden'
    end

    return nil unless resp

    user = resp[:user]
    new_user = resp[:new_user]

    token = user.tokens.create(:access_token => access_token)

    [user, new_user]
  end
end

class Device < ActiveRecord::Base
  belongs_to :user

  APPLE = "APPLE"
  GOOGLE = "GOOGLE"

  def self.my_find_or_create(device_token, kind, user)
    return if device_token.nil?

    device = Device.find_by_device_token_and_kind(device_token, kind)
    if device.nil?
      device = Device.new(device_token: device_token, kind: kind, user_id: user.id)
    else
      device.user = user
    end

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

class Invitation < ActiveRecord::Base
  belongs_to :user
  belongs_to :contact

  after_save :send_invitation  

  CancelMsg = "(REPLY STOP TO CANCEL)"
  
  validates_length_of :body, :maximum => 181 - CancelMsg.length

  def send_invitation
    if !self.delivered && contact.enabled == "t" #urgh, fix this later
      Resque.enqueue(InviteSMSQueue, self.id)
    end
  end
end

class Contact < ActiveRecord::Base
  #todo validates number
end

class FilterSQLLogger < Logger
  def add_with_truncate(level, msg = nil, procinfo = nil, &block) 
    unless msg
      if block_given?
        msg = yield
      else
        msg = procinfo
      end
    end

    msg = msg.gsub(/(gpp_data|fb_data)" = '.*'/m, '\1" = \'REDACTED\'')

    add_without_truncate(level, msg)
  end

  alias_method_chain :add, :truncate
end

ActiveRecord::Base.logger = FilterSQLLogger.new(STDOUT)
use ActiveRecord::QueryCache
ActiveRecord::Base.connection.enable_query_cache!
