ENV['DATABASE_URL'] = ENV['HEROKU_POSTGRESQL_JADE_URL']  unless ENV['DATABASE_URL']
ENV['DATABASE_URL'] = 'postgres://localhost/youtell-api' unless ENV['DATABASE_URL']

set :public_folder, File.dirname(__FILE__) + '/static'
set :show_exceptions, false
set :dump_errors, false
