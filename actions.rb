
before do
  return if ['/admin', '/images', '/ping', '/fb-update', '/login'].include? request.path

  access_token = params[:access_token]

  err 400, 'invalid request' if access_token.nil?

  blitz_token = params[:blitz_token]
  @blitz_mode = (blitz_token == BLITZ_TOKEN)

  token = Token.token_authenticate(access_token)

  if token.nil?
    return err 400, "invalid request"
  else
    @user = token.user
    @new_user = false
  end
end

post '/login' do
  access_token = params[:access_token]
  device_token = params[:device_token]
  provider = params[:provider]

  return err 400, "invalid request" if access_token.blank? || device_token.blank? || provider.blank? || !(params[:fb_data].present? || params[:gpp_data].present?)

  return ok new_user: false if Token.find_by_access_token(access_token)

  fb_data = JSON.parse(params[:fb_data]) unless params[:fb_data].blank?
  gpp_data = JSON.parse(params[:gpp_data]) unless params[:gpp_data].blank?

  auth = Token.authenticate(access_token, provider, fb_data, gpp_data)
  user = auth[0]
  new_user = auth[1]
  device = Device.my_find_or_create(device_token, user)

  if user.fb_data != fb_data && !fb_data.blank?
    user.fb_data = fb_data
  end
  if user.gpp_data != gpp_data && !gpp_data.blank?
    user.gpp_data = gpp_data
  end

  user.save
  ok new_user: new_user
end

get '/featured-users' do
  ok :users => User.dump_featured(@user)
end

post '/buy-clues' do
  receipt = params[:receipt]

  data = { 'receipt-data' => receipt }.to_json
  url = RECEIPT_VERIFY_URL
  client = HTTPClient.new
  resp = client.post(url, data)
  data = JSON.parse(resp.content)

  err 400, 'invalid receipt' if data['status'] != 0

  transaction_id = data['receipt']['original_transaction_id']
  product_id = data['receipt']['product_id']

  products = {
    'YouTell_Mobile_Clues_001' => CLUES_001,
    'YouTell_Mobile_Clues_002' => CLUES_002,
    'YouTell_Mobile_Clues_003' => CLUES_003
  }

  revenues = {
    'YouTell_Mobile_Clues_001' => CLUES_REVENUE_001,
    'YouTell_Mobile_Clues_002' => CLUES_REVENUE_002,
    'YouTell_Mobile_Clues_003' => CLUES_REVENUE_003
  }


  product = products[product_id]


  err 400, 'invalid product' unless product

  pur = Purchase.find_or_create_by_transaction_id(transaction_id)
  err 400, 'invalid receipt' if pur.user.present? and pur.user_id != @user.id

  revenue = pur.user.nil? ? revenues[product_id] : 0

  pur.update_attributes(
    :user => @user,
    :clues => product
  )

  ok :revenue => revenue
end

post '/free-clues' do
  reason = params[:reason]

  if reason != 'debug'
    reason = 'freeclues'
  end

  if reason != 'debug'
    reason = 'freeclues'
  end

  count = 0
  pur = Purchase.find_by_user_id_and_transaction_id(@user, reason)

  if pur.nil?
    count = CLUES_FREE
    pur = Purchase.create(:transaction_id => reason, :user => @user, :clues => count)
    @user.settings['has_shared'] = true
    @user.save
  elsif reason == 'debug'
    count = CLUES_FREE
    pur.clues += count
    pur.save
  end

  ok :count => count
end

post '/feedbacks' do
  content = params[:content]
  rating = params[:rating]

  err 400 if content.blank? or rating.blank?

  Feedback.create(
    :user => @user,
    :content => content,
    :rating => rating
  )

  ok {}
end

post '/check-updates' do
  ok :current_version => CURRENT_VERSION
end

get '/images' do
  secret = params[:secret]

  err 400, 'invalid request' if secret.blank?

  image = Image.find_by_secret(secret)

  err 404, 'File not found' if image.nil?

  content_type image.content_type
  image.data
end

post '/report-abuse' do
  content = params[:content]

  err 400, 'invalid request' if content.blank?

  ar = AbuseReport.create(:content => content, :user => @user)

  ok {}
end

post '/update-settings' do
  key = params[:key]
  value = params[:value]
  value = JSON.load(value)

  err 400, 'invalid request' if key.blank? or value.blank?

  @user.settings[key] = value["value"]
  @user.save

  ok
end

get '/fb-update' do
  mode = params['hub.mode']
  ch = params['hub.challenge']
  token = params['hub.verify_token']

  err 400, 'invalid request' if mode != 'subscribe'
  err 400, 'invalid request' if token != 'caplabs'

  return ch
end

post '/fb-update' do
  request.body.rewind
  data = JSON.parse(request.body.read)
  data['entry'].each do |entry|
    uid = entry['uid']
    user = User.find_by_fb_id(uid)
    user.fetch_fb_friends unless user.nil?
  end
  ok {}
end

get '/ping' do
  ok :base_url => BASE_URL
end

get '/admin' do
  protected!
  erb :admin
end
