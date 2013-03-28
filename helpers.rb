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

    sync_time = Time.now.to_formatted_s :db
    sync_uid = @user.data['id']

    avail_clues = @user.available_clues.to_s

    old_time = (old_uid != sync_uid or old_time.blank?) ? Time.at(0) : Time.parse(old_time)

    messages = Message.dump_updated(@user, old_time)
    gabs = Gab.dump_updated(@user, old_time, messages)
    clues = Clue.dump_updated(@user, old_time)

    logger.info '-----'
    logger.info 'Syncing with time: %s, uid: %s' % [old_time, old_uid]
    logger.info 'Current time: %s, uid: %s' % [sync_time, sync_uid]
    logger.info 'Messages: %d, gabs: %d, clues: %d' % [messages.count, gabs.count, clues.count]
    logger.info '-----'

    return {
      :gabs => gabs,
      :messages => messages,
      :clues => clues,
      :sync_time => sync_time,
      :sync_uid => sync_uid,
      :available_clues => avail_clues
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
