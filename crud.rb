# CRUD apis for data
# gab
# before in actions.rb gets us validated and gets us the @user

def invalid_request
  err 400, 'invalid_request'
end

get '/gabs' do
  ok :gabs => @user.gabs.all.map{|g| g.as_json()["gab"]}
end

post '/gabs' do
  message_params = params[:message]
  receiver = params[:friendship]

  return invalid_request if message_params.blank? or receiver.blank?

  r_friendship = Friendship.find_by_id(receiver[:id])

  #TODO add tests for this
  return err(400, 'friendship does not exist') if r_friendship.blank?
  return invalid_request if r_friendship.user != @user
  r_user = r_friendship.friend

  gab = Gab.my_create(@user, r_user, r_friendship.name, r_user.phone) #TODO fix my_create 
  message = gab.create_message_from_params(message_params)  
  
  #TODO make tests pass here, fix this ugly, DRY with get, put in model
  hsh = gab.as_json
  hsh["gab"]["messages"] = [message.as_json()["message"]]
  ok hsh
end

['/gabs/:gab_id', '/gabs/:gab_id/*'].each do |path|
  before path do
    @gab = @user.gabs.find(params[:gab_id])
    return invalid_request if @gab.nil?
  end
end

get '/gabs/:gab_id' do
  hsh = @gab.as_json
  if !params[:extended].blank? && params[:extended]
    ar = @gab.messages.visible.all.map {|m| m.as_json()["message"]} #drop message key
    hsh["gab"]["messages"] = ar
  end
  ok hsh
end

post '/gabs/:gab_id' do
  if params[:related_user_name].present?
    @gab.related_user_name = params[:related_user_name]
    @gab.save
    ok @gab
  else
    return invalid_request
  end
end

delete '/gabs/:gab_id' do
  @gab.mark_deleted
  ok @gab
end

get '/gabs/:gab_id/messages' do
  #TODO pagination
  ar = @gab.messages.visible.all.map {|m| m.as_json()["message"]} #drop message key
  ok :messages => ar
end

post '/gabs/:gab_id/messages' do
  message = @gab.create_message_from_params(params)
  if message.nil?
    return invalid_request
  else
    ok message
  end
end

get '/gabs/:gab_id/clues/' do
  #TODO test this
  ok clues: @gab.clues.all.map {|c| c.as_json()[:clue]}, available_clues: @user.available_clues
end

post '/gabs/:gab_id/clues/request/:number' do
  number = params[:number].to_i
  clue = @gab.clues.find_by_number(number)
  return invalid_request if clue.nil?
  if clue.reveal.nil?
    err 400, "request failed"
  else
    ok clue
  end
end

delete '/gabs/:gab_id/messages/:message_id' do
  return invalid_request #TODO we do not support deleting a message
end

get '/friends' do
  #TODO make this happen when you sign up...
  if @user.friendships.count == 0
    @user.fetch_friends
  end

  ok :friends => @user.friendships.map{|f| f.as_json["friendship"]}
end

get '/' do
  #get information about myself
  ok available_clues: @user.available_clues
end

post '/' do
  #update fb_data, gpp_data
  fb_data = JSON.parse(params[:fb_data]) unless params[:fb_data].blank?
  gpp_data = JSON.parse(params[:gpp_data]) unless params[:gpp_data].blank?

  if !fb_data && !gpp_data
    return invalid_request
  else
    @user.fb_data = fb_data
    @user.gpp_data = gpp_data
    @user.save
    ok
  end
end

# users in actions
# featured-users 
# buy-clues 
# free-clues
# feedbacks
# check-updates
# ping
