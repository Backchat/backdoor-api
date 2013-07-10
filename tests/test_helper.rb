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

end
