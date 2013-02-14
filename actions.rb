require 'httpclient'

before do
  return if request.path == '/users/login'

  @session = Session.find_by_token(params[:session_token])
  err 403, 'not authorized' unless @session
  @user = @session.user
end

post '/users/login' do
  client = HTTPClient.new
  resp = client.get('https://graph.facebook.com/me', :access_token => params[:access_token])
  data = JSON.parse(resp.content)

  err 403, 'forbidden' unless data['id']

  user = User.find_or_create_by_uid(data['id'])
  user.data = params[:data]
  user.save!

  session = user.sessions.create

  ok session.token
end

post '/users/logout' do
  @session.destroy
  ok
end

post '/topics' do
  ok Topic.create(
    :title => params[:title],
    :sender => @user,
    :receiver => @user
  ).as_json_basic(@user)
end

get '/topics' do
  ok Topic.paginate(:page => params[:page].to_i).map { |x| x.as_json_basic(@user) }
end

get '/topics/:id' do
  topic = Topic.find(params[:id])
  err 403, 'not authorized' unless topic.receiver_id == @user.id
  ok topic.as_json_full
end

put '/topics/:id' do
  topic = Topic.find params[:id]
  err 403, 'not authorized' unless topic.receiver_id == @user.id
  topic.title = params[:title] if params[:title]
  topic.save
  ok topic.as_json_basic(@user)
end

delete '/topics/:id' do
  topic = Topic.find params[:id]
  err 403, 'not authorized' unless topic.receiver_id == @user.id
  topic.destroy
  ok
end

post '/messages' do
  topic = Topic.find params[:topic_id]
  message = topic.messages.create :sender => @user, :content => params[:content]
  ok message.as_json_basic
end

get '/messages/:id/clues' do
  err 501, 'not implemented'
end

post '/messages/:id/clues' do
  err 501, 'not implemented'
end
