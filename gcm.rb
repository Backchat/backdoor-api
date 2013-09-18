class GCM
  def initialize(secret_key)
    @client = HTTPClient.new
    @url = 'https://android.googleapis.com/gcm/send'
    @secret_key = secret_key
  end

  def push device_tokens, data
    headers = {
      'Authorization' => "key=#{@secret_key}",
      'Content-Type' => 'application/json'
    }
    full_data = {
      "registration_ids" => device_tokens,
      "data" => data
    }

    resp = @client.post(@url, full_data.to_json, headers)
    ActiveRecord::Base.logger.info resp.content
    #TODO handle response codes
  end
end
