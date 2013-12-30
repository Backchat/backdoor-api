require 'sinatra'
require 'mini_magick'
require './datahelper'
require 'securerandom'


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

def random_key
  SecureRandom.hex[0..7]
end

def update_fb_data(user, access_token, fb_data)
  has_name_already = user.has_name?
  user.update_fb_data(fb_data)

  if user.has_name?
    Resque.enqueue(UpdateFriendsQueue, user.id, access_token,
                   !has_name_already, Friendship::FACEBOOK_PROVIDER)
  end
end

def update_gpp_data(user, access_token, gpp_data)
  has_name_already = user.has_name?
  user.update_gpp_data(gpp_data)

  if user.has_name?
    #get gpp friendships every time
    Resque.enqueue(UpdateFriendsQueue, user.id, access_token,
                   !has_name_already, Friendship::GPP_PROVIDER)
  end
end
