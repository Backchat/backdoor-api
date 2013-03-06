require 'httpclient'

before do
  @blitz_mode = (params[:blitz_token] == BLITZ_TOKEN)
  return if request.path == '/users/login' or request.path == '/admin'

  access_token = params[:access_token]
  device_token = params[:device_token]
  user_data = params[:user_data]

  err 400, 'invalid request' if access_token.nil?

  @session = Session.find_by_token(access_token)
  if @session
    @user = @session.user
    Gab.current_user = @user
    return
  end

  client = HTTPClient.new
  url = 'https://graph.facebook.com/me'
  resp = client.get(url, :access_token => access_token)
  data = JSON.parse(resp.content)

  err 403, 'forbidden' unless data['id']

  user = User.find_by_uid(data['id'])
  user = User.find_by_email(data['email']) unless user
  user = User.create unless user

  user_data = {} if user_data.nil?
  user_data = user_data.update(data)
  user_data = user.data.update(user_data)

  user.update_attributes(
    :email => data['email'],
    :uid => data['id'],
    :data => user_data,
    :registered => true
  )

  unless device_token.nil?
    device = Device.find_or_create_by_token(device_token)
    device.update_attributes(:user => user)
    device.touch
  end

  @session = user.sessions.create(:token => access_token)
  @user = @session.user
  Gab.current_user = @user
end

get '/gabs' do
  page = params[:page]
  err 400, 'invalid request' if page.blank?
  ok Gab.get_recent(page)
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
    @blitz_mode
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

get '/ping' do
  ok 'pong'
end

get '/admin' do
  protected!
  erb :admin
end
