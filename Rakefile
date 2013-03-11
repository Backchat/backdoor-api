require './api'
require 'resque/tasks'
require 'resque_scheduler/tasks'
require 'sinatra/activerecord/rake'


namespace :resque do
  task :setup do
    require 'resque'
    require 'resque_scheduler'
    require 'resque/scheduler'

    Resque.schedule = {"DeviceCleanupQueue"=>{"cron"=>"0 * * * *"}}
  end

  task :clear  do
    Resque.redis.del 'queue:message_delivery'
    Resque.redis.del 'queue:feedback_delivery'
    Resque.redis.del 'queue:device_cleanup'
  end
end
