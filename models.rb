require 'sinatra/activerecord'
require 'will_paginate'
require 'will_paginate/active_record'

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

    user.update_attributes(
      :autocreated => true,
      :uid => uid,
      :email => email,
      :phone => phone,
      :data => {
        'email' => email,
        'id' => uid
      }
    ) unless user.nil? || user.registered

    user
  end

  def available_clues
    total = purchases.sum(:clues)
    used = clues.count
    total - used
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
  belongs_to :receiver, :class_name => 'User', :foreign_key => 'receiver'
  belongs_to :gab

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
