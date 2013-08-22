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

    #TODO refactor this fuck
    if r_user.fb_id.present?
      related_name = r_user.fb_data['name'] || ''
    elsif r_user.gpp_id.present?
      related_name = r_user.gpp_data['displayName'] || ''
    end
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
  @gab.related_user_name = params[:related_user_name] if params[:related_user_name].present?
  @gab.unread_count = params[:unread_count] if params[:unread_count].present?

  if @gab.changed?
    @gab.save
    hsh = @gab.as_json
    if params[:total_unread_count].present?
      hsh[:total_unread_count] = @user.unread_messages
    end
    ok hsh
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
    ok :message => message.as_json()["message"], :gab => @gab.as_json()["gab"]
  end
end

get '/gabs/:gab_id/clues/' do
  #TODO test this
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
  #TODO test
  #get information about myself
  ok @user
end

post '/' do
  #TODO test
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

post '/invites' do
  invite_params = params[:invite]
  contact_params = params[:contact]
  return invalid_request unless invite_params && contact_params
  return invalid_request unless contact_params[:phone_number]

  contact = Contact.find_by_phone_number contact_params[:phone_number]
  contact = Contact.create!(phone_number: contact_params[:phone_number], enabled: true) unless contact

  invitation = @user.invitations.build(contact_id: contact.id,
                                       body: invite_params[:body],
                                       delivered: false)
  if !invitation.save
    err 400, invitations.errors
  else
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
