
before do
  access_token = params[:access_token]
  device_token = params[:device_token]
  user_data = params[:user_data]
  blitz_token = params[:blitz_token]

  return if request.path == '/admin'

  err 400, 'invalid request' if access_token.nil?

  @blitz_mode = (blitz_token == BLITZ_TOKEN)

  token = Token.authenticate(access_token, user_data)
  device = Device.my_find_or_create(device_token, token.user)

  @user = token.user
  Gab.current_user = token.user

  @user.update_attributes(:data => @user.data.update(user_data)) unless user_data.blank?
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
    receiver_name = params[:receiver_name]
    receiver = User.my_find_or_create(receiver_uid, receiver_email, receiver_phone, @blitz_mode)
    err 404, 'user not found' unless receiver

    gab = Gab.my_create(@user, receiver, receiver_name)
  end

  gab.create_message(content, kind, true)
  gab.related_gab.create_message(content, kind, false)

  gab.mark_read

  ok :gab_id => gab.id, :sync_data => sync_data
end

get '/gabs/:id' do
  gab = Gab
    .where('user_id = ?', @user)
    .includes(:messages)
    .find(params[:id])

  json = gab.as_json_full
  gab.mark_read
  ok json
end


post '/request-clue' do
  gab = Gab
    .where('user_id = ?', @user)
    .find(params[:gab_id])

  clue = gab.create_clue

  ok :sync_data => sync_data
end

post '/gab-delete' do
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

get '/ping' do
  ok 'pong'
end

get '/admin' do
  protected!
  erb :admin
end
