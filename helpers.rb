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
