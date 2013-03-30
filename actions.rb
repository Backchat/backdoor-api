
before do
  access_token = params[:access_token]
  device_token = params[:device_token]
  user_data = params[:user_data]
  blitz_token = params[:blitz_token]

  return if request.path == '/admin' or request.path == '/images'

  err 400, 'invalid request' if access_token.nil?

  @blitz_mode = (blitz_token == BLITZ_TOKEN)

  auth = Token.authenticate(access_token, user_data)
  token = auth[0]
  device = Device.my_find_or_create(device_token, token.user)

  @user = token.user
  Gab.current_user = token.user

  @user.update_attributes(:data => @user.data.update(user_data)) unless user_data.blank?
  @new_user = auth[1]
end

get '/gabs' do
  ok :sync_data => sync_data
end


post '/gabs' do
  content = params[:content]
  kind = params[:kind]
  user_data = params[:user_data]

  err 400, 'invalid request' if content.blank? or kind.blank?
 
  gab_id = params[:gab_id]
  kind = kind.to_i

  unless gab_id.nil?
    gab = Gab.find(gab_id)
  else
    receiver_uid = params[:receiver_uid]
    receiver_email = params[:receiver_email]
    receiver_phone = params[:receiver_phone]
    related_user_name = params[:related_user_name]
    related_phone = params[:related_phone]
    receiver = User.my_find_or_create(receiver_uid, receiver_email, receiver_phone, @blitz_mode)
    err 404, 'user not found' unless receiver

    gab = Gab.my_create(@user, receiver, related_user_name, related_phone)
  end

  gab.create_message(content, kind, true)
  gab.related_gab.create_message(content, kind, false)

  gab.mark_read

  ok :gab_id => gab.id, :sync_data => sync_data
end

post '/request-clue' do
  gab = Gab
    .where('user_id = ?', @user)
    .find(params[:gab_id])

  clue = gab.create_clue

  ok :sync_data => sync_data
end

get '/check-uid' do
  uid = params[:uid]
  user = User.find_by_uid(uid)
  exists = (!user.nil?) && user.registered && user.uid != FACTORY_USER_UID
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


post '/buy-clues' do
  receipt = params[:receipt]

  data = { 'receipt-data' => receipt }.to_json
  url = 'https://sandbox.itunes.apple.com/verifyReceipt'
  client = HTTPClient.new
  resp = client.post(url, data)
  data = JSON.parse(resp.content)

  err 400, 'invalid receipt' if data['status'] != 0

  transaction_id = data['receipt']['original_transaction_id']
  product_id = data['receipt']['product_id']

  products = {
    'YouTell_Mobile_Clues_001' => 3,
    'YouTell_Mobile_Clues_002' => 10,
    'YouTell_Mobile_Clues_003' => 15
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

get '/images' do
  secret = params[:secret]

  err 400, 'invalid request' if secret.blank?

  image = Image.find_by_secret(secret)

  err 404, 'File not found' if image.nil?

  content_type image.content_type
  image.data
end

get '/ping' do
  ok 'pong'
end

get '/admin' do
  protected!
  erb :admin
end
