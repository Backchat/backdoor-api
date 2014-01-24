before do
  return if ['/admin', '/images', '/ping', '/fb-update', '/login'].include? request.path

  @access_token = params[:access_token]

  return err 401, 'invalid token' if @access_token.nil?

  @access_token = @access_token.gsub('%2F', '/')

  blitz_token = params[:blitz_token]
  @blitz_mode = (blitz_token == BLITZ_TOKEN)

  token = Token.token_authenticate(@access_token)

  if token.nil?
    puts "bad token #{@access_token}"
    return err 401, 'invalid token'
  else
    @user = token.user
    @new_user = false
  end
end

post '/login' do
  access_token = params[:access_token]

  return err 400, "invalid request" if access_token.blank? 

  #check to see if the token already exists
  token = Token.find_by_access_token(access_token)
  return ok token.user if token

  #if not, then we have either a new user or a user reauthenticating with a new token.
  provider = params[:provider]
  return err 400, "invalid request" unless !provider.blank?

  auth = Token.authenticate(access_token, provider)

  return err 400, "invalid request" unless auth

  user = auth[0]
  new_user = auth[1]

  #if this is a old client, we'll send a device_token to register:
  #if not, then we won't get one:
  if !params[:device_token].blank?
    device = Device.my_find_or_create(device_token, user)
  end

  #old clients use login to update extended fb/gpp info
  #new clients do this in POST later
  unless params[:fb_data].blank?
    fb_data = JSON.parse(params[:fb_data])
    update_fb_data(user, access_token, fb_data)
  end

  unless params[:gpp_data].blank?
    gpp_data = JSON.parse(params[:gpp_data])
    update_gpp_data(user, access_token, gpp_data)
  end

  user.save

  name = user.name
  ok user: {new_user: new_user, available_clues: user.available_clues, settings: user.settings, id: user.id, full_name: name}
end

get '/featured-users' do
  ok :users => User.dump_featured(@user)
end

post '/buy-clues' do
  if params[:receiptgoogle].present?
    data = JSON.parse(params[:receiptgoogle])
    transaction_id = "#{data["developerPayload"]}-#{data["orderId"]}-#{data["purchaseToken"]}"
    puts "google-receipt: #{data}" # {"orderId"=>"12999763169054705758.1346662564224406", "packageName"=>"com.youtell.backdoor", "productId"=>"clue_3", "purchaseTime"=>1383960854164, "purchaseState"=>0, "developerPayload"=>"44", "purchaseToken"=>"qlkcoebaojwfcnahkfehelob.AO-J1Oz6tnyiJxQneNOrYgnjLP75vrjJUrtC8LqdeOGEE9Vt-zw4e97JcxoKHmBkHssn0zcPEfglrnw8COBBQwCI5v3JO4DMNEDuDtV_yILJ71PHXgyPfyU"}

    #TODO merge with apple code
    products = {
      'clue_3' => CLUES_001,
      'clue_9' => CLUES_002,
      'clue_27' => CLUES_003
    }

    productId = data["productId"]
    product = products[productId]

    return err 402, 'invalid product' unless product

    pur = Purchase.find_or_create_by_transaction_id(transaction_id)

    return err 403, 'invalid receipt' if pur.user.present? && pur.user_id != @user.id
    
    pur.update_attributes(:user => @user, :clues => product)

    ok :available_clues => @user.available_clues
  else
    return do_apple_receipt
  end
end

def do_apple_receipt
  receipt = params[:receipt]
  data = { 'receipt-data' => receipt }.to_json
  url = RECEIPT_VERIFY_URL
  client = HTTPClient.new
  resp = client.post(url, data)
  data = JSON.parse(resp.content)

  puts data

  return err 401, 'invalid receipt' if data['status'] != 0

  transaction_id = data['receipt']['original_transaction_id']
  transaction_id = data['receipt']['transaction_id'] unless transaction_id
  product_id = data['receipt']['product_id']

  product_id = product_id.sub(PRODUCT_ID_SUFFIX, '') unless PRODUCT_ID_SUFFIX.blank?

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

  
  puts "product: #{product}"
  return err 402, 'invalid product' unless product

  pur = Purchase.find_or_create_by_transaction_id(transaction_id)
  puts "purcahse: #{pur}"

  return err 403, 'invalid receipt' if pur.user.present? and pur.user_id != @user.id

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

  ok :count => count, :available_clues => @user.available_clues
end

post '/feedbacks' do
  content = params[:content]
  rating = params[:rating]

  return err 400 if content.blank? or rating.blank?

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

  return err 400, 'invalid request' if secret.blank?

  image = Image.find_by_secret(secret)

  return err 404, 'File not found' if image.nil?

  content_type image.content_type
  image.data
end

post '/report-abuse' do
  content = params[:content]
  
  return err 400, 'invalid request' if content.blank?

  ar = AbuseReport.create(:content => content, :user => @user)

  ok {}
end

post '/update-settings' do
  key = params[:key]
  value = params[:value]
  value = JSON.load(value)

  return err 400, 'invalid request' if key.blank? or value.blank?

  @user.settings[key] = value["value"]
  @user.save

  ok
end

get '/fb-update' do
  mode = params['hub.mode']
  ch = params['hub.challenge']
  token = params['hub.verify_token']

  return err 400, 'invalid request' if mode != 'subscribe'
  return err 400, 'invalid request' if token != 'caplabs'

  return ch
end

post '/fb-update' do
  request.body.rewind
  data = JSON.parse(request.body.read)
  uids = data['entry'].map {|entry|
    entry['uid']}.compact

  valid_uids = User.select([:id]).find_all_by_fb_id(uids)

  valid_uids.each do |u|
    Resque.enqueue(UpdateFriendsQueue, u.id, nil, false, Friendship::FACEBOOK_PROVIDER)
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
