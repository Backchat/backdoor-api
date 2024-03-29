class ApiError < Exception
  def initialize(data)
    @code = data[0]
    @message = data[1]
  end

  def code
    @code
  end

  def message
    @message
  end
end

class ApiSuccess < Exception
  def initialize(data)
    @data = data
  end

  def data
    @data
  end
end

def err(code, msg)
  status code
  return resp false, msg
end

def ok(res = {})
  return resp(true, res)
end

def resp(ok, data)
  content_type 'application/json'

  {
    'status' => ok ? 'ok' : 'error',
    'response' => data
  }.to_json
end

error ActiveRecord::RecordNotFound  do
  status 404
  resp false, 'not found'
end

error do
  boom = env['sinatra.error']
  msg = ["#{boom.class} - #{boom.message}:", *boom.backtrace].join("\n\t")
  @env['rack.errors'].puts(msg)

  status 500
  {
    'status' => 'error',
    'response' => 'Unexpected error: ' + env['sinatra.error'].message
  }.to_json
end
