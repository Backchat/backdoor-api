require 'resque'

ENV['DATABASE_URL'] = ENV['HEROKU_POSTGRESQL_JADE_URL']  unless ENV['DATABASE_URL']
ENV['DATABASE_URL'] = 'postgres://localhost/youtell-api' unless ENV['DATABASE_URL']

ENV['REDISTOGO_URL'] = 'redis://localhost:6379/' unless ENV['REDISTOGO_URL']
Resque.redis = Redis.connect(:url => ENV['REDISTOGO_URL'])

set :public_folder, File.dirname(__FILE__) + '/static'
set :show_exceptions, false
set :dump_errors, false

SMTP_SETTINGS = {
  :address              => "smtp.gmail.com",
  :port                 => "587",
  :user_name            => "app@failin.gs",
  :password             => "dp@VP#09",
  :authentication       => "plain",
  :domain               => "mail.gmail.com",
  :enable_starttls_auto => true,
}

TWILIO_SID = 'AC3a0890f50305fd4b1eccbc2251025ae8'
TWILIO_TOKEN = '16efa8aa2178da2252a43ada84eea196'

APN_CERT = File.dirname(__FILE__) + '/misc/certificate.pem'
APN_PASS = ''

BLITZ_TOKEN = '36a9c080ff6fdce0e32c66c3eb3edd9e'

FEEDBACK_EMAIL = 'qx89l4+workspam@gmail.com'

MESSAGE_KIND_TEXT = 0
MESSAGE_KIND_PHOTO = 1

FACTORY_USER_UID = "100004777423660"

configure :production do
  require 'newrelic_rpm'
end
