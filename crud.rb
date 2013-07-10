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
  receiver = params[:receiver]

  return invalid_request if message_params.blank? or receiver.blank?

  r_user = User.find_by_params(receiver)

  return invalid_request if r_user.blank?
  
  gab = Gab.my_create(@user, r_user, r_user.email, r_user.phone) #TODO fix my_create 
  message = gab.create_message_from_params(message_params)  
  
  ok gab
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
  return invalid_request 
  #TODO we do not have any characteristics users can change yet
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

post '/gabs/:gab_id/clues/request' do
  number = params[:number]
  return invalid_request if number.nil
  clue = gab.clues.find(:number => number.to_i)
  return invalid_request if clue.nil?
  if clue.reveal.nil?
    err 400, "request failed"
  else
    ok :clue => clue
  end
end

delete '/gabs/:gab_id/messages/:message_id' do
  return invalid_request #TODO we do not support deleting a message
end

# users in actions
# featured-users 
# buy-clues 
# free-clues
# feedbacks
# check-updates
# ping
