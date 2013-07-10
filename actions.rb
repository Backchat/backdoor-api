
before do
  access_token = params[:access_token]
  device_token = params[:device_token]
  provider = params[:provider]
  fb_data = JSON.parse(params[:fb_data]) unless params[:fb_data].blank?
  gpp_data = JSON.parse(params[:gpp_data]) unless params[:gpp_data].blank?
  blitz_token = params[:blitz_token]

  return if request.path == '/admin' or request.path == '/images' or request.path == '/ping' or request.path == '/fb-update'

  err 400, 'invalid request' if access_token.nil?

  @blitz_mode = (blitz_token == BLITZ_TOKEN)

  token = Token.token_authenticate(access_token)

  if token.nil?
    auth = Token.authenticate(access_token, provider, fb_data, gpp_data)
    @user = auth[0]
    @new_user = auth[1]
  else
    @user = token.user
    @new_user = false

    if @user.fb_data != fb_data && !fb_data.blank?
      @user.fb_data = fb_data
      @user.save
    end
    if @user.gpp_data != gpp_data && !gpp_data.blank?
      @user.gpp_data = gpp_data
      @user.save
    end
  end

  device = Device.my_find_or_create(device_token, @user)
  Gab.current_user = @user
end

post '/sync' do
  gab_id = params[:gab_id]
  unless gab_id.nil?
    gab = @user.gabs.find_by_id(gab_id)
    gab.mark_read unless gab.nil?
  end

  ok :sync_data => sync_data
end


post '/create-message' do
  content = params[:content]
  kind = params[:kind]
  key = params[:key] || ''

  err 400, 'invalid request' if content.blank? or kind.blank?
 
  gab_id = params[:gab_id]
  kind = kind.to_i

  unless gab_id.nil?
    gab = Gab.find(gab_id)
  else
    receiver_fb_id = params[:receiver_fb_id]
    receiver_gpp_id = params[:receiver_gpp_id]
    receiver_email = params[:receiver_email]
    receiver_phone = params[:receiver_phone]
    related_user_name = params[:related_user_name]
    related_phone = params[:related_phone]
    receiver = User.my_find_or_create(receiver_fb_id, receiver_gpp_id, receiver_email, receiver_phone, @blitz_mode)
    err 404, 'user not found' unless receiver

    gab = Gab.my_create(@user, receiver, related_user_name, related_phone)
  end

  gab.create_message(content, kind, true, key)
  gab.related_gab.create_message(content, kind, false, key)

  gab.mark_read

  ok :gab_id => gab.id, :sync_data => sync_data
end

post '/featured-users' do
  ok :users => User.dump_featured(@user)
end

post '/request-clue' do
  number = params[:number]
  gab_id = params[:gab_id]

  err 400, 'invalid request' if number.blank? or gab_id.blank?

  gab = Gab
    .where('user_id = ?', @user)
    .find(params[:gab_id])

  clues = gab.clues.where(:number => number.to_i)

  err 400, 'invalid request' if clues.count == 0

  clue = clues[0].reveal
  success = !clue.nil?

  ok :success => success, :sync_data => sync_data
end

post '/check-uid' do
  uid = params[:uid]
  user = User.find_by_fb_id(uid)
  user = User.find_by_gpp_id(uid) if user.nil?
  exists = (!user.nil?) && user.registered #&& user.uid != FACTORY_USER_UID
  ok :uid_exists => (exists ? 'yes' : 'no')
end

post '/clear-gab' do
  gab = Gab
    .where('user_id = ?', @user)
    .includes(:messages)
    .find(params[:id])
  gab.mark_deleted
  ok :sync_data => sync_data
end

post '/tag-gab' do
  gab = Gab
    .where('user_id = ?', @user)
    .find(params[:id])

  gab.related_user_name = params[:tag]
  gab.save

  ok :sync_data => sync_data
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

  product = products[product_id]

  err 400, 'invalid receipt' unless product

  pur = Purchase.find_or_create_by_transaction_id(transaction_id)
  err 400, 'invalid receipt' if pur.user.present? and pur.user_id != @user.id



  pur.update_attributes(
    :user => @user,
    :clues => product
  )

  ok :sync_data => sync_data
end

post '/free-clues' do
  reason = params[:reason]

  #err 400, 'unknown reason' unless reason == 'debug' or  CLUE_REASONS.include?(reason)

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

  ok :count => count, :sync_data => sync_data
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

  ok :sync_data => sync_data
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
  data = JSON.load(request.body.read)
  data['entry'].each do |entry|
    uid = entry['uid']
    user = User.where(:fb_id => uid)[0]
    next if user.nil?
    user.fetch_fb_friends
  end
  ok {}
end

post '/get-friends' do
  ok :friends => @user.get_friends
end

get '/ping' do
  ok :base_url => BASE_URL, :database_url => ENV['DATABASE_URL']
end

get '/admin' do
  protected!
  erb :admin
end
