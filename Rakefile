require './api'
require 'resque/tasks'
require 'resque_scheduler/tasks'
require 'sinatra/activerecord/rake'

namespace :resque do
  task :setup do
    require 'resque'
    require 'resque_scheduler'
    require 'resque/scheduler'

    Resque.before_fork = Proc.new { ActiveRecord::Base.establish_connection }
    Resque.schedule = {"DeviceCleanupQueue"=>{"cron"=>"0 * * * *"}}
  end

  task :clear  do
    Resque.redis.del 'queue:message_delivery'
    Resque.redis.del 'queue:feedback_delivery'
    Resque.redis.del 'queue:device_cleanup'
  end
end

namespace :db do
  task :create_factory_user do
    user = User.create({
      :fb_id => FACTORY_USER_UID,
      :registered => true,
      :fb_data => {}
    })
  end
end

require 'rake/testtask'
Rake::TestTask.new do |test|
  test.warning = false
  test.libs = ["tests"]
  test.test_files = FileList['tests/*_test.rb']
end