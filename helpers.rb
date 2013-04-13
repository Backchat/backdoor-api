require 'sinatra'
require 'mini_magick'

helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['admin', 'caplabs']
  end

  def sync_data
    old_time = params[:sync_time]
    old_uid = params[:sync_uid]
    provider = params[:provider]

    sync_time = Time.now.to_formatted_s :db
    sync_uid = @user.id.to_s

    avail_clues = @user.available_clues.to_s

    old_time = (old_uid != sync_uid or old_time.blank?) ? Time.at(0) : Time.parse(old_time)

    messages = Message.dump_updated(@user, old_time)
    gabs = Gab.dump_updated(@user, old_time, messages)
    clues = Clue.dump_updated(@user, old_time)
    unread_messages = @user.unread_messages

    logger.info '-----'
    logger.info 'Syncing with time: %s, uid: %s' % [old_time, old_uid]
    logger.info 'Current time: %s, uid: %s' % [sync_time, sync_uid]
    logger.info 'Messages: %d, gabs: %d, clues: %d' % [messages.count, gabs.count, clues.count]
    logger.info 'Avail clues: %d, unread messages: %d' % [avail_clues, unread_messages]
    logger.info '-----'

    return {
      :gabs => gabs,
      :messages => messages,
      :clues => clues,
      :sync_time => sync_time,
      :sync_uid => sync_uid,
      :available_clues => avail_clues,
      :unread_messages => unread_messages,
      :new_user => @new_user
    }
  end
end

def date_sql(column)
  "TO_CHAR(%s, 'YYYY-MM-DD HH24:MI:SS') AS %s" % [column, column]
end


def generate_thumbnail(data)
  io = StringIO.new(data)
  image = MiniMagick::Image.read(io)
  image.resize('220x220')
  io = StringIO.new
  image.write io
  io.seek(0)
  data = io.read
  return data
end

def clue_data(other_user, current_user)
  fb_data = other_user.fb_data
  gpp_data = other_user.gpp_data
  res = {}

  if !fb_data['gender'].nil?
    res[:gender] = fb_data['gender']
  elsif !gpp_data['gender'].nil?
    res[:gender] = gpp_data['gender']
  end

  if gpp_data['placesLived'].nil?
    gpp_place = nil
  else
    gpp_place = gpp_data['placesLived'].select{ |x| x['primary'] == '1' }[0]
  end

  if !fb_data['location'].nil? && !fb_data['location']['name'].nil?
    res[:location] = fb_data['location']['name']
  elsif !gpp_place.nil?
    res[:location] = gpp_place['value']
  end

  fb_family = fb_data['family']
  if !fb_family.nil? && fb_family.kind_of?(Array) && fb_family.count > 0
    fb_mems = fb_family.map { |x| x['id'] }
    res[:family] = fb_mems.include?(current_user.fb_id)
  end

  fb_work = fb_data['work']
  if !fb_work.nil? && fb_work.kind_of?(Array) && fb_work.count > 0
    fb_work = fb_work[0]
  else
    fb_work = nil
  end

  gpp_work = gpp_data['organizations']
  if !gpp_work.nil?
    gpp_work = gpp_work.select {|x| x['type'] == 'school' }
  else
    gpp_work = []
  end

  gpp_work_prim = gpp_work.select { |x| x['primary'] == '1' }

  if gpp_work_prim.count > 0
    gpp_work = gpp_work_prim[0]
  else
    gpp_work = gpp_work[0]
  end

  if !fb_work.nil? && !fb_work['employer'].nil? && !fb_work['employer']['name'].nil?
    res[:work] = fb_work['employer']['name']
  elsif !gpp_work.nil?
    res[:work] = gpp_work['name']
  end

  fb_edu = fb_data['education']
  if !fb_edu.nil? && fb_edu.kind_of?(Array)
    fb_edu = fb_edu[0]
  else
    fb_edu = nil
  end

  gpp_edu = gpp_data['organizations']
  if !gpp_edu.nil?
    gpp_edu = gpp_edu.select {|x| x['type'] == 'school' }
  else
    gpp_edu = []
  end

  gpp_edu_prim = gpp_edu.select { |x| x['primary'] == '1' }

  if gpp_edu_prim.count > 0
    gpp_edu = gpp_edu_prim[0]
  else
    gpp_edu = gpp_edu[0]
  end

  if !fb_edu.nil? && !fb_edu['school'].nil? && !fb_edu['school']['name'].nil?
    res[:edu] = fb_edu['school']['name']
  elsif !gpp_edu.nil?
    res[:edu] = gpp_edu['name']
  end

  res
end
