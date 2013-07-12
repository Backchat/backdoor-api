# test_helper.rb
ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'rack/test'
require './api.rb' 
require 'blueprints.rb'
require 'resque_spec/scheduler'
require 'json_expressions/minitest'

class BackdoorMiniTestUnit < MiniTest::Unit
  def before_suites
    puts "-"*20+"\nMOCK USERS\n"+"-"*20
    @@users = mock_users
    puts "-"*20+"\nBEGIN TESTS\n"+"-"*20
  end

  def self.users
    @@users
  end
  
  def after_suites
    #truncate it all
    ActiveRecord::Base.establish_connection
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.execute("TRUNCATE #{table}")
    end
  end

  def _run_suites(suites, type)
    begin
      before_suites
      super(suites, type)
    ensure
      after_suites
    end
  end
  
  def _run_suite(suite, type)
    begin
      suite.before_suite if suite.respond_to?(:before_suite)
      super(suite, type)
    ensure
      suite.after_suite if suite.respond_to?(:after_suite)
    end
  end
end

MiniTest::Unit.runner = BackdoorMiniTestUnit.new

class BackdoorTestCase < MiniTest::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end

  [:get, :post, :delete].each do |method|
    define_method "auth_#{method}" do |user, url, params={}|
      assert user, "user is nil"
      assert user.tokens.count >= 1, "user has no access_tokens"
      params[:access_token] = user.tokens.first.access_token
      self.send method, url, params
    end
    
    define_method "auth_#{method}_ok" do |user, url, params={}|
      self.send "auth_#{method}", user, url, params
      assert last_response.ok?, "authenticated #{method} request failed with body #{last_response.body}"
    end
  end

  def response_ok resp
    {
      status: "ok",
      response: resp
    }
  end
  
  def setup
    @users = BackdoorMiniTestUnit.users
    @john = @users[0]
    @mary = @users[1]
  end

  #helpers
  def generate_gab_json gab, opt
    {
      gab: {
        clue_count: opt[:clue_count]||gab.clue_count,
        id: opt[:id]||gab.id,
        related_avatar: opt[:related_avatar]||gab.related_avatar,
        related_phone: opt[:related_phone]||gab.related_phone,
        related_user_name: opt[:related_user_name]||gab.related_user_name,
        updated_at: wildcard_matcher,
        sent: opt[:sent] || gab.sent,
        total_count: opt[:total_count]||gab.total_count,
        unread_count: opt[:unread_count]||gab.unread_count,
        content_cache: opt[:content_cache]||gab.content_cache,
        content_summary: opt[:content_summary]||gab.content_summary
      }
    }
  end

  def generate_message_json message, opt={}
    m =
      {
      content: message.content,
      deleted: message.deleted,
      key: wildcard_matcher,
      read: message.read,
      secret: "",
      sent: message.sent,
      created_at: wildcard_matcher,
      id: Fixnum,
      kind: message.kind,
      user_id: message.user_id
    }

    m[:gab_id] = message.gab.id #TODO ? if opt[:include_gab_id]

    return m
  end

  def generate_message_param content="A new message", kind=0, key=""
    {content: content, kind: kind, key: key}
  end
end
