require './api'
require 'resque/server'

run Rack::URLMap.new \
  "/"       => Sinatra::Application.new,
  "/resque" => Resque::Server.new
