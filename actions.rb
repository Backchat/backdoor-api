require 'httpclient'

before do
  return if request.path == '/users/login' or request.path == '/admin'

  @session = Session.find_by_token(params[:session_token])
  err 403, 'not authorized' unless @session
  @user = @session.user
  Gab.current_user = @user
end

post '/users/login' do

  access_token = params[:access_token]
  device_token = params[:device_token]
  user_data = params[:user_data]

  err 400, 'invalid request' if access_token.nil? or device_token.nil? or user_data.nil?

  client = HTTPClient.new
  url = 'https://graph.facebook.com/me'
  resp = client.get(url, :access_token => access_token)
  data = JSON.parse(resp.content)

  err 403, 'forbidden' unless data['id']

  user = User.find_by_uid(data['uid'])
  user = User.find_by_email(data['email']) unless user
  user = User.create unless user

  user_data = user_data.update(data)
  user_data = user.data.update(user_data)

  user.update_attributes(
    :email => data['email'],
    :uid => data['id'],
    :data => user_data,
    :registered => true
  )

  device = Device.find_or_create_by_token(device_token)
  device.update_attributes(:user => user)

  session = user.sessions.create

  ok(
    :session_token => session.token,
    :available_clues => user.available_clues,
  )
end

get '/gabs' do
  ok Gab
    .where('user_id = ? OR receiver_id = ?', @user, @user)
    .order('updated_at')
    .paginate(:page => params[:page].to_i)
end


post '/gabs' do
  title = params[:title]
  content = params[:content]
  user_data = params[:user_data]

  err 400, 'invalid request' if title.blank? or content.blank? or user_data.blank?

  receiver = User.my_find_or_create(
    params[:receiver_uid],
    params[:receiver_email],
    params[:receiver_phone],
  )

  err 404, 'user not found' unless receiver

  gab = @user.gabs.create(
    :title => title,
    :receiver => receiver
  )

  @user.update_attributes(:data => @user.data.update(user_data))

  message = gab.messages.create(
    :content => content,
    :user => @user
  )

  ok gab
end

get '/gabs/:id' do
  gab = Gab
    .where('user_id = ? OR receiver_id = ?', @user, @user)
    .includes(:messages)
    .find(params[:id])

  json = gab.as_json_full
  gab.mark_read
  ok json
end

post '/gabs/:id' do
  content = params[:content]
  user_data = params[:user_data]

  err 400, 'invalid request' if content.blank? or user_data.blank?

  @user.update_attributes(:data => @user.data.update(user_data))

  gab = Gab
    .where('user_id = ? OR receiver_id = ?', @user, @user)
    .find(params[:id])

  message = gab.messages.create(
    :content => content,
    :user => @user
  )

  ok gab
end

post '/gabs/:id/clues' do
  gab = Gab
    .where('receiver_id = ?', @user)
    .find(params[:id])

  clue = gab.create_clue

  err 400, 'no available clues' if clue.nil?
  ok clue
end

post '/purchases' do
  receipt = params[:receipt]

  data = { 'receipt-data' => receipt }.to_json
  url = 'https://sandbox.itunes.apple.com/verifyReceipt'
  client = HTTPClient.new
  resp = client.post(url, data)
  data = JSON.parse(resp.content)

  #err 400, 'invalid receipt' if data['status'] != 0

  pur = Purchase.find_or_create_by_receipt(receipt)

  err 400, 'invalid receipt' if pur.user.present? and pur.user_id != @user.id

  pur.update_attributes(
    :user => @user,
    :clues => 3
  )

  ok @user.available_clues
end

get '/admin' do
  protected!
  erb :admin
end
