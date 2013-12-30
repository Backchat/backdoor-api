# CRUD apis for data
# gab
# before in actions.rb gets us validated and gets us the @user

def invalid_request
  err 400, 'invalid_request'
end

get '/gabs' do
  ok :gabs => @user.gabs.where("total_count > 0").all.map{|g| g.as_json()["gab"]}
end

post '/gabs' do
  message_params = params[:message]
  return invalid_request if message_params.blank?

  related_name = nil

  if params[:friendship]
    receiver = params[:friendship]
    r_friendship = Friendship.find_by_id(receiver[:id])

    #TODO add tests for this
    return err(400, 'friendship does not exist') if r_friendship.blank?
    return invalid_request if r_friendship.user != @user

    r_user = r_friendship.friend
    related_name = r_friendship.name
  elsif params[:featured]
    return invalid_request unless params[:featured][:id].present?
    id = params[:featured][:id]

    r_user = User.find(id)
    return invalid_request if r_user.nil? || r_user == @user

    related_name = r_user.name
  else
    return invalid_request
  end

  gab = Gab.my_create(@user, r_user, related_name, r_user.phone) #TODO fix my_create 
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
  if params[:unread_count].present?
    @gab.update_column(:unread_count, params[:unread_count])
  end

  if params[:related_user_name].present?
    @gab.related_user_name = params[:related_user_name] 
    @gab.save
  end

  hsh = @gab.as_json
  if params[:total_unread_count].present?
    hsh[:total_unread_count] = @user.unread_messages
  end

  ok hsh
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
    ok :message => message.as_json()["message"], :gab => @gab.as_json()["gab"]
  end
end

get '/gabs/:gab_id/clues' do
  #TODO test this
  hsh = {clues: @gab.clues.revealed.all.map {|c| c.as_json()["clue"]}}
  hsh[:available_clues] = @user.available_clues
  ok hsh
end

#for back compat...
get '/gabs/:gab_id/clues/' do
  #TODO test this
  #TODO merge this
  hsh = {clues: @gab.clues.revealed.all.map {|c| c.as_json()["clue"]}}
  hsh[:available_clues] = @user.available_clues
  ok hsh
end

post '/gabs/:gab_id/clues/request/:number' do
  number = params[:number].to_i
  clue = @gab.clues.find_by_number(number)
  return invalid_request if clue.nil?
  if clue.reveal.nil?
    err 400, "request failed"
  else
    hsh = clue.as_json
    hsh[:available_clues] = @user.available_clues
    ok hsh
  end
end

delete '/gabs/:gab_id/messages/:message_id' do
  return invalid_request #TODO we do not support deleting a message
end

get '/friends' do
  ok :friends => @user.friendships.map{|f| f.as_json["friendship"]}
end

get '/' do
  #TODO test
  #get information about myself
  ok @user
end

post '/' do
  #TODO test
  unless params[:fb_data].blank?
    input = params[:fb_data].encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    fb_data = JSON.parse(input)
    update_fb_data(@user, @access_token, fb_data)
    @user.save
    return ok
  end

  unless params[:gpp_data].blank?
    input = params[:gpp_data].encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    gpp_data = JSON.parse(input)
    update_gpp_data(@user, @access_token, gpp_data)
    @user.save
    return ok
  end

  if params[:settings]
    @user.settings["message_preview"] = params[:settings][:message_preview]
    @user.save
    return ok
  end
end

post '/invites' do
  invite_params = params[:invite]
  contact_params = params[:contact]
  return invalid_request unless invite_params && contact_params
  return invalid_request unless contact_params[:phone_number] || contact_params[:phone_numbers]

  contacts = [contact_params[:phone_number]]
  contacts.concat contact_params[:phone_numbers] if contact_params[:phone_numbers]
  contacts.compact!

  Resque.enqueue(InviteSMSParseQueue, contacts, invite_params[:body], @user.id)

  ok 
end

post '/devices' do
  #register a new device:
  return invalid_request if params[:device_token].blank? 
  kind = params[:kind]
  kind = Device::APPLE if kind.blank? #back-compat: assume APN unless otherwise
  kind.upcase!
  device = Device.my_find_or_create(params[:device_token], kind, @user)
  ok
end
                                
# users in actions
# featured-users 
# buy-clues 
# free-clues
# feedbacks
# check-updates
# ping
