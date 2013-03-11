
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
end

get '/gabs' do
  page = params[:page]
  err 400, 'invalid request' if page.blank?

  time = Time.now

  gabs = Gab
    .where('user_id = ?', @user)
    .order('last_date DESC')
    .paginate(:page => page.to_i, :per_page => 10)

  ok :gabs => gabs, :time => time
end


post '/gabs' do
  content = params[:content]
  user_data = params[:user_data]

  err 400, 'invalid request' if content.blank? or user_data.blank?

  gab_id = params[:gab_id]

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

  gab.create_message(content, true)
  gab.related_gab.create_message(content, false)

  @user.update_attributes(:data => @user.data.update(user_data))

  json = gab.as_json_full
  gab.mark_read
  ok json
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
