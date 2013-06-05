require 'resque'

CURRENT_VERSION = '1.0_beta5.6'

BASE_URL = ENV['BACKDOOR_BASE_URL'] if ENV['BACKDOOR_BASE_URL']
BASE_URL = 'https://capricalabs.com:7564/' unless ENV['BACKDOOR_BASE_URL']

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

APN_CERT = File.dirname(__FILE__) + '/misc/cl_dev.pem'
APN_GATEWAY = 'gateway.sandbox.push.apple.com'
APN_CERT_PROD = File.dirname(__FILE__) + '/misc/cl_prod.pem'
APN_GATEWAY_PROD = 'gateway.push.apple.com'

BLITZ_TOKEN = '36a9c080ff6fdce0e32c66c3eb3edd9e'

FEEDBACK_EMAIL = 'number1@capricalabs.com'
ABUSE_REPORT_EMAIL = 'abuse@youtell.com'

MESSAGE_KIND_TEXT = 0
MESSAGE_KIND_PHOTO = 1

FACTORY_USER_UID = "100004777423660"

USER_DEFAULT_SETTINGS = {'message_preview' => false}

configure :production do
  require 'newrelic_rpm'
end

CLUES_001 = 9
CLUES_002 = 27
CLUES_003 = 72
CLUES_FREE = 9
CLUES_MAX = 9

CLUE_REASONS = ['fbshare', 'fblike', 'fbinvite', 'tweet', 'gppshare']

DB_TIMESTAMP = '2013-06-03T21:05:51+00:00'
