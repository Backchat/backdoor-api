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
end
