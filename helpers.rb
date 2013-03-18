require 'sinatra'

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

    old_time = (old_uid != sync_uid or old_time.blank?) ? Time.at(0) : Time.parse(old_time)

    messages = Message.dump_updated(@user, old_time)
    gabs = Gab.dump_updated(@user, old_time, messages)

    return {
      :gabs => gabs,
      :messages => messages,
      :sync_time => sync_time,
      :sync_uid => sync_uid
    }
  end
end

def date_sql(column)
  "TO_CHAR(%s, 'YYYY-MM-DD HH24:MI:SS') AS %s" % [column, column]
end
