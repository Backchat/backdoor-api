require 'resque'
require 'airbrake'

CURRENT_VERSION = '1.0_beta5.6'

BASE_URL = ENV['BACKDOOR_BASE_URL'] if ENV['BACKDOOR_BASE_URL']
BASE_URL = 'http://capricalabs.com:7564/' unless ENV['BACKDOOR_BASE_URL']

BACKDOOR_ENV = ENV['BACKDOOR_ENV'] if ENV['BACKDOOR_ENV']
BACKDOOR_ENV = 'debug' unless ENV['BACKDOOR_ENV']

ENV['DATABASE_URL'] = ENV['HEROKU_POSTGRESQL_AQUA_URL']  unless ENV['DATABASE_URL']
ENV['DATABASE_URL'] = 'postgres://localhost/youtell-api' unless ENV['DATABASE_URL']

ENV['REDISTOGO_URL'] = 'redis://localhost:6379/' unless ENV['REDISTOGO_URL']
Resque.redis = Redis.connect(:url => ENV['REDISTOGO_URL'])
module Cache
  class << self
    attr_accessor :redis
  end
end
Cache.redis = Redis.connect(:url => ENV['REDISTOGO_URL'])

ALL_QUEUES = ['message_delivery', 'friend_notification', 'feedback_delivery', 'abuse_report_delivery', 'device_cleanup', 'invite_sms']

set :public_folder, File.dirname(__FILE__) + '/static'
set :show_exceptions, false
set :dump_errors, false

SMTP_SETTINGS = {
  :address        => 'smtp.gmail.com',
  :port           => '587',
  :user_name      => 'app@failin.gs',
  :password       => 'dp@VP#09',
  :authentication => :plain,
  :domain         => "mail.gmail.com"
}

TWILIO_SID = 'AC5e6a2cc17a45d941252840c6ca7416ef'
TWILIO_TOKEN = '1346022d42253959d79e47b6c171914f'
TWILIO_NUMBER = '+14248357900'

if BACKDOOR_ENV == 'debug'
  APN_CERT = File.dirname(__FILE__) + '/misc/backdoor_dev.pem'
  APN_GATEWAY = 'gateway.sandbox.push.apple.com'
  RECEIPT_VERIFY_URL = 'https://sandbox.itunes.apple.com/verifyReceipt'
  PRODUCT_ID_SUFFIX = '_Dev'
  FACEBOOK_APP_SECRET = 'ccf194f1fb15d43e32ff24f705e14a77'
  FACEBOOK_APP_ID = '550948541621423'
  AIRBRAKE_TOKEN = '3bd6607eacd01e5e4376e2115e700540'
  GCM_SECRET_KEY = 'AIzaSyC9cnxNV-V8qOHTLxyxEBSEtzTss1stmSo'
elsif BACKDOOR_ENV == 'stage'
  APN_CERT = File.dirname(__FILE__) + '/misc/backdoor_stage.pem'
  APN_GATEWAY= 'gateway.push.apple.com'
  RECEIPT_VERIFY_URL = 'https://sandbox.itunes.apple.com/verifyReceipt'
  PRODUCT_ID_SUFFIX = '_Stage'
  FACEBOOK_APP_SECRET = 'b4c85880f9d0e30f2e192c51a7871095'
  FACEBOOK_APP_ID = '489124394513672'
  AIRBRAKE_TOKEN = '3bd6607eacd01e5e4376e2115e700540'
  GCM_SECRET_KEY = 'AIzaSyC9cnxNV-V8qOHTLxyxEBSEtzTss1stmSo'
elsif BACKDOOR_ENV == 'release'
  APN_CERT = File.dirname(__FILE__) + '/misc/cl_prod.pem'
  APN_GATEWAY = 'gateway.push.apple.com'
  RECEIPT_VERIFY_URL = 'https://buy.itunes.apple.com/verifyReceipt'
  PRODUCT_ID_SUFFIX = nil
  FACEBOOK_APP_SECRET = 'e40b47d88cca1ab20012e85c21da74bb'
  FACEBOOK_APP_ID = '122753474571987'
  AIRBRAKE_TOKEN = 'b759ebcaee4ac821de8eb104033079d7'
  GCM_SECRET_KEY = 'AIzaSyDpxoPG1K-iLvErrxQ_TsvYts3blmFTKeE'

end

BLITZ_TOKEN = '36a9c080ff6fdce0e32c66c3eb3edd9e'

FEEDBACK_EMAIL = 'abuse@getbackchat.com'
ABUSE_REPORT_EMAIL = 'abuse@getbackchat.com'

MESSAGE_KIND_TEXT = 0
MESSAGE_KIND_PHOTO = 1

FACTORY_USER_UID = "455627564507813"

USER_DEFAULT_SETTINGS = {'message_preview' => false}

configure :production do
  require 'newrelic_rpm'
end

CLUES_001 = 9
CLUES_002 = 27
CLUES_003 = 72
CLUES_FREE = 3
CLUES_DEFAULT = 3
CLUES_MAX = 9

CLUES_REVENUE_001 = 70
CLUES_REVENUE_002 = 140
CLUES_REVENUE_003 = 210

CLUE_REASONS = ['fbshare', 'fblike', 'fbinvite', 'tweet', 'gppshare']

KIND_FRIEND_NOTIF = 1
KIND_MSG_NOTIF = 0

DB_TIMESTAMP = '2013-06-18T21:05:51+00:00'

Airbrake.configure do |config|
  config.api_key = AIRBRAKE_TOKEN
  config.development_environments = []
end

use Airbrake::Rack
enable :raise_errors

$stdout.sync = true
